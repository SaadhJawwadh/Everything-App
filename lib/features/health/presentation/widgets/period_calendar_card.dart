import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/app_card.dart';
import '../../providers/period_tracker_provider.dart';

/// Standardized Material 3 Calendar card visualizing logged periods,
/// predicted next period windows, and estimated ovulation windows.
class PeriodCalendarCard extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final PeriodTrackerProvider provider;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final void Function(DateTime focusedDay) onPageChanged;

  const PeriodCalendarCard({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.provider,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  Widget _buildMarker(
    DateTime day,
    Color color,
    Color textColor, {
    required bool isFilled,
    bool isSelected = false,
    bool isToday = false,
  }) {
    return Container(
      margin: const EdgeInsets.all(6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isFilled ? color : color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: isSelected
            ? Border.all(color: textColor, width: 2)
            : (isToday ? Border.all(color: color, width: 2) : null),
      ),
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: isFilled ? textColor : color.withValues(alpha: 0.8),
          fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>();

    final periodColor = semantic?.phaseMenstrual ?? colorScheme.errorContainer;
    final onPeriodColor = theme.brightness == Brightness.dark
        ? colorScheme.surfaceContainerLow
        : colorScheme.onErrorContainer;

    return AppCard(
      backgroundColor: colorScheme.surfaceContainerLow,
      border: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      borderRadius: AppLayout.radiusXL,
      padding: const EdgeInsets.all(8.0),
      child: RepaintBoundary(
        child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: focusedDay,
        selectedDayPredicate: (day) => isSameDay(selectedDay, day),
        onDaySelected: onDaySelected,
        onPageChanged: onPageChanged,
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {
          CalendarFormat.month: 'Month',
        },
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
          leftChevronIcon: Icon(Icons.chevron_left_rounded, color: colorScheme.onSurfaceVariant),
          rightChevronIcon: Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focused) {
            final log = provider.getLogForDay(day);
            if (log != null) {
              return _buildMarker(day, periodColor, onPeriodColor, isFilled: true);
            } else if (provider.isPredictedDay(day)) {
              return _buildMarker(day, periodColor, onPeriodColor, isFilled: false);
            } else if (provider.isOvulationDay(day)) {
              return _buildMarker(
                day,
                colorScheme.tertiaryContainer,
                colorScheme.onTertiaryContainer,
                isFilled: false,
              );
            }
            return null;
          },
          selectedBuilder: (context, day, focused) {
            final log = provider.getLogForDay(day);
            if (log != null) {
              return _buildMarker(day, periodColor, onPeriodColor, isFilled: true, isSelected: true);
            }
            return _buildMarker(day, colorScheme.primary, colorScheme.onPrimary, isFilled: true, isSelected: true);
          },
          todayBuilder: (context, day, focused) {
            final log = provider.getLogForDay(day);
            if (log != null) {
              return _buildMarker(day, periodColor, onPeriodColor, isFilled: true, isToday: true);
            }
            return _buildMarker(
              day,
              colorScheme.surfaceContainerHighest,
              colorScheme.onSurface,
              isFilled: true,
              isToday: true,
            );
          },
        ),
      ),
    ),
    );
  }
}
