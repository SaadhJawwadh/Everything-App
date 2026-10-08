import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../../core/services/app_haptics.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../core/ui/app_dialog.dart';
import '../../../../core/ui/app_morphing_fab.dart';
import '../../../../core/ui/expressive_sliver_app_bar.dart';
import '../../../../data/category_constants.dart';
import '../../../../data/transaction_category.dart';
import '../../../../features/settings/providers/settings_provider.dart';
import '../../../../widgets/calculator_dialog.dart';
import '../../data/models/split_bill_model.dart';
import '../../data/repositories/split_bill_repository.dart';
import '../../providers/split_bill_provider.dart';
import '../widgets/receipt_scanner_sheet.dart';
import '../../../../data/transaction_model.dart';
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
  final _payerFriendController = TextEditingController();
  final _notesController = TextEditingController();
  final _userExactAmountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isPayerUser = true;
  bool _includeUserShare = true;
  SplitMode _splitMode = SplitMode.equal;
  String _selectedCategory = CategoryConstants.food;
  String? _receiptImagePath;
  bool _isFabExpanded = true;
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
    _includeUserShare = foundUser;
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
    final currency = Provider.of<SettingsProvider>(context, listen: false).currencySymbol;
    final taxPercentController = TextEditingController();
    final tipPercentController = TextEditingController();
    final flatFeeController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        final theme = Theme.of(modalContext);
        final colorScheme = theme.colorScheme;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final mediaQuery = MediaQuery.of(context);
            final taxPct = double.tryParse(taxPercentController.text.trim()) ?? 0.0;
            final tipPct = double.tryParse(tipPercentController.text.trim()) ?? 0.0;
            final flatFee = double.tryParse(flatFeeController.text.trim()) ?? 0.0;

            final currentSubtotalSum = _allocatedExactSum;
            final calculatedTax = currentSubtotalSum * (taxPct / 100.0);
            final calculatedTip = currentSubtotalSum * (tipPct / 100.0);
            final grandCalculatedTotal = currentSubtotalSum + calculatedTax + calculatedTip + flatFee;

            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppLayout.radiusXL)),
              ),
              padding: EdgeInsets.only(
                left: AppLayout.spaceL,
                right: AppLayout.spaceL,
                top: AppLayout.spaceM,
                bottom: mediaQuery.viewInsets.bottom + AppLayout.spaceL,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppLayout.spaceM),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(AppLayout.radiusM),
                          ),
                          child: Icon(Icons.calculate_rounded, color: colorScheme.primary, size: 20),
                        ),
                        const SizedBox(width: AppLayout.spaceM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Proportional Tax & Tip Allocator',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Distributes tax, tip & service fees across subtotals',
                                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppLayout.spaceL),

                    // Inputs Row: Tax % & Tip %
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: taxPercentController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Tax / VAT %',
                              hintText: 'e.g. 10',
                              suffixText: '%',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                        const SizedBox(width: AppLayout.spaceM),
                        Expanded(
                          child: TextField(
                            controller: tipPercentController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Tip / Service %',
                              hintText: 'e.g. 15',
                              suffixText: '%',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppLayout.spaceM),

                    // Flat Fee input
                    TextField(
                      controller: flatFeeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Flat Delivery or Service Fee',
                        hintText: 'e.g. 5.00',
                        prefixText: '$currency ',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    const SizedBox(height: AppLayout.spaceL),

                    // Calculation Summary Card
                    AppCard(
                      padding: const EdgeInsets.all(AppLayout.spaceM),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Items Subtotal:', style: theme.textTheme.bodyMedium),
                              Text('$currency ${currentSubtotalSum.toStringAsFixed(2)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          if (calculatedTax > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Tax (${taxPct.toStringAsFixed(1)}%):', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                                Text('+$currency ${calculatedTax.toStringAsFixed(2)}', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ],
                          if (calculatedTip > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Tip (${tipPct.toStringAsFixed(1)}%):', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                                Text('+$currency ${calculatedTip.toStringAsFixed(2)}', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ],
                          if (flatFee > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Flat Extra Fee:', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                                Text('+$currency ${flatFee.toStringAsFixed(2)}', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Computed Grand Total:', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                              Text('$currency ${grandCalculatedTotal.toStringAsFixed(2)}', style: theme.textTheme.titleSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppLayout.spaceL),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: AppLayout.spaceM),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Apply to All Shares'),
                            onPressed: () {
                              if (currentSubtotalSum <= 0) {
                                Navigator.pop(context);
                                return;
                              }
                              final extraRatio = (calculatedTax + calculatedTip) / currentSubtotalSum;
                              final feePerPerson = (_totalSplitCount > 0) ? (flatFee / _totalSplitCount) : 0.0;

                              setState(() {
                                // Update total bill amount
                                _amountController.text = grandCalculatedTotal.toStringAsFixed(2).replaceAll('.00', '');

                                // Update participant shares proportionally
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
                                  _userExactAmountController.text = allocated.toStringAsFixed(2).replaceAll('.00', '');
                                }
                              });

                              Navigator.pop(context);
                              AppHaptics.mediumImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Tax, tip, and fees distributed proportionally!'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
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

  bool _onScrollNotification(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.reverse) {
      if (_isFabExpanded) setState(() => _isFabExpanded = false);
    } else if (notification.direction == ScrollDirection.forward) {
      if (!_isFabExpanded) setState(() => _isFabExpanded = true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final splitProvider = Provider.of<SplitBillProvider>(context);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currency = settings.currencySymbol;

    final effectiveBill = _effectiveExistingBill;

    return Scaffold(
      floatingActionButton: AppMorphingFab(
        isExpanded: _isFabExpanded,
        icon: _isSaving ? Icons.hourglass_empty_rounded : Icons.check_rounded,
        label: _isSaving ? 'Saving...' : (effectiveBill != null ? 'Update Bill' : 'Save Split Bill'),
        onPressed: _isSaving ? () {} : () => _saveBill(),
      ),
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onScrollNotification,
        child: CustomScrollView(
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
                  AppCard(
                    padding: const EdgeInsets.all(AppLayout.spaceM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _titleController,
                          textCapitalization: TextCapitalization.sentences,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            labelText: 'Bill / Event Title',
                            hintText: 'e.g. Dinner at Botanik, Uber Ride, Starlink',
                            prefixIcon: Icon(Icons.receipt_long_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: AppLayout.spaceM),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _amountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  labelText: 'Total Bill Amount (${settings.currency})',
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Center(
                                      widthFactor: 0.0,
                                      child: Text(
                                        settings.currency,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                                onChanged: (_) {
                                  setState(() {
                                    if (_splitMode == SplitMode.exact &&
                                        (_allocatedExactSum == 0.0 || _remainingToAllocate == _totalAmount)) {
                                      _assignEqualCustomShares();
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: AppLayout.spaceS),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.calculate_rounded),
                              tooltip: 'Calculator',
                              onPressed: _openCalculator,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppLayout.spaceM),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _selectDate,
                                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                                label: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: const StadiumBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppLayout.spaceM),
                        // Financial Category Selector
                        Text('Category', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: AppLayout.spaceS),
                        Wrap(
                          spacing: AppLayout.spaceS,
                          runSpacing: AppLayout.spaceXS,
                          children: [
                            ...TransactionCategory.allNames.map((cat) {
                              final catColor = TransactionCategory.colorFor(cat);
                              final catIcon = TransactionCategory.iconFor(cat);
                              final isSelected = _selectedCategory == cat;
                              return FilterChip(
                                showCheckmark: false,
                                avatar: Icon(
                                  catIcon,
                                  size: 16,
                                  color: isSelected ? catColor : colorScheme.onSurfaceVariant,
                                ),
                                label: Text(cat),
                                selected: isSelected,
                                onSelected: (_) {
                                  AppHaptics.selectionClick();
                                  setState(() => _selectedCategory = cat);
                                },
                                selectedColor: catColor.withValues(alpha: 0.2),
                                labelStyle: TextStyle(
                                  color: isSelected ? catColor : colorScheme.onSurfaceVariant,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                side: BorderSide(
                                  color: isSelected ? catColor : colorScheme.outline.withValues(alpha: 0.5),
                                  width: isSelected ? 1.5 : 0.5,
                                ),
                                shape: const StadiumBorder(),
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppLayout.spaceM),

                  // Who Paid & Split Mode Card
                  AppCard(
                    padding: const EdgeInsets.all(AppLayout.spaceM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Who Paid for this Bill?', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: AppLayout.spaceS),
                        SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('I Paid for All'),
                              icon: Icon(Icons.person_rounded, size: 18),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('Friend Paid'),
                              icon: Icon(Icons.group_rounded, size: 18),
                            ),
                          ],
                          selected: {_isPayerUser},
                          onSelectionChanged: (set) {
                            AppHaptics.selectionClick();
                            setState(() => _isPayerUser = set.first);
                          },
                        ),
                        if (!_isPayerUser) ...[
                          const SizedBox(height: AppLayout.spaceM),
                          TextField(
                            controller: _payerFriendController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Friend Who Paid',
                              hintText: 'e.g. Alex, Sarah',
                              prefixIcon: Icon(Icons.account_circle_rounded),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty) {
                                setState(() {
                                  _ensureFriendPayerInParticipants(val.trim());
                                });
                              }
                            },
                          ),
                          // Quick-select chips from participants & recent contacts
                          Builder(builder: (context) {
                            final suggestions = <String>{};
                            for (final p in _participantsData) {
                              final name = p['name'] as String;
                              if (name.isNotEmpty) suggestions.add(name);
                            }
                            final splitProv = Provider.of<SplitBillProvider>(context, listen: false);
                            for (final c in splitProv.recentContacts) {
                              if (c.name.isNotEmpty) suggestions.add(c.name);
                            }
                            if (suggestions.isEmpty) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: AppLayout.spaceS),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Quick Select Payer:',
                                    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: AppLayout.spaceXS),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 110),
                                    child: SingleChildScrollView(
                                      child: Wrap(
                                        spacing: AppLayout.spaceXS,
                                        runSpacing: AppLayout.spaceXS,
                                        children: suggestions.map((name) {
                                          final isPayer = _payerFriendController.text.trim().toLowerCase() == name.toLowerCase();
                                          return ChoiceChip(
                                            showCheckmark: false,
                                            label: Text(name),
                                            selected: isPayer,
                                            onSelected: (sel) {
                                              AppHaptics.selectionClick();
                                              setState(() {
                                                _payerFriendController.text = sel ? name : '';
                                                if (sel) {
                                                  _ensureFriendPayerInParticipants(name);
                                                }
                                              });
                                            },
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        const SizedBox(height: AppLayout.spaceM),
                        SwitchListTile(
                          value: _includeUserShare,
                          onChanged: (val) => setState(() => _includeUserShare = val),
                          title: const Text('Include My Personal Share'),
                          subtitle: Text(
                            _includeUserShare
                                ? 'Your share is calculated and subtracted from what others owe'
                                : 'You paid 100% purely on behalf of others',
                            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                        const SizedBox(height: AppLayout.spaceM),
                        Text('Splitting Method', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: AppLayout.spaceS),
                        SegmentedButton<SplitMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment<SplitMode>(
                              value: SplitMode.equal,
                              label: Text('Equal Split'),
                              icon: Icon(Icons.safety_divider_rounded, size: 18),
                            ),
                            ButtonSegment<SplitMode>(
                              value: SplitMode.exact,
                              label: Text('Custom Exact'),
                              icon: Icon(Icons.tune_rounded, size: 18),
                            ),
                          ],
                          selected: {_splitMode},
                          onSelectionChanged: (set) {
                            AppHaptics.selectionClick();
                            setState(() {
                              _splitMode = set.first;
                              if (_splitMode == SplitMode.exact) {
                                _assignEqualCustomShares();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppLayout.spaceM),

                  // Participants List Card
                  AppCard(
                    padding: const EdgeInsets.all(AppLayout.spaceM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Participants ($_totalSplitCount)',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (_splitMode == SplitMode.equal && _totalSplitCount > 0 && _totalAmount > 0)
                              Text(
                                '$currency ${_equalShareAmount.toStringAsFixed(2)} / person',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        if (_splitMode == SplitMode.exact) ...[
                          const SizedBox(height: AppLayout.spaceS),
                          Wrap(
                            spacing: AppLayout.spaceS,
                            runSpacing: AppLayout.spaceXS,
                            children: [
                              ActionChip(
                                avatar: Icon(Icons.safety_divider_rounded, size: 16, color: colorScheme.primary),
                                label: const Text('Split Equally'),
                                tooltip: 'Assign total bill amount equally among all people with penny-perfect precision',
                                onPressed: () {
                                  AppHaptics.selectionClick();
                                  setState(() {
                                    _assignEqualCustomShares();
                                  });
                                },
                              ),
                              ActionChip(
                                avatar: Icon(Icons.calculate_outlined, size: 16, color: colorScheme.primary),
                                label: const Text('Add Tax / Tip / Fee'),
                                tooltip: 'Distribute tax, tip, or service charge proportionally',
                                onPressed: _showTaxTipAllocatorSheet,
                              ),
                              if (_remainingToAllocate.abs() > 0.009)
                                ActionChip(
                                  avatar: Icon(Icons.auto_awesome_rounded, size: 16, color: colorScheme.tertiary),
                                  label: Text(
                                    _remainingToAllocate > 0
                                        ? 'Fill Remainder ($currency ${_remainingToAllocate.toStringAsFixed(2)})'
                                        : 'Reconcile Balance',
                                  ),
                                  tooltip: 'Automatically balance remaining amount',
                                  onPressed: _distributeRemainder,
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: AppLayout.spaceS),

                        // Recent Friends Quick Add Chips
                        if (splitProvider.recentContacts.isNotEmpty) ...[
                          Text(
                            'Quick Add Recent Friends:',
                            style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: AppLayout.spaceXS),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 110),
                            child: SingleChildScrollView(
                              child: Wrap(
                                spacing: AppLayout.spaceXS,
                                runSpacing: AppLayout.spaceXS,
                                children: splitProvider.recentContacts.map((c) {
                                  final isAdded = _participantsData.any((p) => (p['name'] as String).toLowerCase() == c.name.toLowerCase());
                                  if (isAdded) return const SizedBox.shrink();
                                  return ActionChip(
                                    avatar: CircleAvatar(
                                      radius: 10,
                                      backgroundColor: Color(c.colorValue),
                                      child: Text(
                                        c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                        style: const TextStyle(fontSize: 10, color: Colors.white),
                                      ),
                                    ),
                                    label: Text(c.name),
                                    onPressed: () => _addParticipant(c.name),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppLayout.spaceM),
                        ],

                        // Add Person Field
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newParticipantController,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  hintText: 'Enter friend name...',
                                  prefixIcon: Icon(Icons.person_add_rounded),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onSubmitted: _addParticipant,
                              ),
                            ),
                            const SizedBox(width: AppLayout.spaceS),
                            IconButton.filled(
                              icon: const Icon(Icons.add_rounded),
                              tooltip: 'Add Person',
                              onPressed: () => _addParticipant(_newParticipantController.text),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppLayout.spaceM),

                        // User Share Tile
                        if (_includeUserShare) ...[
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: colorScheme.primaryContainer,
                              child: Text('You', style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
                            ),
                            title: const Text('You (Your Share)', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(_isPayerUser ? 'Payer • Already paid' : 'Owed to friend'),
                            trailing: _splitMode == SplitMode.equal
                                ? Text(
                                    '$currency ${_equalShareAmount.toStringAsFixed(2)}',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                  )
                                : SizedBox(
                                    width: 130,
                                    child: TextField(
                                      controller: _userExactAmountController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: _remainingToAllocate > 0
                                            ? _remainingToAllocate.toStringAsFixed(2)
                                            : '0.00',
                                        isDense: true,
                                        prefixText: '$currency ',
                                        prefixStyle: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        filled: true,
                                        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppLayout.radiusS),
                                          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppLayout.radiusS),
                                          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppLayout.radiusS),
                                          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                                        ),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: AppLayout.spaceS),
                        ],

                        // Participant Rows
                        if (_participantsData.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceL),
                            child: Center(
                              child: Text(
                                'Add at least one friend to split this bill.',
                                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _participantsData.length,
                            separatorBuilder: (_, __) => const SizedBox(height: AppLayout.spaceXS),
                            itemBuilder: (context, index) {
                              final p = _participantsData[index];
                              final name = p['name'] as String;
                              final ctrl = _exactAmountControllers[name];

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: colorScheme.secondaryContainer,
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: TextStyle(color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: (!_isPayerUser && _payerFriendController.text.trim().toLowerCase() == name.toLowerCase())
                                    ? Text('Payer • Settled', style: TextStyle(color: theme.extension<AppSemanticColors>()?.success ?? colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w500))
                                    : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_splitMode == SplitMode.equal)
                                      Text(
                                        '$currency ${_equalShareAmount.toStringAsFixed(2)}',
                                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                      )
                                    else
                                      SizedBox(
                                        width: 148,
                                        child: TextField(
                                          controller: ctrl,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          textAlign: TextAlign.end,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            prefixText: '$currency ',
                                            prefixStyle: TextStyle(
                                              color: colorScheme.onSurfaceVariant,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            suffixIcon: IconButton(
                                              icon: const Icon(Icons.calculate_outlined, size: 18),
                                              tooltip: 'Calculate share',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                              onPressed: ctrl != null ? () => _openCalculator(ctrl) : null,
                                            ),
                                            suffixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                            filled: true,
                                            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(AppLayout.radiusS),
                                              borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(AppLayout.radiusS),
                                              borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(AppLayout.radiusS),
                                              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                                            ),
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                    const SizedBox(width: AppLayout.spaceS),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 20),
                                      tooltip: 'Remove',
                                      onPressed: () => _removeParticipant(index),
                                    ),
                                  ],
                                ),
                                contentPadding: EdgeInsets.zero,
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppLayout.spaceXXL),
                ]),
              ),
            ),
          ],
        ),
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
        final share = _equalShareAmount;
        if (_includeUserShare) {
          final userPaid = _isPayerUser || _userHasPaid;
          final userPaidAt = _isPayerUser ? (_userPaidAt ?? DateTime.now()) : (_userHasPaid ? _userPaidAt : null);
          participantsList.add(
            SplitParticipantModel(
              id: _userParticipantId ?? const Uuid().v4(),
              billId: billId,
              contactName: 'You',
              shareAmount: share,
              hasPaid: userPaid,
              paidAt: userPaidAt,
            ),
          );
        }

        for (final p in _participantsData) {
          final isPayerFriend = !_isPayerUser &&
              (p['name'] as String).trim().toLowerCase() == _payerFriendController.text.trim().toLowerCase();
          final hasPaid = isPayerFriend ? true : (p['hasPaid'] as bool? ?? false);

          participantsList.add(
            SplitParticipantModel(
              id: p['id'] as String? ?? const Uuid().v4(),
              billId: billId,
              contactName: p['name'] as String,
              shareAmount: share,
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
      }

      final newBill = SplitBillModel(
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

      if (existing != null) {
        await splitProvider.updateBill(newBill);
      } else {
        await splitProvider.createBill(newBill);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
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
      await splitProvider.deleteBill(bill.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hasLinkedTx
                ? 'Split bill and linked expense deleted.'
                : 'Split bill deleted.'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                splitProvider.restoreBill(bill.id);
              },
            ),
          ),
        );
      }
    }
  }
}
