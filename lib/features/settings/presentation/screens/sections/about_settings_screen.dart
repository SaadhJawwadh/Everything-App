import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../../core/services/app_haptics.dart';
import '../../../../../core/theme/app_layout.dart';
import '../../../../../core/ui/app_bottom_sheet.dart';
import '../../../../../core/ui/expressive_sliver_app_bar.dart';
import '../../../../../screens/changelog_screen.dart';
import '../../../../../services/notification_service.dart';
import '../../../../../utils/app_constants.dart';
import '../../../../../utils/app_route.dart';
import '../../../../../widgets/home/home_tip_card.dart';
import '../../../../../widgets/settings_widgets.dart';
import '../onboarding_screen.dart';
import '../settings_dialogs.dart';

class AboutSettingsScreen extends StatelessWidget {
  const AboutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const ExpressiveSliverAppBar(
            titleText: 'About & Guides',
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
                  title: 'Community & Feedback',
                  icon: Icons.favorite_outline_rounded,
                  accentColor: Colors.amber.shade700,
                  children: [
                    SettingsTile(
                      icon: Icons.star_outline_rounded,
                      iconColor: Colors.amber.shade700,
                      iconBackgroundColor: Colors.amber.withValues(alpha: 0.2),
                      title: 'Rate & Feedback',
                      subtitle: 'Love the app? Rate us on the Play Store',
                      trailing: Icon(
                        Icons.open_in_new_rounded,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onTap: () => SettingsDialogs.launchExternalUrl(
                        'https://play.google.com/store/apps/details?id=com.saadhjawwadh.notebook',
                      ),
                    ),
                    SettingsTile(
                      icon: Icons.history_rounded,
                      iconColor: colorScheme.primary,
                      title: 'Changelog',
                      subtitle: 'View version release logs',
                      showArrow: true,
                      onTap: () => AppRoute.push(context, const ChangelogScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: AppLayout.spaceL),
                SettingsSection(
                  title: 'Diagnostics & Onboarding',
                  icon: Icons.handyman_outlined,
                  accentColor: colorScheme.secondary,
                  children: [
                    SettingsTile(
                      icon: Icons.notifications_active_outlined,
                      iconColor: colorScheme.primary,
                      title: 'Test Notifications',
                      subtitle: 'Trigger a sample diagnostic alert immediately',
                      showArrow: true,
                      onTap: () async {
                        AppHaptics.selectionClick();
                        await NotificationService.showTestNotification();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Test notification sent! Check your notification shade.'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                    SettingsTile(
                      icon: Icons.rocket_launch_outlined,
                      iconColor: colorScheme.secondary,
                      title: 'Replay Setup & Intro',
                      subtitle: 'Configure theme, modules, and AI assistant',
                      showArrow: true,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const OnboardingScreen(isReplay: true),
                          ),
                        );
                      },
                    ),
                    SettingsTile(
                      icon: Icons.lightbulb_outline_rounded,
                      iconColor: Colors.amber.shade700,
                      title: 'Tips & Gestural Shortcuts',
                      subtitle: 'Discover pro gestures, shortcuts, and features',
                      showArrow: true,
                      onTap: () => _showTipsSheet(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppLayout.spaceL),
                SettingsSection(
                  title: 'Application Information',
                  icon: Icons.info_outline_rounded,
                  accentColor: colorScheme.onSurfaceVariant,
                  children: [
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) {
                        final version = snapshot.hasData
                            ? 'v${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                            : 'Loading...';
                        return SettingsTile(
                          icon: Icons.info_outline_rounded,
                          iconColor: colorScheme.tertiary,
                          title: 'Version',
                          subtitle: version,
                          showArrow: true,
                          onTap: () => SettingsDialogs.launchExternalUrl(AppConstants.releaseUrl),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppLayout.fabBottomPadding),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showTipsSheet(BuildContext context) {
    AppHaptics.selectionClick();
    final tips = HomeTipCard.getCatalog(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    AppBottomSheet.show(
      context: context,
      title: 'Tips & Gestural Shortcuts',
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: tips.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          itemBuilder: (ctx, index) {
            final tip = tips[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppLayout.radiusM),
                    ),
                    child: Icon(tip.icon, size: 20, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tip.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tip.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                        if (tip.actionLabel != null && tip.onAction != null) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              tip.onAction!();
                            },
                            child: Text(tip.actionLabel!),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
