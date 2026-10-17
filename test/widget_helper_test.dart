import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/features/finances/data/transaction_repository.dart';
import 'package:note_taking_app/data/transaction_model.dart';
import 'package:note_taking_app/data/note_model.dart';
import 'package:note_taking_app/features/notes/data/note_repository.dart';
import 'package:note_taking_app/utils/widget_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Setup sqflite_common_ffi
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('WidgetHelper Unit Tests', () {
    late Database db;
    late TransactionRepository repository;
    final List<MethodCall> methodCalls = [];

    setUp(() async {
      methodCalls.clear();

      // Mock method channel for the widget to verify it triggers updateWidget
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.saadhjawwadh.notebook/widget'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          if (methodCall.method == 'requestPinAppWidget') return true;
          return null;
        },
      );

      // Set mock initial values for SharedPreferences (default currency USD)
      SharedPreferences.setMockInitialValues({
        'flutter.currency': 'USD',
      });

      // Initialize fresh in-memory database
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseHelper.instance.createTestDatabase(db);
      DatabaseHelper.setMockDatabase(db);
      await db.delete('transactions');

      repository = TransactionRepository.instance;
    });

    tearDown(() async {
      await db.close();
      DatabaseHelper.setMockDatabase(null);
    });

    test('updateWidgetData correctly calculates summaries and formats preferences', () async {
      final now = DateTime.now();

      // Today expense
      final tx1 = TransactionModel(
        amount: 25.0,
        description: 'Lunch',
        date: now,
        isExpense: true,
        category: 'Food',
      );

      // Today income (should go to income, not today spent)
      final tx2 = TransactionModel(
        amount: 100.0,
        description: 'Part-time job',
        date: now.subtract(const Duration(minutes: 5)),
        isExpense: false,
        category: 'Salary',
      );

      // Past month expense (still this month)
      final tx3 = TransactionModel(
        amount: 50.0,
        description: 'Utility bill',
        date: DateTime(now.year, now.month, 1),
        isExpense: true,
        category: 'Utilities',
      );

      // Reversal Sentinel (should be filtered out entirely)
      final tx4 = TransactionModel(
        amount: 99.0,
        description: 'Reversal item',
        date: now,
        isExpense: true,
        category: '__reversal__',
      );

      // Insert via repository
      await repository.createTransaction(tx1);
      await repository.createTransaction(tx2);
      await repository.createTransaction(tx3);
      await repository.createTransaction(tx4);

      // Call WidgetHelper manually to populate prefs (also triggered by createTransaction)
      await WidgetHelper.updateWidgetData();

      // Verify Shared Preferences
      final prefs = await SharedPreferences.getInstance();

      final expectedSpentToday = now.day == 1 ? '\$ 75' : '\$ 25';
      expect(prefs.getString('widget_spent_today'), expectedSpentToday);
      expect(prefs.getString('widget_spent_month'), '\$ 75'); // 25 (today) + 50 (month start)
      expect(prefs.getString('widget_income_month'), '\$ 100');

      // Verify recent transactions json format
      final recentJson = prefs.getString('widget_recent_transactions');
      expect(recentJson, isNotNull);

      final List<dynamic> recentList = json.decode(recentJson!);
      expect(recentList.length, 3); // Top 3, reversal tx4 is skipped

      // Verify date ordering (newest first, which is DESC)
      final firstTx = recentList[0];
      final secondTx = recentList[1];
      final thirdTx = recentList[2];

      expect(firstTx['description'], 'Lunch');
      expect(secondTx['description'], 'Part-time job');
      expect(thirdTx['description'], 'Utility bill');

      // Verify format matches pattern
      expect(firstTx['amount'], '- \$ 25');
      expect(secondTx['amount'], '+ \$ 100');
      expect(thirdTx['amount'], '- \$ 50');

      // Verify method channel was triggered
      expect(methodCalls.any((call) => call.method == 'updateWidget'), isTrue);
    });

    test('requestPinWidget and pinTodoWidget trigger platform method channel', () async {
      final result1 = await WidgetHelper.requestPinWidget('finance');
      expect(result1, isTrue);
      expect(methodCalls.any((call) => call.method == 'requestPinAppWidget' && call.arguments?['type'] == 'finance'), isTrue);

      final result2 = await WidgetHelper.requestPinWidget('unified');
      expect(result2, isTrue);
      expect(methodCalls.any((call) => call.method == 'requestPinAppWidget' && call.arguments?['type'] == 'unified'), isTrue);

      final result3 = await WidgetHelper.pinTodoWidget();
      expect(result3, isTrue);
      expect(methodCalls.any((call) => call.method == 'requestPinAppWidget' && call.arguments?['type'] == 'todo'), isTrue);
    });

    test('updateTodoWidgetData correctly updates active note titles and cleans orphaned per-widget IDs', () async {
      final now = DateTime.now();
      final noteRepo = NoteRepository.instance;

      // Create an active note with checklist items
      final note1 = Note(
        id: 'note_123',
        title: 'Project Roadmap',
        content: jsonEncode([
          {"insert": "Milestone 1\n", "attributes": {"list": "unchecked"}},
          {"insert": "Milestone 2\n", "attributes": {"list": "checked"}},
        ]),
        dateCreated: now,
        dateModified: now,
      );
      await noteRepo.createNote(note1);

      // Pre-populate SharedPreferences with:
      // 1. widget_active_note_id pointing to note_123 with stale/empty title
      // 2. widget_active_note_id_app1 pointing to note_123
      // 3. widget_active_note_id_app2 pointing to a deleted note 'deleted_note_999'
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('widget_active_note_id', 'note_123');
      await prefs.setString('widget_active_note_title', 'Old Title');
      await prefs.setString('widget_active_note_id_app1', 'note_123');
      await prefs.setString('widget_active_note_title_app1', 'Old App1 Title');
      await prefs.setString('widget_active_note_id_app2', 'deleted_note_999');
      await prefs.setString('widget_active_note_title_app2', 'Deleted Note Title');

      await WidgetHelper.updateTodoWidgetData();

      // Verify widget_todo_notes_json contains note_123 with items
      final todoNotesJson = prefs.getString('widget_todo_notes_json');
      expect(todoNotesJson, isNotNull);
      final List<dynamic> todoNotes = jsonDecode(todoNotesJson!);
      expect(todoNotes.any((n) => n['id'] == 'note_123'), isTrue);

      // Verify active note titles are synchronized
      expect(prefs.getString('widget_active_note_title'), 'Project Roadmap');
      expect(prefs.getString('widget_active_note_title_app1'), 'Project Roadmap');

      // Verify orphaned/deleted note widget resets to ALL_NOTES and All Action Items
      expect(prefs.getString('widget_active_note_id_app2'), 'ALL_NOTES');
      expect(prefs.getString('widget_active_note_title_app2'), 'All Action Items');
    });
  });
}
