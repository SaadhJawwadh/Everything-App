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

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('WidgetHelper Unit Tests', () {
    late Database db;
    late TransactionRepository repository;
    final List<MethodCall> methodCalls = [];
    Map<String, String>? mockActiveNoteIds;
    String? mockPendingToggles;

    setUp(() async {
      methodCalls.clear();
      mockActiveNoteIds = null;
      mockPendingToggles = null;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.saadhjawwadh.notebook/widget'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          if (methodCall.method == 'requestPinAppWidget') return true;
          if (methodCall.method == 'getWidgetActiveNoteIds') {
            return mockActiveNoteIds;
          }
          if (methodCall.method == 'getPendingTodoToggles') {
            return mockPendingToggles;
          }
          if (methodCall.method == 'setPendingTodoToggles') {
            mockPendingToggles = methodCall.arguments as String?;
            return true;
          }
          return true;
        },
      );

      SharedPreferences.setMockInitialValues({
        'flutter.currency': 'USD',
        'flutter.account1Name': 'Checking',
        'flutter.account2Name': 'Vault',
        'flutter.enableSavingsVault': true,
        'flutter.enableBudgetsAndAnalytics': true,
      });

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

    test('updateWidgetData builds finance_snapshot_json with exact boundaries and dual accounts', () async {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final yesterdayEnd = todayStart.subtract(const Duration(milliseconds: 1));
      final monthStart = DateTime(now.year, now.month, 1);

      // Today expense on daily account (at exact midnight start)
      final tx1 = TransactionModel(
        amount: 25.5,
        description: 'Lunch',
        date: todayStart,
        isExpense: true,
        category: 'Food',
        account: AccountType.daily,
      );

      // Today income on savings account
      final tx2 = TransactionModel(
        amount: 100.0,
        description: 'Interest',
        date: now,
        isExpense: false,
        category: 'Salary',
        account: AccountType.savings,
      );

      // Yesterday at 23:59:59.999 (must NOT leak into spentToday)
      final txYesterday = TransactionModel(
        amount: 40.0,
        description: 'Yesterday snack',
        date: yesterdayEnd,
        isExpense: true,
        category: 'Food',
        account: AccountType.daily,
      );

      // Reversal Sentinel (must be excluded)
      final txReversal = TransactionModel(
        amount: 99.0,
        description: 'Reversal item',
        date: now,
        isExpense: true,
        category: '__reversal__',
      );

      await repository.createTransaction(tx1, updateWidgets: false);
      await repository.createTransaction(tx2, updateWidgets: false);
      await repository.createTransaction(txYesterday, updateWidgets: false);
      await repository.createTransaction(txReversal, updateWidgets: false);

      await WidgetHelper.updateWidgetData();

      final syncCall = methodCalls.lastWhere(
        (c) => c.method == 'syncFinanceSnapshot',
      );
      final snapshot = json.decode(syncCall.arguments as String) as Map<String, dynamic>;

      expect(snapshot['spentToday'], '\$ 25.5');
      final expectedMonthSpent = yesterdayEnd.isBefore(monthStart) ? 25.5 : 65.5;
      expect(snapshot['totalExpense'], expectedMonthSpent);
      expect(snapshot['totalIncome'], 100.0);
      expect(snapshot['netBalance'], closeTo(100.0 - expectedMonthSpent, 0.001));
      expect(snapshot['netPositive'], isTrue);
      expect(snapshot['currencySymbol'], '\$');
      expect(snapshot['account1Name'], 'Checking');
      expect(snapshot['account2Name'], 'Vault');
      expect(snapshot['enableSavingsVault'], isTrue);
      expect(snapshot['enableBudgetsAndAnalytics'], isTrue);
      expect(snapshot['savingsBalance'], '\$ 100');
      expect(snapshot['topCategory'], 'Food');

      // Plaintext financial cache must NOT be written into FlutterSharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('widget_recent_transactions'), isNull);
      expect(prefs.getString('widget_spent_today'), isNull);
    });

    test('updateWidgetData stages widget_bg_staging_finance on MissingPluginException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.saadhjawwadh.notebook/widget'),
        null,
      );

      await repository.createTransaction(
        TransactionModel(
          amount: 15.0,
          description: 'Coffee',
          date: DateTime.now(),
          isExpense: true,
          category: 'Food',
        ),
        updateWidgets: false,
      );

      await WidgetHelper.updateWidgetData();

      final prefs = await SharedPreferences.getInstance();
      final staged = prefs.getString('widget_bg_staging_finance');
      expect(staged, isNotNull);
      final decoded = json.decode(staged!) as Map<String, dynamic>;
      expect(decoded['spentToday'], '\$ 15');
    });

    test('requestPinWidget and pinTodoWidget trigger platform method channel', () async {
      final result1 = await WidgetHelper.requestPinWidget('finance');
      expect(result1, isTrue);
      expect(
        methodCalls.any((call) =>
            call.method == 'requestPinAppWidget' &&
            call.arguments?['type'] == 'finance'),
        isTrue,
      );

      final result2 = await WidgetHelper.pinTodoWidget();
      expect(result2, isTrue);
      expect(
        methodCalls.any((call) =>
            call.method == 'requestPinAppWidget' &&
            call.arguments?['type'] == 'todo'),
        isTrue,
      );
    });

    test('syncWidgetConfig sends privacy and module flags to native channel', () async {
      await WidgetHelper.syncWidgetConfig(
        showFinancialManager: true,
        appLockEnabled: true,
        lockFinances: true,
        hideWidgetDataWhenLocked: false,
        screenshotShieldEnabled: true,
        languageCode: 'ta',
      );

      final call = methodCalls.lastWhere((c) => c.method == 'syncWidgetConfig');
      final args = Map<String, dynamic>.from(call.arguments as Map);
      expect(args['showFinancialManager'], isTrue);
      expect(args['appLockEnabled'], isTrue);
      expect(args['lockFinances'], isTrue);
      expect(args['hideWidgetDataWhenLocked'], isFalse);
      expect(args['screenshotShieldEnabled'], isTrue);
      expect(args['languageCode'], 'ta');
    });

    test('updateTodoWidgetData filters pending before take(30), supports - [X], and syncs active titles', () async {
      final now = DateTime.now();
      final noteRepo = NoteRepository.instance;

      // Note with 35 completed items followed by 3 pending items
      final ops = <Map<String, dynamic>>[];
      for (int i = 0; i < 35; i++) {
        ops.add({'insert': 'Done $i'});
        ops.add({'insert': '\n', 'attributes': {'list': 'checked'}});
      }
      for (int i = 0; i < 3; i++) {
        ops.add({'insert': 'Pending $i'});
        ops.add({'insert': '\n', 'attributes': {'list': 'unchecked'}});
      }

      final note1 = Note(
        id: 'note_123',
        title: 'Project Roadmap',
        content: jsonEncode(ops),
        dateCreated: now,
        dateModified: now,
      );
      final note2 = Note(
        id: 'note_upper',
        title: 'Markdown Uppercase',
        content: '- [X] Completed task\n- [ ] Open uppercase test',
        dateCreated: now,
        dateModified: now,
      );
      await noteRepo.createNote(note1);
      await noteRepo.createNote(note2);

      mockActiveNoteIds = {
        'global': 'note_123',
        '101': 'note_123',
        '102': 'deleted_note_999',
      };

      await WidgetHelper.updateTodoWidgetData();

      final syncCall = methodCalls.lastWhere((c) => c.method == 'syncTodoSnapshot');
      final List<dynamic> todoNotes = jsonDecode(syncCall.arguments as String);

      final n1 = todoNotes.firstWhere((n) => n['id'] == 'note_123') as Map<String, dynamic>;
      expect(n1['checkedCount'], 35);
      expect(n1['pendingCount'], 3);
      expect(n1['totalCount'], 38);
      expect((n1['items'] as List).length, 3);
      expect(n1['items'][0]['text'], 'Pending 0');

      final n2 = todoNotes.firstWhere((n) => n['id'] == 'note_upper') as Map<String, dynamic>;
      expect(n2['checkedCount'], 1);
      expect(n2['pendingCount'], 1);
      expect(n2['totalCount'], 2);
      expect(n2['items'][0]['text'], 'Open uppercase test');

      final titleUpdateCall = methodCalls.lastWhere(
        (c) => c.method == 'updateWidgetActiveNoteTitles',
      );
      final updates = Map<String, dynamic>.from(titleUpdateCall.arguments as Map);
      expect(updates['global']['title'], 'Project Roadmap');
      expect(updates['101']['title'], 'Project Roadmap');
      expect(updates['102']['id'], 'ALL_NOTES');
      expect(updates['102']['title'], 'All Action Items');

      // Plaintext todo JSON must NOT be stored in FlutterSharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('widget_todo_notes_json'), isNull);
    });
  });
}
