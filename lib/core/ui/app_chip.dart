import 'package:flutter/material.dart';
import '../theme/app_layout.dart';
import '../services/app_haptics.dart';

/// Reusable Chip/Pill component for tags, categories, phase badges, and filters.
class AppChip extends StatelessWidget {
  final String label;
  final Widget? avatar;
  final IconData? icon;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Color? backgroundColor;
  final Color? selectedBackgroundColor;
  final Color? textColor;
  final BorderSide? border;

  const AppChip({
    super.key,
    required this.label,
    this.avatar,
    this.icon,
    this.isSelected = false,
    this.isCompact = false,
    this.onTap,
    this.onDelete,
    this.backgroundColor,
    this.selectedBackgroundColor,
    this.textColor,
    this.border,
  });

  /// Helper to calculate high-contrast WCAG-compliant colors for any tag color seed
  static ({Color bg, Color fg, BorderSide border}) getTagColors(
    BuildContext context,
    int? tagColorVal, {
    required bool isSelected,
  }) {
    final theme = Theme.of(context);

    if (tagColorVal != null && tagColorVal != 0) {
      final seedColor = Color(tagColorVal);
      final scheme = ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: theme.brightness,
      );

      if (isSelected) {
        return (
          bg: scheme.primary,
          fg: scheme.onPrimary,
          border: BorderSide(
            color: scheme.primary,
            width: 1.5,
          ),
        );
      } else {
        return (
          bg: scheme.secondaryContainer.withValues(alpha: 0.5),
          fg: scheme.onSecondaryContainer,
          border: BorderSide(
            color: scheme.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
        );
      }
    }

    if (isSelected) {
      return (
        bg: theme.colorScheme.primaryContainer,
        fg: theme.colorScheme.onPrimaryContainer,
        border: BorderSide(
          color: theme.colorScheme.primary,
          width: 1.5,
        ),
      );
    } else {
      return (
        bg: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        fg: theme.colorScheme.onSurfaceVariant,
        border: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 1.5,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBg = isSelected
        ? (selectedBackgroundColor ?? theme.colorScheme.primaryContainer)
        : (backgroundColor ?? theme.colorScheme.surfaceContainerHighest);

    final effectiveFg = textColor ??
        (isSelected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurfaceVariant);

    final horizPadding = isCompact ? 10.0 : 14.0;
    final vertPadding = isCompact ? 4.0 : 7.0;
    final fontSize = isCompact ? 12.0 : 13.0;
    final iconSize = isCompact ? 14.0 : 16.0;

    const effectiveRadius = AppLayout.radiusStadium;

    final chipWidget = Container(
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: border != null ? Border.fromBorderSide(border!) : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: InkWell(
          onTap: onTap != null
              ? () {
                  AppHaptics.selectionClick();
                  onTap!();
                }
              : null,
          borderRadius: BorderRadius.circular(effectiveRadius),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizPadding,
              vertical: vertPadding,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (avatar != null) ...[
                  avatar!,
                  const SizedBox(width: AppLayout.spaceXS),
                ] else if (icon != null) ...[
                  Icon(icon, size: iconSize, color: effectiveFg),
                  const SizedBox(width: AppLayout.spaceXS),
                ],
                Text(
                  label,
                  style: (theme.textTheme.labelMedium ?? const TextStyle()).copyWith(
                    fontSize: fontSize,
                    color: effectiveFg,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: AppLayout.spaceXS),
                  Semantics(
                    button: true,
                    label: 'Delete $label',
                    child: GestureDetector(
                      onTap: () {
                        AppHaptics.lightImpact();
                        onDelete!();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.close_rounded,
                            size: iconSize,
                            color: effectiveFg,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (onTap != null) {
      return Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: chipWidget,
      );
    }
    return chipWidget;
  }
}
