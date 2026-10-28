import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../data/database_helper.dart';
import '../../../../data/database_constants.dart';
import '../../../../data/transaction_model.dart';
import '../../../../utils/widget_helper.dart';
import '../../presentation/screens/financial_manager_screen.dart';
import '../models/savings_goal_model.dart';

class SavingsGoalRepository {
  static final SavingsGoalRepository instance = SavingsGoalRepository._();
  SavingsGoalRepository._();

  DatabaseHelper get _dbHelper => DatabaseHelper.instance;

  Future<List<SavingsGoalModel>> getGoals({bool includeCompleted = true}) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>['${SavingsGoalFields.deletedAt} IS NULL'];
    if (!includeCompleted) {
      whereClauses.add('${SavingsGoalFields.isCompleted} = 0');
    }

    final maps = await db.query(
      TableNames.savingsGoals,
      where: whereClauses.join(' AND '),
      orderBy: '${SavingsGoalFields.isCompleted} ASC, ${SavingsGoalFields.createdAt} DESC',
    );

    return maps.map(SavingsGoalModel.fromMap).toList();
  }

  Future<SavingsGoalModel?> getGoalById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      TableNames.savingsGoals,
      where: '${SavingsGoalFields.id} = ? AND ${SavingsGoalFields.deletedAt} IS NULL',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return SavingsGoalModel.fromMap(maps.first);
  }

  Future<void> createGoal(SavingsGoalModel goal) async {
    final db = await _dbHelper.database;
    await db.insert(
      TableNames.savingsGoals,
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateGoal(SavingsGoalModel goal) async {
    final db = await _dbHelper.database;
    await db.update(
      TableNames.savingsGoals,
      goal.toMap(),
      where: '${SavingsGoalFields.id} = ?',
      whereArgs: [goal.id],
    );
  }

  Future<void> softDeleteGoal(String id) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      TableNames.savingsGoals,
      {SavingsGoalFields.deletedAt: now},
      where: '${SavingsGoalFields.id} = ?',
      whereArgs: [id],
    );
  }

  /// Records an authentic transfer deposit into the goal:
  /// Moving funds from [fromAccount] (e.g. Daily) to [toAccount] (e.g. Savings)
  /// and crediting the goal's currentAmount.
  Future<SavingsGoalModel?> recordDeposit({
    required String goalId,
    required double amount,
    String fromAccount = AccountType.daily,
    String toAccount = AccountType.savings,
    bool recordLedgerTransaction = true,
    String? note,
  }) async {
    if (amount <= 0) return null;
    final db = await _dbHelper.database;
    final goal = await getGoalById(goalId);
    if (goal == null) return null;

    final newAmount = goal.currentAmount + amount;
    final isCompleted = newAmount >= goal.targetAmount;
    final now = DateTime.now();

    final updatedGoal = goal.copyWith(
      currentAmount: newAmount,
      isCompleted: isCompleted,
      completedAt: isCompleted ? (goal.completedAt ?? now) : null,
    );

    await db.transaction((txn) async {
      await txn.update(
        TableNames.savingsGoals,
        updatedGoal.toMap(),
        where: '${SavingsGoalFields.id} = ?',
        whereArgs: [goalId],
      );

      if (recordLedgerTransaction) {
        // Authentically log the transfer transaction in personal ledger
        // Debit from source account
        final desc = note != null && note.trim().isNotEmpty
            ? 'Goal Deposit: ${goal.title} ($note)'
            : 'Goal Deposit: ${goal.title}';

        final debitTx = TransactionModel(
          amount: amount,
          description: desc,
          date: now,
          isExpense: true,
          category: 'Transfer',
          account: fromAccount,
        );
        await txn.insert(TableNames.transactions, debitTx.toJson());

        // Credit to target savings account
        final creditTx = TransactionModel(
          amount: amount,
          description: desc,
          date: now,
          isExpense: false,
          category: 'Transfer',
          account: toAccount,
        );
        await txn.insert(TableNames.transactions, creditTx.toJson());
      }
    });

    try {
      FinancialManagerScreen.refreshNotifier.value = DateTime.now().millisecondsSinceEpoch;
      await WidgetHelper.updateWidgetData();
    } catch (_) {}

    return updatedGoal;
  }

  /// Records a withdrawal from the goal back to operating funds
  Future<SavingsGoalModel?> recordWithdrawal({
    required String goalId,
    required double amount,
    String fromAccount = AccountType.savings,
    String toAccount = AccountType.daily,
    bool recordLedgerTransaction = true,
    String? note,
  }) async {
    if (amount <= 0) return null;
    final db = await _dbHelper.database;
    final goal = await getGoalById(goalId);
    if (goal == null) return null;

    final actualWithdrawn = amount > goal.currentAmount ? goal.currentAmount : amount;
    if (actualWithdrawn <= 0) return goal;
    final newAmount = (goal.currentAmount - actualWithdrawn).clamp(0.0, double.infinity);
    final isCompleted = newAmount >= goal.targetAmount;
    final now = DateTime.now();

    final updatedGoal = goal.copyWith(
      currentAmount: newAmount,
      isCompleted: isCompleted,
      completedAt: isCompleted ? goal.completedAt : null,
    );

    await db.transaction((txn) async {
      await txn.update(
        TableNames.savingsGoals,
        updatedGoal.toMap(),
        where: '${SavingsGoalFields.id} = ?',
        whereArgs: [goalId],
      );

      if (recordLedgerTransaction) {
        final desc = note != null && note.trim().isNotEmpty
            ? 'Goal Withdrawal: ${goal.title} ($note)'
            : 'Goal Withdrawal: ${goal.title}';

        final debitTx = TransactionModel(
          amount: actualWithdrawn,
          description: desc,
          date: now,
          isExpense: true,
          category: 'Transfer',
          account: fromAccount,
        );
        await txn.insert(TableNames.transactions, debitTx.toJson());

        final creditTx = TransactionModel(
          amount: actualWithdrawn,
          description: desc,
          date: now,
          isExpense: false,
          category: 'Transfer',
          account: toAccount,
        );
        await txn.insert(TableNames.transactions, creditTx.toJson());
      }
    });

    try {
      FinancialManagerScreen.refreshNotifier.value = DateTime.now().millisecondsSinceEpoch;
      await WidgetHelper.updateWidgetData();
    } catch (_) {}

    return updatedGoal;
  }

  /// Liquidates a completed goal by recording an expense against the Savings Vault account
  Future<void> liquidateGoal({
    required String goalId,
    required double amount,
    required String category,
    required String merchantTitle,
    bool recordLedgerTransaction = true,
  }) async {
    final db = await _dbHelper.database;
    final goal = await getGoalById(goalId);
    if (goal == null) return;

    final now = DateTime.now();
    final updatedGoal = goal.copyWith(
      isCompleted: true,
      completedAt: now,
    );

    await db.transaction((txn) async {
      await txn.update(
        TableNames.savingsGoals,
        updatedGoal.toMap(),
        where: '${SavingsGoalFields.id} = ?',
        whereArgs: [goalId],
      );

      if (recordLedgerTransaction) {
        final expenseTx = TransactionModel(
          amount: amount,
          description: merchantTitle.isNotEmpty ? merchantTitle : 'Spent Goal: ${goal.title}',
          date: now,
          isExpense: true,
          category: category,
          account: goal.account,
        );
        await txn.insert(TableNames.transactions, expenseTx.toJson());
      }
    });

    try {
      FinancialManagerScreen.refreshNotifier.value = DateTime.now().millisecondsSinceEpoch;
      await WidgetHelper.updateWidgetData();
    } catch (_) {}
  }
}
