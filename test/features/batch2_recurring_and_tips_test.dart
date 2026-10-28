import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/data/recurring_rule_model.dart';
import 'package:note_taking_app/data/repositories/recurring_rule_repository.dart';
import 'package:note_taking_app/features/finances/data/transaction_repository.dart';
import 'package:note_taking_app/data/transaction_model.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/widgets/home/home_tip_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  group('Batch 2: Recurring Payments Smart Deduplication Tests', () {
    late Database testDb;

    setUp(() async {
      testDb = await openDatabase(
        inMemoryDatabasePath,
        version: 19,
        onCreate: (db, version) async {
          await DatabaseHelper.instance.createTestDatabase(db);
        },
      );
      DatabaseHelper.setMockDatabase(testDb);
    });

    tearDown(() async {
      await testDb.close();
      DatabaseHelper.setMockDatabase(null);
    });

    test('materializeDueRules inserts new transaction when no matching transaction exists', () async {
      final pastDate = DateTime.now().subtract(const Duration(days: 1));
      final rule = RecurringRule(
        id: 'rule_1',
        description: 'Netflix Monthly',
        amount: 15.99,
        category: 'Entertainment',
        isExpense: true,
        frequency: RecurringFrequency.monthly,
        nextDue: pastDate,
      );

      await RecurringRuleRepository.instance.createRule(rule);

      final count = await RecurringRuleRepository.instance.materializeDueRules();
      expect(count, 1);

      final transactions = await TransactionRepository.instance.readAllTransactions();
      expect(transactions.length, 1);
      expect(transactions.first.description, 'Netflix Monthly');
      expect(transactions.first.amount, 15.99);

      // Verify rule nextDue was advanced
      final updatedRules = await RecurringRuleRepository.instance.readAllRules();
      expect(updatedRules.first.nextDue.isAfter(pastDate), isTrue);
    });

    test('materializeDueRules skips inserting duplicate when matching SMS transaction exists within ±2 days', () async {
      final dueDate = DateTime.now().subtract(const Duration(hours: 12));
      // Pre-existing SMS transaction received 1 day before due date with slight fee/amount difference (within 1%)
      final smsTx = TransactionModel(
        amount: 16.05, // 15.99 vs 16.05 is within 1% / < 1.0 diff
        description: 'Netflix.com payment debited',
        category: 'Entertainment',
        date: dueDate.subtract(const Duration(days: 1)),
        isExpense: true,
        smsId: 'sms_netflix_123',
      );
      await TransactionRepository.instance.createTransaction(smsTx);

      final rule = RecurringRule(
        id: 'rule_netflix',
        description: 'Netflix',
        amount: 15.99,
        category: 'Entertainment',
        isExpense: true,
        frequency: RecurringFrequency.monthly,
        nextDue: dueDate,
      );
      await RecurringRuleRepository.instance.createRule(rule);

      // Materialize should detect duplicate and advance without creating extra transaction
      final createdCount = await RecurringRuleRepository.instance.materializeDueRules();
      expect(createdCount, 0);

      final allTx = await TransactionRepository.instance.readAllTransactions();
      expect(allTx.length, 1, reason: 'No duplicate transaction should have been added');

      // Ensure rule nextDue is advanced past dueDate
      final updatedRules = await RecurringRuleRepository.instance.readAllRules();
      expect(updatedRules.first.nextDue.isAfter(dueDate), isTrue);
    });

    test('daily recurring rule materializes every elapsed calendar day without skipping 3 out of 4 days', () async {
      final now = DateTime.now();
      final fourDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 4));

      final dailyRule = RecurringRule(
        id: 'rule_daily_commute',
        description: 'Daily Train Pass',
        amount: 250.0,
        category: 'Transport',
        isExpense: true,
        frequency: RecurringFrequency.daily,
        nextDue: fourDaysAgo,
      );
      await RecurringRuleRepository.instance.createRule(dailyRule);

      // Should materialize for 4 days ago, 3 days ago, 2 days ago, yesterday, and today (5 days total)
      final createdCount = await RecurringRuleRepository.instance.materializeDueRules();
      expect(createdCount, 5, reason: 'Daily rule due 4 days ago should materialize 5 consecutive days (including today)');

      final allTx = await TransactionRepository.instance.readAllTransactions();
      expect(allTx.length, 5);
    });

    test('two distinct subscriptions with identical amount and category on the same day both materialize', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      final spotifyRule = RecurringRule(
        id: 'rule_spotify',
        description: 'Spotify Premium',
        amount: 9.99,
        category: 'Subscriptions',
        isExpense: true,
        frequency: RecurringFrequency.monthly,
        nextDue: yesterday,
      );
      final appleMusicRule = RecurringRule(
        id: 'rule_apple_music',
        description: 'Apple Music',
        amount: 9.99,
        category: 'Subscriptions',
        isExpense: true,
        frequency: RecurringFrequency.monthly,
        nextDue: yesterday,
      );

      await RecurringRuleRepository.instance.createRule(spotifyRule);
      await RecurringRuleRepository.instance.createRule(appleMusicRule);

      final createdCount = await RecurringRuleRepository.instance.materializeDueRules();
      expect(createdCount, 2, reason: 'Both Spotify and Apple Music must materialize without cannibalizing each other');

      final allTx = await TransactionRepository.instance.readAllTransactions();
      expect(allTx.any((t) => t.description == 'Spotify Premium'), isTrue);
      expect(allTx.any((t) => t.description == 'Apple Music'), isTrue);
    });

    test('findMatchingRule does not falsely match unrelated transactions via generic words like monthly or payment', () async {
      final netflixRule = RecurringRule(
        id: 'rule_netflix_monthly',
        description: 'Monthly Netflix Payment',
        amount: 15.99,
        category: 'Subscriptions',
        isExpense: true,
        frequency: RecurringFrequency.monthly,
        nextDue: DateTime.now().add(const Duration(days: 10)),
      );
      await RecurringRuleRepository.instance.createRule(netflixRule);

      // Unrelated transaction that shares "Monthly" and "Payment"
      final falseMatch = await RecurringRuleRepository.instance.findMatchingRule(
        description: 'Monthly Grocery Payment',
        category: 'Groceries',
        isExpense: true,
        amount: 120.0,
      );
      expect(falseMatch, isNull, reason: 'Generic stopwords must not link unrelated transactions to existing rules');

      // Genuine match on "Netflix"
      final trueMatch = await RecurringRuleRepository.instance.findMatchingRule(
        description: 'Netflix Subscription',
        category: 'Subscriptions',
        isExpense: true,
        amount: 15.99,
      );
      expect(trueMatch, isNotNull);
      expect(trueMatch!.id, 'rule_netflix_monthly');
    });

    test('RecurringRule preserves account (Savings Vault vs Daily) and anchorDay across SQLite persistence', () async {
      final jan31 = DateTime(2026, 1, 31, 9, 0);
      final savingsRule = RecurringRule(
        id: 'rule_savings_transfer',
        description: 'Monthly Emergency Fund Deposit',
        amount: 5000.0,
        category: 'Savings',
        isExpense: false,
        frequency: RecurringFrequency.monthly,
        nextDue: jan31,
        account: AccountType.savings,
        anchorDay: 31,
      );

      await RecurringRuleRepository.instance.createRule(savingsRule);

      // Simulate clamping to Feb 28 in DB
      final clampedFeb = savingsRule.copyWith(
        nextDue: savingsRule.advance(jan31),
        anchorDay: savingsRule.anchorDay,
      );
      expect(clampedFeb.nextDue.month, 2);
      expect(clampedFeb.nextDue.day, 28);
      await RecurringRuleRepository.instance.updateRule(clampedFeb);

      final loaded = (await RecurringRuleRepository.instance.readAllRules())
          .firstWhere((r) => r.id == 'rule_savings_transfer');
      expect(loaded.account, AccountType.savings);
      expect(loaded.anchorDay, 31, reason: 'anchorDay 31 must survive SQLite round-trip after Feb 28 clamping');
      expect(loaded.advance(loaded.nextDue), DateTime(2026, 3, 31, 9, 0));
    });

    test('RecurringFrequency.unitName returns grammatically accurate singular nouns', () {
      expect(RecurringFrequency.daily.unitName, 'day');
      expect(RecurringFrequency.weekly.unitName, 'week');
      expect(RecurringFrequency.monthly.unitName, 'month');
    });
  });

  group('Batch 2: Pro-Tips UI & Provider Tests', () {
    test('SettingsProvider manages pro-tips state and rotation', () async {
      SharedPreferences.setMockInitialValues({
        'showProTips': true,
        'currentTipIndex': 2,
        'lastTipDismissedTimestamp': 0,
      });

      final settings = SettingsProvider();
      await settings.loadSettings();

      expect(settings.showProTips, isTrue);
      expect(settings.currentTipIndex, 2);
      expect(settings.isTipDue, isTrue);

      // Dismiss current tip
      await settings.dismissCurrentTip();
      expect(settings.currentTipIndex, 3);
      expect(settings.isTipDue, isFalse); // Just dismissed, not due for 3 days

      // Disable pro-tips
      await settings.setShowProTips(false);
      expect(settings.showProTips, isFalse);
      expect(settings.isTipDue, isFalse);
    });

    testWidgets('HomeTipCard renders tip content and handles callbacks', (tester) async {
      var dismissed = false;
      var disabled = false;

      const tip = ProTipItem(
        icon: Icons.sync_rounded,
        title: 'Zero-Cloud P2P Device Sync',
        description: 'Pair devices over local Wi-Fi to sync notes.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeTipCard(
              tip: tip,
              onDismiss: () => dismissed = true,
              onDisable: () => disabled = true,
            ),
          ),
        ),
      );

      expect(find.text('PRO-TIP'), findsOneWidget);
      expect(find.text('Zero-Cloud P2P Device Sync'), findsOneWidget);
      expect(find.text('Pair devices over local Wi-Fi to sync notes.'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
      expect(find.text("Don't show tips"), findsOneWidget);

      // Tap 'Got it'
      await tester.tap(find.text('Got it'));
      await tester.pump();
      expect(dismissed, isTrue);

      // Tap 'Don't show tips'
      await tester.tap(find.text("Don't show tips"));
      await tester.pump();
      expect(disabled, isTrue);
    });

    testWidgets('HomeTipCard renders action button and executes onAction', (tester) async {
      var actionTriggered = false;

      final tip = ProTipItem(
        icon: Icons.import_contacts_rounded,
        title: 'Migrate from Google Keep',
        description: 'Import your Google Keep notes & checklists.',
        actionLabel: 'Import Notes',
        onAction: () => actionTriggered = true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeTipCard(
              tip: tip,
              onDismiss: () {},
              onDisable: () {},
            ),
          ),
        ),
      );

      expect(find.text('Import Notes'), findsOneWidget);
      await tester.tap(find.text('Import Notes'));
      await tester.pump();
      expect(actionTriggered, isTrue);
    });
  });
}
