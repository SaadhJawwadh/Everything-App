import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/data/transaction_model.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/features/finances/services/spending_forecast_service.dart';
import 'package:note_taking_app/features/finances/presentation/widgets/burn_rate_forecast_card.dart';
import 'package:note_taking_app/features/finances/presentation/widgets/financial_analytics_tab.dart';
import 'package:note_taking_app/features/finances/presentation/widgets/minimal_chart_deck.dart';
import 'package:note_taking_app/features/finances/presentation/widgets/savings_goals_card.dart';

void main() {
  group('SpendingForecastService Math & Logic Tests', () {
    test('Calculates onTrack pace for mid-month spending correctly', () {
      // Day 15 of 30-day month (April 2026)
      final refDate = DateTime(2026, 4, 15);
      final budgets = {
        'Food': 10000.0,
        'Shopping': 5000.0,
      }; // Total Budget = 15000.0

      // Spent 7500 on Day 15 (exactly 50% spent on 50% elapsed)
      final transactions = [
        TransactionModel(
          id: 1,
          amount: 5000.0,
          date: DateTime(2026, 4, 5),
          description: 'Groceries',
          category: 'Food',
          isExpense: true,
        ),
        TransactionModel(
          id: 2,
          amount: 2500.0,
          date: DateTime(2026, 4, 10),
          description: 'Clothes',
          category: 'Shopping',
          isExpense: true,
        ),
      ];

      final forecast = SpendingForecastService.calculateMonthlyForecast(
        transactions: transactions,
        categoryBudgets: budgets,
        referenceDate: refDate,
      );

      expect(forecast.totalBudget, 15000.0);
      expect(forecast.currentMonthSpent, 7500.0);
      expect(forecast.remainingBudget, 7500.0);
      expect(forecast.currentDay, 15);
      expect(forecast.totalDaysInMonth, 30);
      expect(forecast.remainingDays, 16);
      expect(forecast.dailyBurnRate, 500.0);
      expect(forecast.projectedMonthEndSpend, 15000.0);
      expect(forecast.dailySafeToSpend, closeTo(7500.0 / 16, 0.01));
      expect(forecast.status, SpendingPaceStatus.onTrack);
    });

    test('Calculates underPace when spending is low', () {
      // Day 20 of 31-day month (May 2026)
      final refDate = DateTime(2026, 5, 20);
      final budgets = {'Food': 10000.0};

      final transactions = [
        TransactionModel(
          id: 1,
          amount: 2000.0, // only 20% spent at ~65% month elapsed
          date: DateTime(2026, 5, 5),
          description: 'Lunch',
          category: 'Food',
          isExpense: true,
        ),
      ];

      final forecast = SpendingForecastService.calculateMonthlyForecast(
        transactions: transactions,
        categoryBudgets: budgets,
        referenceDate: refDate,
      );

      expect(forecast.status, SpendingPaceStatus.underPace);
      expect(forecast.dailySafeToSpend, greaterThan(forecast.dailyBurnRate));
    });

    test('Calculates exhausted pace when budget is fully exceeded', () {
      final refDate = DateTime(2026, 5, 10);
      final budgets = {'Food': 5000.0};

      final transactions = [
        TransactionModel(
          id: 1,
          amount: 6000.0,
          date: DateTime(2026, 5, 2),
          description: 'Party',
          category: 'Food',
          isExpense: true,
        ),
      ];

      final forecast = SpendingForecastService.calculateMonthlyForecast(
        transactions: transactions,
        categoryBudgets: budgets,
        referenceDate: refDate,
      );

      expect(forecast.status, SpendingPaceStatus.exhausted);
      expect(forecast.dailySafeToSpend, 0.0);
      expect(forecast.remainingBudget, 0.0);
    });

    test('Handles zero budget and empty transactions gracefully', () {
      final refDate = DateTime(2026, 2, 14); // Feb 2026 (28 days)

      final forecast = SpendingForecastService.calculateMonthlyForecast(
        transactions: [],
        categoryBudgets: {},
        referenceDate: refDate,
      );

      expect(forecast.totalBudget, 0.0);
      expect(forecast.currentMonthSpent, 0.0);
      expect(forecast.dailySafeToSpend, 0.0);
      expect(forecast.totalDaysInMonth, 28);
      expect(forecast.status, SpendingPaceStatus.noBudget);
    });
  });

  group('BurnRateForecastCard Widget Tests', () {
    testWidgets('Renders daily safe-to-spend and status chip cleanly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const forecast = MonthlySpendingForecast(
        totalBudget: 20000.0,
        currentMonthSpent: 8000.0,
        remainingBudget: 12000.0,
        dailyBurnRate: 800.0,
        projectedMonthEndSpend: 24000.0,
        dailySafeToSpend: 600.0,
        elapsedFraction: 10 / 30,
        budgetSpentFraction: 8000 / 20000,
        currentDay: 10,
        totalDaysInMonth: 30,
        remainingDays: 21,
        status: SpendingPaceStatus.overPace,
        paceMessage: 'Pacing fast! At current rate, projected to exceed budget.',
        categoryPaces: {},
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BurnRateForecastCard(
                forecast: forecast,
                currency: 'Rs.',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Spending Pace & Burn Rate'), findsOneWidget);
      expect(find.text('Daily Safe-to-Spend'), findsOneWidget);
      expect(find.text('Pacing High'), findsOneWidget);
      expect(find.textContaining('Rs. 600'), findsOneWidget);
    });

    testWidgets('MinimalChartDeck renders and supports swiping and details navigation', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool detailsTapped = false;
      final monthlyData = [
        {'month': 'Jan', 'expense': 12000.0, 'income': 15000.0},
        {'month': 'Feb', 'expense': 14000.0, 'income': 16000.0},
        {'month': 'Mar', 'expense': 10000.0, 'income': 18000.0},
      ];
      final categoryExpenses = {
        'Food': 5000.0,
        'Transport': 3000.0,
        'Shopping': 2000.0,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MinimalChartDeck(
                monthlyData: monthlyData,
                categoryExpenses: categoryExpenses,
                totalExpense: 10000.0,
                currency: 'Rs.',
                onTapDetails: () {
                  detailsTapped = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Spending Trend'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(detailsTapped, isTrue);

      // Swipe to Donut Chart slide
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Expense Breakdown'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
    });

    testWidgets('FinancialAnalyticsTab renders empty state and active dashboard correctly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                FinancialAnalyticsTab(
                  transactions: const [],
                  monthlyData: const [],
                  currency: 'Rs.',
                  settings: SettingsProvider(),
                  onRefresh: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No financial data yet'), findsOneWidget);
    });

    testWidgets('FinancialAnalyticsTab renders Budgets and Breakdown deck and toggles pills', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final transactions = [
        TransactionModel(
          id: 1,
          amount: 5000.0,
          date: DateTime.now(),
          description: 'Groceries',
          category: 'Food',
          isExpense: true,
        ),
        TransactionModel(
          id: 2,
          amount: 2500.0,
          date: DateTime.now(),
          description: 'Fuel',
          category: 'Transport',
          isExpense: true,
        ),
      ];

      final monthlyData = [
        {'month': 'Jan', 'expense': 5000.0, 'income': 10000.0},
        {'month': 'Feb', 'expense': 7500.0, 'income': 12000.0},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                FinancialAnalyticsTab(
                  transactions: transactions,
                  monthlyData: monthlyData,
                  currency: 'Rs.',
                  settings: SettingsProvider(),
                  onRefresh: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify pill selector
      expect(find.text('Budgets'), findsWidgets);
      expect(find.text('Breakdown'), findsWidgets);

      // By default, Breakdown is selected 1st
      expect(find.text('Ranked Category Spend'), findsOneWidget);
      expect(find.text('Food'), findsWidgets);
      expect(find.text('Transport'), findsWidgets);

      // Tap Budgets pill
      await tester.tap(find.text('Budgets'));
      await tester.pumpAndSettle();

      expect(find.text('Set Monthly Budgets'), findsOneWidget);

      // Tap Savings pill
      expect(find.text('Savings'), findsWidgets);
      await tester.tap(find.text('Savings'));
      await tester.pumpAndSettle();

      expect(find.byType(SavingsGoalsCard), findsOneWidget);
    });
  });
}
