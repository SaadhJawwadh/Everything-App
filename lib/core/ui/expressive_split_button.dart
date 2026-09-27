import 'package:flutter/material.dart';
import '../services/app_haptics.dart';
import '../theme/app_layout.dart';

/// Material 3 Expressive Split Button.
/// Combines a primary constructive CTA on the left with an attached dropdown anchor menu on the right.
class ExpressiveSplitButton<T> extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onPrimaryPressed;
  final List<PopupMenuEntry<T>> menuItems;
  final PopupMenuItemSelected<T> onSelected;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? primaryTooltip;
  final String? dropdownTooltip;

  const ExpressiveSplitButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPrimaryPressed,
    required this.menuItems,
    required this.onSelected,
    this.backgroundColor,
    this.foregroundColor,
    this.primaryTooltip,
    this.dropdownTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bg = backgroundColor ?? colorScheme.primaryContainer;
    final fg = foregroundColor ?? colorScheme.onPrimaryContainer;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Primary Action Button
            Tooltip(
              message: primaryTooltip ?? label,
              child: InkWell(
                onTap: () {
                  AppHaptics.lightImpact();
                  onPrimaryPressed();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconTheme(
                        data: IconThemeData(color: fg, size: 20),
                        child: icon,
                      ),
                      const SizedBox(width: AppLayout.spaceS),
                      Text(
                        label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Vertical Divider
            VerticalDivider(
              width: 1,
              thickness: 1,
              indent: 8,
              endIndent: 8,
              color: fg.withValues(alpha: 0.25),
            ),
            // Dropdown Menu Anchor Button
            PopupMenuButton<T>(
              tooltip: dropdownTooltip ?? 'More options',
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: fg, size: 22),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              color: colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusXL),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              onSelected: (val) {
                AppHaptics.selectionClick();
                onSelected(val);
              },
              itemBuilder: (context) => menuItems,
            ),
          ],
        ),
      ),
    );
  }
}
