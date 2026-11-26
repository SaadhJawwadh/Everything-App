import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../core/ui/app_chip.dart';
import '../../services/spending_forecast_service.dart';

/// Modular M3 Expressive Card displaying Daily Safe-to-Spend, Burn Rate, and Month-End Forecast.
class BurnRateForecastCard extends StatelessWidget {
  final MonthlySpendingForecast forecast;
  final String currency;
  final VoidCallback? onAdjustBudgets;

  const BurnRateForecastCard({
    super.key,
    required this.forecast,
    required this.currency,
    this.onAdjustBudgets,
  });

  Color _getStatusColor(ThemeData theme, SpendingPaceStatus status) {
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>();
    final successColor = semantic?.success ?? colorScheme.primary;

    switch (status) {
      case SpendingPaceStatus.underPace:
        return colorScheme.tertiary;
      case SpendingPaceStatus.onTrack:
        return successColor;
      case SpendingPaceStatus.overPace:
        return colorScheme.error.withValues(alpha: 0.85);
      case SpendingPaceStatus.exhausted:
        return colorScheme.error;
      case SpendingPaceStatus.noBudget:
        return colorScheme.outline;
    }
  }

  String _getStatusLabel(SpendingPaceStatus status) {
    switch (status) {
      case SpendingPaceStatus.underPace:
        return 'Under Pace';
      case SpendingPaceStatus.onTrack:
        return 'On Track';
      case SpendingPaceStatus.overPace:
        return 'Pacing High';
      case SpendingPaceStatus.exhausted:
        return 'Exceeded';
      case SpendingPaceStatus.noBudget:
        return 'No Budget Set';
    }
  }

  IconData _getStatusIcon(SpendingPaceStatus status) {
    switch (status) {
      case SpendingPaceStatus.underPace:
        return Icons.verified_outlined;
      case SpendingPaceStatus.onTrack:
        return Icons.check_circle_outline;
      case SpendingPaceStatus.overPace:
        return Icons.warning_amber_rounded;
      case SpendingPaceStatus.exhausted:
        return Icons.error_outline_rounded;
      case SpendingPaceStatus.noBudget:
        return Icons.tune_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final statusColor = _getStatusColor(theme, forecast.status);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppLayout.spaceXS),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.speed_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppLayout.spaceS),
              Expanded(
                child: Text(
                  'Spending Pace & Burn Rate',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppLayout.spaceS),
              AppChip(
                label: _getStatusLabel(forecast.status),
                icon: _getStatusIcon(forecast.status),
                backgroundColor: statusColor.withValues(alpha: 0.15),
                textColor: statusColor,
              ),
            ],
          ),
          const SizedBox(height: AppLayout.spaceL),

          // Daily Safe-to-Spend Hero Metric
          if (forecast.status != SpendingPaceStatus.noBudget) ...[
            Container(
              padding: const EdgeInsets.all(AppLayout.spaceM),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Safe-to-Spend',
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$currency ${NumberFormat('#,##0').format(forecast.dailySafeToSpend)}',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: forecast.dailySafeToSpend > 0
                                ? colorScheme.onSurface
                                : colorScheme.error,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'for remaining ${forecast.remainingDays} days',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 48,
                    width: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: AppLayout.spaceM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Projected Month-End',
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$currency ${NumberFormat('#,##0').format(forecast.projectedMonthEndSpend)}',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: forecast.projectedMonthEndSpend > forecast.totalBudget
                                ? colorScheme.error
                                : colorScheme.primary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Budget: $currency ${NumberFormat('#,##0').format(forecast.totalBudget)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppLayout.spaceM),

            // Timeline Pace Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Day ${forecast.currentDay} of ${forecast.totalDaysInMonth}',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      '${(forecast.budgetSpentFraction * 100).toInt()}% budget spent',
                      style: textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppLayout.spaceXS),
                Stack(
                  children: [
                    // Background track
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // Elapsed Time marker
                    FractionallySizedBox(
                      widthFactor: forecast.elapsedFraction.clamp(0.0, 1.0),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    // Spent Budget bar
                    FractionallySizedBox(
                      widthFactor: forecast.budgetSpentFraction.clamp(0.0, 1.0),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ] else ...[
            // Prompt to set budgets
            Container(
              padding: const EdgeInsets.all(AppLayout.spaceM),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                  const SizedBox(width: AppLayout.spaceM),
                  Expanded(
                    child: Text(
                      'Set monthly limits on your categories below to see burn rate projections and daily safe-to-spend targets.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppLayout.spaceM),

          // Actionable pace advice note
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: AppLayout.spaceS),
              Expanded(
                child: Text(
                  forecast.paceMessage,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
