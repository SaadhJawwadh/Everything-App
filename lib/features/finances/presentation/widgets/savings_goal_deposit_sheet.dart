import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import '../../../../data/transaction_model.dart';
import '../../../../data/transaction_category.dart';
import '../../data/models/savings_goal_model.dart';
import '../../providers/savings_goal_provider.dart';

enum _PocketAction { deposit, withdraw, liquidate }

/// Modal bottom sheet to deposit, withdraw, or liquidate funds in a savings pocket.
class SavingsGoalDepositSheet extends StatefulWidget {
  final SavingsGoal goal;

  const SavingsGoalDepositSheet({super.key, required this.goal});

  static Future<void> show(BuildContext context, {required SavingsGoal goal}) {
    return AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      title: 'Pocket: ${goal.title}',
      child: SavingsGoalDepositSheet(goal: goal),
    );
  }

  @override
  State<SavingsGoalDepositSheet> createState() => _SavingsGoalDepositSheetState();
}

class _SavingsGoalDepositSheetState extends State<SavingsGoalDepositSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  _PocketAction _action = _PocketAction.deposit;
  bool _recordInLedger = true;
  bool _isGoalCelebration = false;
  late String _liquidationCategory;

  @override
  void initState() {
    super.initState();
    final all = TransactionCategory.allNames;
    if (all.contains(widget.goal.category)) {
      _liquidationCategory = widget.goal.category;
    } else if (all.contains('Shopping')) {
      _liquidationCategory = 'Shopping';
    } else if (all.contains('Other')) {
      _liquidationCategory = 'Other';
    } else {
      _liquidationCategory = all.isNotEmpty ? all.first : 'Savings';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _setAmount(double val) {
    AppHaptics.selectionClick();
    _amountController.text = val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 2);
    setState(() {});
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (_action != _PocketAction.liquidate && amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final provider = context.read<SavingsGoalProvider>();
    final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();
    final goal = widget.goal;

    final settings = Provider.of<SettingsProvider?>(context, listen: false);
    final showDelight = settings?.showMilestoneDelight ?? true;
    final willComplete = _action == _PocketAction.deposit &&
        goal.targetAmount > 0 &&
        (goal.currentAmount + amount) >= goal.targetAmount &&
        goal.currentAmount < goal.targetAmount;

    if (_action == _PocketAction.deposit) {
      final fromAcc = goal.account == AccountType.savings ? AccountType.daily : AccountType.savings;
      await provider.deposit(
        goalId: goal.id,
        amount: amount,
        fromAccount: fromAcc,
        toAccount: goal.account,
        recordLedgerTransaction: _recordInLedger,
        note: note,
      );
    } else if (_action == _PocketAction.withdraw) {
      final toAcc = goal.account == AccountType.savings ? AccountType.daily : AccountType.savings;
      await provider.withdraw(
        goalId: goal.id,
        amount: amount,
        fromAccount: goal.account,
        toAccount: toAcc,
        recordLedgerTransaction: _recordInLedger,
        note: note,
      );
    } else {
      await provider.liquidateGoal(
        goalId: goal.id,
        amount: goal.currentAmount,
        category: _liquidationCategory,
        merchantTitle: goal.title,
      );
    }

    if (mounted && willComplete && showDelight) {
      setState(() => _isGoalCelebration = true);
      AppHaptics.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 500));
    } else {
      AppHaptics.mediumImpact();
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currency = context.watch<SettingsProvider>().currencySymbol;
    final goal = widget.goal;

    final remaining = goal.remainingAmount;
    final goalColor = Color(goal.colorValue);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: viewInsets.bottom + AppLayout.spaceXL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action Toggle
          SegmentedButton<_PocketAction>(
            segments: [
              const ButtonSegment(
                value: _PocketAction.deposit,
                icon: Icon(Icons.add_rounded, size: 16),
                label: Text('Deposit'),
              ),
              ButtonSegment(
                value: _PocketAction.withdraw,
                icon: const Icon(Icons.remove_rounded, size: 16),
                label: const Text('Withdraw'),
                enabled: goal.currentAmount > 0,
              ),
              ButtonSegment(
                value: _PocketAction.liquidate,
                icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                label: const Text('Spend / Reach'),
                enabled: goal.currentAmount > 0,
              ),
            ],
            selected: {_action},
            onSelectionChanged: (set) {
              setState(() {
                _action = set.first;
                if (_action == _PocketAction.liquidate) {
                  _amountController.text = goal.currentAmount.toStringAsFixed(0);
                }
              });
            },
          ),
          const SizedBox(height: AppLayout.spaceL),

          // Goal Progress Glance
          Container(
            padding: const EdgeInsets.all(AppLayout.spaceM),
            decoration: BoxDecoration(
              color: goalColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppLayout.radiusM),
              border: Border.all(color: goalColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: goalColor.withValues(alpha: 0.2),
                  child: Icon(SavingsGoalModel.getIcon(goal.iconCodePoint), color: goalColor),
                ),
                const SizedBox(width: AppLayout.spaceM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saved $currency ${goal.currentAmount.toStringAsFixed(2)} of $currency ${goal.targetAmount.toStringAsFixed(2)}',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: goal.progressRatio,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        color: goalColor,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(AppLayout.radiusMAX),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppLayout.spaceS),
                Text(
                  '${goal.progressPercent.toStringAsFixed(0)}%',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: goalColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppLayout.spaceL),

          if (_action != _PocketAction.liquidate) ...[
            // Amount Input Field
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: _action == _PocketAction.deposit ? 'Deposit Amount' : 'Withdrawal Amount',
                prefixText: '$currency ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppLayout.radiusM)),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppLayout.spaceM),

            // Shortcut Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _action == _PocketAction.deposit
                  ? [
                      if (remaining > 0)
                        ActionChip(
                          label: Text('Fill Left ($currency ${remaining.toStringAsFixed(0)})'),
                          onPressed: () => _setAmount(remaining),
                        ),
                      if (goal.effectiveMonthlyPace > 0)
                        ActionChip(
                          label: Text('1 Mo Pace ($currency ${goal.effectiveMonthlyPace.toStringAsFixed(0)})'),
                          onPressed: () => _setAmount(goal.effectiveMonthlyPace),
                        ),
                      ActionChip(label: const Text('+500'), onPressed: () => _setAmount(500)),
                      ActionChip(label: const Text('+1,000'), onPressed: () => _setAmount(1000)),
                      ActionChip(label: const Text('+2,500'), onPressed: () => _setAmount(2500)),
                      ActionChip(label: const Text('+5,000'), onPressed: () => _setAmount(5000)),
                    ]
                  : [
                      ActionChip(
                        label: const Text('All Balance'),
                        onPressed: () => _setAmount(goal.currentAmount),
                      ),
                      ActionChip(
                        label: const Text('50%'),
                        onPressed: () => _setAmount(goal.currentAmount * 0.5),
                      ),
                      ActionChip(
                        label: const Text('25%'),
                        onPressed: () => _setAmount(goal.currentAmount * 0.25),
                      ),
                    ],
            ),
            const SizedBox(height: AppLayout.spaceM),
          ] else ...[
            // Liquidation summary card
            Card(
              elevation: 0,
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
                side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppLayout.spaceM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.celebration_rounded, color: colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('Goal Milestone Reached!', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ready to spend your saved funds for ${goal.title}? Completing will liquidate the pocket balance of $currency ${goal.currentAmount.toStringAsFixed(2)} and log it as an authentic expense under "$_liquidationCategory".',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ledger Expense Category:',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: TransactionCategory.allNames.map((cat) {
                          final isSelected = _liquidationCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: isSelected,
                              showCheckmark: false,
                              avatar: Icon(
                                TransactionCategory.iconFor(cat),
                                size: 14,
                                color: isSelected ? colorScheme.onPrimaryContainer : TransactionCategory.colorFor(cat),
                              ),
                              label: Text(cat, style: const TextStyle(fontSize: 12)),
                              onSelected: (_) {
                                setState(() => _liquidationCategory = cat);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppLayout.spaceM),
          ],

          // Optional Note
          TextField(
            controller: _noteController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Optional Note / Memo',
              hintText: _action == _PocketAction.deposit ? 'e.g. Monthly stipend transfer' : 'e.g. Emergency withdrawal',
              prefixIcon: const Icon(Icons.notes_rounded, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppLayout.radiusM)),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: AppLayout.spaceS),

          // Authentic Ledger Integration Checkbox
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _recordInLedger,
            onChanged: (v) => setState(() => _recordInLedger = v ?? true),
            title: Text(
              _action == _PocketAction.deposit
                  ? 'Record transfer in Ledger'
                  : _action == _PocketAction.withdraw
                      ? 'Record return transfer in Ledger'
                      : 'Record expenditure in Ledger',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Text(
              _action == _PocketAction.deposit
                  ? 'Creates authentic transfer from Daily Operating to Savings Vault'
                  : _action == _PocketAction.withdraw
                      ? 'Transfers funds back to Daily Operating account'
                      : 'Logs $currency ${goal.currentAmount.toStringAsFixed(2)} expense in ${goal.account == AccountType.savings ? 'Savings Vault' : 'Daily Operating'}',
              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
          const SizedBox(height: AppLayout.spaceL),

          // Submit Button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: _isGoalCelebration
                  ? const Color(0xFF10B981)
                  : (_action == _PocketAction.liquidate ? colorScheme.primary : goalColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppLayout.radiusM)),
            ),
            icon: Icon(
              _isGoalCelebration
                  ? Icons.celebration_rounded
                  : (_action == _PocketAction.deposit
                      ? Icons.check_circle_outline_rounded
                      : _action == _PocketAction.withdraw
                          ? Icons.arrow_downward_rounded
                          : Icons.shopping_cart_checkout_rounded),
            ),
            label: Text(
              _isGoalCelebration
                  ? 'Target Achieved! Fully Funded'
                  : (_action == _PocketAction.deposit
                      ? 'Confirm Deposit'
                      : _action == _PocketAction.withdraw
                          ? 'Confirm Withdrawal'
                          : 'Liquidate & Mark Completed'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: _isGoalCelebration ? null : _submit,
          ),
          const SizedBox(height: AppLayout.spaceM),
        ],
      ),
    );
  }
}
