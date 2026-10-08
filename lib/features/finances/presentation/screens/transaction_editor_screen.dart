import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:note_taking_app/core/services/app_haptics.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/features/finances/data/transaction_repository.dart';
import 'package:note_taking_app/data/transaction_model.dart';
import 'package:note_taking_app/data/transaction_category.dart';
import 'package:note_taking_app/data/category_definition.dart';
import 'package:note_taking_app/data/recurring_rule_model.dart';
import 'package:note_taking_app/data/repositories/recurring_rule_repository.dart';
import 'package:note_taking_app/widgets/calculator_dialog.dart';
import 'package:note_taking_app/features/finances/presentation/screens/category_management_screen.dart';
import 'package:note_taking_app/services/sms_service.dart';
import 'package:note_taking_app/utils/app_route.dart';
import 'package:uuid/uuid.dart';
import 'package:note_taking_app/core/theme/app_layout.dart';
import 'package:note_taking_app/core/ui/app_morphing_fab.dart';
import 'package:note_taking_app/core/ui/expressive_sliver_app_bar.dart';
import 'package:note_taking_app/utils/app_globals.dart';
import 'package:note_taking_app/features/finances/providers/financial_manager_provider.dart';
import 'package:note_taking_app/features/finances/data/models/split_bill_model.dart';
import 'package:note_taking_app/features/finances/data/repositories/split_bill_repository.dart';
import 'split_bill_editor_screen.dart';

class TransactionEditorScreen extends StatefulWidget {
  final TransactionModel? transaction;

  const TransactionEditorScreen({super.key, this.transaction});

  @override
  State<TransactionEditorScreen> createState() =>
      _TransactionEditorScreenState();
}

