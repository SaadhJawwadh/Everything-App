import 'package:flutter/material.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../data/period_log_model.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../core/ui/app_dialog.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/period_tracker_provider.dart';

/// Modal bottom sheet for logging or editing a menstrual period record.
class PeriodLogEditorSheet extends StatefulWidget {
  final PeriodLog? log;
  final DateTime? defaultStartDate;
  final PeriodTrackerProvider provider;

  const PeriodLogEditorSheet({
    super.key,
    this.log,
    this.defaultStartDate,
    required this.provider,
  });

  static Future<bool?> show({
    required BuildContext context,
    PeriodLog? log,
    DateTime? defaultStartDate,
    required PeriodTrackerProvider provider,
  }) {
    return AppBottomSheet.show<bool>(
      context: context,
      isScrollControlled: true,
      child: PeriodLogEditorSheet(
        log: log,
        defaultStartDate: defaultStartDate,
        provider: provider,
      ),
    );
  }

  @override
  State<PeriodLogEditorSheet> createState() => _PeriodLogEditorSheetState();
}

class _PeriodLogEditorSheetState extends State<PeriodLogEditorSheet> {
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

  String _localizedSymptom(BuildContext context, String symptom) {
    final l10n = AppLocalizations.of(context);
    switch (symptom) {
      case 'Cramps':
        return l10n?.symptomCramps ?? 'Cramps';
      case 'Bloating':
        return l10n?.symptomBloating ?? 'Bloating';
      case 'Headache':
        return l10n?.symptomHeadache ?? 'Headache';
      case 'Fatigue':
        return l10n?.symptomFatigue ?? 'Fatigue';
      case 'Acne':
        return l10n?.symptomAcne ?? 'Acne';
      case 'Mood Swings':
        return l10n?.symptomMoodSwings ?? 'Mood Swings';
      case 'Nausea':
        return l10n?.symptomNausea ?? 'Nausea';
      case 'Backache':
        return l10n?.symptomBackache ?? 'Backache';
      default:
        return symptom;
    }
  }

  late DateTime _tempStart;
  DateTime? _tempEnd;
  late String _tempIntensity;
  late List<String> _tempSymptoms;
  late bool _isOngoing;

  @override
  void initState() {
    super.initState();
    final initialStart = widget.log?.startDate ?? widget.defaultStartDate ?? DateTime.now();
    _tempStart = DateTime.utc(initialStart.year, initialStart.month, initialStart.day);

    if (widget.log?.endDate != null) {
      final end = widget.log!.endDate!;
      _tempEnd = DateTime.utc(end.year, end.month, end.day);
    } else {
      _tempEnd = null;
    }

    _tempIntensity = widget.log?.intensity ?? 'Medium';
    _tempSymptoms = List<String>.from(widget.log?.symptoms ?? []);
    _isOngoing = _tempEnd == null;
  }

  Future<void> _handleSave() async {
    AppHaptics.mediumImpact();
    final l10n = AppLocalizations.of(context);

    if (!_isOngoing && _tempEnd != null && _tempStart.isAfter(_tempEnd!)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.startDateAfterEndDate ?? 'Start date cannot be after end date')),
        );
      }
      return;
    }

    final hasOverlap = widget.provider.checkOverlap(_tempStart, _isOngoing ? null : _tempEnd, widget.log?.id);
    if (hasOverlap) {
      if (!mounted) return;
      await AppDialog.showConfirm(
        context: context,
        title: l10n?.overlapDetectedTitle ?? 'Overlap Detected',
        message: l10n?.overlapDetectedMessage ?? 'The selected dates overlap with an existing logged period. Please adjust the dates.',
        confirmLabel: l10n?.done ?? 'OK',
      );
      return;
    }

    if (widget.log != null) {
      final updated = widget.log!.copyWith(
        startDate: _tempStart,
        endDate: _isOngoing ? null : _tempEnd,
        intensity: _tempIntensity,
        symptoms: _tempSymptoms,
      );
      await widget.provider.updateLog(updated);
    } else {
      final newLog = PeriodLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startDate: _tempStart,
        endDate: _isOngoing ? null : _tempEnd,
        intensity: _tempIntensity,
        symptoms: _tempSymptoms,
      );
      await widget.provider.createLog(newLog);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppLayout.spaceS,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            Row(
              children: [
                Text(
                  widget.log != null ? 'Edit Period Log' : 'Add Period Log',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Start Date'),
              subtitle: Text(AppFormatters.formatDate(context, _tempStart)),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () async {
                if (!context.mounted) return;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _tempStart,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() {
                    _tempStart = DateTime.utc(picked.year, picked.month, picked.day);
                    if (_tempEnd != null && _tempStart.isAfter(_tempEnd!)) {
                      _tempEnd = null;
                      _isOngoing = true;
                    }
                  });
                }
              },
            ),
            const SizedBox(height: AppLayout.spaceS),

            SwitchListTile(
              title: const Text('Ongoing Period'),
              subtitle: const Text('Still active/no end date yet'),
              value: _isOngoing,
              onChanged: (val) async {
                AppHaptics.selectionClick();
                setState(() {
                  _isOngoing = val;
                  if (val) {
                    _tempEnd = null;
                  } else {
                    _tempEnd = _tempStart.add(const Duration(days: 4));
                  }
                });
              },
            ),
            if (!_isOngoing) ...[
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('End Date'),
                subtitle: Text(_tempEnd != null ? AppFormatters.formatDate(context, _tempEnd!) : 'Select end date'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () async {
                  if (!context.mounted) return;
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _tempEnd ?? _tempStart.add(const Duration(days: 4)),
                    firstDate: _tempStart,
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                      _tempEnd = DateTime.utc(picked.year, picked.month, picked.day);
                    });
                  }
                },
              ),
            ],
            const SizedBox(height: AppLayout.spaceM),
            Text('Flow Intensity', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                const ButtonSegment(value: 'Spotting', label: Text('Spotting')),
                ButtonSegment(value: 'Light', label: Text(l10n?.intensityLight ?? 'Light')),
                ButtonSegment(value: 'Medium', label: Text(l10n?.intensityMedium ?? 'Medium')),
                ButtonSegment(value: 'Heavy', label: Text(l10n?.intensityHeavy ?? 'Heavy')),
              ],
              selected: {_tempIntensity},
              onSelectionChanged: (Set<String> selection) {
                AppHaptics.selectionClick();
                setState(() {
                  _tempIntensity = selection.first;
                });
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: colorScheme.tertiaryContainer,
                selectedForegroundColor: colorScheme.onTertiaryContainer,
                backgroundColor: colorScheme.surfaceContainerLow,
              ),
            ),

            const SizedBox(height: 20),
            Text('Symptoms', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _predefinedSymptoms.map((symptom) {
                final isSelected = _tempSymptoms.contains(symptom);
                return FilterChip(
                  showCheckmark: false,
                  label: Text(_localizedSymptom(context, symptom)),
                  selected: isSelected,
                  onSelected: (selected) {
                    AppHaptics.selectionClick();
                    setState(() {
                      if (selected) {
                        _tempSymptoms.add(symptom);
                      } else {
                        _tempSymptoms.remove(symptom);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

          FilledButton(
            onPressed: _handleSave,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppLayout.radiusL)),
            ),
            child: Text(l10n?.save ?? 'Save Log'),
          ),
        ],
      ),
    );
  }
}
