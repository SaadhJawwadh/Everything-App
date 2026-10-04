import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:note_taking_app/features/notes/data/note_repository.dart';
import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/data/note_model.dart';
import 'package:note_taking_app/data/database_constants.dart';

void main() {
  // Setup sqflite_common_ffi for flutter test
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('NoteRepository clearOldTrash Tests', () {
    late Database db;
    late NoteRepository repository;

    setUp(() async {
      // Open fresh in-memory database
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      
      // Initialize schemas
      await DatabaseHelper.instance.createTestDatabase(db);
      
      // Inject database helper mock
      DatabaseHelper.setMockDatabase(db);
      
      repository = NoteRepository();
    });

    tearDown(() async {
      await db.close();
      DatabaseHelper.setMockDatabase(null);
    });

    test('clearOldTrash purges notes deleted > 7 days ago, but retains recent/active notes', () async {
      final now = DateTime.now();
      
      // 1. Note A: deleted 8 days ago (should be cleared)
      final noteA = Note(
        id: 'note_a_old_trash',
        title: 'Old Trash Note',
        content: 'This note was deleted 8 days ago.',
        dateCreated: now.subtract(const Duration(days: 10)),
        dateModified: now.subtract(const Duration(days: 8)),
        deletedAt: now.subtract(const Duration(days: 8)),
        tags: ['OldTag'],
      );

      // 2. Note B: deleted 3 days ago (should be retained)
      final noteB = Note(
        id: 'note_b_recent_trash',
        title: 'Recent Trash Note',
        content: 'This note was deleted 3 days ago.',
        dateCreated: now.subtract(const Duration(days: 5)),
        dateModified: now.subtract(const Duration(days: 3)),
        deletedAt: now.subtract(const Duration(days: 3)),
        tags: ['RecentTag'],
      );

      // 3. Note C: active note / not deleted (should be retained)
      final noteC = Note(
        id: 'note_c_active',
        title: 'Active Note',
        content: 'This note is not deleted.',
        dateCreated: now.subtract(const Duration(days: 2)),
        dateModified: now,
        deletedAt: null,
        tags: ['ActiveTag'],
      );

      // Insert all notes via repository
      await repository.createNote(noteA);
      await repository.createNote(noteB);
      await repository.createNote(noteC);

      // Verify they are created successfully in the DB
      final initialNotes = await db.query(TableNames.notes);
      expect(initialNotes.length, 3);

      final initialTags = await db.query('note_tags');
      expect(initialTags.length, 3);

      // Call clearOldTrash
      await repository.clearOldTrash();

      // Verify DB contents after purging
      final remainingNotes = await db.query(TableNames.notes);
      expect(remainingNotes.length, 2);

      // Verify which notes remain
      final remainingIds = remainingNotes.map((r) => r[NoteFields.id] as String).toList();
      expect(remainingIds.contains('note_b_recent_trash'), true);
      expect(remainingIds.contains('note_c_active'), true);
      expect(remainingIds.contains('note_a_old_trash'), false);

      // Verify tags are cleaned up properly
      final remainingTags = await db.query('note_tags');
      expect(remainingTags.length, 2);
      final remainingTagNoteIds = remainingTags.map((t) => t['note_id'] as String).toList();
      expect(remainingTagNoteIds.contains('note_b_recent_trash'), true);
      expect(remainingTagNoteIds.contains('note_c_active'), true);
      expect(remainingTagNoteIds.contains('note_a_old_trash'), false);
    });
  });

  group('NoteRepository Bulk Operations P2P Timestamp Advancement Tests', () {
    late Database db;
    late NoteRepository repository;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseHelper.instance.createTestDatabase(db);
      DatabaseHelper.setMockDatabase(db);
      repository = NoteRepository();
    });

    tearDown(() async {
      await db.close();
      DatabaseHelper.setMockDatabase(null);
    });

    test('bulkSetPinned, bulkArchive, bulkDelete, and bulkTag advance dateModified', () async {
      final past = DateTime.now().subtract(const Duration(days: 5));
      final note1 = Note(
        id: 'bulk_1',
        title: 'Bulk Note 1',
        content: 'Content 1',
        dateCreated: past,
        dateModified: past,
      );
      final note2 = Note(
        id: 'bulk_2',
        title: 'Bulk Note 2',
        content: 'Content 2',
        dateCreated: past,
        dateModified: past,
      );

      await repository.createNote(note1);
      await repository.createNote(note2);

      // 1. Verify bulkSetPinned updates dateModified
      await Future.delayed(const Duration(milliseconds: 10));
      await repository.bulkSetPinned(['bulk_1', 'bulk_2'], true);

      var read1 = await repository.readNote('bulk_1');
      var read2 = await repository.readNote('bulk_2');
      expect(read1!.isPinned, true);
      expect(read2!.isPinned, true);
      expect(read1.dateModified.isAfter(past), true);
      expect(read2.dateModified.isAfter(past), true);

      final postPinTime = read1.dateModified;

      // 2. Verify bulkArchive updates dateModified
      await Future.delayed(const Duration(milliseconds: 10));
      await repository.bulkArchive(['bulk_1'], true);

      read1 = await repository.readNote('bulk_1');
      expect(read1!.isArchived, true);
      expect(read1.dateModified.isAfter(postPinTime), true);

      final postArchiveTime = read1.dateModified;

      // 3. Verify bulkTag updates dateModified
      await Future.delayed(const Duration(milliseconds: 10));
      await repository.bulkTag(['bulk_1', 'bulk_2'], ['ProjectA']);

      read1 = await repository.readNote('bulk_1');
      read2 = await repository.readNote('bulk_2');
      expect(read1!.tags.contains('ProjectA'), true);
      expect(read2!.tags.contains('ProjectA'), true);
      expect(read1.dateModified.isAfter(postArchiveTime), true);

      // 4. Verify bulkDelete updates dateModified
      final preDeleteTime = read2.dateModified;
      await Future.delayed(const Duration(milliseconds: 10));
      await repository.bulkDelete(['bulk_2']);

      final deletedRows = await db.query(TableNames.notes, where: 'id = ?', whereArgs: ['bulk_2']);
      expect(deletedRows.isNotEmpty, true);
      final deletedMod = DateTime.parse(deletedRows.first[NoteFields.dateModified] as String);
      expect(deletedMod.isAfter(preDeleteTime), true);
    });

    test('getChecklistNotesCount returns accurate count of active checklist notes', () async {
      final now = DateTime.now();

      // Note 1: Active with checklist
      await repository.createNote(Note(
        id: 'chk_1',
        title: 'Groceries',
        content: '[{"insert":"Milk"},{"attributes":{"list":"unchecked"},"insert":"\\n"}]',
        dateCreated: now,
        dateModified: now,
        category: 'Personal',
      ));

      // Note 2: Active with markdown checklist
      await repository.createNote(Note(
        id: 'chk_2',
        title: 'Work Tasks',
        content: '- [ ] Complete design review\n- [x] Send invoice',
        dateCreated: now,
        dateModified: now,
        category: 'Work',
      ));

      // Note 3: Active plain note (no checklist)
      await repository.createNote(Note(
        id: 'chk_3',
        title: 'Meeting Notes',
        content: 'Just general discussion notes here.',
        dateCreated: now,
        dateModified: now,
        category: 'Work',
      ));

      // Note 4: Archived checklist note
      await repository.createNote(Note(
        id: 'chk_4',
        title: 'Old Tasks',
        content: '- [x] Done task',
        dateCreated: now,
        dateModified: now,
        isArchived: true,
        category: 'Work',
      ));

      // Note 5: Trashed checklist note
      await repository.createNote(Note(
        id: 'chk_5',
        title: 'Trashed Tasks',
        content: '- [ ] Dropped task',
        dateCreated: now,
        dateModified: now,
        deletedAt: now,
        category: 'Personal',
      ));

      final totalCount = await repository.getChecklistNotesCount();
      expect(totalCount, 2);

      final workCount = await repository.getChecklistNotesCount(folder: 'Work');
      expect(workCount, 1);

      final personalCount = await repository.getChecklistNotesCount(folder: 'Personal');
      expect(personalCount, 1);
    });
  });
}
