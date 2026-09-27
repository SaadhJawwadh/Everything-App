import 'package:flutter/material.dart';
import '../../../../core/services/app_haptics.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../core/ui/app_dialog.dart';
import '../../providers/period_tracker_provider.dart';
import 'period_log_editor_sheet.dart';

/// Standardized Material 3 Card managing the active day's period log,
/// quick Start/Stop flow triggers, 4-tier intensity selection, and symptoms.
class PeriodLogDashboardCard extends StatefulWidget {
  final DateTime selectedDay;
  final PeriodTrackerProvider provider;

  const PeriodLogDashboardCard({
    super.key,
    required this.selectedDay,
    required this.provider,
  });

  @override
  State<PeriodLogDashboardCard> createState() => _PeriodLogDashboardCardState();
}

class _PeriodLogDashboardCardState extends State<PeriodLogDashboardCard> {
  static const List<String> _predefinedSymptoms = [
    'Cramps',
    'Bloating',
    'Headache',
    'Fatigue',
    'Acne',
    'Mood Swings',
    'Nausea',
    'Backache',
  ];

  static const List<IconData> _intensityIcons = [
    Icons.water_drop_outlined, // Spotting
    Icons.water_drop,          // Light
    Icons.water,               // Medium
    Icons.flood,               // Heavy
  ];
  static const List<String> _intensityLabels = [
    'Spotting', 'Light', 'Medium', 'Heavy',
  ];

  bool _symptomsExpanded = false;

  Future<void> _handleToggleStatus() async {
    AppHaptics.mediumImpact();
    final success = await widget.provider.togglePeriodStatus();
    if (!success && mounted) {
      await AppDialog.showConfirm(
        context: context,
        title: 'Overlap Detected',
        message: 'Starting or updating a period today would overlap with an existing logged period. Please edit the logs instead.',
        confirmLabel: 'OK',
      );
    }
  }

  Future<void> _handleDeleteLog(String id) async {
    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: 'Delete Period Log',
      message: 'Are you sure you want to delete this period log record?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true) {
      AppHaptics.mediumImpact();
      await widget.provider.deleteLog(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final selectedLog = widget.provider.getLogForDay(widget.selectedDay);
    final isPeriodActive = widget.provider.isPeriodActive;

    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final isSelectedToday = isSameDay(widget.selectedDay, today);

    return AppCard(
      backgroundColor: colorScheme.surfaceContainerHigh,
      border: BorderSide(
        color: isPeriodActive && isSelectedToday
            ? colorScheme.primary
            : colorScheme.outlineVariant.withValues(alpha: 0.3),
        width: isPeriodActive && isSelectedToday ? 1.5 : 1.0,
      ),
      borderRadius: AppLayout.radiusXL,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: title + action buttons
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedLog != null
                          ? 'Period Log'
                          : (isSelectedToday ? 'Start your period' : 'No log for this day'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (selectedLog != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        selectedLog.endDate != null
                            ? '${DateFormat.MMMd().format(selectedLog.startDate)} – ${DateFormat.MMMd().format(selectedLog.endDate!)}'
                            : '${DateFormat.MMMd().format(selectedLog.startDate)} · Ongoing',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selectedLog != null) ...[
                IconButton(
                  onPressed: () {
                    PeriodLogEditorSheet.show(
                      context: context,
                      log: selectedLog,
                      provider: widget.provider,
                    );
                  },
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: Icon(Icons.edit_outlined, size: 20, color: colorScheme.onSurfaceVariant),
                  tooltip: 'Edit Dates',
                ),
                IconButton(
                  onPressed: () => _handleDeleteLog(selectedLog.id),
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: Icon(Icons.delete_outline, size: 20, color: colorScheme.error),
                  tooltip: 'Delete Log',
                ),
              ],
            ],
          ),

          if (selectedLog == null && isSelectedToday) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _handleToggleStatus,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(double.infinity, 52),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Period'),
            ),
          ],

          if (selectedLog == null && !isSelectedToday) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                PeriodLogEditorSheet.show(
                  context: context,
                  defaultStartDate: widget.selectedDay,
                  provider: widget.provider,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(double.infinity, 52),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Period Log'),
            ),
          ],

          if (selectedLog != null) ...[
            // Stop Period Button if currently active
            if (selectedLog.endDate == null && isSelectedToday) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _handleToggleStatus,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.errorContainer,
                  foregroundColor: colorScheme.onErrorContainer,
                  minimumSize: const Size(double.infinity, 52),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Stop Period'),
              ),
            ],

            const SizedBox(height: AppLayout.spaceL),

            // Flow Intensity
            Text(
              'Flow Intensity',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(_intensityLabels.length, (i) {
                final label = _intensityLabels[i];
                final icon = _intensityIcons[i];
                final isChosen = selectedLog.intensity == label;
                return Expanded(
                  child: Semantics(
                    button: true,
                    label: '$label flow',
                    selected: isChosen,
                    child: GestureDetector(
                      onTap: () async {
                        AppHaptics.selectionClick();
                        await widget.provider.updateIntensity(selectedLog, label);
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isChosen
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppLayout.radiusM),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                icon,
                                size: 20,
                                color: isChosen ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isChosen ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                                  fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: AppLayout.spaceM),

            // Collapsible Symptoms Section
            InkWell(
              onTap: () {
                setState(() => _symptomsExpanded = !_symptomsExpanded);
              },
              borderRadius: BorderRadius.circular(AppLayout.radiusS),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.mood_outlined,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Symptoms',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (selectedLog.symptoms.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                        ),
                        child: Text(
                          '${selectedLog.symptoms.length}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(
                      _symptomsExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _symptomsExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _predefinedSymptoms.map((symptom) {
                            final isSelected = selectedLog.symptoms.contains(symptom);
                            return Semantics(
                              button: true,
                              selected: isSelected,
                              label: symptom,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                                child: GestureDetector(
                                  onTap: () async {
                                    AppHaptics.selectionClick();
                                    await widget.provider.toggleSymptom(selectedLog, symptom);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? colorScheme.primaryContainer
                                          : colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                                    ),
                                    child: Text(
                                      symptom,
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: isSelected
                                            ? colorScheme.onPrimaryContainer
                                            : colorScheme.onSurfaceVariant,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}
