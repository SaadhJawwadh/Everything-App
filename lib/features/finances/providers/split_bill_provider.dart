import 'dart:async';
import 'package:flutter/material.dart';
import '../data/models/split_bill_model.dart';
import '../data/repositories/split_bill_repository.dart';
import '../data/transaction_repository.dart';
import '../presentation/screens/financial_manager_screen.dart';
import '../../../services/p2p_sync_service.dart';
import '../../sync/providers/p2p_sync_provider.dart';

class SplitBillProvider extends ChangeNotifier {
  final SplitBillRepository _repository = SplitBillRepository.instance;
  StreamSubscription? _syncEventsSubscription;

  SplitBillProvider() {
    _syncEventsSubscription = P2pSyncService.instance.syncEvents.listen((result) {
      if (result.success) {
        loadSplitBills(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _syncEventsSubscription?.cancel();
    super.dispose();
  }

  List<SplitBillModel> _bills = [];
  List<SplitContactModel> _recentContacts = [];
  Map<String, double> _contactBalances = {};
  double _totalOwedToUser = 0.0;
  double _totalUserOwes = 0.0;
  bool _isLoading = false;
  String _activeFilter = 'all'; // 'all', 'unsettled', 'settled', 'i_am_owed', 'i_owe'
  String? _activeGroupTag;
  int _activeViewMode = 0; // 0: People View, 1: Bills View

  List<String>? _cachedAvailableGroupTags;
  List<SplitBillModel>? _cachedFilteredBills;
  Map<String, List<SplitBillModel>> _openBillsByContactLower = const {};
  Set<String> _contactsWithSettledBillsLower = const {};

  List<SplitBillModel> get bills => _bills;
  List<SplitContactModel> get recentContacts => _recentContacts;
  Map<String, double> get contactBalances => _contactBalances;
  Map<String, double> get contactNetBalances => _contactBalances;
  double get totalOwedToUser => _totalOwedToUser;
  double get totalUserOwes => _totalUserOwes;
  double get netBalance => _totalOwedToUser - _totalUserOwes;
  bool get isLoading => _isLoading;
  String get activeFilter => _activeFilter;
  String? get activeGroupTag => _activeGroupTag;
  int get activeViewMode => _activeViewMode;

  /// O(1) lookup for unsettled bills involving [name] (case-insensitive).
  List<SplitBillModel> openBillsForContact(String name) =>
      _openBillsByContactLower[name.trim().toLowerCase()] ?? const [];

  /// O(1) lookup indicating whether [name] has any settled bills.
  bool contactHasSettledBills(String name) =>
      _contactsWithSettledBillsLower.contains(name.trim().toLowerCase());

  List<String> get availableGroupTags {
    return _cachedAvailableGroupTags ??= () {
      final tags = <String>{};
      for (final bill in _bills) {
        if (bill.groupTag != null && bill.groupTag!.trim().isNotEmpty) {
          tags.add(bill.groupTag!.trim());
        }
      }
      return List<String>.unmodifiable(tags.toList()..sort());
    }();
  }

  List<SplitBillModel> get filteredBills {
    return _cachedFilteredBills ??= List<SplitBillModel>.unmodifiable(_bills.where((bill) {
      if (_activeGroupTag != null && _activeGroupTag!.isNotEmpty && _activeGroupTag != 'All') {
        if (bill.groupTag?.toLowerCase() != _activeGroupTag!.toLowerCase()) {
          return false;
        }
      }

      switch (_activeFilter) {
        case 'unsettled':
          return !bill.isFullySettled;
        case 'settled':
          return bill.isFullySettled;
        case 'i_am_owed':
          return bill.isPayerUser && !bill.isFullySettled;
        case 'i_owe':
          return !bill.isPayerUser && !bill.isFullySettled;
        default:
          return true;
      }
    }));
  }

  Future<void> loadSplitBills({bool showLoading = false}) async {
    if (showLoading && _bills.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final results = await Future.wait<dynamic>([
        _repository.getSplitBills(includeSettled: true),
        _repository.getRecentContacts(),
      ]);
      _bills = results[0] as List<SplitBillModel>;
      _recentContacts = results[1] as List<SplitContactModel>;
      _cachedAvailableGroupTags = null;
      _cachedFilteredBills = null;
      _recalculateMetrics();
    } catch (e) {
      debugPrint('[SplitBillProvider] Error loading bills: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(String filter) {
    if (_activeFilter != filter) {
      _activeFilter = filter;
      _cachedFilteredBills = null;
      notifyListeners();
    }
  }

  void setGroupTag(String? groupTag) {
    if (_activeGroupTag != groupTag) {
      _activeGroupTag = groupTag;
      _cachedFilteredBills = null;
      notifyListeners();
    }
  }

  void setViewMode(int mode) {
    if (_activeViewMode != mode) {
      _activeViewMode = mode;
      notifyListeners();
    }
  }

  Future<void> createBill(SplitBillModel bill) async {
    // Optimistic insert
    _bills.insert(0, bill);
    _recalculateMetrics();
    notifyListeners();

    try {
      await _repository.insertSplitBill(bill);
      await loadSplitBills(showLoading: false);
      P2pSyncProvider.activeInstance?.triggerEventSync();
    } catch (e) {
      debugPrint('[SplitBillProvider] Error creating bill: $e');
      await loadSplitBills(showLoading: false);
    }
  }

  Future<void> updateBill(SplitBillModel bill) async {
    final index = _bills.indexWhere((b) => b.id == bill.id);
    if (index != -1) {
      _bills[index] = bill;
      _recalculateMetrics();
      notifyListeners();
    }

    try {
      await _repository.updateSplitBill(bill);
      if (bill.transactionId != null) {
        FinancialManagerScreen.refreshNotifier.value++;
      }
      await loadSplitBills(showLoading: false);
      P2pSyncProvider.activeInstance?.triggerEventSync();
    } catch (e) {
      debugPrint('[SplitBillProvider] Error updating bill: $e');
      await loadSplitBills(showLoading: false);
    }
  }

  Future<void> deleteBill(String id) async {
    final deleted = _bills.where((b) => b.id == id).toList();
    _bills.removeWhere((b) => b.id == id);
    _recalculateMetrics();
    notifyListeners();

    try {
      await _repository.softDeleteSplitBill(id);
      FinancialManagerScreen.refreshNotifier.value++;
      await loadSplitBills(showLoading: false);
      P2pSyncProvider.activeInstance?.triggerEventSync();
    } catch (e) {
      if (deleted.isNotEmpty) {
        _bills.add(deleted.first);
        _recalculateMetrics();
        notifyListeners();
      }
    }
  }

  Future<void> restoreBill(String id) async {
    try {
      await _repository.restoreSplitBill(id);
      FinancialManagerScreen.refreshNotifier.value++;
      await loadSplitBills(showLoading: false);
    } catch (e) {
      debugPrint('[SplitBillProvider] Error restoring bill: $e');
      await loadSplitBills(showLoading: false);
    }
  }

  Future<int?> toggleParticipantPaid(
    String participantId,
    bool hasPaid, {
    int? settlementTransactionId,
  }) async {
    // 0ms Optimistic UI mutation
    for (int i = 0; i < _bills.length; i++) {
      final b = _bills[i];
      final pIndex = b.participants.indexWhere((p) => p.id == participantId);
      if (pIndex != -1) {
        final updatedParticipants = List<SplitParticipantModel>.from(b.participants);
        updatedParticipants[pIndex] = updatedParticipants[pIndex].copyWith(
          hasPaid: hasPaid,
          paidAt: hasPaid ? DateTime.now() : null,
          settlementTransactionId: hasPaid ? settlementTransactionId : null,
          clearSettlementTxId: !hasPaid,
        );
        final updatedBill = b.copyWith(
          participants: updatedParticipants,
          status: b.copyWith(participants: updatedParticipants).computeDerivedStatus(),
        );
        _bills[i] = updatedBill;
        break;
      }
    }
    _recalculateMetrics();
    notifyListeners();

    try {
      final removedTxId = await _repository.toggleParticipantPaid(
        participantId,
        hasPaid,
        settlementTransactionId: settlementTransactionId,
      );
      if (!hasPaid && removedTxId != null) {
        await TransactionRepository.instance.deleteTransaction(removedTxId);
        FinancialManagerScreen.refreshNotifier.value++;
      }
      _contactBalances = await _repository.getContactNetBalances();
      notifyListeners();
      return removedTxId;
    } catch (e) {
      await loadSplitBills(showLoading: false);
      return null;
    }
  }

  Future<int?> toggleUserShareForBill(
    String billId,
    bool hasPaid, {
    int? settlementTransactionId,
  }) async {
    for (int i = 0; i < _bills.length; i++) {
      final b = _bills[i];
      if (b.id == billId) {
        final pIndex = b.participants.indexWhere((p) => p.contactName.trim().toLowerCase() == 'you');
        final updatedParticipants = List<SplitParticipantModel>.from(b.participants);
        if (pIndex != -1) {
          updatedParticipants[pIndex] = updatedParticipants[pIndex].copyWith(
            hasPaid: hasPaid,
            paidAt: hasPaid ? DateTime.now() : null,
            settlementTransactionId: hasPaid ? settlementTransactionId : null,
            clearSettlementTxId: !hasPaid,
          );
        } else if (hasPaid) {
          updatedParticipants.add(
            SplitParticipantModel(
              id: '${billId}_you',
              billId: billId,
              contactName: 'You',
              shareAmount: b.userShare,
              hasPaid: true,
              paidAt: DateTime.now(),
              settlementTransactionId: settlementTransactionId,
            ),
          );
        }
        final updatedBill = b.copyWith(
          participants: updatedParticipants,
          status: b.copyWith(participants: updatedParticipants).computeDerivedStatus(),
        );
        _bills[i] = updatedBill;
        break;
      }
    }
    _recalculateMetrics();
    notifyListeners();

    try {
      final removedTxId = await _repository.toggleUserShareForBill(
        billId,
        hasPaid,
        settlementTransactionId: settlementTransactionId,
      );
      if (!hasPaid && removedTxId != null) {
        await TransactionRepository.instance.deleteTransaction(removedTxId);
        FinancialManagerScreen.refreshNotifier.value++;
      }
      _contactBalances = await _repository.getContactNetBalances();
      notifyListeners();
      return removedTxId;
    } catch (e) {
      await loadSplitBills(showLoading: false);
      return null;
    }
  }

  Future<void> settleAllForContact(
    String contactName, {
    int? settlementTransactionId,
  }) async {
    // Optimistic mutation
    final now = DateTime.now();
    for (int i = 0; i < _bills.length; i++) {
      final b = _bills[i];
      if (b.isPayerUser) {
        final updatedParticipants = b.participants.map((p) {
          if (p.contactName.trim().toLowerCase() == contactName.trim().toLowerCase()) {
            return p.copyWith(
              hasPaid: true,
              paidAt: now,
              settlementTransactionId: settlementTransactionId,
            );
          }
          return p;
        }).toList();
        _bills[i] = b.copyWith(
          participants: updatedParticipants,
          status: b.copyWith(participants: updatedParticipants).computeDerivedStatus(),
        );
      } else if (b.payerName.trim().toLowerCase() == contactName.trim().toLowerCase()) {
        final updatedParticipants = b.participants.map((p) {
          if (p.contactName.trim().toLowerCase() == 'you') {
            return p.copyWith(
              hasPaid: true,
              paidAt: now,
              settlementTransactionId: settlementTransactionId,
            );
          }
          return p;
        }).toList();
        _bills[i] = b.copyWith(
          participants: updatedParticipants,
          status: SplitStatus.settled,
        );
      }
    }
    _contactBalances[contactName] = 0.0;
    _recalculateMetrics();
    notifyListeners();

    try {
      await _repository.settleAllForContact(
        contactName,
        settlementTransactionId: settlementTransactionId,
      );
      await loadSplitBills(showLoading: false);
    } catch (e) {
      await loadSplitBills(showLoading: false);
    }
  }

  Future<List<int>> unsettleAllForContact(String contactName) async {
    final normalized = contactName.trim().toLowerCase();
    for (int i = 0; i < _bills.length; i++) {
      final b = _bills[i];
      if (b.isPayerUser) {
        final updatedParticipants = b.participants.map((p) {
          if (p.contactName.trim().toLowerCase() == normalized) {
            return p.copyWith(hasPaid: false, paidAt: null, clearSettlementTxId: true);
          }
          return p;
        }).toList();
        _bills[i] = b.copyWith(
          participants: updatedParticipants,
          status: b.copyWith(participants: updatedParticipants).computeDerivedStatus(),
        );
      } else if (b.payerName.trim().toLowerCase() == normalized) {
        final updatedParticipants = b.participants.map((p) {
          if (p.contactName.trim().toLowerCase() == 'you') {
            return p.copyWith(hasPaid: false, paidAt: null, clearSettlementTxId: true);
          }
          return p;
        }).toList();
        _bills[i] = b.copyWith(
          participants: updatedParticipants,
          status: b.copyWith(participants: updatedParticipants).computeDerivedStatus(),
        );
      }
    }
    _recalculateMetrics();
    notifyListeners();

    try {
      final removedTxIds = await _repository.unsettleAllForContact(contactName);
      for (final txId in removedTxIds) {
        await TransactionRepository.instance.deleteTransaction(txId);
      }
      if (removedTxIds.isNotEmpty) {
        FinancialManagerScreen.refreshNotifier.value++;
      }
      await loadSplitBills(showLoading: false);
      return removedTxIds;
    } catch (e) {
      await loadSplitBills(showLoading: false);
      return [];
    }
  }

  void _recalculateMetrics() {
    double owedToUser = 0.0;
    double userOwes = 0.0;
    final lowerBalances = <String, double>{};
    final firstSeenCase = <String, String>{};
    final openByContact = <String, List<SplitBillModel>>{};
    final settledContacts = <String>{};

    for (final bill in _bills) {
      if (bill.deletedAt != null) continue;
      if (bill.isPayerUser) {
        final seenOpenInBill = <String>{};
        for (final p in bill.participants) {
          final lower = p.contactName.trim().toLowerCase();
          if (lower == 'you') continue;
          if (!p.hasPaid) {
            owedToUser += p.shareAmount;
            firstSeenCase.putIfAbsent(lower, () => p.contactName.trim());
            lowerBalances[lower] = (lowerBalances[lower] ?? 0.0) + p.shareAmount;
            if (!bill.isFullySettled && seenOpenInBill.add(lower)) {
              openByContact.putIfAbsent(lower, () => []).add(bill);
            }
          } else {
            settledContacts.add(lower);
          }
        }
      } else {
        final lower = bill.payerName.trim().toLowerCase();
        if (!bill.isUserSharePaid) {
          userOwes += bill.userShare;
          firstSeenCase.putIfAbsent(lower, () => bill.payerName.trim());
          lowerBalances[lower] = (lowerBalances[lower] ?? 0.0) - bill.userShare;
          if (!bill.isFullySettled) {
            openByContact.putIfAbsent(lower, () => []).add(bill);
          }
        } else {
          settledContacts.add(lower);
        }
      }
    }

    final balances = <String, double>{};
    for (final entry in lowerBalances.entries) {
      final displayName = firstSeenCase[entry.key] ?? entry.key;
      balances[displayName] = entry.value;
    }

    _totalOwedToUser = owedToUser;
    _totalUserOwes = userOwes;
    _contactBalances = balances;
    _openBillsByContactLower = openByContact;
    _contactsWithSettledBillsLower = settledContacts;
  }
}
