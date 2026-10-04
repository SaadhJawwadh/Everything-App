import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/widgets/whats_new_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Backward Compatibility & Schema Upgrade Tests', () {
    test('Simulate upgrading an old database from v1 directly to v19', () async {
      const dbPath = 'upgrade_migration_test.db';
      if (await databaseFactory.databaseExists(dbPath)) {
        await databaseFactory.deleteDatabase(dbPath);
      }

      // 1. Create a raw SQLite database at version 1 with only the initial notes table
      final db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE notes (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              content TEXT NOT NULL,
              dateCreated TEXT NOT NULL,
              dateModified TEXT NOT NULL,
              color INTEGER NOT NULL,
              isPinned INTEGER NOT NULL,
              category TEXT
            )
          ''');
          // Insert a legacy note from v1
          await db.insert('notes', {
            'id': 'legacy_v1_note_1',
            'title': 'My Old Note',
            'content': '[{"insert":"Hello from v1\\n"}]',
            'dateCreated': '2025-01-01T00:00:00.000',
            'dateModified': '2025-01-01T00:00:00.000',
            'color': 0,
            'isPinned': 0,
            'category': 'Personal',
          });
        },
      );

      // Verify the legacy note is in the DB
      final v1Notes = await db.query('notes');
      expect(v1Notes.length, 1);
      expect(v1Notes.first['title'], 'My Old Note');
      await db.close();

      // 2. Open the same database at version 19 with _upgradeDB
      final upgradedDb = await openDatabase(
        dbPath,
        version: 19,
        onUpgrade: (db, oldVersion, newVersion) async {
          await DatabaseHelper.instance.upgradeTestDatabase(db, oldVersion, newVersion);
        },
      );

      // Verify all new tables exist in upgraded DB
      final tables = await upgradedDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      expect(tableNames.contains('notes'), isTrue);
      expect(tableNames.contains('tags'), isTrue);
      expect(tableNames.contains('note_tags'), isTrue);
      expect(tableNames.contains('transactions'), isTrue);
      expect(tableNames.contains('category_definitions'), isTrue);
      expect(tableNames.contains('sms_contacts'), isTrue);
      expect(tableNames.contains('period_logs'), isTrue);
      expect(tableNames.contains('recurring_rules'), isTrue);
      expect(tableNames.contains('deleted_notes'), isTrue);
      expect(tableNames.contains('deleted_transaction_sms_ids'), isTrue);

      // Verify legacy note was preserved and new columns were defaulted safely
      final upgradedNotes = await upgradedDb.query('notes', where: 'id = ?', whereArgs: ['legacy_v1_note_1']);
      expect(upgradedNotes.length, 1);
      expect(upgradedNotes.first['title'], 'My Old Note');
      expect(upgradedNotes.first['isArchived'], 0);
      expect(upgradedNotes.first['isLocked'], 0);
      expect(upgradedNotes.first['deletedAt'], isNull);

      await upgradedDb.close();
      if (await databaseFactory.databaseExists(dbPath)) {
        await databaseFactory.deleteDatabase(dbPath);
      }
    });

    test('SettingsProvider loads gracefully with empty or legacy SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'hasSeenOnboarding_v1': true,
        'lastSeenVersion': '2.19.0',
        'isGridView': true, // Legacy boolean key
        // No showFinancialManager, isPeriodTrackerEnabled, categoryBudgets, or showProTips
      });

      final settings = SettingsProvider();
      await settings.loadSettings();

      // Verify graceful fallback defaults
      expect(settings.hasSeenOnboarding, isTrue); // Should NOT re-trigger onboarding
      expect(settings.lastSeenVersion, '2.19.0');
      expect(settings.isGridView, isTrue);
      expect(settings.showFinancialManager, isFalse);
      expect(settings.isPeriodTrackerEnabled, isFalse);
      expect(settings.showProTips, isTrue);
      expect(settings.categoryBudgets, isEmpty);
      expect(settings.trashAutoPurgeDays, 30);
    });

    testWidgets('WhatsNewSheet renders v2.45.0 cards and records version on dismiss', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        'lastSeenVersion': '2.44.0',
      });
      final settings = SettingsProvider();
      await settings.loadSettings();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            home: Scaffold(
              body: WhatsNewSheet(currentVersion: '2.45.0'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check categories
      expect(find.text("New Features"), findsOneWidget);
      expect(find.text("Improvements"), findsOneWidget);
      expect(find.text("Fixes"), findsOneWidget);

      // Check marquee items
      expect(find.text("Story Card Reader Mode"), findsOneWidget);
      expect(find.text("Inter-Vault Account Transfers"), findsOneWidget);
      expect(find.text("In-Note Links & Expenses"), findsOneWidget);
      expect(find.text("Checklist Drag & Drop"), findsOneWidget);
      expect(find.text("P2P Sync Audit Activity"), findsOneWidget);

      // Tap "Awesome, Got It!" to finish
      await tester.runAsync(() async {
        await tester.tap(find.text('Awesome, Got It!'));
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(settings.lastSeenVersion, '2.45.0');
    });
  });
}
