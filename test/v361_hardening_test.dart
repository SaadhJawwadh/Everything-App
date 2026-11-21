import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/data/database_constants.dart';
import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/data/period_log_model.dart';
import 'package:note_taking_app/data/transaction_model.dart';
import 'package:note_taking_app/features/finances/presentation/widgets/financial_analytics_tab.dart';
import 'package:note_taking_app/features/notes/data/note_repository.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/features/story_cards/presentation/widgets/story_card_studio_sheet.dart';
import 'package:note_taking_app/services/backup_service.dart';
import 'package:note_taking_app/services/backup_vault_key_service.dart';
import 'package:note_taking_app/services/sync_crypto_service.dart';
import 'package:note_taking_app/services/sync_merge_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() {
    BackupVaultKeyService.mockVaultKeyForTest = null;
    BackupVaultKeyService.simulateReadFailureForTest = false;
  });

  group('BackupVaultKeyService & BackupService v3 hardening', () {
    test('BackupVaultKeyService fails closed when initialized key cannot be read', () async {
      SharedPreferences.setMockInitialValues({'autoBackupVaultInitialized': true});
      BackupVaultKeyService.simulateReadFailureForTest = true;

      final key = await BackupVaultKeyService.instance.getOrCreateVaultKey();
      expect(key, isNull);
    });

    test('BackupService rejects v3 container with missing mac and round-trips keySource vault', () {
      const rawJson = '{"notes":[],"version":11}';
      const vaultKey = 'test_vault_secret_key_32bytes_123456';

      final encrypted = BackupService.encryptBackupJson(rawJson, vaultKey, keySource: 'vault');
      final container = json.decode(encrypted) as Map<String, dynamic>;
      expect(container['version'], 3);
      expect(container['keySource'], 'vault');
      expect(BackupService.decryptBackupJson(container, vaultKey), rawJson);

      container.remove('mac');
      expect(
        () => BackupService.decryptBackupJson(container, vaultKey),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('SyncCryptoService v3 Encrypt-then-MAC & v2/v1 compatibility', () {
    test('encryptPayload emits v3 with mac and rejects tampered mac without fallback', () {
      const secret = 'PAIR_CODE_9988';
      const payload = '{"notes":[{"id":"n1","title":"Hello"}]}';

      final encryptedB64 = SyncCryptoService.instance.encryptPayload(payload, secret);
      expect(encryptedB64, isNotNull);

      final envelope = json.decode(utf8.decode(base64.decode(encryptedB64!))) as Map<String, dynamic>;
      expect(envelope['v'], 3);
      expect(envelope['mac'], isA<String>());
      expect((envelope['mac'] as String).isNotEmpty, isTrue);

      final (decrypted, usedLegacy) = SyncCryptoService.instance.decryptPayloadDetailed(encryptedB64, secret);
      expect(decrypted, payload);
      expect(usedLegacy, isFalse);

      // Tamper MAC -> must return null with no fallback
      envelope['mac'] = base64.encode(List<int>.filled(32, 0xAA));
      final tamperedB64 = base64.encode(utf8.encode(json.encode(envelope)));
      final (tamperedDecrypted, _) = SyncCryptoService.instance.decryptPayloadDetailed(tamperedB64, secret);
      expect(tamperedDecrypted, isNull);

      // Strip MAC on v3 -> must also fail closed
      envelope.remove('mac');
      final strippedB64 = base64.encode(utf8.encode(json.encode(envelope)));
      final (strippedDecrypted, _) = SyncCryptoService.instance.decryptPayloadDetailed(strippedB64, secret);
      expect(strippedDecrypted, isNull);
    });
  });

  group('Finance Analytics Transfer Exclusion', () {
    testWidgets('FinancialAnalyticsTab excludes Transfer category from donut & totals', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();
      await settings.loadSettings();

      final now = DateTime.now();
      final txs = [
        TransactionModel(amount: 500, description: 'Vault Move', date: now, isExpense: true, category: 'Transfer'),
        TransactionModel(amount: 120, description: 'Lunch', date: now, isExpense: true, category: 'Food'),
      ];
      expect(txs.first.isTransfer, isTrue);
      expect(txs.last.isTransfer, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                FinancialAnalyticsTab(
                  transactions: txs,
                  monthlyData: const [],
                  currentMonthCategoryExpenses: const {'Food': 120},
                  currency: 'LKR',
                  settings: settings,
                  onRefresh: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 Categories'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Transfer'), findsNothing);
    });
  });

  group('DB v27 Migration, Full-Body Note Search & Cross-Version Merge', () {
    test('Upgrades v26 -> v27, backfills searchText & updatedAt, and searches safely', () async {
      const dbPath = 'v361_v27_migration_test.db';
      if (await databaseFactory.databaseExists(dbPath)) {
        await databaseFactory.deleteDatabase(dbPath);
      }

      final v26Db = await openDatabase(
        dbPath,
        version: 26,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE ${TableNames.notes} (
              id TEXT PRIMARY KEY, title TEXT NOT NULL, content TEXT NOT NULL,
              dateCreated TEXT NOT NULL, dateModified TEXT NOT NULL,
              color INTEGER NOT NULL, isPinned INTEGER NOT NULL,
              isArchived INTEGER NOT NULL DEFAULT 0, imagePath TEXT,
              category TEXT, tags TEXT, previewText TEXT, deletedAt TEXT,
              reminderAt TEXT, isLocked INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('CREATE TABLE ${TableNames.tags} (name TEXT PRIMARY KEY, color INTEGER NOT NULL)');
          await db.execute('CREATE TABLE note_tags (note_id TEXT NOT NULL, tag_name TEXT NOT NULL, PRIMARY KEY (note_id, tag_name))');
          await db.execute('''
            CREATE TABLE ${TableNames.periodLogs} (
              id TEXT PRIMARY KEY, startDate TEXT NOT NULL, endDate TEXT,
              intensity TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '',
              symptoms TEXT NOT NULL DEFAULT '[]'
            )
          ''');
          await db.execute('CREATE TABLE ${TableNames.recurringRules} (id TEXT PRIMARY KEY, description TEXT NOT NULL, amount REAL NOT NULL, category TEXT NOT NULL, isExpense INTEGER NOT NULL, frequency TEXT NOT NULL, nextDue TEXT NOT NULL)');

          final longDelta = json.encode([
            {'insert': 'Line 1\nLine 2\nLine 3\nLine 4\nLine 5\nLine 6\nLine 7 secretneedle\n', 'attributes': {'bold': true}},
          ]);
          await db.insert(TableNames.notes, {
            'id': 'n_unlocked',
            'title': 'Long Note',
            'content': longDelta,
            'dateCreated': '2026-11-01T00:00:00.000',
            'dateModified': '2026-11-01T00:00:00.000',
            'color': 0,
            'isPinned': 0,
            'previewText': 'Line 1',
            'isLocked': 0,
          });
          await db.insert(TableNames.notes, {
            'id': 'n_locked',
            'title': 'Private',
            'content': json.encode([{'insert': 'secretneedle hidden\n'}]),
            'dateCreated': '2026-11-01T00:00:00.000',
            'dateModified': '2026-11-01T00:00:00.000',
            'color': 0,
            'isPinned': 0,
            'previewText': '',
            'isLocked': 1,
          });
          await db.insert(TableNames.periodLogs, {
            'id': 'p1',
            'startDate': '2026-11-01T00:00:00.000',
            'endDate': '2026-11-05T00:00:00.000',
            'intensity': 'Medium',
          });
        },
      );
      await v26Db.close();

      final db = await openDatabase(
        dbPath,
        version: 27,
        onUpgrade: (db, oldV, newV) => DatabaseHelper.instance.upgradeTestDatabase(db, oldV, newV),
      );
      DatabaseHelper.setMockDatabase(db);
      addTearDown(() async {
        DatabaseHelper.setMockDatabase(null);
        await db.close();
        if (await databaseFactory.databaseExists(dbPath)) {
          await databaseFactory.deleteDatabase(dbPath);
        }
      });

      final periodRows = await db.query(TableNames.periodLogs, where: 'id = ?', whereArgs: ['p1']);
      expect(periodRows.first['updatedAt'], '2026-11-05T00:00:00.000');
      expect(PeriodLog.fromMap(periodRows.first).updatedAt, isNotNull);

      // Search finds line 7 on unlocked note, ignores locked body, and does NOT match Quill JSON "attributes"
      final bodyMatches = await NoteRepository.instance.searchNotes('secretneedle');
      expect(bodyMatches.map((n) => n.id).toList(), ['n_unlocked']);

      final jsonKeyMatches = await NoteRepository.instance.searchNotes('attributes');
      expect(jsonKeyMatches, isEmpty);
    });

    test('SyncMergeService strips unknown columns from remote period_logs & notes', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 27,
        onCreate: (db, v) => DatabaseHelper.instance.createTestDatabase(db),
      );
      DatabaseHelper.setMockDatabase(db);
      addTearDown(() async {
        DatabaseHelper.setMockDatabase(null);
        await db.close();
      });

      final result = await SyncMergeService.instance.mergeRemoteData({
        'notes': [
          {
            'id': 'remote_n1',
            'title': 'Synced',
            'content': '[{"insert":"Hello\\n"}]',
            'dateCreated': '2026-11-10T00:00:00.000',
            'dateModified': '2026-11-10T00:00:00.000',
            'color': 0,
            'isPinned': 0,
            'futureUnknownCol': 'should_be_stripped',
          },
        ],
        'periodLogs': [
          {
            'id': 'remote_p1',
            'startDate': '2026-11-10T00:00:00.000',
            'intensity': 'Light',
            'futureUnknownCol': 123,
          },
        ],
      });
      expect(result.notesMerged, 1);
      expect(result.periodLogsMerged, 1);
    });
  });

  group('SettingsProvider Backup Parity & Story Card GenAI Gating', () {
    test('SettingsProvider round-trips categoryBudgets and security toggles', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = SettingsProvider();
      await provider.loadSettings();
      await provider.setCategoryBudget('Food', 250.0);
      await provider.setLockFinances(true);
      await provider.setLockHealth(true);
      await provider.setScreenshotShieldEnabled(true);

      final backupMap = provider.toBackupMap();
      expect((backupMap['categoryBudgets'] as Map)['Food'], 250.0);
      expect(backupMap['lockFinances'], isTrue);
      expect(backupMap['lockHealth'], isTrue);
      expect(backupMap['screenshotShieldEnabled'], isTrue);

      final restored = SettingsProvider();
      await restored.loadSettings();
      await restored.restoreFromBackupMap(backupMap);
      expect(restored.categoryBudgets['Food'], 250.0);
      expect(restored.lockFinances, isTrue);
      expect(restored.lockHealth, isTrue);
      expect(restored.screenshotShieldEnabled, isTrue);
    });

    testWidgets('StoryCardStudioSheet hides AI Highlight when isGenAiActive is false', (tester) async {
      SharedPreferences.setMockInitialValues({'useOnDeviceAi': true});
      final settings = SettingsProvider();
      await settings.loadSettings();
      expect(settings.isGenAiActive, isFalse);

      final longText = List.filled(45, 'word').join(' ');
      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(
            home: Scaffold(
              body: StoryCardStudioSheet(
                initialText: longText,
                noteTitle: 'Long Note',
                category: 'Notes',
                noteColorValue: 0xFF252529,
                noteDate: DateTime(2026, 11, 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Highlight'), findsNothing);
    });
  });
}
