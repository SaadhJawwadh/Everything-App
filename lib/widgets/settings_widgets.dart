import 'package:flutter/material.dart';
import '../core/services/app_haptics.dart';
import '../core/theme/app_layout.dart';
import '../core/ui/app_chip.dart';
import 'bouncing_widget.dart';

/// Top Hero Dashboard Card displaying status indicators, active modules, and quick theme toggle.
class SettingsHeroCard extends StatelessWidget {
  final bool isAppLockEnabled;
  final bool isFinancialManagerEnabled;
  final bool isPeriodTrackerEnabled;
  final bool isAiEnabled;
  final bool autoBackupEnabled;
  final String? lastAutoBackupTimeFormatted;
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback? onAppLockTap;
  final VoidCallback? onBackupTap;

  const SettingsHeroCard({
    super.key,
    required this.isAppLockEnabled,
    required this.isFinancialManagerEnabled,
    required this.isPeriodTrackerEnabled,
    required this.isAiEnabled,
    required this.autoBackupEnabled,
    this.lastAutoBackupTimeFormatted,
    required this.currentThemeMode,
    required this.onThemeModeChanged,
    this.onAppLockTap,
    this.onBackupTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: isDark ? 0.20 : 0.52),
          borderRadius: BorderRadius.circular(AppLayout.radiusL),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: isDark ? 0.35 : 0.45),
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(AppLayout.spaceL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header & Security Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary,
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            size: 22,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: AppLayout.spaceM),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Control Center',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    children: [
                                      Text(
                                        'Preferences & Health',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: (isDark ? const Color(0xFF10B981) : const Color(0xFF059669)).withValues(alpha: isDark ? 0.18 : 0.10),
                                          borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                                          border: Border.all(
                                            color: (isDark ? const Color(0xFF34D399) : const Color(0xFF10B981)).withValues(alpha: 0.35),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 5,
                                              height: 5,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF10B981),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Local Vault',
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.2,
                                                color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppLayout.spaceS),
                      AppChip(
                        isCompact: true,
                        icon: isAppLockEnabled
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        label: isAppLockEnabled ? 'Protected' : 'Unlocked',
                        isSelected: isAppLockEnabled,
                        onTap: onAppLockTap,
                        selectedBackgroundColor: isAppLockEnabled
                            ? colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.15)
                            : colorScheme.surfaceContainerHighest,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        textColor: isAppLockEnabled
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppLayout.spaceL),

                  // 2. Active Feature Module Badges
                  Text(
                    'ACTIVE MODULES & SYSTEM STATUS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: colorScheme.primary.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: AppLayout.spaceS),
                  Wrap(
                    spacing: AppLayout.spaceXS,
                    runSpacing: AppLayout.spaceXS,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (isFinancialManagerEnabled)
                        AppChip(
                          isCompact: true,
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Finances',
                          isSelected: true,
                          selectedBackgroundColor:
                              const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.14),
                          textColor: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                        ),
                      if (isPeriodTrackerEnabled)
                        AppChip(
                          isCompact: true,
                          icon: Icons.favorite_rounded,
                          label: 'Health Tracker',
                          isSelected: true,
                          selectedBackgroundColor:
                              const Color(0xFFF43F5E).withValues(alpha: isDark ? 0.22 : 0.14),
                          textColor: isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C),
                        ),
                      if (isAiEnabled)
                        AppChip(
                          isCompact: true,
                          icon: Icons.auto_awesome_rounded,
                          label: 'Gemini AI',
                          isSelected: true,
                          selectedBackgroundColor:
                              colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.14),
                          textColor: colorScheme.primary,
                        ),
                      AppChip(
                        isCompact: true,
                        icon: autoBackupEnabled
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_off_rounded,
                        label: autoBackupEnabled
                            ? (lastAutoBackupTimeFormatted != null
                                ? 'Backup: $lastAutoBackupTimeFormatted'
                                : 'Auto-Backup On')
                            : 'Manual Backup',
                        isSelected: autoBackupEnabled,
                        onTap: onBackupTap,
                        selectedBackgroundColor:
                            const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.22 : 0.14),
                        textColor: autoBackupEnabled
                            ? (isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1))
                            : colorScheme.onSurfaceVariant,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppLayout.spaceL),

                  // 3. Quick Theme Toggle
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Theme Mode',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppLayout.spaceS),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto_rounded, size: 16),
                              label: Text('Auto'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_rounded, size: 16),
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_rounded, size: 16),
                              label: Text('Dark'),
                            ),
                          ],
                          selected: {currentThemeMode},
                          onSelectionChanged: (Set<ThemeMode> newSelection) {
                            AppHaptics.selectionClick();
                            onThemeModeChanged(newSelection.first);
                          },
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                              if (states.contains(WidgetState.selected)) {
                                return colorScheme.primary.withValues(alpha: isDark ? 0.30 : 0.20);
                              }
                              return Colors.transparent;
                            }),
                            foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                              if (states.contains(WidgetState.selected)) {
                                return colorScheme.primary;
                              }
                              return colorScheme.onSurfaceVariant;
                            }),
                            side: WidgetStateProperty.all(
                              BorderSide(
                                color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.40 : 0.50),
                                width: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

class SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color? accentColor;

  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final effectiveAccent = accentColor ?? colorScheme.primary;
    final containerColor = accentColor != null
        ? (isDark
            ? accentColor!.withValues(alpha: 0.08)
            : accentColor!.withValues(alpha: 0.04))
        : (isDark
            ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.5)
            : colorScheme.surfaceContainerLow);
    final borderColor = accentColor != null
        ? accentColor!.withValues(alpha: isDark ? 0.28 : 0.18)
        : colorScheme.outlineVariant.withValues(alpha: 0.35);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8, top: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: effectiveAccent.withValues(alpha: isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    size: 15,
                    color: effectiveAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: effectiveAccent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: containerColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppLayout.radiusL),
              side: BorderSide(
                color: borderColor,
                width: 1.0,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            child: Column(
              children: [
                const SizedBox(height: 4),
                ...children,
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final Widget? customLeading;
  final String title;
  final String? subtitle;
  final String? valueBadge;
  final Widget? trailing;
  final bool showArrow;
  final VoidCallback? onTap;

  const SettingsTile({
    super.key,
    this.icon,
    this.iconColor,
    this.iconBackgroundColor,
    this.customLeading,
    required this.title,
    this.subtitle,
    this.valueBadge,
    this.trailing,
    this.showArrow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveIconBg = iconBackgroundColor ??
        colorScheme.primaryContainer.withValues(alpha: 0.4);
    final effectiveIconColor = iconColor ?? colorScheme.primary;

    final tileChild = Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: customLeading ??
            (icon != null
                ? Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: effectiveIconBg,
                      borderRadius: BorderRadius.circular(AppLayout.radiusM),
                    ),
                    child: Icon(icon, size: 20, color: effectiveIconColor),
                  )
                : null),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: trailing ??
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (valueBadge != null) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: AppChip(
                      isCompact: true,
                      label: valueBadge!,
                      backgroundColor:
                          colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                      textColor: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (showArrow) const SizedBox(width: AppLayout.spaceXS),
                ],
                if (showArrow)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colorScheme.outline,
                  ),
              ],
            ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onTap,
      ),
    );

    if (onTap != null) {
      return BouncingWidget(
        onTap: onTap,
        child: tileChild,
      );
    }

    return tileChild;
  }
}

class SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsSwitchTile({
    super.key,
    required this.icon,
    this.iconColor,
    this.iconBackgroundColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveIconBg = iconBackgroundColor ??
        (value
            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5));
    final effectiveIconColor = iconColor ??
        (value ? colorScheme.primary : colorScheme.onSurfaceVariant);

    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: effectiveIconBg,
            borderRadius: BorderRadius.circular(AppLayout.radiusM),
          ),
          child: Icon(icon, size: 20, color: effectiveIconColor),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        value: value,
        onChanged: (v) {
          AppHaptics.selectionClick();
          onChanged(v);
        },
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        activeThumbColor: colorScheme.primary,
      ),
    );
  }
}

class SettingsSegmentedTile<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<ButtonSegment<T>> segments;
  final T selectedValue;
  final ValueChanged<T> onSelectionChanged;

  const SettingsSegmentedTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.segments,
    required this.selectedValue,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppLayout.radiusM),
                ),
                child: Icon(icon, size: 20, color: colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              segments: segments,
              selected: {selectedValue},
              onSelectionChanged: (Set<T> newSelection) {
                AppHaptics.selectionClick();
                onSelectionChanged(newSelection.first);
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
