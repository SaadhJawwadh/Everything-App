import 'package:flutter/material.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../services/period_prediction_service.dart';

/// Standardized Material 3 Card presenting cycle statistical insights,
/// regularity score, period duration, and cycle variation.
class CycleInsightsCard extends StatelessWidget {
  final CycleStats stats;

  const CycleInsightsCard({
    super.key,
    required this.stats,
  });

  Color _getRegularityColor(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>();
    final successColor = semantic?.success ?? colorScheme.primary;

    if (stats.regularityScore >= 88.0) return successColor;
    if (stats.regularityScore >= 75.0) return colorScheme.tertiary;
    if (stats.regularityScore >= 60.0) return colorScheme.error.withValues(alpha: 0.85);
    return colorScheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>();
    final regularityColor = _getRegularityColor(theme);

    return AppCard(
      backgroundColor: colorScheme.surfaceContainerHigh,
      border: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      borderRadius: AppLayout.radiusXL,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Regularity Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_graph_rounded, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Cycle Insights',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (stats.cycleCount > 0)
                Text(
                  '${stats.regularityScore.toStringAsFixed(0)}% · ${stats.regularityLabel}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: regularityColor,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                )
              else
                Text(
                  'No data yet',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 3-Metric Row separated by clean 1px vertical dividers (no nested tile boxes)
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Avg Cycle',
                  value: '${stats.avgCycleLength}',
                  unit: 'days',
                  icon: Icons.repeat_rounded,
                  color: colorScheme.primary,
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
              Expanded(
                child: _MetricTile(
                  label: 'Avg Period',
                  value: '${stats.avgPeriodDuration}',
                  unit: 'days',
                  icon: Icons.water_drop_outlined,
                  color: semantic?.phaseMenstrual ?? colorScheme.primary,
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
              Expanded(
                child: _MetricTile(
                  label: 'Variation',
                  value: '±${stats.variationDays}',
                  unit: 'days',
                  icon: Icons.swap_horiz_rounded,
                  color: colorScheme.tertiary,
                ),
              ),
            ],
          ),

          if (stats.cycleCount > 0) ...[
            const SizedBox(height: 12),
            Text(
              'Calculated across ${stats.cycleCount} recorded cycle${stats.cycleCount > 1 ? "s" : ""}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
