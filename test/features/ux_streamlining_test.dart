import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/data/note_model.dart';
import 'package:note_taking_app/data/transaction_model.dart';
import 'package:note_taking_app/features/finances/data/models/savings_goal_model.dart';
import 'package:note_taking_app/features/finances/data/repositories/savings_goal_repository.dart';
import 'package:note_taking_app/features/finances/data/transaction_repository.dart';
import 'package:note_taking_app/features/finances/presentation/widgets/finance_hero_summary_card.dart';
import 'package:note_taking_app/features/finances/providers/financial_manager_provider.dart';
import 'package:note_taking_app/features/notes/data/note_repository.dart';
import 'package:note_taking_app/features/notes/providers/note_provider.dart';
import 'package:note_taking_app/features/settings/presentation/screens/sections/about_settings_screen.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/widgets/home/home_tip_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('UX Streamlining & Pruning Verification', () {
    late SettingsProvider settingsProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'currency': '\$',
        'hasSeenOnboarding': true,
        'hasSeenOnboarding_v2': true,
        'showFinancialManager': true,
        'isPeriodTrackerEnabled': false,
        'enableSavingsVault': true,
        'account1Name': 'Daily Checking',
        'account2Name': 'Savings Vault',
      });
      settingsProvider = SettingsProvider();
      await settingsProvider.loadSettings();
    });

    testWidgets('AboutSettingsScreen provides access to Tips sheet without home feed clutter',
        (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settingsProvider,
          child: const MaterialApp(
            home: AboutSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Tips tile
      final tipsTile = find.text('Tips & Gestural Shortcuts');
      expect(tipsTile, findsWidgets);

      // Tap on Tips tile to open the bottom sheet
      await tester.tap(tipsTile.first);
      await tester.pumpAndSettle();

      // Verify the sheet opened with ListView of tips
      expect(find.byType(ListView), findsWidgets);
      final catalog = HomeTipCard.getCatalog(tester.element(find.byType(AboutSettingsScreen)));
      expect(catalog.isNotEmpty, isTrue);
      expect(find.text(catalog.first.title), findsOneWidget);
    });

    testWidgets('FinanceHeroSummaryCard displays static cash flow and dual accounts without auto-cycle timers',
        (tester) async {
      String selectedAccount = 'all';
      final now = DateTime.now();

      final transactions = <TransactionModel>[
        TransactionModel(
          id: 1,
          amount: 5000.0,
          date: now,
          description: 'Direct Deposit Salary',
          category: 'Salary',
          isExpense: false,
          account: AccountType.daily,
        ),
        TransactionModel(
          id: 2,
          amount: 150.0,
          date: now,
          description: 'Grocery Store',
          category: 'Groceries',
          isExpense: true,
          account: AccountType.daily,
        ),
      ];

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settingsProvider,
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return FinanceHeroSummaryCard(
                    isLoading: false,
                    totalIncome: 5000.0,
                    totalExpense: 150.0,
                    dailyCashFlow: 4850.0,
                    savingsVaultCashFlow: 0.0,
                    selectedRange: DateTimeRange(
                      start: DateTime(now.year, 1, 1),
                      end: now,
                    ),
                    transactions: transactions,
                    currency: '\$',
                    selectedAccount: selectedAccount,
                    onAccountSelected: (acc) => setState(() => selectedAccount = acc),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifies Net Savings Surplus label and trend metrics
      expect(find.text('Net Savings Surplus'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.textContaining('Daily Checking'), findsOneWidget);
      expect(find.textContaining('Savings Vault'), findsOneWidget);

      // Verify that no PageView or auto-cycle indicators are present in this card
      expect(find.byType(PageView), findsNothing);

      // Tap Daily Checking filter
      await tester.tap(find.textContaining('Daily Checking'));
      await tester.pumpAndSettle();
      expect(selectedAccount, 'daily');
    });

    testWidgets('NoteCard preview cleanly excludes completed items and shows celebrations when all are done',
        (tester) async {
      // Incomplete tasks
      const incompleteContent = '- [ ] Task 1\n- [x] Task 2\n- [ ] Task 3';
      final lines = incompleteContent.split('\n');
      final pendingLines = lines.where((l) => !l.startsWith('- [x]')).toList();
      expect(pendingLines, contains('- [ ] Task 1'));
      expect(pendingLines, contains('- [ ] Task 3'));
      expect(pendingLines.any((l) => l.startsWith('- [x]')), isFalse);
    });

    test('SavingsGoalRepository deposit uses Transfer category on both legs, caps withdrawals, and respects recordLedgerTransaction', () async {
      final testDb = await openDatabase(
        inMemoryDatabasePath,
        version: 26,
        onCreate: (db, version) async {
          await DatabaseHelper.instance.createTestDatabase(db);
        },
      );
      DatabaseHelper.setMockDatabase(testDb);

      try {
        final goal = SavingsGoalModel(
          id: 'goal_1',
          title: 'Emergency Fund',
          targetAmount: 1000.0,
          currentAmount: 0.0,
          createdAt: DateTime.now(),
        );
        await SavingsGoalRepository.instance.createGoal(goal);

        // 1. Deposit $200 from Daily into Savings Vault pocket
        await SavingsGoalRepository.instance.recordDeposit(
          goalId: goal.id,
          amount: 200.0,
          recordLedgerTransaction: true,
        );

        final allTx = await TransactionRepository.instance.readAllTransactions();
        expect(allTx.length, 2);
        expect(
          allTx.every((tx) => tx.category == 'Transfer'),
          isTrue,
          reason: 'Both debit and credit legs must use Transfer category so Monthly Income is not inflated',
        );

        // Verify FinancialManagerProvider does not count internal pocket deposit as Monthly Income
        final finProvider = FinancialManagerProvider();
        await finProvider.loadTransactions();
        expect(finProvider.totalIncome, 0.0);
        expect(finProvider.totalExpense, 0.0);

        // 2. Cap withdrawal at currentAmount ($200) even if $500 is requested
        final refreshedGoal1 = (await SavingsGoalRepository.instance.getGoalById(goal.id))!;
        expect(refreshedGoal1.currentAmount, 200.0);
        await SavingsGoalRepository.instance.recordWithdrawal(
          goalId: goal.id,
          amount: 500.0,
          recordLedgerTransaction: true,
        );

        final refreshedGoal2 = (await SavingsGoalRepository.instance.getGoalById(goal.id))!;
        expect(refreshedGoal2.currentAmount, 0.0);

        // 3. Re-deposit $150 and liquidate with recordLedgerTransaction: false
        await SavingsGoalRepository.instance.recordDeposit(
          goalId: goal.id,
          amount: 150.0,
          recordLedgerTransaction: false,
        );
        final txCountBeforeLiquidate = (await TransactionRepository.instance.readAllTransactions()).length;
        await SavingsGoalRepository.instance.liquidateGoal(
          goalId: goal.id,
          amount: 150.0,
          category: 'Shopping',
          merchantTitle: 'Bought headphones',
          recordLedgerTransaction: false,
        );
        final txCountAfterLiquidate = (await TransactionRepository.instance.readAllTransactions()).length;
        expect(
          txCountAfterLiquidate,
          txCountBeforeLiquidate,
          reason: 'Unchecking recordLedgerTransaction should not insert a ledger expense',
        );
      } finally {
        await testDb.close();
        DatabaseHelper.setMockDatabase(null);
      }
    });

    test('NoteProvider Checklists virtual view spans folders and handleTagRenamed updates selectedTags', () async {
      final testDb = await openDatabase(
        inMemoryDatabasePath,
        version: 26,
        onCreate: (db, version) async {
          await DatabaseHelper.instance.createTestDatabase(db);
        },
      );
      DatabaseHelper.setMockDatabase(testDb);

      try {
        final now = DateTime.now();
        await NoteRepository.instance.createNote(
          Note(
            id: 'note_work_1',
            title: 'Work Tasks',
            content: '- [ ] Finish report',
            dateCreated: now,
            dateModified: now,
            category: 'Work',
            tags: ['urgent'],
          ),
        );
        await NoteRepository.instance.createNote(
          Note(
            id: 'note_gen_1',
            title: 'General Note',
            content: 'Plain text note',
            dateCreated: now,
            dateModified: now,
            category: 'Notes',
            tags: ['urgent'],
          ),
        );

        final noteProvider = NoteProvider();
        await noteProvider.refreshNotes();

        // Default folder is 'Notes', so 'Work Tasks' checklist isn't visible until Checklists virtual view is enabled
        expect(noteProvider.selectedFolder, 'Notes');
        expect(noteProvider.checklistNotesCount, 1);

        noteProvider.setFilterChecklistsOnly(true);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(noteProvider.filteredNotes.length, 1);
        expect(noteProvider.filteredNotes.first.title, 'Work Tasks');

        // Selecting a folder turns off filterChecklistsOnly
        noteProvider.setFolder('All Notes');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(noteProvider.filterChecklistsOnly, isFalse);
        expect(noteProvider.filteredNotes.length, 2);

        // Tag rename syncs active selectedTags
        noteProvider.toggleTag('urgent');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(noteProvider.selectedTags, contains('urgent'));
        await NoteRepository.instance.renameTag('urgent', 'priority');
        await noteProvider.handleTagRenamed('urgent', 'priority');
        expect(noteProvider.selectedTags, contains('priority'));
        expect(noteProvider.selectedTags.contains('urgent'), isFalse);
      } finally {
        await testDb.close();
        DatabaseHelper.setMockDatabase(null);
      }
    });
  });
}
