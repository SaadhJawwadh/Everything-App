import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_layout.dart';
import '../providers/note_provider.dart';
import '../features/finances/providers/financial_manager_provider.dart';
import '../features/settings/providers/settings_provider.dart';

/// A calm, non-judgmental 14-day activity strip visualizing cumulative mindful engagement.
///
/// Follows Calm Interaction Psychology:
/// - Zero streaks, zero broken-chain shame, zero countdown anxiety.
/// - Cumulative volume of mindfulness (e.g. "9 active days in the last 2 weeks").
/// - Gated by [SettingsProvider.showClarityMosaic].
class ClarityMosaicStrip extends StatelessWidget {
  const ClarityMosaicStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider?>(context);
    if (settings != null && !settings.showClarityMosaic) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final noteProvider = Provider.of<NoteProvider?>(context);
    final fmProvider = Provider.of<FinancialManagerProvider?>(context);

    // Build the set of active calendar day keys for the last 14 days
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    final days = List.generate(14, (i) {
      return todayMidnight.subtract(Duration(days: 13 - i));
    });

    final notes = noteProvider?.notes ?? [];
    final transactions = fmProvider?.transactions ?? [];

    final activeDaysMap = <String, int>{};

    for (final note in notes) {
      if (note.deletedAt != null) continue;
      final dMod = DateTime(note.dateModified.year, note.dateModified.month, note.dateModified.day);
      final key = _dayKey(dMod);
      activeDaysMap[key] = (activeDaysMap[key] ?? 0) + 1;
    }

    for (final tx in transactions) {
      final dTx = DateTime(tx.date.year, tx.date.month, tx.date.day);
      final key = _dayKey(dTx);
      activeDaysMap[key] = (activeDaysMap[key] ?? 0) + 1;
    }

    int activeCount = 0;
    for (final day in days) {
      if ((activeDaysMap[_dayKey(day)] ?? 0) > 0) {
        activeCount++;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppLayout.spaceM, vertical: AppLayout.spaceXS),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow.withValues(alpha: isDark ? 0.4 : 0.6),
          borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.4),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.wb_sunny_outlined,
              size: 14,
              color: colorScheme.primary,
            ),
            const SizedBox(width: AppLayout.spaceS),
            Text(
              '$activeCount of 14 mindful days',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: days.map((day) {
                final key = _dayKey(day);
                final activityCount = activeDaysMap[key] ?? 0;
                final isActive = activityCount > 0;
                final isToday = day == todayMidnight;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Tooltip(
                    message: '${_formatDayLabel(day)}: $activityCount action${activityCount == 1 ? '' : 's'}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppLayout.radiusXS),
                      onTap: () {},
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: isToday ? 12 : 9,
                        height: isToday ? 12 : 9,
                        decoration: BoxDecoration(
                          color: isActive
                              ? (isToday
                                  ? colorScheme.primary
                                  : colorScheme.primary.withValues(alpha: isDark ? 0.75 : 0.65))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(isToday ? 4 : 3),
                          border: Border.all(
                            color: isToday
                                ? colorScheme.primary
                                : (isActive
                                    ? colorScheme.primary.withValues(alpha: isDark ? 0.9 : 0.8)
                                    : colorScheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.5)),
                            width: isToday ? 1.4 : 1.0,
                          ),
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
    );
  }

  static String _dayKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatDayLabel(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}
