import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../core/ui/app_dialog.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import '../../../../data/transaction_model.dart';
import '../../data/models/savings_goal_model.dart';
import '../../providers/savings_goal_provider.dart';
import 'savings_goal_deposit_sheet.dart';
import 'savings_goal_editor_sheet.dart';

/// Card widget showcasing active goal-oriented savings pockets, progress, auto-pacing, and quick deposit.
class SavingsGoalsCard extends StatelessWidget {
  final String? currency;
  final bool isEmbeddedInCard;

  const SavingsGoalsCard({
    super.key,
    this.currency,
    this.isEmbeddedInCard = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final currencySymbol = currency ??
        Provider.of<SettingsProvider?>(context)?.currencySymbol ??
        'Rs.';

    final provider = Provider.of<SavingsGoalProvider?>(context);
    final goals = provider?.goals ?? const <SavingsGoal>[];

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.flag_rounded, color: colorScheme.primary, size: 18),
            ),
            const SizedBox(width: AppLayout.spaceS),
            Text(
              'Savings Pockets',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppLayout.radiusM),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New Goal', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => SavingsGoalEditorSheet.show(context),
            ),
          ],
        ),
        const SizedBox(height: AppLayout.spaceM),

        if (goals.isEmpty) ...[
          // Empty State
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceL),
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.savings_rounded,
                      size: 36,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppLayout.spaceM),
                  Text(
                    'No active savings goals',
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create goal pockets for college, travel, emergency funds, or gadgets.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppLayout.spaceL),
                  FilledButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Create First Goal'),
                    onPressed: () => SavingsGoalEditorSheet.show(context),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          // Aggregate Overview
          _buildAggregateOverview(context, goals, currencySymbol),
          const SizedBox(height: AppLayout.spaceL),

          // Goals List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: goals.length,
            separatorBuilder: (_, __) => Divider(
              height: AppLayout.spaceL * 1.5,
              thickness: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
            itemBuilder: (context, index) {
              final goal = goals[index];
              return _buildGoalRow(context, goal, currencySymbol, provider);
            },
          ),
        ],
      ],
    );

    if (isEmbeddedInCard) {
      return content;
    }

    return AppCard(
      child: content,
    );
  }

  Widget _buildAggregateOverview(
    BuildContext context,
    List<SavingsGoal> goals,
    String currency,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final totalSaved = goals.fold<double>(0.0, (acc, g) => acc + g.currentAmount);
    final totalTarget = goals.fold<double>(0.0, (acc, g) => acc + g.targetAmount);
    final ratio = totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0;
    final activeCount = goals.where((g) => !g.isCompleted).length;

    return Container(
      padding: const EdgeInsets.all(AppLayout.spaceL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: isDark ? 0.30 : 0.28),
            colorScheme.tertiaryContainer.withValues(alpha: isDark ? 0.22 : 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(AppLayout.radiusL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total saved',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$currency ${totalSaved.toStringAsFixed(0)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              Text(
                '${(ratio * 100).toStringAsFixed(0)}% achieved',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(AppLayout.radiusMAX),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target: $currency ${totalTarget.toStringAsFixed(0)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '$activeCount active goal${activeCount == 1 ? "" : "s"}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalRow(
    BuildContext context,
    SavingsGoal goal,
    String currency,
    SavingsGoalProvider? provider,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final goalColor = Color(goal.colorValue);

    final settings = Provider.of<SettingsProvider?>(context);
    final showDelight = settings?.showMilestoneDelight ?? true;
    final isAchieved = goal.isCompleted || (goal.targetAmount > 0 && goal.currentAmount >= goal.targetAmount);
    final isFinishLine = showDelight && !isAchieved && goal.progressPercent >= 75 && goal.remainingAmount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceXS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Icon, Title, Typographic Metadata, 3-dots Menu
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: goalColor.withValues(alpha: isDark ? 0.22 : 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  SavingsGoalModel.getIcon(goal.iconCodePoint),
                  color: goalColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppLayout.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${goal.category} · ${goal.account == AccountType.savings ? 'Savings Vault' : 'Daily Account'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppLayout.radiusM)),
                onSelected: (val) {
                  if (val == 'edit') {
                    SavingsGoalEditorSheet.show(context, goal: goal);
                  } else if (val == 'deposit') {
                    SavingsGoalDepositSheet.show(context, goal: goal);
                  } else if (val == 'delete') {
                    _confirmDelete(context, goal, provider);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'deposit',
                    child: ListTile(
                      leading: Icon(Icons.add_circle_outline_rounded, size: 18),
                      title: Text('Deposit / Withdraw'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined, size: 18),
                      title: Text('Edit Goal'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline_rounded, size: 18, color: colorScheme.error),
                      title: Text('Delete Goal', style: TextStyle(color: colorScheme.error)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppLayout.spaceM),

          // Row 2: Progress & Amounts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$currency ${goal.currentAmount.toStringAsFixed(0)} / $currency ${goal.targetAmount.toStringAsFixed(0)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Row(
                children: [
                  if (isAchieved && showDelight)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        'Fully funded ·',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: goalColor,
                        ),
                      ),
                    )
                  else if (isFinishLine)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        '$currency ${goal.remainingAmount.toStringAsFixed(0)} left ·',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: goalColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    )
                  else if (goal.milestoneLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        '${goal.milestoneLabel} ·',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: goalColor,
                        ),
                      ),
                    ),
                  Text(
                    '${goal.progressPercent.toStringAsFixed(0)}%',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: goalColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress Bar with vibrant track & indicator
          LinearProgressIndicator(
            value: goal.progressRatio,
            minHeight: 8,
            backgroundColor: goalColor.withValues(alpha: 0.15),
            color: goalColor,
            borderRadius: BorderRadius.circular(AppLayout.radiusMAX),
          ),
          const SizedBox(height: AppLayout.spaceM),

          // Row 3: Pacing & Quick Deposit Button
          Row(
            children: [
              Expanded(
                child: isAchieved
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.task_alt_rounded, size: 14, color: goalColor),
                              const SizedBox(width: 4),
                              Text(
                                'Goal Completed',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: goalColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Target of $currency ${goal.targetAmount.toStringAsFixed(0)} achieved',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.speed_rounded, size: 14, color: colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                '$currency ${goal.effectiveMonthlyPace.toStringAsFixed(0)} / mo',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '~${goal.estimatedMonthsRemaining} months left to reach target',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: goalColor.withValues(alpha: isAchieved ? 0.15 : 0.2),
                  foregroundColor: goalColor,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppLayout.radiusM),
                  ),
                ),
                icon: Icon(isAchieved ? Icons.check_rounded : Icons.add_rounded, size: 16),
                label: Text(
                  isAchieved ? 'Completed' : 'Deposit',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => SavingsGoalDepositSheet.show(context, goal: goal),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, SavingsGoal goal, SavingsGoalProvider? provider) async {
    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: 'Delete Savings Goal?',
      message: 'Are you sure you want to delete "${goal.title}"? Your recorded ledger transactions will not be deleted.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed == true && provider != null) {
      await provider.deleteGoal(goal.id);
    }
  }
}
