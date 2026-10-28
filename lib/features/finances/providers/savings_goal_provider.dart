import 'package:flutter/material.dart';
import '../data/models/savings_goal_model.dart';
import '../data/repositories/savings_goal_repository.dart';

class SavingsGoalProvider extends ChangeNotifier {
  final SavingsGoalRepository _repository = SavingsGoalRepository.instance;

  List<SavingsGoalModel> _goals = [];
  bool _isLoading = false;

  List<SavingsGoalModel> get goals => _goals;
  List<SavingsGoalModel> get activeGoals => _goals.where((g) => !g.isCompleted).toList();
  List<SavingsGoalModel> get completedGoals => _goals.where((g) => g.isCompleted).toList();
  bool get isLoading => _isLoading;

  double get totalTargetAmount => _goals.fold(0.0, (sum, g) => sum + g.targetAmount);
  double get totalCurrentAmount => _goals.fold(0.0, (sum, g) => sum + g.currentAmount);
  double get overallProgressRatio => totalTargetAmount > 0 ? (totalCurrentAmount / totalTargetAmount).clamp(0.0, 1.0) : 0.0;
  int get overallProgressPercent => (overallProgressRatio * 100).round();

  Future<void> loadGoals() async {
    _isLoading = true;
    notifyListeners();

    _goals = await _repository.getGoals(includeCompleted: true);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> createGoal(SavingsGoalModel goal) async {
    await _repository.createGoal(goal);
    await loadGoals();
  }

  Future<void> updateGoal(SavingsGoalModel goal) async {
    await _repository.updateGoal(goal);
    await loadGoals();
  }

  Future<void> deleteGoal(String id) async {
    await _repository.softDeleteGoal(id);
    await loadGoals();
  }

  Future<SavingsGoalModel?> deposit({
    required String goalId,
    required double amount,
    String fromAccount = 'daily',
    String toAccount = 'savings',
    bool recordLedgerTransaction = true,
    String? note,
  }) async {
    final updated = await _repository.recordDeposit(
      goalId: goalId,
      amount: amount,
      fromAccount: fromAccount,
      toAccount: toAccount,
      recordLedgerTransaction: recordLedgerTransaction,
      note: note,
    );
    await loadGoals();
    return updated;
  }

  Future<SavingsGoalModel?> withdraw({
    required String goalId,
    required double amount,
    String fromAccount = 'savings',
    String toAccount = 'daily',
    bool recordLedgerTransaction = true,
    String? note,
  }) async {
    final updated = await _repository.recordWithdrawal(
      goalId: goalId,
      amount: amount,
      fromAccount: fromAccount,
      toAccount: toAccount,
      recordLedgerTransaction: recordLedgerTransaction,
      note: note,
    );
    await loadGoals();
    return updated;
  }

  Future<void> liquidateGoal({
    required String goalId,
    required double amount,
    required String category,
    required String merchantTitle,
    bool recordLedgerTransaction = true,
  }) async {
    await _repository.liquidateGoal(
      goalId: goalId,
      amount: amount,
      category: category,
      merchantTitle: merchantTitle,
      recordLedgerTransaction: recordLedgerTransaction,
    );
    await loadGoals();
  }
}
