import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_layout.dart';
import '../../../../../core/ui/expressive_sliver_app_bar.dart';
import '../../../../../widgets/settings_widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../providers/settings_provider.dart';
import '../settings_dialogs.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              ExpressiveSliverAppBar(
                titleText: l10n?.appearance ?? 'Appearance & UI',
                showBackButton: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.spaceXL,
                  vertical: AppLayout.spaceL,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    SettingsSection(
                      title: l10n?.themeAndColorSystem ?? 'Theme & Color System',
                      icon: Icons.palette_outlined,
                      accentColor: colorScheme.primary,
                      children: [
                        SettingsTile(
                          icon: Icons.brightness_medium_rounded,
                          iconColor: colorScheme.primary,
                          title: l10n?.appThemeMode ?? l10n?.theme ?? 'App Theme Mode',
                          subtitle: SettingsDialogs.getThemeLabel(settings.themeMode),
                          valueBadge: SettingsDialogs.getThemeLabel(settings.themeMode),
                          showArrow: true,
                          onTap: () => SettingsDialogs.showThemePicker(context, settings),
                        ),
                        SettingsSwitchTile(
                          icon: Icons.color_lens_outlined,
                          iconColor: colorScheme.secondary,
                          title: l10n?.dynamicWallpaperTheme ?? 'Dynamic Wallpaper Theme',
                          subtitle: l10n?.dynamicWallpaperSubtitle ?? 'Match app colors with device wallpaper (Android 12+)',
                          value: settings.useDynamicColor,
                          onChanged: settings.setUseDynamicColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppLayout.spaceL),
                    SettingsSection(
                      title: l10n?.interactionAndAccessibility ?? 'Interaction & Accessibility',
                      icon: Icons.touch_app_outlined,
                      accentColor: colorScheme.tertiary,
                      children: [
                        SettingsSwitchTile(
                          icon: Icons.vibration_rounded,
                          iconColor: colorScheme.tertiary,
                          title: l10n?.tactileHaptics ?? 'Tactile Haptics',
                          subtitle: l10n?.tactileHapticsSubtitle ?? 'Restrained physical feedback for sliders, long-press, and actions',
                          value: settings.enableHaptics,
                          onChanged: settings.setEnableHaptics,
                        ),
                        SettingsSegmentedTile<double>(
                          icon: Icons.text_fields,
                          title: l10n?.textScale ?? 'Text Scale',
                          subtitle: l10n?.textScaleSubtitle ?? 'Global font sizing',
                          segments: [
                            ButtonSegment(value: 14.0, label: Text(l10n?.textScaleSmall ?? 'Small')),
                            ButtonSegment(value: 16.0, label: Text(l10n?.textScaleMedium ?? 'Medium')),
                            ButtonSegment(value: 20.0, label: Text(l10n?.textScaleLarge ?? 'Large')),
                          ],
                          selectedValue: settings.textSize,
                          onSelectionChanged: settings.setTextSize,
                        ),
                        SettingsTile(
                          icon: Icons.translate_rounded,
                          iconColor: colorScheme.primary,
                          title: l10n?.appLanguage ?? l10n?.language ?? 'Language',
                          subtitle: SettingsDialogs.getLanguageDisplayName(settings.selectedLanguageCode),
                          valueBadge: SettingsDialogs.getLanguageBadge(settings.selectedLanguageCode),
                          showArrow: true,
                          onTap: () => SettingsDialogs.showLanguagePicker(context, settings),
                        ),
                      ],
                    ),
                    if (!kIsWeb && Platform.isAndroid) ...[
                      const SizedBox(height: AppLayout.spaceL),
                      SettingsSection(
                        title: 'Home Screen Widgets',
                        icon: Icons.widgets_outlined,
                        accentColor: colorScheme.secondary,
                        children: [
                          SettingsTile(
                            icon: Icons.checklist_rtl_rounded,
                            iconColor: colorScheme.primary,
                            title: 'Action Items & Checklist Widget',
                            subtitle: 'Interactive checklist with 1-tap toggling and quick-add',
                            showArrow: true,
                            onTap: () => SettingsDialogs.showPinWidgetSheet(context, 'todo'),
                          ),
                          SettingsTile(
                            icon: Icons.account_balance_wallet_outlined,
                            iconColor: colorScheme.secondary,
                            title: 'Financial Manager Widget',
                            subtitle: 'Real-time spendings overview & sparkline pace plot',
                            showArrow: true,
                            onTap: () => SettingsDialogs.showPinWidgetSheet(context, 'finance'),
                          ),
                          SettingsTile(
                            icon: Icons.dashboard_customize_outlined,
                            iconColor: colorScheme.tertiary,
                            title: 'Unified Dual-Domain Widget',
                            subtitle: 'Dual-domain balance metrics with active checklist preview',
                            showArrow: true,
                            onTap: () => SettingsDialogs.showPinWidgetSheet(context, 'unified'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppLayout.fabBottomPadding),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
