import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/services/sync_merge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SyncMergeService Non-Destructive Delta Merge Tests', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseHelper.instance.createTestDatabase(db);
      DatabaseHelper.setMockDatabase(db);
    });

    tearDown(() async {
      await db.close();
      DatabaseHelper.setMockDatabase(null);
    });

    test('merges remote notes using Last-Write-Wins (LWW) without overwriting local data', () async {
      final now = DateTime.now();
      final olderDate = now.subtract(const Duration(hours: 2)).toIso8601String();
      final newerDate = now.toIso8601String();

      // Seed local database with Note A (edited older) and Note B (unique local)
      await db.insert('notes', {
        'id': 'note_a',
        'title': 'Local Note A Old Title',
        'content': 'Local Content A',
        'dateCreated': olderDate,
        'dateModified': olderDate,
        'color': 0,
        'isPinned': 0,
        'isArchived': 0,
        'category': 'Notes',
      });

      await db.insert('notes', {
        'id': 'note_b',
        'title': 'Unique Local Note B',
        'content': 'Local Content B',
        'dateCreated': olderDate,
        'dateModified': olderDate,
        'color': 0,
        'isPinned': 0,
        'isArchived': 0,
        'category': 'Notes',
      });

      // Prepare remote payload containing Note A (newer edit) and Note C (new remote note)
      final remotePayload = {
        'notes': [
          {
            'id': 'note_a',
            'title': 'Updated Remote Note A Title',
            'content': 'Updated Remote Content A',
            'dateCreated': olderDate,
            'dateModified': newerDate,
            'color': 0,
            'isPinned': 1,
            'isArchived': 0,
            'category': 'Notes',
          },
          {
            'id': 'note_c',
            'title': 'New Remote Note C',
            'content': 'Remote Content C',
            'dateCreated': newerDate,
            'dateModified': newerDate,
            'color': 0,
            'isPinned': 0,
            'isArchived': 0,
            'category': 'Notes',
          },
        ]
      };

      final result = await SyncMergeService.instance.mergeRemoteData(remotePayload);

      expect(result.notesMerged, equals(2));

      // Verify all 3 notes exist in local database
      final allNotes = await db.query('notes', orderBy: 'id ASC');
      expect(allNotes.length, equals(3));

      // Note A should be updated to remote newer version
      final noteA = allNotes.firstWhere((n) => n['id'] == 'note_a');
      expect(noteA['title'], equals('Updated Remote Note A Title'));
      expect(noteA['isPinned'], equals(1));

      // Note B should be untouched (not deleted by sync)
      final noteB = allNotes.firstWhere((n) => n['id'] == 'note_b');
      expect(noteB['title'], equals('Unique Local Note B'));

      // Note C should be inserted
      final noteC = allNotes.firstWhere((n) => n['id'] == 'note_c');
      expect(noteC['title'], equals('New Remote Note C'));
    });

    test('merges remote soft-deleted note (deletedAt) into local Trash correctly', () async {
      final now = DateTime.now();
      final olderDate = now.subtract(const Duration(hours: 2)).toIso8601String();
      final newerDate = now.toIso8601String();

      // Seed local active note
      await db.insert('notes', {
        'id': 'note_del',
        'title': 'Active Note To Be Trashed',
        'content': 'Content',
        'dateCreated': olderDate,
        'dateModified': olderDate,
        'color': 0,
        'isPinned': 0,
        'isArchived': 0,
        'category': 'Notes',
        'deletedAt': null,
      });

      // Prepare remote payload where note_del was soft deleted
      final remotePayload = {
        'notes': [
          {
            'id': 'note_del',
            'title': 'Active Note To Be Trashed',
            'content': 'Content',
            'dateCreated': olderDate,
            'dateModified': newerDate,
            'color': 0,
            'isPinned': 0,
            'isArchived': 0,
            'category': 'Notes',
            'deletedAt': newerDate,
          },
        ]
      };

      final result = await SyncMergeService.instance.mergeRemoteData(remotePayload);

      expect(result.notesMerged, equals(1));

      final note = (await db.query('notes', where: 'id = ?', whereArgs: ['note_del'])).first;
      expect(note['deletedAt'], equals(newerDate));
    });

    test('merges remote archived note (isArchived: 1) into local note correctly', () async {
      final now = DateTime.now();
      final olderDate = now.subtract(const Duration(minutes: 10)).toIso8601String();
      final newerDate = now.toIso8601String();

      // Seed local unarchived note
      await db.insert('notes', {
        'id': 'note_arch',
        'title': 'Local Note To Be Archived',
        'content': 'Content',
        'dateCreated': olderDate,
        'dateModified': olderDate,
        'color': 0,
        'isPinned': 0,
        'isArchived': 0,
        'category': 'Notes',
        'deletedAt': null,
      });

      // Remote payload where note_arch was archived on another device
      final remotePayload = {
        'notes': [
          {
            'id': 'note_arch',
            'title': 'Local Note To Be Archived',
            'content': 'Content',
            'dateCreated': olderDate,
            'dateModified': newerDate,
            'color': 0,
            'isPinned': 0,
            'isArchived': 1,
            'category': 'Notes',
            'deletedAt': null,
          },
        ]
      };

      final result = await SyncMergeService.instance.mergeRemoteData(remotePayload);

      expect(result.notesMerged, equals(1));

      final note = (await db.query('notes', where: 'id = ?', whereArgs: ['note_arch'])).first;
      expect(note['isArchived'], equals(1));
    });

    test('merges remote archived note even within 5-second clock skew tolerance', () async {
      final now = DateTime.now();
      final localMod = now.toIso8601String();
      final remoteModWithSkew = now.subtract(const Duration(seconds: 2)).toIso8601String();

      // Seed local unarchived note
      await db.insert('notes', {
        'id': 'note_skew_arch',
        'title': 'Note Clock Skew',
        'content': 'Content',
        'dateCreated': localMod,
        'dateModified': localMod,
        'color': 0,
        'isPinned': 0,
        'isArchived': 0,
        'category': 'Notes',
        'deletedAt': null,
      });

      // Remote payload where note was archived with 2-second clock skew
      final remotePayload = {
        'notes': [
          {
            'id': 'note_skew_arch',
            'title': 'Note Clock Skew',
            'content': 'Content',
            'dateCreated': localMod,
            'dateModified': remoteModWithSkew,
            'color': 0,
            'isPinned': 0,
            'isArchived': 1,
            'category': 'Notes',
            'deletedAt': null,
          },
        ]
      };

      final result = await SyncMergeService.instance.mergeRemoteData(remotePayload);

      expect(result.notesMerged, equals(1));

      final note = (await db.query('notes', where: 'id = ?', whereArgs: ['note_skew_arch'])).first;
      expect(note['isArchived'], equals(1));
    });

    test('normalizes boolean attributes (isLocked, isAiRefined, isPayerUser, hasPaid) to integers', () async {
      final now = DateTime.now().toIso8601String();
      final remotePayload = {
        'notes': [
          {
            'id': 'note_bool_test',
            'title': 'Locked Note',
            'content': 'Locked Content',
            'dateCreated': now,
            'dateModified': now,
            'color': 0,
            'isPinned': false,
            'isArchived': false,
            'isLocked': true, // boolean attribute
            'category': 'Notes',
          },
        ],
        'transactions': [
          {
            'date': now,
            'amount': 25.50,
            'description': 'AI Refined Coffee',
            'category': 'Dining',
            'isExpense': true, // boolean attribute
            'isAiRefined': true, // boolean attribute
            'smsId': 'sms_bool_1',
          },
        ],
        'splitBills': [
          {
            'id': 'split_bool_1',
            'title': 'Dinner Split',
            'totalAmount': 50.0,
            'payerName': 'Me',
            'isPayerUser': true, // boolean attribute
            'date': now,
          },
        ],
        'splitParticipants': [
          {
            'id': 'part_bool_1',
            'billId': 'split_bool_1',
            'contactName': 'Alex',
            'shareAmount': 25.0,
            'hasPaid': true, // boolean attribute
          },
        ],
        'savingsGoals': [
          {
            'id': 'goal_bool_1',
            'title': 'Vacation Fund',
            'targetAmount': 1000.0,
            'currentAmount': 1000.0,
            'isCompleted': true, // boolean attribute
            'createdAt': now,
          },
        ],
      };

      final result = await SyncMergeService.instance.mergeRemoteData(remotePayload);
      expect(result.notesMerged, greaterThanOrEqualTo(1));
      expect(result.transactionsMerged, greaterThanOrEqualTo(1));

      final note = (await db.query('notes', where: 'id = ?', whereArgs: ['note_bool_test'])).first;
      expect(note['isLocked'], equals(1));
      expect(note['isPinned'], equals(0));

      final tx = (await db.query('transactions', where: 'smsId = ?', whereArgs: ['sms_bool_1'])).first;
      expect(tx['isExpense'], equals(1));
      expect(tx['isAiRefined'], equals(1));

      final bill = (await db.query('split_bills', where: 'id = ?', whereArgs: ['split_bool_1'])).first;
      expect(bill['isPayerUser'], equals(1));

      final part = (await db.query('split_participants', where: 'id = ?', whereArgs: ['part_bool_1'])).first;
      expect(part['hasPaid'], equals(1));

      final goal = (await db.query('savings_goals', where: 'id = ?', whereArgs: ['goal_bool_1'])).first;
      expect(goal['isCompleted'], equals(1));
    });
  });
}
