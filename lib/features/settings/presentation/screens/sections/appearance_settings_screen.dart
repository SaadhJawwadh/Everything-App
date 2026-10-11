import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_layout.dart';
import '../../../../../core/ui/expressive_sliver_app_bar.dart';
import '../../../../../widgets/settings_widgets.dart';
import '../../../providers/settings_provider.dart';
import '../settings_dialogs.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const ExpressiveSliverAppBar(
                titleText: 'Appearance & UI',
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
                      title: 'Theme & Color System',
                      icon: Icons.palette_outlined,
                      accentColor: colorScheme.primary,
                      children: [
                        SettingsTile(
                          icon: Icons.brightness_medium_rounded,
                          iconColor: colorScheme.primary,
                          title: 'App Theme Mode',
                          subtitle: SettingsDialogs.getThemeLabel(settings.themeMode),
                          valueBadge: SettingsDialogs.getThemeLabel(settings.themeMode),
                          showArrow: true,
                          onTap: () => SettingsDialogs.showThemePicker(context, settings),
                        ),
                        SettingsSwitchTile(
                          icon: Icons.color_lens_outlined,
                          iconColor: colorScheme.secondary,
                          title: 'Dynamic Wallpaper Theme',
                          subtitle: 'Match app colors with device wallpaper (Android 12+)',
                          value: settings.useDynamicColor,
                          onChanged: settings.setUseDynamicColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppLayout.spaceL),
                    SettingsSection(
                      title: 'Interaction & Accessibility',
                      icon: Icons.touch_app_outlined,
                      accentColor: colorScheme.tertiary,
                      children: [
                        SettingsSwitchTile(
                          icon: Icons.vibration_rounded,
                          iconColor: colorScheme.tertiary,
                          title: 'Tactile Haptics',
                          subtitle: 'Restrained physical feedback for sliders, long-press, and actions',
                          value: settings.enableHaptics,
                          onChanged: settings.setEnableHaptics,
                        ),
                        SettingsSegmentedTile<double>(
                          icon: Icons.text_fields,
                          title: 'Text Scale',
                          subtitle: 'Global font sizing',
                          segments: const [
                            ButtonSegment(value: 14.0, label: Text('Small')),
                            ButtonSegment(value: 16.0, label: Text('Medium')),
                            ButtonSegment(value: 20.0, label: Text('Large')),
                          ],
                          selectedValue: settings.textSize,
                          onSelectionChanged: settings.setTextSize,
                        ),
                        SettingsTile(
                          icon: Icons.translate_rounded,
                          iconColor: colorScheme.primary,
                          title: 'Language',
                          subtitle: SettingsDialogs.getLanguageDisplayName(settings.selectedLanguageCode),
                          valueBadge: SettingsDialogs.getLanguageBadge(settings.selectedLanguageCode),
                          showArrow: true,
                          onTap: () => SettingsDialogs.showLanguagePicker(context, settings),
                        ),
                      ],
                    ),
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
