import 'package:flutter/material.dart';
import '../../../../core/services/app_haptics.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_layout.dart';
import '../widgets/split_bill_editor_sections.dart';
import '../widgets/split_bill_tax_tip_sheet.dart';
import '../../../../core/ui/app_dialog.dart';
import '../../../../core/ui/editor_bottom_action_bar.dart';
import '../../../../core/ui/expressive_sliver_app_bar.dart';
import '../../../../data/category_constants.dart';
import '../../../../features/settings/providers/settings_provider.dart';
import '../../../../widgets/calculator_dialog.dart';
import '../../data/models/split_bill_model.dart';
import '../../data/repositories/split_bill_repository.dart';
import '../../providers/financial_manager_provider.dart';
import '../../providers/split_bill_provider.dart';
import '../widgets/receipt_scanner_sheet.dart';
import '../../../../data/transaction_model.dart';
import '../../../../utils/app_globals.dart';
import '../../data/transaction_repository.dart';
import 'financial_manager_screen.dart';

class SplitBillEditorScreen extends StatefulWidget {
  final SplitBillModel? existingBill;
  final int? prelinkedTransactionId;
  final String? initialTitle;
  final double? initialAmount;
  final DateTime? initialDate;

  const SplitBillEditorScreen({
    super.key,
    this.existingBill,
    this.prelinkedTransactionId,
    this.initialTitle,
    this.initialAmount,
    this.initialDate,
  });

  @override
  State<SplitBillEditorScreen> createState() => _SplitBillEditorScreenState();
}

