import 'package:flutter/material.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../widgets/moon_phase_painter.dart';

/// Standardized Material 3 Tonal Hero Card rendering moon phase visualizer,
/// active cycle day metrics, and physiological guidance. Supports discreet privacy mode.
class CyclePhaseHeroCard extends StatefulWidget {
  final String phase;
  final String description;
  final int? cycleDay;
  final int avgCycleLength;
  final Color phaseColor;
  final String? predictionStatus;
  final bool isDiscreetMode;

  const CyclePhaseHeroCard({
    super.key,
    required this.phase,
    required this.description,
    required this.cycleDay,
    required this.avgCycleLength,
    required this.phaseColor,
    this.predictionStatus,
    this.isDiscreetMode = false,
  });

  @override
  State<CyclePhaseHeroCard> createState() => _CyclePhaseHeroCardState();
}

class _CyclePhaseHeroCardState extends State<CyclePhaseHeroCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isHidden = widget.isDiscreetMode && !_revealed;

    // Calculate lunar phase progression (0.0 to 1.0)
    double phaseValue = 0.0;
    if (widget.cycleDay != null && widget.avgCycleLength > 0) {
      phaseValue = ((widget.cycleDay! - 1) / widget.avgCycleLength).clamp(0.0, 1.0);
    }

    final activeColor = isHidden ? colorScheme.primary : widget.phaseColor;

    return Semantics(
      button: widget.isDiscreetMode,
      label: isHidden ? 'Discreet health mode active. Tap to reveal details.' : 'Cycle phase hero card',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppLayout.radiusXL),
        onTap: widget.isDiscreetMode
            ? () {
                AppHaptics.lightImpact();
                setState(() => _revealed = !_revealed);
              }
            : null,
        child: AppCard.tonal(
          color: activeColor.withValues(alpha: isDark ? 0.20 : 0.52),
          borderColor: activeColor.withValues(alpha: isDark ? 0.35 : 0.45),
          borderRadius: AppLayout.radiusXL,
          child: Padding(
            padding: const EdgeInsets.all(AppLayout.spaceL),
            child: Row(
              children: [
                MoonPhaseWidget(
                  phase: isHidden ? 0.5 : phaseValue,
                  size: 80,
                  moonColor: activeColor,
                ),
                const SizedBox(width: AppLayout.spaceL),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isHidden ? 'Wellness Tracker' : widget.phase,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: activeColor,
                              ),
                            ),
                          ),
                          if (widget.isDiscreetMode)
                            Icon(
                              isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 18,
                              color: activeColor.withValues(alpha: 0.7),
                            ),
                        ],
                      ),
                      if (widget.cycleDay != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          isHidden ? 'Cycle in Progress' : 'Day ${widget.cycleDay} of ${widget.avgCycleLength}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (widget.predictionStatus != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          isHidden ? 'Protected Mode • Tap to reveal' : widget.predictionStatus!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: activeColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        isHidden
                            ? 'Health details are hidden in public. Tap anywhere on this card to peek.'
                            : widget.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