class _TransactionEditorScreenState extends State<TransactionEditorScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isExpense = true;
  bool _isLoading = false;
  bool _isFabExpanded = true;
  bool _isRefiningAi = false;
  String _category = TransactionCategory.other;
  String _account = AccountType.daily;
  RecurringFrequency? _repeatFrequency;
  String? _matchedRuleId;

  bool _onScrollNotification(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.reverse) {
      if (_isFabExpanded) setState(() => _isFabExpanded = false);
    } else if (notification.direction == ScrollDirection.forward) {
      if (!_isFabExpanded) setState(() => _isFabExpanded = true);
    }
    return false;
  }

  late String _initialCategory;
  late final String _initAmount;
  late final String _initDesc;
  late final DateTime _initDate;
  late final bool _initIsExpense;
  late final String _initCategory;
  late final String _initAccount;
  RecurringFrequency? _initRepeatFrequency;
  SplitBillModel? _linkedSplitBill;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _amountController.text =
          widget.transaction!.amount.toStringAsFixed(2).replaceAll('.00', '');
      _descriptionController.text = widget.transaction!.description;
      _selectedDate = widget.transaction!.date;
      _isExpense = widget.transaction!.isExpense;
      _category = widget.transaction!.category;
      _account = widget.transaction!.account;
      _checkExistingRecurringRule();
      _checkExistingSplitBill();
    }
    _initialCategory = _category;
    _initAmount = _amountController.text.trim();
    _initDesc = _descriptionController.text.trim();
    _initDate = _selectedDate;
    _initIsExpense = _isExpense;
    _initCategory = _category;
    _initAccount = _account;
    _initRepeatFrequency = _repeatFrequency;
  }

  Future<void> _checkExistingSplitBill() async {
    if (widget.transaction?.id == null) return;
    try {
      final bill = await SplitBillRepository.instance.getBillByTransactionId(widget.transaction!.id!);
      if (bill != null && mounted) {
        setState(() => _linkedSplitBill = bill);
      }
    } catch (_) {}
  }

  bool get _isDirty {
    if (_amountController.text.trim() != _initAmount) return true;
    if (_descriptionController.text.trim() != _initDesc) return true;
    if (_isExpense != _initIsExpense) return true;
    if (_category != _initCategory) return true;
    if (_account != _initAccount) return true;
    if (_selectedDate.year != _initDate.year ||
        _selectedDate.month != _initDate.month ||
        _selectedDate.day != _initDate.day) {
      return true;
    }
    if (_repeatFrequency != _initRepeatFrequency) return true;
    return false;
  }

  Future<bool> _showDiscardConfirmation() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusL),
        ),
        title: Text(
          'Unsaved Changes',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You have unsaved changes to this transaction. Do you want to save them before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('keep'),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == 'discard') {
      return true;
    } else if (result == 'save') {
      await _saveTransaction();
      return false;
    }
    return false;
  }

  Future<void> _checkExistingRecurringRule() async {
    if (widget.transaction == null) return;
    try {
      final rule = await RecurringRuleRepository.instance.findMatchingRule(
        description: widget.transaction!.description,
        category: widget.transaction!.category,
        isExpense: widget.transaction!.isExpense,
        amount: widget.transaction!.amount,
      );
      if (rule != null && mounted) {
        setState(() {
          _matchedRuleId = rule.id;
          _repeatFrequency = rule.frequency;
          _initRepeatFrequency = rule.frequency;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    final amountText = _amountController.text;
    final description = _descriptionController.text.trim();

    if (amountText.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than zero')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final transaction = TransactionModel(
      id: widget.transaction?.id,
      amount: amount,
      description: description,
      date: _selectedDate,
      isExpense: _isExpense,
      category: _category,
      smsId: widget.transaction?.smsId,
      account: _account,
    );

    if (widget.transaction == null) {
      await TransactionRepository.instance.createTransaction(transaction);
    } else {
      await TransactionRepository.instance.updateTransaction(transaction);
    }

    if (_repeatFrequency != null) {
      if (_matchedRuleId != null) {
        // Update existing rule so future materialized transactions reflect the new details
        final allRules = await RecurringRuleRepository.instance.readAllRules();
        RecurringRule? existing;
        for (final r in allRules) {
          if (r.id == _matchedRuleId) {
            existing = r;
            break;
          }
        }
        if (existing != null) {
          final updatedRule = existing.copyWith(
            description: description,
            amount: amount,
            category: _category,
            isExpense: _isExpense,
            frequency: _repeatFrequency!,
          );
          await RecurringRuleRepository.instance.updateRule(updatedRule);
        } else {
          var rule = RecurringRule(
            id: _matchedRuleId!,
            description: description,
            amount: amount,
            category: _category,
            isExpense: _isExpense,
            frequency: _repeatFrequency!,
            nextDue: _selectedDate,
          );
          rule = rule.copyWith(nextDue: rule.advance(_selectedDate));
          await RecurringRuleRepository.instance.createRule(rule);
        }
      } else {
        // The transaction covers this period; the rule owns the next one onward.
        var rule = RecurringRule(
          id: const Uuid().v4(),
          description: description,
          amount: amount,
          category: _category,
          isExpense: _isExpense,
          frequency: _repeatFrequency!,
          nextDue: _selectedDate,
        );
        rule = rule.copyWith(nextDue: rule.advance(_selectedDate));
        await RecurringRuleRepository.instance.createRule(rule);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Repeats ${_repeatFrequency!.label.toLowerCase()} — updated for future payments'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (_matchedRuleId != null) {
      // Frequency was removed / set to None on an existing recurring transaction
      await RecurringRuleRepository.instance.deleteRule(_matchedRuleId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed recurring rule for upcoming payments'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (widget.transaction != null) {
      // Training Prompt logic
      if (widget.transaction!.smsId != null &&
          widget.transaction!.isExpense != _isExpense) {
        final rule = await _showTrainingDialog(description);
        if (rule != null && rule.isNotEmpty) {
           if (!mounted) return;
           final settings = Provider.of<SettingsProvider>(context, listen: false);
           await settings.addCustomRule(rule, isExpense: _isExpense);
           // We also need to reload the static SMS service cache
           // For that, we need to import SmsService at the top.
           try {
             // Use dynamic invocation or ensure reloadSmsContacts is available.
             // We will import sms_service.dart at the top.
             await SmsService.reloadSmsContacts();
           } catch (_) {}
        }
      }

      // Category Training Prompt logic
      if (widget.transaction!.smsId != null &&
          _initialCategory != _category) {
        final rule = await _showCategoryTrainingDialog(description, _category);
        if (rule != null && rule.isNotEmpty) {
          final db = TransactionRepository.instance;
          final defs = await db.getAllCategoryDefinitions();
          CategoryDefinition? targetDef;
          for (final d in defs) {
            if (d.name == _category) {
              targetDef = d;
              break;
            }
          }
          if (targetDef != null) {
            if (!targetDef.keywords.contains(rule)) {
              final updatedKeywords = List<String>.from(targetDef.keywords)..add(rule.toLowerCase());
              await db.upsertCategoryDefinition(targetDef.copyWith(keywords: updatedKeywords));
              await TransactionCategory.reload();
            }
          }
        }
      }
    }

    setState(() => _isLoading = false);
    if (mounted) {
      final navigator = Navigator.of(context);
      AppHaptics.mediumImpact();
      navigator.pop(true);
    }
  }

  Future<void> _deleteTransaction() async {
    if (widget.transaction == null) return;
    final txn = widget.transaction!;
    final isSmsTxn = txn.smsId != null && txn.smsId!.isNotEmpty;
    var blockSender = false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;

          return AlertDialog(
            title: const Text('Delete Transaction?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Move this transaction to Trash? You can restore it anytime within 30 days.',
                ),
                if (isSmsTxn) ...[
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppLayout.radiusM),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: CheckboxListTile(
                      value: blockSender,
                      onChanged: (val) => setDialogState(() => blockSender = val ?? false),
                      title: Text(
                        'Block future SMS imports for this source',
                        style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Prevent incoming SMS from this sender from being added to your ledger.',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      ),
    );

    if (confirm == true) {
      final txnId = txn.id!;
      final desc = txn.description;
      setState(() => _isLoading = true);
      await TransactionRepository.instance.deleteTransaction(txnId);

      if (blockSender && txn.smsId != null) {
        try {
          final contacts = await TransactionRepository.instance.getAllSmsContacts();
          for (final c in contacts) {
            if (c.senderIds.any((s) => desc.toLowerCase().contains(s.toLowerCase()) || txn.smsId!.toLowerCase().contains(s.toLowerCase()))) {
              await TransactionRepository.instance.setSmsContactBlocked(c.id, true);
            }
          }
          await SmsService.reloadSmsContacts();
        } catch (e) {
          debugPrint('Error blocking contact on delete: $e');
        }
      }

      setState(() => _isLoading = false);
      if (mounted) {
        final navigator = Navigator.of(context);
        AppHaptics.mediumImpact();
        navigator.pop(true);
        appScaffoldMessengerKey.currentState?.clearSnackBars();
        appScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(blockSender ? 'Deleted "$desc" and blocked sender' : 'Deleted "$desc"'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () async {
                await TransactionRepository.instance.restoreTransaction(txnId);
                final ctx = appScaffoldMessengerKey.currentContext;
                if (ctx != null && ctx.mounted) {
                  await Provider.of<FinancialManagerProvider>(ctx, listen: false)
                      .loadTransactions();
                }
              },
            ),
          ),
        );
      }
    }
  }

  Future<String?> _showTrainingDialog(String initialKeyword) async {
    String keyword = initialKeyword.replaceAll(RegExp(r'(?:Debit|Credit|Payment at|Purchase at|Transfer to)\s*', caseSensitive: false), '').trim();

    return showDialog<String>(
      context: context,
      builder: (context) {
        String input = keyword;
        return AlertDialog(
          title: const Text('Train SMS Parser?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Would you like the app to remember this? Future SMS messages containing the keyword below will automatically be marked as exactly what you selected.'),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: keyword),
                decoration: const InputDecoration(
                  labelText: 'Matching Keyword/Phrase',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Uber, Keells, Salary',
                ),
                onChanged: (v) => input = v.trim(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('No, just this once'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, input),
              child: const Text('Train Parser'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _showCategoryTrainingDialog(String initialKeyword, String category) async {
    String keyword = initialKeyword.replaceAll(RegExp(r'(?:Debit|Credit|Payment at|Purchase at|Transfer to)\s*', caseSensitive: false), '').trim();

    return showDialog<String>(
      context: context,
      builder: (context) {
        String input = keyword;
        return AlertDialog(
          title: const Text('Train Category Parser?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Would you like the app to remember this? Future SMS messages containing the keyword below will automatically be categorized as "$category".'),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: keyword),
                decoration: const InputDecoration(
                  labelText: 'Matching Keyword/Phrase',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Uber, Keells, Mc',
                ),
                onChanged: (v) => input = v.trim(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('No, just this once'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, input),
              child: const Text('Train Category'),
            ),
          ],
        );
      },
    );
  }

  static const _stopwords = {
    'debit', 'credit', 'payment', 'purchase', 'transfer', 'card', 'bank',
    'paid', 'sent', 'received', 'withdrawal', 'deposit', 'pos', 'atm',
    'online', 'charge', 'money', 'store', 'shop', 'order', 'total', 'bill',
    'lkr', 'usd', 'eur', 'gbp', 'inr', 'rs', 'at', 'to', 'for', 'from', 'in', 'the', 'a', 'an',
  };

  String? _extractCleanMerchantKeyword(String rawDesc) {
    var cleaned = rawDesc
        .replaceAll(RegExp(r'(?:Debit|Credit|Payment at|Purchase at|Transfer to|Received from)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\d,]+\.?\d*'), '')
        .replaceAll(RegExp(r"[^A-Za-z0-9\s&'\-]"), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    if (cleaned.length < 3) return null;
    if (_stopwords.contains(cleaned.toLowerCase())) return null;
    return cleaned;
  }

  Future<void> _trainCategoryKeyword(String keyword, String category) async {
    final db = TransactionRepository.instance;
    final defs = await db.getAllCategoryDefinitions();
    CategoryDefinition? targetDef;
    for (final d in defs) {
      if (d.name == category) {
        targetDef = d;
        break;
      }
    }
    if (targetDef != null) {
      final updatedKeywords = List<String>.from(targetDef.keywords);
      if (!updatedKeywords.any((k) => k.toLowerCase() == keyword.toLowerCase())) {
        updatedKeywords.add(keyword);
        await db.upsertCategoryDefinition(targetDef.copyWith(keywords: updatedKeywords));
        await TransactionCategory.reload();
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      AppHaptics.selectionClick();
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _openCalculator() async {
    if (!mounted) return;
    final double? currentVal = double.tryParse(_amountController.text);
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => CalculatorDialog(initialValue: currentVal),
    );

    if (result != null) {
      setState(() {
        _amountController.text =
            result.toStringAsFixed(2).replaceAll('.00', '');
      });
    }
  }

  Future<void> _refineDescriptionWithAi() async {
    final text = _descriptionController.text.trim();
    if (text.isEmpty && widget.transaction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a description first or select a transaction.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isRefiningAi = true);

    try {
      final dummyTxn = widget.transaction ??
          TransactionModel(
            amount: double.tryParse(_amountController.text) ?? 0,
            description: text,
            date: _selectedDate,
            isExpense: _isExpense,
            category: _category,
          );

      final refined = await SmsService.refineSingleTransactionWithAi(dummyTxn);
      if (!mounted) return;

      if (refined != null) {
        AppHaptics.mediumImpact();
        setState(() {
          _descriptionController.text = refined.description;
          _category = refined.category;
        });
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Refined title & category with Gemini Nano'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Gemini Nano unavailable on this device or could not refine text.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error refining transaction with AI: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefiningAi = false);
      }
    }
  }

  static const _colorSwatches = [
    Color(0xFFE06D53), // Coral Dusk
    Color(0xFFD9779B), // Soft Rose
    Color(0xFF9E7BB5), // Lavender Dusk
    Color(0xFF6A7EC0), // Indigo Dusk
    Color(0xFF5194B6), // Sky Blue
    Color(0xFF4E9F90), // Sage Teal
    Color(0xFF5A9E75), // Emerald
    Color(0xFF86A148), // Olive Green
    Color(0xFFD49339), // Amber Harvest
    Color(0xFFC86F4B), // Terracotta
    Color(0xFF917265), // Warm Brown
    Color(0xFF758596), // Slate Blue
  ];

  Future<void> _showNewCategoryDialog() async {
    String name = '';
    Color selectedColor = _colorSwatches[5];
    IconData selectedIcon = TransactionCategory.swatches[0];

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('New Category'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Category name',
                          hintText: 'e.g., Groceries',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => name = v.trim(),
                      ),
                      const SizedBox(height: 16),
                      Text('Icon', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: GridView.builder(
                          shrinkWrap: true,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: TransactionCategory.swatches.length,
                          itemBuilder: (context, idx) {
                            final icon = TransactionCategory.swatches[idx];
                            final isSelected = selectedIcon.codePoint == icon.codePoint;
                            return GestureDetector(
                              onTap: () {
                                AppHaptics.selectionClick();
                                setDialogState(() => selectedIcon = icon);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? selectedColor.withValues(alpha: 0.2)
                                      : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(color: selectedColor, width: 2)
                                      : null,
                                ),
                                child: Icon(
                                  icon,
                                  size: 20,
                                  color: isSelected ? selectedColor : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Color', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _colorSwatches.map((c) {
                          final isSelected =
                              c.toARGB32() == selectedColor.toARGB32();
                          return Semantics(
                            button: true,
                            label: 'Color option',
                            selected: isSelected,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                              onTap: () => setDialogState(() => selectedColor = c),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                child: Center(
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: c,
                                    child: isSelected
                                        ? const Icon(Icons.check,
                                            size: 16, color: Colors.white)
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (name.isEmpty) return;
                    Navigator.pop(context, true);
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true && name.isNotEmpty) {
      final def = CategoryDefinition(
        name: name,
        colorValue: selectedColor.toARGB32(),
        keywords: [],
        iconCodePoint: selectedIcon.codePoint,
      );
      await TransactionRepository.instance.upsertCategoryDefinition(def);
      await TransactionCategory.reload();
      setState(() => _category = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final settings = Provider.of<SettingsProvider>(context);
    final currency = settings.currency;

    return PopScope(
      canPop: !_isDirty && !_isLoading,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showDiscardConfirmation();
        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: NotificationListener<UserScrollNotification>(
          onNotification: _onScrollNotification,
          child: CustomScrollView(
            slivers: [
              ExpressiveSliverAppBar(
                titleText: widget.transaction == null
                    ? 'New Transaction'
                    : 'Edit Transaction',
                showBackButton: true,
                onBackPressed: () => Navigator.maybePop(context),
                actions: [
                  if (widget.transaction != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: colorScheme.error,
                      onPressed: _deleteTransaction,
                    ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Transaction Type Segmented Button
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('Expense'),
                          icon: Icon(Icons.arrow_outward),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('Income'),
                          icon: Icon(Icons.south_west),
                        ),
                      ],
                      selected: {_isExpense},
                      onSelectionChanged: (Set<bool> newSelection) {
                        AppHaptics.selectionClick();
                        setState(() {
                          _isExpense = newSelection.first;
                        });
                      },
                      style: ButtonStyle(
                        side: WidgetStateProperty.resolveWith<BorderSide>((states) {
                          return BorderSide(color: colorScheme.outline);
                        }),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Amount Field with Calculator
                    TextFormField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _isExpense ? colorScheme.error : colorScheme.tertiary,
                      ),
                      decoration: InputDecoration(
                        prefixText: '$currency ',
                        labelText: 'Amount',
                        hintText: '0.00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppLayout.radiusL),
                        ),
                        suffixIcon: IconButton(
                          onPressed: _openCalculator,
                          icon: const Icon(Icons.calculate_outlined),
                          tooltip: 'Open Calculator',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Description Field
                    TextFormField(
                      controller: _descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'e.g., Groceries, Rent',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppLayout.radiusL),
                        ),
                        prefixIcon: const Icon(Icons.description_outlined),
                        suffixIcon: settings.isAiActive
                            ? IconButton(
                                onPressed: _isRefiningAi ? null : _refineDescriptionWithAi,
                                icon: _isRefiningAi
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.auto_awesome_rounded),
                                tooltip: 'Refine Title with AI',
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Category Picker
                    Row(
                      children: [
                        Text(
                          'Category',
                          style: textTheme.labelLarge
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () async {
                            await AppRoute.push(context, const CategoryManagementScreen());
                            await TransactionCategory.reload();
                            if (!TransactionCategory.allNames.contains(_category)) {
                              _category = TransactionCategory.other;
                            }
                            setState(() {});
                          },
                          icon: const Icon(Icons.tune, size: 16),
                          label: const Text('Manage'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            textStyle: textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...TransactionCategory.allNames.map((cat) {
                              final catColor = TransactionCategory.colorFor(cat);
                              final catIcon = TransactionCategory.iconFor(cat);
                              final selected = _category == cat;
                              return FilterChip(
                                showCheckmark: false,
                                avatar: Icon(
                                  catIcon,
                                  size: 16,
                                  color: selected ? catColor : colorScheme.onSurfaceVariant,
                                ),
                                label: Text(cat),
                                selected: selected,
                                onSelected: (_) {
                                  AppHaptics.selectionClick();
                                  setState(() => _category = cat);
                                },
                                selectedColor: catColor.withValues(alpha: 0.2),
                                labelStyle: TextStyle(
                                  color: selected ? catColor : colorScheme.onSurfaceVariant,
                                  fontWeight:
                                      selected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                side: BorderSide(
                                  color: selected ? catColor : colorScheme.outline.withValues(alpha: 0.5),
                                  width: selected ? 1.5 : 0.5,
                                ),
                                shape: const StadiumBorder(),
                              );
                            }),
                            ActionChip(
                              avatar: Icon(Icons.add, size: 18, color: colorScheme.primary),
                              label:
                                  Text('New', style: TextStyle(color: colorScheme.primary)),
                              onPressed: _showNewCategoryDialog,
                              side: BorderSide(color: colorScheme.primary, width: 0.5),
                              shape: const StadiumBorder(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ListenableBuilder(
                      listenable: _descriptionController,
                      builder: (context, _) {
                        final candidate = _extractCleanMerchantKeyword(_descriptionController.text);
                        if (candidate == null || candidate.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: ActionChip(
                            avatar: const Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
                            label: Text(
                              'Always categorize "$candidate" as $_category',
                              style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                            side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                            shape: const StadiumBorder(),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              AppHaptics.selectionClick();
                              await _trainCategoryKeyword(candidate, _category);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Future SMS matching "$candidate" will be categorized as "$_category"'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    if (Provider.of<SettingsProvider>(context, listen: false).enableSavingsVault) ...[
                      // Account Bucket (Daily Operating vs. Savings Vault)
                      Text(
                        'Account Bucket',
                        style: textTheme.labelLarge
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: AccountType.daily,
                            label: Text(settings.account1Name),
                            icon: const Icon(Icons.credit_card_outlined),
                          ),
                          ButtonSegment(
                            value: AccountType.savings,
                            label: Text(settings.account2Name),
                            icon: const Icon(Icons.account_balance_outlined),
                          ),
                        ],
                        selected: {_account},
                        onSelectionChanged: (selected) {
                          AppHaptics.selectionClick();
                          setState(() => _account = selected.first);
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Date Picker
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(AppLayout.radiusL),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppLayout.radiusL),
                          ),
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                          enabled: false,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat.yMMMd().format(_selectedDate),
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down_rounded,
                                color: colorScheme.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),

                    // Repeat picker
                    if (settings.enableRecurringRules) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Repeat',
                        style: textTheme.labelLarge
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<RecurringFrequency?>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: null, label: Text('Once')),
                          ButtonSegment(
                              value: RecurringFrequency.daily, label: Text('Daily')),
                          ButtonSegment(
                              value: RecurringFrequency.weekly, label: Text('Weekly')),
                          ButtonSegment(
                              value: RecurringFrequency.monthly,
                              label: Text('Monthly')),
                        ],
                        selected: {_repeatFrequency},
                        onSelectionChanged: (selection) {
                          AppHaptics.selectionClick();
                          setState(() => _repeatFrequency = selection.first);
                        },
                      ),
                      if (_repeatFrequency != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'This will be added automatically every '
                          '${_repeatFrequency!.label.toLowerCase().replaceFirst('ly', '')} '
                          'starting from the date above.',
                          style: textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],

                    if (settings.showSplitBills) ...[
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final title = _descriptionController.text.trim();
                          final amount = double.tryParse(_amountController.text.trim());
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SplitBillEditorScreen(
                                existingBill: _linkedSplitBill,
                                prelinkedTransactionId: widget.transaction?.id,
                                initialTitle: title.isNotEmpty ? title : null,
                                initialAmount: amount,
                                initialDate: _selectedDate,
                              ),
                            ),
                          );
                          if (mounted) {
                            await _checkExistingSplitBill();
                          }
                        },
                        icon: Icon(_linkedSplitBill != null ? Icons.pie_chart_rounded : Icons.pie_chart_outline_rounded),
                        label: Text(_linkedSplitBill != null ? 'View / Edit Split Bill (${_linkedSplitBill!.participants.length} people)' : 'Split This Bill with Friends'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppLayout.radiusM),
                          ),
                        ),
                      ),
                    ],

                    // Guaranteed bottom clearance past floating action button
                    const SizedBox(height: AppLayout.fabBottomPadding),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: AppMorphingFab(
        isExpanded: _isFabExpanded,
        icon: _isLoading ? Icons.hourglass_empty_rounded : Icons.save_outlined,
        collapsedIcon: Icons.save_outlined,
        label: widget.transaction == null ? 'Save Transaction' : 'Update Transaction',
        onPressed: _isLoading ? () {} : _saveTransaction,
        secondaryAction: IconButton(
          tooltip: 'Categories',
          icon: Icon(Icons.category_outlined, color: colorScheme.onPrimaryContainer, size: 20),
          onPressed: () {
            AppRoute.push(context, const CategoryManagementScreen());
          },
        ),
      ),
    ),
  );
}
}