class _SplitBillEditorScreenState extends State<SplitBillEditorScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _newParticipantController = TextEditingController();
  final _newParticipantFocusNode = FocusNode();
  final _payerFriendController = TextEditingController();
  final _notesController = TextEditingController();
  final _userExactAmountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isPayerUser = true;
  bool _includeUserShare = true;
  SplitMode _splitMode = SplitMode.equal;
  String _selectedCategory = CategoryConstants.food;
  String? _receiptImagePath;
  bool _isSaving = false;
  bool _isLoadingBill = false;
  SplitBillModel? _loadedBill;

  SplitBillModel? get _effectiveExistingBill => _loadedBill ?? widget.existingBill;

  String? _userParticipantId;
  bool _userHasPaid = false;
  DateTime? _userPaidAt;

  final List<Map<String, dynamic>> _participantsData = [];
  final Map<String, TextEditingController> _exactAmountControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final splitProvider = Provider.of<SplitBillProvider>(context, listen: false);
        if (splitProvider.recentContacts.isEmpty) {
          splitProvider.loadSplitBills();
        }
      }
    });
    if (widget.existingBill != null) {
      _populateFromBill(widget.existingBill!);
    } else {
      if (widget.initialTitle != null) _titleController.text = widget.initialTitle!;
      if (widget.initialAmount != null && widget.initialAmount! > 0) {
        _amountController.text = widget.initialAmount!.toStringAsFixed(2).replaceAll('.00', '');
      }
      if (widget.initialDate != null) _selectedDate = widget.initialDate!;

      if (widget.prelinkedTransactionId != null) {
        _loadBillForPrelinkedTx(widget.prelinkedTransactionId!);
      }
    }
  }

  void _populateFromBill(SplitBillModel b) {
    _titleController.text = b.title;
    _amountController.text = b.totalAmount.toStringAsFixed(2).replaceAll('.00', '');
    _selectedDate = b.date;
    _isPayerUser = b.isPayerUser;
    _splitMode = b.splitMode;
    _selectedCategory = b.groupTag ?? CategoryConstants.food;
    _notesController.text = b.notes ?? '';
    _receiptImagePath = b.receiptImagePath;

    if (!_isPayerUser) {
      _payerFriendController.text = b.payerName;
    }

    // Clean previous controllers
    for (final c in _exactAmountControllers.values) {
      c.dispose();
    }
    _exactAmountControllers.clear();
    _participantsData.clear();
    _userParticipantId = null;
    _userHasPaid = false;
    _userPaidAt = null;

    bool foundUser = false;
    for (final p in b.participants) {
      if (p.contactName.trim().toLowerCase() == 'you') {
        foundUser = true;
        _userParticipantId = p.id;
        _userHasPaid = p.hasPaid;
        _userPaidAt = p.paidAt;
        _userExactAmountController.text = p.shareAmount.toStringAsFixed(2).replaceAll('.00', '');
      } else {
        _participantsData.add({
          'id': p.id,
          'name': p.contactName,
          'amount': p.shareAmount,
          'hasPaid': p.hasPaid,
          'paidAt': p.paidAt,
        });
        _exactAmountControllers[p.contactName] = TextEditingController(
          text: p.shareAmount.toStringAsFixed(2).replaceAll('.00', ''),
        );
      }
    }
    _includeUserShare = !_isPayerUser ? true : foundUser;
  }

  Future<void> _loadBillForPrelinkedTx(int txId) async {
    setState(() => _isLoadingBill = true);
    try {
      final bill = await SplitBillRepository.instance.getBillByTransactionId(txId);
      if (bill != null && mounted) {
        setState(() {
          _loadedBill = bill;
          _populateFromBill(bill);
        });
      }
    } catch (_) {
      // Graceful fallback to initial values
    } finally {
      if (mounted) {
        setState(() => _isLoadingBill = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _newParticipantController.dispose();
    _newParticipantFocusNode.dispose();
    _payerFriendController.dispose();
    _notesController.dispose();
    _userExactAmountController.dispose();
    for (final c in _exactAmountControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _totalAmount => double.tryParse(_amountController.text.trim()) ?? 0.0;

  int get _totalSplitCount {
    final othersCount = _participantsData.length;
    return _includeUserShare ? othersCount + 1 : othersCount;
  }

  double get _equalShareAmount {
    final count = _totalSplitCount;
    if (count <= 0 || _totalAmount <= 0) return 0.0;
    return _totalAmount / count;
  }

  double get _allocatedExactSum {
    double sum = 0.0;
    for (final p in _participantsData) {
      final name = p['name'] as String;
      final ctrl = _exactAmountControllers[name];
      if (ctrl != null) {
        sum += double.tryParse(ctrl.text.trim()) ?? 0.0;
      }
    }
    if (_includeUserShare) {
      final userText = _userExactAmountController.text.trim();
      if (userText.isNotEmpty) {
        sum += double.tryParse(userText) ?? 0.0;
      }
    }
    return sum;
  }

  double get _remainingToAllocate => _totalAmount - _allocatedExactSum;

  void _addParticipant(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    if (clean.toLowerCase() == 'you') return;

    final exists = _participantsData.any((p) => (p['name'] as String).toLowerCase() == clean.toLowerCase());
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$clean is already added.')),
      );
      return;
    }

    AppHaptics.selectionClick();
    setState(() {
      _participantsData.add({
        'id': const Uuid().v4(),
        'name': clean,
        'amount': 0.0,
        'hasPaid': false,
      });
      _exactAmountControllers[clean] = TextEditingController(
        text: _equalShareAmount.toStringAsFixed(2).replaceAll('.00', ''),
      );
      _newParticipantController.clear();
    });
  }

  void _removeParticipant(int index) {
    AppHaptics.selectionClick();
    setState(() {
      final removed = _participantsData.removeAt(index);
      final name = removed['name'] as String;
      _exactAmountControllers[name]?.dispose();
      _exactAmountControllers.remove(name);
    });
  }

  void _ensureFriendPayerInParticipants(String friendName) {
    final clean = friendName.trim();
    if (clean.isEmpty || clean.toLowerCase() == 'you') return;
    final pIndex = _participantsData.indexWhere((p) => (p['name'] as String).toLowerCase() == clean.toLowerCase());
    if (pIndex == -1) {
      _participantsData.add({
        'id': const Uuid().v4(),
        'name': clean,
        'amount': 0.0,
        'hasPaid': true,
      });
      _exactAmountControllers[clean] = TextEditingController(
        text: _equalShareAmount.toStringAsFixed(2).replaceAll('.00', ''),
      );
    } else {
      _participantsData[pIndex]['hasPaid'] = true;
    }
  }

  Future<void> _scanReceipt() async {
    final result = await ReceiptScannerSheet.show(context);
    if (result != null) {
      setState(() {
        if (result['title'] != null && _titleController.text.isEmpty) {
          _titleController.text = result['title'] as String;
        }
        if (result['total'] != null) {
          _amountController.text = (result['total'] as double).toStringAsFixed(2).replaceAll('.00', '');
        }
        if (result['imagePath'] != null) {
          _receiptImagePath = result['imagePath'] as String;
        }
      });
    }
  }

  Future<void> _openCalculator([TextEditingController? targetController]) async {
    final ctrl = targetController ?? _amountController;
    final currentVal = double.tryParse(ctrl.text) ?? 0.0;
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => CalculatorDialog(initialValue: currentVal),
    );
    if (result != null) {
      setState(() {
        ctrl.text = result.toStringAsFixed(2).replaceAll('.00', '');
      });
    }
  }

  /// Automatically assigns the total bill amount equally among all active parties
  /// (participants + user if included) with penny-perfect precision so the sum
  /// of shares strictly equals [_totalAmount] without any rounding discrepancy.
  void _assignEqualCustomShares() {
    final total = _totalAmount;
    final count = _totalSplitCount;
    if (count <= 0 || total <= 0) return;

    final totalCents = (total * 100).round();
    final baseCents = totalCents ~/ count;
    final remCents = totalCents % count;

    int assignedCount = 0;

    // Allocate to user first if included
    if (_includeUserShare) {
      final userCents = baseCents + (assignedCount < remCents ? 1 : 0);
      assignedCount++;
      final userShare = userCents / 100.0;
      _userExactAmountController.text = userShare.toStringAsFixed(2).replaceAll('.00', '');
    }

    // Allocate to participants
    for (final p in _participantsData) {
      final name = p['name'] as String;
      final ctrl = _exactAmountControllers[name];
      if (ctrl != null) {
        final pCents = baseCents + (assignedCount < remCents ? 1 : 0);
        assignedCount++;
        final pShare = pCents / 100.0;
        ctrl.text = pShare.toStringAsFixed(2).replaceAll('.00', '');
      }
    }
  }

  void _distributeRemainder() {
    final rem = _remainingToAllocate;
    if (rem.abs() < 0.005) return;
    AppHaptics.selectionClick();

    // If custom amounts are unset or all 0, assign equally
    if (_allocatedExactSum == 0.0) {
      setState(() {
        _assignEqualCustomShares();
      });
      return;
    }

    // If only user share is unallocated, fill it into user share
    final userText = _userExactAmountController.text.trim();
    final userAmt = double.tryParse(userText) ?? 0.0;
    if (_includeUserShare && userAmt == 0.0 && rem > 0) {
      setState(() {
        _userExactAmountController.text = rem.toStringAsFixed(2).replaceAll('.00', '');
      });
      return;
    }

    // Distribute remaining cents across active parties
    final count = _totalSplitCount;
    if (count <= 0) return;

    final remCents = (rem * 100).round();
    final baseDeltaCents = remCents ~/ count;
    final extraCents = remCents.abs() % count;

    int allocated = 0;
    setState(() {
      if (_includeUserShare) {
        final curCents = ((double.tryParse(_userExactAmountController.text.trim()) ?? 0.0) * 100).round();
        final delta = baseDeltaCents + (allocated < extraCents ? (remCents >= 0 ? 1 : -1) : 0);
        allocated++;
        final updatedCents = (curCents + delta).clamp(0, 999999999);
        _userExactAmountController.text = (updatedCents / 100.0).toStringAsFixed(2).replaceAll('.00', '');
      }

      for (final p in _participantsData) {
        final name = p['name'] as String;
        final ctrl = _exactAmountControllers[name];
        if (ctrl != null) {
          final curCents = ((double.tryParse(ctrl.text.trim()) ?? 0.0) * 100).round();
          final delta = baseDeltaCents + (allocated < extraCents ? (remCents >= 0 ? 1 : -1) : 0);
          allocated++;
          final updatedCents = (curCents + delta).clamp(0, 999999999);
          ctrl.text = (updatedCents / 100.0).toStringAsFixed(2).replaceAll('.00', '');
        }
      }
    });
  }

  void _showTaxTipAllocatorSheet() {
    SplitBillTaxTipSheet.show(
      context: context,
      currentSubtotalSum: _allocatedExactSum,
      totalSplitCount: _totalSplitCount,
      onApply: (grandCalculatedTotal, extraRatio, feePerPerson) {
        setState(() {
          _amountController.text =
              grandCalculatedTotal.toStringAsFixed(2).replaceAll('.00', '');

          for (final p in _participantsData) {
            final name = p['name'] as String;
            final ctrl = _exactAmountControllers[name];
            if (ctrl != null) {
              final sub = double.tryParse(ctrl.text.trim()) ?? 0.0;
              final allocated = sub * (1.0 + extraRatio) + feePerPerson;
              ctrl.text = allocated.toStringAsFixed(2).replaceAll('.00', '');
            }
          }

          if (_includeUserShare) {
            final sub = double.tryParse(_userExactAmountController.text.trim()) ?? 0.0;
            final allocated = sub * (1.0 + extraRatio) + feePerPerson;
            _userExactAmountController.text =
                allocated.toStringAsFixed(2).replaceAll('.00', '');
          }
        });
      },
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final splitProvider = Provider.of<SplitBillProvider>(context);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currency = settings.currencySymbol;

    final effectiveBill = _effectiveExistingBill;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
            ExpressiveSliverAppBar(
              titleText: effectiveBill != null ? 'Edit Split Bill' : 'New Split Bill',
              showBackButton: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined),
                  tooltip: 'Scan Physical Receipt',
                  onPressed: _scanReceipt,
                ),
                if (effectiveBill != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: 'Delete Bill',
                    onPressed: _confirmDelete,
                  ),
              ],
            ),
            if (_isLoadingBill)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppLayout.spaceM, vertical: AppLayout.spaceS),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Bill Details Card
                  SplitBillDetailsCard(
                    titleController: _titleController,
                    amountController: _amountController,
                    currencySymbol: settings.currencySymbol,
                    selectedDate: _selectedDate,
                    selectedCategory: _selectedCategory,
                    onAmountChanged: () {
                      setState(() {
                        if (_splitMode == SplitMode.exact &&
                            (_allocatedExactSum == 0.0 ||
                                _remainingToAllocate == _totalAmount)) {
                          _assignEqualCustomShares();
                        }
                      });
                    },
                    onOpenCalculator: () => _openCalculator(),
                    onSelectDate: _selectDate,
                    onCategorySelected: (cat) =>
                        setState(() => _selectedCategory = cat),
                  ),

                  const SizedBox(height: AppLayout.spaceM),

                  // Who Paid & Split Mode Card
                  SplitBillPayerCard(
                    isPayerUser: _isPayerUser,
                    includeUserShare: _includeUserShare,
                    splitMode: _splitMode,
                    payerFriendController: _payerFriendController,
                    participantsData: _participantsData,
                    recentContacts: splitProvider.recentContacts,
                    onPayerTypeChanged: (val) {
                      setState(() {
                        _isPayerUser = val;
                        if (!_isPayerUser) {
                          _includeUserShare = true;
                        }
                      });
                    },
                    onFriendNameChanged: () => setState(() {}),
                    onFriendNameSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        setState(() {
                          _ensureFriendPayerInParticipants(val.trim());
                        });
                      }
                    },
                    onQuickSelectPayer: (sel, name) {
                      setState(() {
                        _payerFriendController.text = sel ? name : '';
                        if (sel) {
                          _ensureFriendPayerInParticipants(name);
                        }
                      });
                    },
                    onIncludeUserShareChanged: (val) =>
                        setState(() => _includeUserShare = val),
                    onSplitModeChanged: (mode) {
                      setState(() {
                        _splitMode = mode;
                        if (_splitMode == SplitMode.exact) {
                          _assignEqualCustomShares();
                        }
                      });
                    },
                  ),

                  const SizedBox(height: AppLayout.spaceM),

                  // Participants List Card
                  SplitBillParticipantsCard(
                    currency: currency,
                    totalSplitCount: _totalSplitCount,
                    splitMode: _splitMode,
                    totalAmount: _totalAmount,
                    equalShareAmount: _equalShareAmount,
                    remainingToAllocate: _remainingToAllocate,
                    isPayerUser: _isPayerUser,
                    includeUserShare: _includeUserShare,
                    payerFriendName: _payerFriendController.text,
                    recentContacts: splitProvider.recentContacts,
                    participantsData: _participantsData,
                    exactAmountControllers: _exactAmountControllers,
                    newParticipantController: _newParticipantController,
                    newParticipantFocusNode: _newParticipantFocusNode,
                    userExactAmountController: _userExactAmountController,
                    onAssignEqualCustomShares: () {
                      setState(() {
                        _assignEqualCustomShares();
                      });
                    },
                    onShowTaxTipAllocator: _showTaxTipAllocatorSheet,
                    onDistributeRemainder: _distributeRemainder,
                    onAddParticipant: _addParticipant,
                    onRemoveParticipant: _removeParticipant,
                    onOpenCalculator: (ctrl) => _openCalculator(ctrl),
                    onAmountChanged: () => setState(() {}),
                  ),

                  const SizedBox(height: AppLayout.spaceL),
                ]),
              ),
            ),
        ],
      ),
      bottomNavigationBar: EditorBottomActionBar(
        icon: _isSaving ? Icons.hourglass_empty_rounded : Icons.check_rounded,
        label: _isSaving ? 'Saving...' : (effectiveBill != null ? 'Update Bill' : 'Save Split Bill'),
        onPressed: _isSaving ? null : () => _saveBill(),
      ),
    );
  }

  Future<void> _saveBill() async {
    final title = _titleController.text.trim();
    final total = _totalAmount;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a bill title.')),
      );
      return;
    }

    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid bill amount.')),
      );
      return;
    }

    if (_participantsData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one friend to split with.')),
      );
      return;
    }

    if (!_isPayerUser && _payerFriendController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the name of the friend who paid.')),
      );
      return;
    }

    if (!_isPayerUser) {
      _includeUserShare = true;
    }

    if (_splitMode == SplitMode.exact) {
      double exactSum = 0.0;
      for (final p in _participantsData) {
        final name = p['name'] as String;
        final ctrl = _exactAmountControllers[name];
        exactSum += double.tryParse(ctrl?.text.trim() ?? '') ?? 0.0;
      }
      if (_includeUserShare) {
        final userText = _userExactAmountController.text.trim();
        exactSum += double.tryParse(userText) ?? 0.0;
      }
      if ((exactSum - total).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exact shares sum (${exactSum.toStringAsFixed(2)}) does not match total (${total.toStringAsFixed(2)}).',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
    }

    final splitProvider = Provider.of<SplitBillProvider>(context, listen: false);
    setState(() => _isSaving = true);
    AppHaptics.mediumImpact();

    try {
      final existing = _effectiveExistingBill;
      final billId = existing?.id ?? const Uuid().v4();
      final participantsList = <SplitParticipantModel>[];

      if (!_isPayerUser && _payerFriendController.text.trim().isNotEmpty) {
        _ensureFriendPayerInParticipants(_payerFriendController.text.trim());
      }

      if (_splitMode == SplitMode.equal) {
        final int totalCents = (total * 100).round();
        final int totalCount = _totalSplitCount;
        final int baseCents = totalCount > 0 ? totalCents ~/ totalCount : 0;
        final int remainder = totalCount > 0 ? totalCents % totalCount : 0;
        int assignedIndex = 0;

        if (_includeUserShare) {
          final int userCents = baseCents + (assignedIndex < remainder ? 1 : 0);
          assignedIndex++;
          final double userShare = userCents / 100.0;
          final userPaid = _isPayerUser || _userHasPaid;
          final userPaidAt = _isPayerUser ? (_userPaidAt ?? DateTime.now()) : (_userHasPaid ? _userPaidAt : null);
          participantsList.add(
            SplitParticipantModel(
              id: _userParticipantId ?? const Uuid().v4(),
              billId: billId,
              contactName: 'You',
              shareAmount: userShare,
              hasPaid: userPaid,
              paidAt: userPaidAt,
            ),
          );
        }

        for (final p in _participantsData) {
          final int pCents = baseCents + (assignedIndex < remainder ? 1 : 0);
          assignedIndex++;
          final double pShare = pCents / 100.0;
          final isPayerFriend = !_isPayerUser &&
              (p['name'] as String).trim().toLowerCase() == _payerFriendController.text.trim().toLowerCase();
          final hasPaid = isPayerFriend ? true : (p['hasPaid'] as bool? ?? false);

          participantsList.add(
            SplitParticipantModel(
              id: p['id'] as String? ?? const Uuid().v4(),
              billId: billId,
              contactName: p['name'] as String,
              shareAmount: pShare,
              hasPaid: hasPaid,
              paidAt: hasPaid ? (p['paidAt'] as DateTime? ?? DateTime.now()) : null,
            ),
          );
        }
      } else {
        // Custom Exact Mode
        for (final p in _participantsData) {
          final name = p['name'] as String;
          final ctrl = _exactAmountControllers[name];
          final exactShare = double.tryParse(ctrl?.text.trim() ?? '') ?? 0.0;
          final isPayerFriend = !_isPayerUser &&
              name.trim().toLowerCase() == _payerFriendController.text.trim().toLowerCase();
          final hasPaid = isPayerFriend ? true : (p['hasPaid'] as bool? ?? false);

          participantsList.add(
            SplitParticipantModel(
              id: p['id'] as String? ?? const Uuid().v4(),
              billId: billId,
              contactName: name,
              shareAmount: exactShare,
              hasPaid: hasPaid,
              paidAt: hasPaid ? (p['paidAt'] as DateTime? ?? DateTime.now()) : null,
            ),
          );
        }

        if (_includeUserShare) {
          final userText = _userExactAmountController.text.trim();
          final userShare = userText.isNotEmpty
              ? (double.tryParse(userText) ?? 0.0)
              : _remainingToAllocate;
          final userPaid = _isPayerUser || _userHasPaid;
          final userPaidAt = _isPayerUser ? (_userPaidAt ?? DateTime.now()) : (_userHasPaid ? _userPaidAt : null);
          participantsList.add(
            SplitParticipantModel(
              id: _userParticipantId ?? const Uuid().v4(),
              billId: billId,
              contactName: 'You',
              shareAmount: userShare > 0 ? userShare : 0.0,
              hasPaid: userPaid,
              paidAt: userPaidAt,
            ),
          );
        }
      }

      final payer = _isPayerUser ? 'You' : _payerFriendController.text.trim();
      int? linkedTxId = existing?.transactionId ?? widget.prelinkedTransactionId;

      // Invariant 12 & User Requirement:
      // When the user pays for a group bill, automatically record full receipt total in personal ledger.
      // When someone else pays, do NOT record in user's ledger (only debts settled via Settle Up appear).
      if (_isPayerUser) {
        if (linkedTxId != null) {
          // Update existing linked transaction if amount, title, date or category changed
          final existingTx = await TransactionRepository.instance.readTransaction(linkedTxId);
          if (existingTx != null) {
            final updatedTx = existingTx.copy(
              amount: total,
              description: '$title (Split: You paid)',
              date: _selectedDate,
              category: _selectedCategory,
            );
            await TransactionRepository.instance.updateTransaction(updatedTx);
            FinancialManagerScreen.refreshNotifier.value = DateTime.now().millisecondsSinceEpoch;
          }
        } else {
          // Create new ledger expense for user payment
          final newTx = TransactionModel(
            amount: total,
            description: '$title (Split: You paid)',
            date: _selectedDate,
            isExpense: true,
            category: _selectedCategory,
            account: AccountType.daily,
          );
          final createdTx = await TransactionRepository.instance.createTransaction(newTx);
          linkedTxId = createdTx.id;
          FinancialManagerScreen.refreshNotifier.value = DateTime.now().millisecondsSinceEpoch;
        }
      } else {
        // User is not payer (e.g. payer changed to a friend) -> delete previous linked ledger transaction
        if (existing?.transactionId != null) {
          await TransactionRepository.instance.deleteTransaction(existing!.transactionId!);
          linkedTxId = null;
          FinancialManagerScreen.refreshNotifier.value = DateTime.now().millisecondsSinceEpoch;
        } else if (widget.prelinkedTransactionId != null) {
          await TransactionRepository.instance.deleteTransaction(widget.prelinkedTransactionId!);
          linkedTxId = null;
          FinancialManagerScreen.refreshNotifier.value = DateTime.now().millisecondsSinceEpoch;
        }
      }

      final candidateBill = SplitBillModel(
        id: billId,
        transactionId: linkedTxId,
        title: title,
        totalAmount: total,
        payerName: payer,
        isPayerUser: _isPayerUser,
        splitMode: _splitMode,
        groupTag: _selectedCategory,
        date: _selectedDate,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        receiptImagePath: _receiptImagePath,
        participants: participantsList,
      );

      final newBill = candidateBill.copyWith(
        status: candidateBill.computeDerivedStatus(),
      );

      if (existing != null) {
        await splitProvider.updateBill(newBill);
      } else {
        await splitProvider.createBill(newBill);
      }

      if (mounted) {
        try {
          await context.read<FinancialManagerProvider>().loadTransactions();
        } catch (_) {}
      }

      if (mounted) {
        Navigator.of(context).pop();
        appScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(existing != null ? 'Split bill updated.' : 'Split bill created.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving split bill: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final bill = _effectiveExistingBill;
    if (bill == null) return;
    final hasLinkedTx = bill.transactionId != null;
    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: 'Delete Split Bill?',
      message: hasLinkedTx
          ? 'Are you sure you want to delete "${bill.title}"? The associated ledger expense will also be removed.'
          : 'Are you sure you want to delete "${bill.title}"?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed == true && mounted) {
      final splitProvider = Provider.of<SplitBillProvider>(context, listen: false);
      final fmProvider = Provider.of<FinancialManagerProvider?>(context, listen: false);
      await splitProvider.deleteBill(bill.id);
      if (fmProvider != null) {
        await fmProvider.loadTransactions();
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
      appScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(hasLinkedTx
              ? 'Split bill and linked expense deleted.'
              : 'Split bill deleted.'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              await splitProvider.restoreBill(bill.id);
              if (fmProvider != null) {
                await fmProvider.loadTransactions();
              }
            },
          ),
        ),
      );
    }
  }
}
