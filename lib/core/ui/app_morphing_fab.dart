import 'package:flutter/material.dart';
import '../services/app_haptics.dart';
import '../theme/app_layout.dart';

/// Standardized M3 Expressive Morphing Floating Action Button.
///
/// Automatically morphs between an expanded stadium button (icon + label + optional secondary action)
/// and a compact circular 56x56dp icon button based on scroll state.
class AppMorphingFab extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final IconData? collapsedIcon;
  final String? tooltip;
  final Widget? secondaryAction;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AppMorphingFab({
    super.key,
    required this.isExpanded,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.collapsedIcon,
    this.tooltip,
    this.secondaryAction,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? colorScheme.primaryContainer;
    final fg = foregroundColor ?? colorScheme.onPrimaryContainer;

    return Material(
      elevation: AppLayout.floatingElevation,
      borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
      color: bg,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.2),
      child: AnimatedContainer(
        duration: AppLayout.animDefault,
        curve: AppLayout.curveEmphasizedDecelerate,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: AnimatedSize(
          duration: AppLayout.animDefault,
          curve: AppLayout.curveEmphasizedDecelerate,
          child: !isExpanded
              ? SizedBox(
                  width: 56,
                  height: 56,
                  child: IconButton(
                    icon: Icon(collapsedIcon ?? icon, color: fg),
                    tooltip: tooltip ?? label,
                    onPressed: () {
                      AppHaptics.lightImpact();
                      onPressed();
                    },
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: fg,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () {
                        AppHaptics.lightImpact();
                        onPressed();
                      },
                      icon: Icon(icon, color: fg),
                      label: Text(
                        label,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (secondaryAction != null) ...[
                      Container(
                        height: 24,
                        width: 1,
                        color: fg.withValues(alpha: 0.25),
                      ),
                      secondaryAction!,
                      const SizedBox(width: 4),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
