import 'dart:async';
import 'package:flutter/material.dart';
import '../data/models/savings_goal_model.dart';
import '../data/repositories/savings_goal_repository.dart';
import '../../../services/p2p_sync_service.dart';
import '../../sync/providers/p2p_sync_provider.dart';

class SavingsGoalProvider extends ChangeNotifier {
  final SavingsGoalRepository _repository = SavingsGoalRepository.instance;
  StreamSubscription? _syncEventsSubscription;

  SavingsGoalProvider() {
    _syncEventsSubscription = P2pSyncService.instance.syncEvents.listen((result) {
      if (result.success) {
        loadGoals();
      }
    });
  }

  @override
  void dispose() {
    _syncEventsSubscription?.cancel();
    super.dispose();
  }

  List<SavingsGoalModel> _goals = [];
  List<SavingsGoalModel> _activeGoals = const [];
  List<SavingsGoalModel> _completedGoals = const [];
  double _totalTargetAmount = 0.0;
  double _totalCurrentAmount = 0.0;
  bool _isLoading = false;

  List<SavingsGoalModel> get goals => _goals;
  List<SavingsGoalModel> get activeGoals => _activeGoals;
  List<SavingsGoalModel> get completedGoals => _completedGoals;
  bool get isLoading => _isLoading;

  double get totalTargetAmount => _totalTargetAmount;
  double get totalCurrentAmount => _totalCurrentAmount;
  double get overallProgressRatio => _totalTargetAmount > 0 ? (_totalCurrentAmount / _totalTargetAmount).clamp(0.0, 1.0) : 0.0;
  int get overallProgressPercent => (overallProgressRatio * 100).round();

  void _rebuildGoalCache() {
    _activeGoals = List.unmodifiable(_goals.where((g) => !g.isCompleted));
    _completedGoals = List.unmodifiable(_goals.where((g) => g.isCompleted));
    double target = 0.0;
    double current = 0.0;
    for (final g in _goals) {
      target += g.targetAmount;
      current += g.currentAmount;
    }
    _totalTargetAmount = target;
    _totalCurrentAmount = current;
  }

  Future<void> loadGoals() async {
    if (_goals.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    _goals = await _repository.getGoals(includeCompleted: true);
    _rebuildGoalCache();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> createGoal(SavingsGoalModel goal) async {
    await _repository.createGoal(goal);
    await loadGoals();
    P2pSyncProvider.activeInstance?.triggerEventSync();
  }

  Future<void> updateGoal(SavingsGoalModel goal) async {
    await _repository.updateGoal(goal);
    await loadGoals();
    P2pSyncProvider.activeInstance?.triggerEventSync();
  }

  Future<void> deleteGoal(String id) async {
    await _repository.softDeleteGoal(id);
    await loadGoals();
    P2pSyncProvider.activeInstance?.triggerEventSync();
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
    P2pSyncProvider.activeInstance?.triggerEventSync();
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
    P2pSyncProvider.activeInstance?.triggerEventSync();
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
    P2pSyncProvider.activeInstance?.triggerEventSync();
  }
}
