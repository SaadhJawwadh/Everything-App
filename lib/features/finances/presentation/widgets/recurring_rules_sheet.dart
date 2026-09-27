import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../data/recurring_rule_model.dart';
import '../../../../data/repositories/recurring_rule_repository.dart';
import '../../../../data/transaction_category.dart';
import '../../../../data/category_constants.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../core/ui/app_dialog.dart';
import '../../../../core/ui/expressive_shape_morph_indicator.dart';

/// Interactive modal sheet to view, add, and manage automated recurring transaction rules.
class RecurringRulesSheet extends StatefulWidget {
  final String currency;
  final VoidCallback onRulesUpdated;

  const RecurringRulesSheet({
    super.key,
    required this.currency,
    required this.onRulesUpdated,
  });

  static Future<void> show({
    required BuildContext context,
    required String currency,
    required VoidCallback onRulesUpdated,
  }) {
    return AppBottomSheet.show(
      context: context,
      title: 'Recurring Subscriptions & Rules',
      child: RecurringRulesSheet(
        currency: currency,
        onRulesUpdated: onRulesUpdated,
      ),
    );
  }

  @override
  State<RecurringRulesSheet> createState() => _RecurringRulesSheetState();
}

class _RecurringRulesSheetState extends State<RecurringRulesSheet> {
  List<RecurringRule> _rules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    final rules = await RecurringRuleRepository.instance.readAllRules();
    if (mounted) {
      setState(() {
        _rules = rules;
        _isLoading = false;
      });
    }
  }

  Future<void> _materializeNow() async {
    AppHaptics.mediumImpact();
    final count = await RecurringRuleRepository.instance.materializeDueRules();
    widget.onRulesUpdated();
    await _loadRules();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? 'Generated $count due recurring transaction${count > 1 ? 's' : ''}'
                : 'All recurring rules are up to date.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteRule(RecurringRule rule) async {
    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: 'Delete Recurring Rule',
      message: 'Stop recurring payments for "${rule.description}"? Existing ledger transactions will not be deleted.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true) {
      await RecurringRuleRepository.instance.deleteRule(rule.id);
      widget.onRulesUpdated();
      await _loadRules();
    }
  }

  Future<void> _showAddRuleDialog() async {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    var isExpense = true;
    var selectedCategory = CategoryConstants.subscriptions;
    var selectedFreq = RecurringFrequency.monthly;
    var selectedDate = DateTime.now();

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {

          return AlertDialog(
            title: const Text('Add Recurring Rule'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: true, label: Text('Expense'), icon: Icon(Icons.arrow_upward)),
                      ButtonSegment(value: false, label: Text('Income'), icon: Icon(Icons.arrow_downward)),
                    ],
                    selected: {isExpense},
                    onSelectionChanged: (set) => setDialogState(() {
                      isExpense = set.first;
                      selectedCategory = isExpense ? CategoryConstants.subscriptions : CategoryConstants.deposit;
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description (e.g. Netflix, Rent)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (text) {
                      if (text.trim().length >= 3) {
                        final autoCat = TransactionCategory.fromDescriptionCached(text);
                        if (autoCat != CategoryConstants.other && autoCat != selectedCategory) {
                          setDialogState(() => selectedCategory = autoCat);
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount (${widget.currency})',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Category',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: TransactionCategory.allNames.map((c) {
                        final isSelected = selectedCategory == c;
                        final color = TransactionCategory.colorFor(c);
                        final colorScheme = Theme.of(context).colorScheme;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            showCheckmark: false,
                            avatar: Icon(
                              TransactionCategory.iconFor(c),
                              size: 16,
                              color: isSelected ? color : colorScheme.onSurfaceVariant,
                            ),
                            label: Text(c),
                            selected: isSelected,
                            selectedColor: color.withValues(alpha: 0.18),
                            side: BorderSide(
                              color: isSelected ? color : colorScheme.outline.withValues(alpha: 0.25),
                              width: isSelected ? 1.4 : 1.0,
                            ),
                            labelStyle: TextStyle(
                              color: isSelected ? color : colorScheme.onSurface,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                            onSelected: (_) {
                              setDialogState(() => selectedCategory = c);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Frequency',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<RecurringFrequency>(
                      showSelectedIcon: false,
                      segments: RecurringFrequency.values.map((f) {
                        return ButtonSegment<RecurringFrequency>(
                          value: f,
                          label: Text(f.label, style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      selected: {selectedFreq},
                      onSelectionChanged: (val) {
                        setDialogState(() => selectedFreq = val.first);
                      },
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        selectedBackgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                        selectedForegroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('First Due Date'),
                    subtitle: Text(DateFormat.yMMMd().format(selectedDate)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text.trim());
                  final desc = descController.text.trim();
                  if (desc.isEmpty || amount == null || amount <= 0) return;

                  final rule = RecurringRule(
                    id: const Uuid().v4(),
                    description: desc,
                    amount: amount,
                    category: selectedCategory,
                    isExpense: isExpense,
                    frequency: selectedFreq,
                    nextDue: selectedDate,
                  );

                  await RecurringRuleRepository.instance.createRule(rule);
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
                },
                child: const Text('Save Rule'),
              ),
            ],
          );
        },
      ),
    );

    if (created == true) {
      widget.onRulesUpdated();
      await _loadRules();
    }
  }

  Future<void> _showEditRuleDialog(RecurringRule rule) async {
    final descController = TextEditingController(text: rule.description);
    final amountController = TextEditingController(text: rule.amount.toStringAsFixed(2).replaceAll('.00', ''));
    var isExpense = rule.isExpense;
    var selectedCategory = rule.category;
    var selectedFreq = rule.frequency;
    var selectedDate = rule.nextDue;

    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Recurring Rule'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: true, label: Text('Expense'), icon: Icon(Icons.arrow_upward)),
                      ButtonSegment(value: false, label: Text('Income'), icon: Icon(Icons.arrow_downward)),
                    ],
                    selected: {isExpense},
                    onSelectionChanged: (set) => setDialogState(() => isExpense = set.first),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description (e.g. Netflix, Rent)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount (${widget.currency})',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Category',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: TransactionCategory.allNames.map((c) {
                        final isSelected = selectedCategory == c;
                        final color = TransactionCategory.colorFor(c);
                        final colorScheme = Theme.of(context).colorScheme;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            showCheckmark: false,
                            avatar: Icon(
                              TransactionCategory.iconFor(c),
                              size: 16,
                              color: isSelected ? color : colorScheme.onSurfaceVariant,
                            ),
                            label: Text(c),
                            selected: isSelected,
                            selectedColor: color.withValues(alpha: 0.18),
                            side: BorderSide(
                              color: isSelected ? color : colorScheme.outline.withValues(alpha: 0.25),
                              width: isSelected ? 1.4 : 1.0,
                            ),
                            labelStyle: TextStyle(
                              color: isSelected ? color : colorScheme.onSurface,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                            onSelected: (_) {
                              setDialogState(() => selectedCategory = c);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Frequency',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<RecurringFrequency>(
                      showSelectedIcon: false,
                      segments: RecurringFrequency.values.map((f) {
                        return ButtonSegment<RecurringFrequency>(
                          value: f,
                          label: Text(f.label, style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      selected: {selectedFreq},
                      onSelectionChanged: (val) {
                        setDialogState(() => selectedFreq = val.first);
                      },
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        selectedBackgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                        selectedForegroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Next Due Date'),
                    subtitle: Text(DateFormat.yMMMd().format(selectedDate)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text.trim());
                  final desc = descController.text.trim();
                  if (desc.isEmpty || amount == null || amount <= 0) return;

                  final updatedRule = rule.copyWith(
                    description: desc,
                    amount: amount,
                    category: selectedCategory,
                    isExpense: isExpense,
                    frequency: selectedFreq,
                    nextDue: selectedDate,
                  );

                  await RecurringRuleRepository.instance.updateRule(updatedRule);
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );

    if (updated == true) {
      widget.onRulesUpdated();
      await _loadRules();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: ExpressiveShapeMorphIndicator(size: 44)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _materializeNow,
                  icon: const Icon(Icons.sync_outlined, size: 18),
                  label: const Text('Catch Up Due'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _showAddRuleDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Rule'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_rules.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.repeat_outlined, size: 48, color: colorScheme.outlineVariant),
                  const SizedBox(height: 12),
                  Text(
                    'No recurring subscriptions yet',
                    style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add rent, utility bills, or subscriptions to automate ledger logging.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _rules.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final rule = _rules[index];
                  final isDue = !rule.nextDue.isAfter(DateTime.now());

                  return Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppLayout.radiusM),
                      side: BorderSide(
                        color: isDue
                            ? colorScheme.error.withValues(alpha: 0.5)
                            : colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: ListTile(
                      onTap: () => _showEditRuleDialog(rule),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: rule.isExpense
                            ? colorScheme.errorContainer
                            : colorScheme.primaryContainer,
                        child: Icon(
                          TransactionCategory.iconFor(rule.category),
                          color: rule.isExpense
                              ? colorScheme.onErrorContainer
                              : colorScheme.onPrimaryContainer,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        rule.description,
                        style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${rule.frequency.label} • Next: ${DateFormat.MMMd().format(rule.nextDue)} ${isDue ? "(DUE NOW)" : ""}',
                        style: textTheme.bodySmall?.copyWith(
                          color: isDue ? colorScheme.error : colorScheme.onSurfaceVariant,
                          fontWeight: isDue ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${rule.isExpense ? '-' : '+'}${widget.currency} ${rule.amount.toStringAsFixed(0)}',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: rule.isExpense ? colorScheme.error : colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            color: colorScheme.error,
                            onPressed: () => _deleteRule(rule),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
