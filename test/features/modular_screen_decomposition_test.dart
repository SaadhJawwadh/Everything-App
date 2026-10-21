import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/data/transaction_model.dart';
import 'package:note_taking_app/features/finances/presentation/widgets/finance_date_range_sheet.dart';
import 'package:note_taking_app/features/finances/presentation/widgets/finance_hero_summary_card.dart';
import 'package:note_taking_app/features/notes/presentation/widgets/note_embed_builders.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Modular Screen Decomposition Tests', () {
    late SettingsProvider settingsProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'currency': '\$',
        'enableSavingsVault': true,
        'account1Name': 'Daily Checking',
        'account2Name': 'Savings Vault',
      });
      settingsProvider = SettingsProvider();
      await settingsProvider.loadSettings();
    });

    testWidgets('FinanceDateRangeSheet renders presets and custom option',
        (tester) async {
      DateTimeRange? selected;
      final now = DateTime.now();
      final currentRange = DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    selected = await FinanceDateRangeSheet.show(
                      context,
                      currentRange: currentRange,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Select Period'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('Last Month'), findsOneWidget);
      expect(find.text('Last 90 Days'), findsOneWidget);
      expect(find.text('This Year'), findsOneWidget);
      expect(find.text('All Time (Full History)'), findsOneWidget);
      expect(find.text('Custom Date Range…'), findsOneWidget);

      // Tap 'Last Month' preset
      await tester.tap(find.text('Last Month'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      final expectedLastMonthStart = DateTime(now.year, now.month - 1, 1);
      final expectedLastMonthEnd = DateTime(now.year, now.month, 0);
      expect(selected!.start.year, equals(expectedLastMonthStart.year));
      expect(selected!.start.month, equals(expectedLastMonthStart.month));
      expect(selected!.end.day, equals(expectedLastMonthEnd.day));
    });

    testWidgets('FinanceHeroSummaryCard renders cash flow and dual accounts',
        (tester) async {
      final now = DateTime.now();
      final range = DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      );

      String selectedAccount = 'all';

      final transactions = <TransactionModel>[
        TransactionModel(
          id: 1,
          amount: 5000.0,
          date: now,
          description: 'Salary',
          category: 'Salary',
          isExpense: false,
          account: AccountType.daily,
        ),
        TransactionModel(
          id: 2,
          amount: 1200.0,
          date: now,
          description: 'Groceries',
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
              body: FinanceHeroSummaryCard(
                isLoading: false,
                totalIncome: 5000.0,
                totalExpense: 1200.0,
                dailyCashFlow: 3800.0,
                savingsVaultCashFlow: 15000.0,
                selectedRange: range,
                transactions: transactions,
                currency: '\$',
                selectedAccount: selectedAccount,
                onAccountSelected: (acc) => selectedAccount = acc,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Net savings surplus is 5000 - 1200 = 3800
      expect(find.text('+ \$ 3800'), findsOneWidget);
      expect(find.text('Net Savings Surplus'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('\$ 5000'), findsOneWidget);
      expect(find.text('\$ 1200'), findsOneWidget);

      // Dual account badges
      expect(find.textContaining('Daily Checking: \$ 3800'), findsOneWidget);
      expect(find.textContaining('Savings Vault: \$ 15000'), findsOneWidget);

      // Verify tapping account badge triggers callback
      await tester.tap(find.textContaining('Daily Checking'));
      await tester.pump();
      expect(selectedAccount, equals(AccountType.daily));
    });

    test('Note embed builders contracts and notifications', () {
      const imgBuilder = RoundedImageEmbedBuilder();
      expect(imgBuilder.key, equals('image'));

      const tableBuilder = TableEmbedBuilder();
      expect(tableBuilder.key, equals('table'));

      const notification = TableCellFocusNotification(true);
      expect(notification.isFocused, isTrue);

      const unfocusedNotification = TableCellFocusNotification(false);
      expect(unfocusedNotification.isFocused, isFalse);
    });
  });
}
