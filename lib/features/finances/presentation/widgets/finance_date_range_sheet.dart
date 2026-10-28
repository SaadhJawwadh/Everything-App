import 'package:flutter/material.dart';

import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../l10n/app_localizations.dart';

const Object _customRangeSentinel = Object();

/// Modal bottom sheet allowing users to select common financial date presets
/// (This Month, Last Month, Last 90 Days, This Year, All Time) or open a
/// custom date range picker.
class FinanceDateRangeSheet extends StatelessWidget {
  final DateTimeRange currentRange;

  const FinanceDateRangeSheet({
    super.key,
    required this.currentRange,
  });

  /// Displays the date range selection sheet and returns the selected [DateTimeRange],
  /// or `null` if dismissed without changes.
  static Future<DateTimeRange?> show(
    BuildContext context, {
    required DateTimeRange currentRange,
  }) async {
    final l10n = AppLocalizations.of(context);

    final result = await AppBottomSheet.show<dynamic>(
      context: context,
      title: l10n?.selectPeriod ?? 'Select Period',
      child: FinanceDateRangeSheet(currentRange: currentRange),
    );

    if (result is DateTimeRange) {
      return result;
    } else if (identical(result, _customRangeSentinel)) {
      if (!context.mounted) return null;
      return await showDateRangePicker(
        context: context,
        initialDateRange: currentRange,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        builder: (ctx, child) {
          return Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(ctx).colorScheme.copyWith(
                surface: Theme.of(ctx).colorScheme.surfaceContainerHigh,
              ),
            ),
            child: child!,
          );
        },
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();

    final thisMonth = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
    final lastMonth = DateTimeRange(
      start: DateTime(now.year, now.month - 1, 1),
      end: DateTime(now.year, now.month, 0),
    );
    final last90Days = DateTimeRange(
      start: now.subtract(const Duration(days: 90)),
      end: now,
    );
    final thisYear = DateTimeRange(
      start: DateTime(now.year, 1, 1),
      end: now,
    );
    final allTime = DateTimeRange(
      start: DateTime(2000, 1, 1),
      end: DateTime(2100, 1, 1),
    );

    bool isCurrent(DateTimeRange range) {
      return currentRange.start.year == range.start.year &&
          currentRange.start.month == range.start.month &&
          currentRange.start.day == range.start.day &&
          currentRange.end.year == range.end.year &&
          currentRange.end.month == range.end.month &&
          currentRange.end.day == range.end.day;
    }

    Widget buildPresetCard(String label, IconData icon, DateTimeRange range) {
      final isSelected = isCurrent(range);
      return InkWell(
        onTap: () {
          AppHaptics.selectionClick();
          Navigator.pop(context, range);
        },
        borderRadius: BorderRadius.circular(AppLayout.radiusM),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(AppLayout.radiusM),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: buildPresetCard(
                  l10n?.thisMonth ?? 'This Month',
                  Icons.today_outlined,
                  thisMonth,
                ),
              ),
                const SizedBox(width: 10),
                Expanded(
                  child: buildPresetCard(
                    l10n?.lastMonth ?? 'Last Month',
                    Icons.history_outlined,
                    lastMonth,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: buildPresetCard(
                    l10n?.last90Days ?? 'Last 90 Days',
                    Icons.auto_graph_outlined,
                    last90Days,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: buildPresetCard(
                    l10n?.thisYear ?? 'This Year',
                    Icons.calendar_today_outlined,
                    thisYear,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            buildPresetCard(
              l10n?.allTime ?? 'All Time (Full History)',
              Icons.all_inclusive_outlined,
              allTime,
            ),
            const SizedBox(height: AppLayout.spaceS),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: colorScheme.secondaryContainer,
                child: Icon(
                  Icons.date_range_outlined,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              title: Text(
                l10n?.customDateRange ?? 'Custom Date Range…',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                l10n?.customDateRangeSubtitle ?? 'Pick exact start and end dates from calendar',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context, _customRangeSentinel);
              },
            ),
          ],
        ),
      );
  }
}
