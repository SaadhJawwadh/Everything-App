import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/data/transaction_model.dart';
import 'package:note_taking_app/data/note_model.dart';
import 'package:note_taking_app/features/finances/data/transaction_repository.dart';
import 'package:note_taking_app/features/notes/data/note_repository.dart';
import 'package:note_taking_app/screens/app_lock_screen.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/services/backup_service.dart';
import 'package:note_taking_app/services/sync_merge_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late TransactionRepository transactionRepo;
  late NoteRepository noteRepo;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 25,
      onCreate: (db, version) async {
        await DatabaseHelper.instance.createTestDatabase(db);
      },
    );
    DatabaseHelper.setMockDatabase(db);
    transactionRepo = TransactionRepository.instance;
    noteRepo = NoteRepository.instance;
  });

  tearDown(() async {
    await db.close();
  });

  group('Finances: Atomic Transfer & Summary Exclusion Tests', () {
    test('createTransferTransactions creates withdrawal and deposit atomically', () async {
      final now = DateTime.now();
      final withdrawal = TransactionModel(
        amount: 500.0,
        description: 'Vault Deposit (Transfer Out)',
        date: now,
        isExpense: true,
        category: 'Transfer',
        account: AccountType.daily,
      );
      final deposit = TransactionModel(
        amount: 500.0,
        description: 'Vault Deposit (Transfer In)',
        date: now,
        isExpense: false,
        category: 'Transfer',
        account: AccountType.savings,
      );

      final results = await transactionRepo.createTransferTransactions(
        withdrawal: withdrawal,
        deposit: deposit,
      );

      expect(results.length, 2);
      expect(results[0].id, isNotNull);
      expect(results[1].id, isNotNull);

      final allTxns = await transactionRepo.readAllTransactions();
      expect(allTxns.length, 2);
    });

    test('getMonthlyTransactionSummary and getAllTimeSummary exclude Transfer category', () async {
      final now = DateTime.now();

      // Regular income and expense
      await transactionRepo.createTransaction(TransactionModel(
        amount: 2000.0,
        description: 'Salary',
        date: now,
        isExpense: false,
        category: 'Salary',
        account: AccountType.daily,
      ));
      await transactionRepo.createTransaction(TransactionModel(
        amount: 300.0,
        description: 'Groceries',
        date: now,
        isExpense: true,
        category: 'Food',
        account: AccountType.daily,
      ));

      // Transfer records (should NOT inflate income or expense)
      await transactionRepo.createTransferTransactions(
        withdrawal: TransactionModel(
          amount: 500.0,
          description: 'Transfer Out',
          date: now,
          isExpense: true,
          category: 'Transfer',
          account: AccountType.daily,
        ),
        deposit: TransactionModel(
          amount: 500.0,
          description: 'Transfer In',
          date: now,
          isExpense: false,
          category: 'transfer',
          account: AccountType.savings,
        ),
      );

      final monthlySummary = await transactionRepo.getMonthlyTransactionSummary(1);
      expect(monthlySummary.first['totalIncome'], 2000.0,
          reason: 'Internal transfer must not be counted as income');
      expect(monthlySummary.first['totalExpense'], 300.0,
          reason: 'Internal transfer must not be counted as expense');

      final allTimeSummary = await transactionRepo.getAllTimeSummary();
      expect(allTimeSummary['totalIncome'], 2000.0);
      expect(allTimeSummary['totalExpense'], 300.0);
    });
  });

  group('Notes: Search Preview vs Delta Metadata Tests', () {
    test('searchNotes searches previewText and avoids matching raw Delta JSON syntax', () async {
      final now = DateTime.now();

      // Note with Delta JSON content containing 'insert' and 'bold'
      final note1 = Note(
        id: 'note-1',
        title: 'Meeting Notes',
        content: r'[{"insert":"Meeting with the team about project alpha\n","attributes":{"bold":true}}]',
        dateCreated: now,
        dateModified: now,
      );
      await noteRepo.createNote(note1);

      // Note with legitimate text containing 'insert'
      final note2 = Note(
        id: 'note-2',
        title: 'SQL Tutorial',
        content: r'[{"insert":"Learn how to insert records into a database table\n"}]',
        dateCreated: now,
        dateModified: now,
      );
      await noteRepo.createNote(note2);

      // Searching for 'alpha' should only find note1
      final alphaResults = await noteRepo.searchNotes('alpha');
      expect(alphaResults.length, 1);
      expect(alphaResults.first.id, 'note-1');

      // Searching for 'insert' should only match note2 (whose text actually has the word 'insert'),
      // NOT note1 (whose JSON syntax merely has 'insert')
      final insertResults = await noteRepo.searchNotes('insert');
      expect(insertResults.length, 1);
      expect(insertResults.first.id, 'note-2');

      // Searching for 'bold' should return nothing because neither has the word 'bold' in text
      final boldResults = await noteRepo.searchNotes('bold');
      expect(boldResults.length, 0);
    });
  });

  group('Lock Screen: PopScope & Authentication Protection Tests', () {
    testWidgets('Unauthenticated AppLockScreen contains PopScope preventing pop', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/local_auth'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'authenticate') {
            return false;
          }
          if (methodCall.method == 'isDeviceSupported') {
            return true;
          }
          return null;
        },
      );

      SharedPreferences.setMockInitialValues({
        'appLockEnabled': true,
        'appLockTimeout': 0,
      });
      final settings = SettingsProvider();
      await settings.loadSettings();

      AppLockScreen.sessionAuthenticated.value = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SettingsProvider>.value(
            value: settings,
            child: const AppLockScreen(
              child: Text('Protected Content'),
            ),
          ),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Lock screen should be active and App Locked displayed
      expect(find.text('App Locked'), findsOneWidget);

      // Protected content should be hidden behind lock overlay wrapped in PopScope(canPop: false)
      final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
      expect(popScopeFinder, findsOneWidget);
      final popScope = tester.widget<PopScope>(popScopeFinder);
      expect(popScope.canPop, isFalse);
    });
  });

  group('Backup & Restore: Savings Goals, Period Logs, and FK Integrity', () {
    test('restoreFromBackupData cleanly replaces savings_goals and deleted_period_logs', () async {
      // 1. Insert existing local goal and tombstone that are NOT in the incoming backup
      await db.insert('savings_goals', {
        'id': 'stale-goal-1',
        'title': 'Old Stale Goal',
        'targetAmount': 1000.0,
        'currentAmount': 100.0,
        'isCompleted': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await db.insert('deleted_period_logs', {
        'id': 'stale-tombstone-1',
        'deletedAt': DateTime.now().toIso8601String(),
      });

      // 2. Prepare backup data containing only fresh new goal and tombstone
      final backupData = <String, dynamic>{
        'savingsGoals': [
          {
            'id': 'fresh-goal-2',
            'title': 'New Emergency Fund',
            'targetAmount': 5000.0,
            'currentAmount': 500.0,
            'isCompleted': 0,
          }
        ],
        'deletedPeriodLogs': [
          {
            'id': 'fresh-tombstone-2',
            'deletedAt': DateTime.now().toIso8601String(),
          }
        ],
      };

      // 3. Restore backup
      await BackupService.restoreFromBackupData(backupData);

      // 4. Assert old stale records were cleared and only fresh records exist
      final restoredGoals = await db.query('savings_goals');
      expect(restoredGoals.length, 1);
      expect(restoredGoals.first['id'], 'fresh-goal-2');
      expect(restoredGoals.first['title'], 'New Emergency Fund');

      final restoredTombstones = await db.query('deleted_period_logs');
      expect(restoredTombstones.length, 1);
      expect(restoredTombstones.first['id'], 'fresh-tombstone-2');
    });

    test('restoreFromBackupData supports snake_case savings_goals key', () async {
      final backupData = <String, dynamic>{
        'savings_goals': [
          {
            'id': 'snake-goal-1',
            'title': 'Snake Case Goal',
            'targetAmount': 2500.0,
            'currentAmount': 250.0,
            'isCompleted': 0,
          }
        ],
      };

      await BackupService.restoreFromBackupData(backupData);

      final restoredGoals = await db.query('savings_goals');
      expect(restoredGoals.length, 1);
      expect(restoredGoals.first['id'], 'snake-goal-1');
    });
  });

  group('P2P Sync: Split Bills, Savings Goals LWW and SMS Edit Propagation', () {
    test('mergeRemoteData preserves soft-delete states on split_bills and savings_goals', () async {
      // Setup local deleted split bill and active savings goal
      final now = DateTime.now().toIso8601String();
      await db.insert('split_bills', {
        'id': 'bill-1',
        'title': 'Dinner',
        'totalAmount': 100.0,
        'payerName': 'Alice',
        'isPayerUser': 1,
        'splitMode': 'equal',
        'date': now,
        'deletedAt': now, // Locally deleted!
      });

      await db.insert('savings_goals', {
        'id': 'goal-1',
        'title': 'Vacation',
        'targetAmount': 2000.0,
        'currentAmount': 300.0,
        'isCompleted': 0,
        'createdAt': now,
        'deletedAt': null, // Locally active!
      });

      // Remote incoming data:
      // - bill-1 has deletedAt: null (remote older/active shouldn't un-delete local deletion)
      // - goal-1 has deletedAt: now (remote deleted should propagate to local)
      final remoteData = {
        'splitBills': [
          {
            'id': 'bill-1',
            'title': 'Dinner',
            'totalAmount': 100.0,
            'payerName': 'Alice',
            'isPayerUser': 1,
            'splitMode': 'equal',
            'date': now,
            'deletedAt': null,
          }
        ],
        'savingsGoals': [
          {
            'id': 'goal-1',
            'title': 'Vacation',
            'targetAmount': 2000.0,
            'currentAmount': 300.0,
            'isCompleted': 0,
            'deletedAt': now,
          }
        ],
      };

      final result = await SyncMergeService.instance.mergeRemoteData(remoteData);

      final bills = await db.query('split_bills', where: 'id = ?', whereArgs: ['bill-1']);
      expect(bills.first['deletedAt'], isNotNull,
          reason: 'Remote active bill should not resurrect locally soft-deleted bill');

      final goals = await db.query('savings_goals', where: 'id = ?', whereArgs: ['goal-1']);
      expect(goals.first['deletedAt'], isNotNull,
          reason: 'Remote soft-delete should propagate to local savings goal');
      expect(result.savingsGoalsMerged, 1);
    });

    test('mergeRemoteData propagates SMS transaction category and account updates', () async {
      final now = DateTime.now().toIso8601String();
      // Local transaction
      await db.insert('transactions', {
        'smsId': 'sms_12345',
        'amount': 50.0,
        'description': 'Coffee Shop',
        'date': now,
        'isExpense': 1,
        'category': 'Other',
        'account': 'daily',
        'isAiRefined': 0,
      });

      // Remote transaction with updated category and account
      final remoteData = {
        'transactions': [
          {
            'smsId': 'sms_12345',
            'amount': 50.0,
            'description': 'Coffee Shop Premium',
            'date': now,
            'isExpense': 1,
            'category': 'Food & Drinks',
            'account': 'savings',
            'isAiRefined': 1,
          }
        ]
      };

      final result = await SyncMergeService.instance.mergeRemoteData(remoteData);
      expect(result.transactionsMerged, 1);

      final txns = await db.query('transactions', where: 'smsId = ?', whereArgs: ['sms_12345']);
      expect(txns.first['category'], 'Food & Drinks');
      expect(txns.first['account'], 'savings');
      expect(txns.first['isAiRefined'], 1);
      expect(txns.first['description'], 'Coffee Shop Premium');
    });
  });
}
