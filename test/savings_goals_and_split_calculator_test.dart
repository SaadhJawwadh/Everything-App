import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:note_taking_app/data/database_constants.dart';
import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/data/transaction_model.dart';
import 'package:note_taking_app/features/finances/data/models/savings_goal_model.dart';
import 'package:note_taking_app/features/finances/data/repositories/savings_goal_repository.dart';
import 'package:note_taking_app/features/finances/data/transaction_repository.dart';
import 'package:note_taking_app/services/backup_service.dart';
import 'package:note_taking_app/services/sync_merge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.instance.createTestDatabase(db);
    DatabaseHelper.setMockDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SavingsGoalModel Mathematics & Pacing Tests', () {
    test('Calculates progress ratio, percentage, and remaining amount correctly', () {
      final goal = SavingsGoalModel(
        id: 'goal-1',
        title: 'College Semester Fee',
        targetAmount: 50000.0,
        currentAmount: 25000.0,
        targetMonths: 5,
        monthlyContribution: 10000.0,
        createdAt: DateTime.now(),
      );

      expect(goal.progressRatio, 0.5);
      expect(goal.progressPercent, 50);
      expect(goal.remainingAmount, 25000.0);
      expect(goal.milestoneTier, 2);
      expect(goal.milestoneLabel, 'Halfway');
    });

    test('Milestone labels transition accurately across percentages', () {
      final base = SavingsGoalModel(
        id: 'g-tiers',
        title: 'Laptop',
        targetAmount: 1000.0,
        createdAt: DateTime.now(),
      );

      expect(base.copyWith(currentAmount: 100).milestoneLabel, '');
      expect(base.copyWith(currentAmount: 250).milestoneLabel, 'Quarterway');
      expect(base.copyWith(currentAmount: 500).milestoneLabel, 'Halfway');
      expect(base.copyWith(currentAmount: 850).milestoneLabel, 'Almost there!');
      expect(base.copyWith(currentAmount: 1000).milestoneLabel, 'Completed!');
    });

    test('Effective monthly pacing calculates remaining divided by months remaining', () {
      final futureDate = DateTime.now().add(const Duration(days: 92)); // ~3 months
      final goal = SavingsGoalModel(
        id: 'g-pace',
        title: 'Vacation',
        targetAmount: 30000.0,
        currentAmount: 15000.0,
        targetDate: futureDate,
        targetMonths: 3,
        createdAt: DateTime.now(),
      );

      // Remaining: 15000 / ~3 months = ~5000/mo
      expect(goal.effectiveMonthlyPace, closeTo(5000.0, 100.0));
      expect(goal.estimatedMonthsRemaining, 3);
    });

    test('JSON/SQLite Map serialization and deserialization is lossless', () {
      final now = DateTime.now();
      final original = SavingsGoalModel(
        id: 'goal-test-json',
        title: 'Emergency Fund',
        targetAmount: 100000.0,
        currentAmount: 40000.0,
        targetDate: now.add(const Duration(days: 180)),
        targetMonths: 6,
        monthlyContribution: 10000.0,
        category: 'Emergency',
        account: AccountType.savings,
        colorValue: 0xFF2196F3,
        iconCodePoint: 0xe57f,
        isCompleted: false,
        createdAt: now,
      );

      final map = original.toMap();
      final restored = SavingsGoalModel.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.targetAmount, original.targetAmount);
      expect(restored.currentAmount, original.currentAmount);
      expect(restored.targetMonths, original.targetMonths);
      expect(restored.category, original.category);
      expect(restored.account, original.account);
      expect(restored.colorValue, original.colorValue);
      expect(restored.iconCodePoint, original.iconCodePoint);
      expect(restored.isCompleted, original.isCompleted);
    });
  });

  group('SavingsGoalRepository Authentic Ledger Transactions Tests', () {
    test('Create goal and deposit with authentic transfer transaction in ledger', () async {
      final repo = SavingsGoalRepository.instance;
      final txRepo = TransactionRepository.instance;

      final goal = SavingsGoalModel(
        id: 'goal-college',
        title: 'College Semester',
        targetAmount: 50000.0,
        currentAmount: 0.0,
        targetMonths: 5,
        monthlyContribution: 10000.0,
        category: 'Education',
        account: AccountType.savings,
        createdAt: DateTime.now(),
      );

      await repo.createGoal(goal);

      // Verify goal stored
      final fetched = await repo.getGoalById('goal-college');
      expect(fetched, isNotNull);
      expect(fetched!.title, 'College Semester');
      expect(fetched.currentAmount, 0.0);

      // Deposit 10,000 with authentic ledger transaction enabled
      final afterDeposit = await repo.recordDeposit(
        goalId: 'goal-college',
        amount: 10000.0,
        fromAccount: AccountType.daily,
        toAccount: AccountType.savings,
        recordLedgerTransaction: true,
        note: 'Month 1 Contribution',
      );

      expect(afterDeposit, isNotNull);
      expect(afterDeposit!.currentAmount, 10000.0);
      expect(afterDeposit.isCompleted, isFalse);

      // Verify authentic ledger transactions were inserted:
      // 1. Daily Account: Expense/Transfer Out (-10000)
      // 2. Savings Account: Income/Transfer In (+10000)
      final allTx = await txRepo.readAllTransactions();
      expect(allTx.length, 2);

      final dailyTx = allTx.firstWhere((t) => t.account == AccountType.daily);
      expect(dailyTx.isExpense, isTrue);
      expect(dailyTx.amount, 10000.0);
      expect(dailyTx.description, contains('College Semester'));

      final savingsTx = allTx.firstWhere((t) => t.account == AccountType.savings);
      expect(savingsTx.isExpense, isFalse);
      expect(savingsTx.amount, 10000.0);
      expect(savingsTx.description, contains('College Semester'));
    });

    test('Target reached marks goal completed automatically', () async {
      final repo = SavingsGoalRepository.instance;

      final goal = SavingsGoalModel(
        id: 'goal-gadget',
        title: 'Noise Cancelling Headphones',
        targetAmount: 15000.0,
        currentAmount: 10000.0,
        targetMonths: 2,
        monthlyContribution: 7500.0,
        category: 'Electronics',
        account: AccountType.savings,
        createdAt: DateTime.now(),
      );

      await repo.createGoal(goal);

      // Deposit remaining 5000
      final updated = await repo.recordDeposit(
        goalId: 'goal-gadget',
        amount: 5000.0,
        recordLedgerTransaction: false,
      );

      expect(updated!.currentAmount, 15000.0);
      expect(updated.isCompleted, isTrue);
      expect(updated.completedAt, isNotNull);
    });

    test('Withdrawal updates goal balance and creates return ledger transaction', () async {
      final repo = SavingsGoalRepository.instance;
      final txRepo = TransactionRepository.instance;

      final goal = SavingsGoalModel(
        id: 'goal-withdraw-test',
        title: 'Emergency Reserve',
        targetAmount: 20000.0,
        currentAmount: 15000.0,
        createdAt: DateTime.now(),
      );
      await repo.createGoal(goal);

      // Withdraw 5000 back to daily operating account
      final updated = await repo.recordWithdrawal(
        goalId: 'goal-withdraw-test',
        amount: 5000.0,
        fromAccount: AccountType.savings,
        toAccount: AccountType.daily,
        recordLedgerTransaction: true,
        note: 'Car repair urgent draw',
      );

      expect(updated!.currentAmount, 10000.0);

      // Verify return transactions created in ledger
      final allTx = await txRepo.readAllTransactions();
      expect(allTx.length, 2);
      final dailyTx = allTx.firstWhere((t) => t.account == AccountType.daily);
      expect(dailyTx.isExpense, isFalse); // Credited back to daily
      expect(dailyTx.amount, 5000.0);
    });

    test('Liquidate goal logs authentic expenditure in ledger and completes goal', () async {
      final repo = SavingsGoalRepository.instance;
      final txRepo = TransactionRepository.instance;

      final goal = SavingsGoalModel(
        id: 'goal-tuition',
        title: 'University Tuition Sem 1',
        targetAmount: 40000.0,
        currentAmount: 40000.0,
        category: 'Education',
        account: AccountType.savings,
        createdAt: DateTime.now(),
      );
      await repo.createGoal(goal);

      await repo.liquidateGoal(
        goalId: 'goal-tuition',
        amount: 40000.0,
        category: 'Education',
        merchantTitle: 'City University Bursar',
      );

      final updated = await repo.getGoalById('goal-tuition');
      expect(updated!.isCompleted, isTrue);
      expect(updated.completedAt, isNotNull);

      // Verify expense logged in user ledger
      final allTx = await txRepo.readAllTransactions();
      expect(allTx.length, 1);
      final tuitionExpense = allTx.first;
      expect(tuitionExpense.isExpense, isTrue);
      expect(tuitionExpense.amount, 40000.0);
      expect(tuitionExpense.category, 'Education');
      expect(tuitionExpense.description, 'City University Bursar');
      expect(tuitionExpense.account, AccountType.savings);
    });

    test('Soft delete goal sets deletedAt and excludes from default queries', () async {
      final repo = SavingsGoalRepository.instance;

      final goal = SavingsGoalModel(
        id: 'goal-delete-test',
        title: 'Temporary Goal',
        targetAmount: 5000.0,
        createdAt: DateTime.now(),
      );
      await repo.createGoal(goal);

      await repo.softDeleteGoal('goal-delete-test');

      final activeGoals = await repo.getGoals(includeCompleted: true);
      expect(activeGoals.any((g) => g.id == 'goal-delete-test'), isFalse);
    });
  });

  group('Split Bill Itemized Calculator & Proportional Distribution Tests', () {
    test('Allocates tax and tip proportionally across participant subtotals', () {
      // Subtotals:
      // User: 500.0
      // Alice: 300.0
      // Bob: 200.0
      // Total Subtotal: 1000.0
      final subtotals = {
        'You': 500.0,
        'Alice': 300.0,
        'Bob': 200.0,
      };

      const taxPercent = 10.0; // 10% = 100.0 total
      const tipPercent = 15.0; // 15% = 150.0 total
      const flatFee = 50.0;    // 50.0 split equally between 3 = 16.67 each

      final subtotalSum = subtotals.values.fold(0.0, (sum, v) => sum + v);
      final totalTax = subtotalSum * (taxPercent / 100.0);
      final totalTip = subtotalSum * (tipPercent / 100.0);
      final feePerPerson = flatFee / subtotals.length;

      final allocatedShares = <String, double>{};
      for (final entry in subtotals.entries) {
        final shareRatio = entry.value / subtotalSum;
        final personTax = totalTax * shareRatio;
        final personTip = totalTip * shareRatio;
        final total = entry.value + personTax + personTip + feePerPerson;
        allocatedShares[entry.key] = double.parse(total.toStringAsFixed(2));
      }

      // User (50%): 500 + 50 (tax) + 75 (tip) + 16.67 = 641.67
      expect(allocatedShares['You'], 641.67);
      // Alice (30%): 300 + 30 (tax) + 45 (tip) + 16.67 = 391.67
      expect(allocatedShares['Alice'], 391.67);
      // Bob (20%): 200 + 20 (tax) + 30 (tip) + 16.67 = 266.67
      expect(allocatedShares['Bob'], 266.67);

      final grandTotal = allocatedShares.values.fold(0.0, (s, v) => s + v);
      // Subtotal (1000) + Tax (100) + Tip (150) + Fee (50) = 1300.01 (penny variance within rounding tolerance)
      expect(grandTotal, closeTo(1300.0, 0.05));
    });

    test('Penny remainder reconciliation fills leftover accurately', () {
      const billTotal = 100.0;
      final allocated = [33.33, 33.33];
      final allocatedSum = allocated.fold(0.0, (s, v) => s + v); // 66.66
      final remaining = billTotal - allocatedSum; // 33.34

      expect(remaining, closeTo(33.34, 0.001));
    });

    test('Custom split integer cent distribution sums to exactly totalAmount with zero penny variance', () {
      List<double> distribute(double totalAmount, int count) {
        final totalCents = (totalAmount * 100).round();
        final baseCents = totalCents ~/ count;
        final remCents = totalCents % count;

        final result = <double>[];
        for (int i = 0; i < count; i++) {
          final cents = baseCents + (i < remCents ? 1 : 0);
          result.add(cents / 100.0);
        }
        return result;
      }

      // Case 1: 100 split 3 ways
      final split100 = distribute(100.0, 3);
      expect(split100, [33.34, 33.33, 33.33]);
      expect(split100.fold(0.0, (s, v) => s + v), closeTo(100.0, 0.0001));

      // Case 2: 250 split 4 ways
      final split250 = distribute(250.0, 4);
      expect(split250, [62.50, 62.50, 62.50, 62.50]);
      expect(split250.fold(0.0, (s, v) => s + v), closeTo(250.0, 0.0001));

      // Case 3: 10 split 3 ways
      final split10 = distribute(10.0, 3);
      expect(split10, [3.34, 3.33, 3.33]);
      expect(split10.fold(0.0, (s, v) => s + v), closeTo(10.0, 0.0001));

      // Case 4: 0.05 split 2 ways
      final split5c = distribute(0.05, 2);
      expect(split5c, [0.03, 0.02]);
      expect(split5c.fold(0.0, (s, v) => s + v), closeTo(0.05, 0.0001));

      // Case 5: 1234.56 split 7 ways
      final splitOdd = distribute(1234.56, 7);
      expect(splitOdd.length, 7);
      expect(splitOdd.fold(0.0, (s, v) => s + v), closeTo(1234.56, 0.0001));
    });
  });

  group('BackupService & SyncMergeService Savings Goals Parity Tests', () {
    test('Backup JSON payload includes savings_goals and restores accurately', () async {
      final repo = SavingsGoalRepository.instance;

      final originalGoal = SavingsGoalModel(
        id: 'backup-goal-1',
        title: 'Gold Coin Savings',
        targetAmount: 75000.0,
        currentAmount: 30000.0,
        targetMonths: 8,
        monthlyContribution: 9375.0,
        category: 'Savings',
        account: AccountType.savings,
        colorValue: 0xFFFF9800,
        iconCodePoint: 0xe57f,
        createdAt: DateTime.now(),
      );
      await repo.createGoal(originalGoal);

      final jsonStr = await generateBackupJson();
      expect(jsonStr, isNotEmpty);

      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded.containsKey('savingsGoals'), isTrue);

      final goalsJson = decoded['savingsGoals'] as List;
      expect(goalsJson.length, 1);
      expect(goalsJson.first['title'], 'Gold Coin Savings');

      // Clear table to test restore
      await db.delete(TableNames.savingsGoals);
      expect((await repo.getGoals(includeCompleted: true)).isEmpty, isTrue);

      // Restore from backup JSON
      await BackupService.restoreFromBackupData(decoded);

      final restoredList = await repo.getGoals(includeCompleted: true);
      expect(restoredList.length, 1);
      expect(restoredList.first.title, 'Gold Coin Savings');
      expect(restoredList.first.currentAmount, 30000.0);
      expect(restoredList.first.account, AccountType.savings);
    });

    test('SyncMergeService delta merge handles remote savings goals non-destructively', () async {
      final syncService = SyncMergeService.instance;
      final repo = SavingsGoalRepository.instance;

      final remotePayload = {
        'savings_goals': [
          {
            'id': 'remote-goal-1',
            'title': 'MacBook Pro',
            'targetAmount': 200000.0,
            'currentAmount': 50000.0,
            'targetMonths': 10,
            'monthlyContribution': 20000.0,
            'category': 'Electronics',
            'account': 'savings',
            'colorValue': 0xFF2196F3,
            'iconCodePoint': 0xe395,
            'isCompleted': 0,
            'createdAt': DateTime.now().toIso8601String(),
          }
        ]
      };

      await syncService.mergeRemoteData(remotePayload);

      final goals = await repo.getGoals(includeCompleted: true);
      expect(goals.any((g) => g.id == 'remote-goal-1'), isTrue);
      final syncedGoal = goals.firstWhere((g) => g.id == 'remote-goal-1');
      expect(syncedGoal.title, 'MacBook Pro');
      expect(syncedGoal.targetAmount, 200000.0);
    });
  });
}
