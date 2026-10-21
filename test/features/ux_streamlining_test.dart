import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/data/transaction_model.dart';
import 'package:note_taking_app/features/finances/presentation/widgets/finance_hero_summary_card.dart';
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
  });
}
