import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:note_taking_app/core/services/app_function_inbox_service.dart';
import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/features/finances/data/transaction_repository.dart';
import 'package:note_taking_app/features/finances/providers/financial_manager_provider.dart';
import 'package:note_taking_app/features/notes/data/note_repository.dart';
import 'package:note_taking_app/features/notes/providers/note_provider.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.saadhjawwadh.notebook/widget'),
      (MethodCall methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.saadhjawwadh.notebook/device_lock'),
      (MethodCall methodCall) async => null,
    );

    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.instance.createTestDatabase(db);
    DatabaseHelper.setMockDatabase(db);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.setMockDatabase(null);
  });

  group('AppFunctionInboxService Tests', () {

    testWidgets('Empty or null queue does nothing and does not throw', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => AppFunctionInboxService.drainPendingQueue(context),
                  child: const Text('Drain'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Drain'));
      await tester.pump();

      await tester.runAsync(() async {
        final txs = await TransactionRepository.instance.readAllTransactions();
        expect(txs, isEmpty);
      });
    });

    testWidgets('Corrupt JSON queue is safely caught and cleared', (tester) async {
      SharedPreferences.setMockInitialValues({
        AppFunctionInboxService.queueKey: '{corrupt json',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => AppFunctionInboxService.drainPendingQueue(context),
                  child: const Text('Drain'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Drain'));
      await tester.pump();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(AppFunctionInboxService.queueKey), isFalse);
    });

    testWidgets('Drains log_expense action, updates DB and displays undo SnackBar', (tester) async {
      final queue = [
        {
          'action': 'log_expense',
          'id': 'test_tx_1',
          'amount': 450.0,
          'description': 'Coffee at cafe',
          'category': 'Food & Dining',
          'accountType': 'daily',
          'isExpense': true,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      ];

      SharedPreferences.setMockInitialValues({
        AppFunctionInboxService.queueKey: jsonEncode(queue),
      });

      final finProvider = FinancialManagerProvider();
      final noteProvider = NoteProvider();
      final settings = SettingsProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: finProvider),
            ChangeNotifierProvider.value(value: noteProvider),
            ChangeNotifierProvider.value(value: settings),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () => AppFunctionInboxService.drainPendingQueue(context),
                    child: const Text('Drain'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        await tester.tap(find.text('Drain'));
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      // Verify transaction was inserted into SQLite
      await tester.runAsync(() async {
        final txs = await TransactionRepository.instance.readAllTransactions();
        expect(txs.length, 1);
        expect(txs.first.amount, 450.0);
        expect(txs.first.description, 'Coffee at cafe');
        expect(txs.first.category, 'Food & Dining');
        expect(txs.first.account, 'daily');
        expect(txs.first.isExpense, isTrue);
      });

      // Verify queue was emptied
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppFunctionInboxService.queueKey), '[]');

      // Verify SnackBar appeared
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Expense: Coffee at cafe'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Wait for SnackBar slide-in animation to finish
      await tester.pump(const Duration(milliseconds: 800));

      // Tap Undo inside runAsync so any real sqflite async calls complete
      await tester.runAsync(() async {
        await tester.tap(find.text('Undo'));
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump(const Duration(seconds: 15));

      // Verify transaction was removed on Undo
      await tester.runAsync(() async {
        final txsAfterUndo = await TransactionRepository.instance.readAllTransactions();
        expect(txsAfterUndo, isEmpty);
      });
    });

    testWidgets('Drains add_task and create_note actions successfully', (tester) async {
      final queue = [
        {
          'action': 'add_task',
          'id': 'test_task_1',
          'title': 'Buy almond milk',
          'targetNoteTitle': "Today's Tasks",
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        {
          'action': 'create_note',
          'id': 'test_note_1',
          'title': 'Project Ideas',
          'content': '1. AI on device\n2. AppFunctions',
          'folder': 'Work',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      ];

      SharedPreferences.setMockInitialValues({
        AppFunctionInboxService.queueKey: jsonEncode(queue),
      });

      final finProvider = FinancialManagerProvider();
      final noteProvider = NoteProvider();
      final settings = SettingsProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: finProvider),
            ChangeNotifierProvider.value(value: noteProvider),
            ChangeNotifierProvider.value(value: settings),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () => AppFunctionInboxService.drainPendingQueue(context),
                    child: const Text('Drain'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        await tester.tap(find.text('Drain'));
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      // Verify notes in database
      await tester.runAsync(() async {
        final notes = await NoteRepository.instance.readAllNotes();
        expect(notes.any((n) => n.title == 'Project Ideas'), isTrue);
        expect(notes.any((n) => n.content.contains('Buy almond milk')), isTrue);
      });

      // SnackBar shows multiple items applied
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('2 AI Assistant actions applied'), findsOneWidget);

      await tester.pump(const Duration(seconds: 15));
    });
  });
}
