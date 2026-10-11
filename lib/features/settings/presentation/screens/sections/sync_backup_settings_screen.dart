import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/services/app_haptics.dart';
import '../../../../../core/theme/app_layout.dart';
import '../../../../../core/ui/expressive_sliver_app_bar.dart';
import '../../../../../services/backup_service.dart';
import '../../../../../utils/app_route.dart';
import '../../../../../widgets/settings_widgets.dart';
import '../../../../sync/presentation/screens/p2p_sync_screen.dart';
import '../../../providers/settings_provider.dart';
import '../settings_dialogs.dart';

class SyncBackupSettingsScreen extends StatelessWidget {
  const SyncBackupSettingsScreen({super.key});

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
                titleText: 'Data, Sync & Backups',
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
                      title: 'Peer-to-Peer Sync',
                      icon: Icons.devices_rounded,
                      accentColor: const Color(0xFF0EA5E9),
                      children: [
                        SettingsTile(
                          icon: Icons.devices_rounded,
                          iconColor: const Color(0xFF0EA5E9),
                          title: 'P2P Device Sync',
                          subtitle: 'Zero-cloud Wi-Fi sync for notes and financial records',
                          showArrow: true,
                          onTap: () => AppRoute.push(context, const P2pSyncScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppLayout.spaceL),
                    SettingsSection(
                      title: 'Encrypted JSON Backups',
                      icon: Icons.shield_outlined,
                      accentColor: colorScheme.primary,
                      children: [
                        SettingsTile(
                          icon: Icons.download_outlined,
                          iconColor: colorScheme.primary,
                          title: 'Export Backup',
                          subtitle: 'Save notes and ledgers to an encrypted file',
                          showArrow: true,
                          onTap: () => BackupService.exportBackup(context),
                        ),
                        SettingsTile(
                          icon: Icons.upload_outlined,
                          iconColor: colorScheme.secondary,
                          title: 'Import Backup',
                          subtitle: 'Restore from an encrypted JSON backup file',
                          showArrow: true,
                          onTap: () => BackupService.importBackup(context),
                        ),
                      ],
                    ),
                    if (!kIsWeb && Platform.isAndroid) ...[
                      const SizedBox(height: AppLayout.spaceL),
                      SettingsSection(
                        title: 'Automated Background Backups',
                        icon: Icons.cloud_sync_outlined,
                        accentColor: const Color(0xFF0EA5E9),
                        children: [
                          SettingsSwitchTile(
                            icon: Icons.cloud_sync_outlined,
                            iconColor: const Color(0xFF0EA5E9),
                            title: 'Automatic Backups',
                            subtitle: 'Schedule regular encrypted local backups',
                            value: settings.autoBackupEnabled,
                            onChanged: (value) async {
                              await settings.setAutoBackupEnabled(value);
                              await syncAutoBackupSchedule();
                            },
                          ),
                          if (settings.autoBackupEnabled) ...[
                            SettingsTile(
                              icon: Icons.schedule_outlined,
                              iconColor: colorScheme.primary,
                              title: 'Backup Frequency',
                              subtitle: 'Frequency of automated backup tasks',
                              valueBadge: SettingsDialogs.getFrequencyLabel(settings.autoBackupFrequency),
                              showArrow: true,
                              onTap: () => SettingsDialogs.showFrequencyPicker(context, settings),
                            ),
                            SettingsTile(
                              icon: Icons.folder_outlined,
                              iconColor: colorScheme.secondary,
                              title: 'Backup Location',
                              subtitle: settings.autoBackupPath ?? 'Secure App Storage (Resilient)',
                              showArrow: true,
                              onTap: () => SettingsDialogs.showBackupLocationPicker(context, settings),
                            ),
                            if (settings.lastAutoBackupTime != null)
                              SettingsTile(
                                icon: Icons.history_outlined,
                                iconColor: colorScheme.tertiary,
                                title: 'Last Auto Backup',
                                subtitle: 'Most recent successful backup',
                                valueBadge: SettingsDialogs.formatLastBackupTime(settings.lastAutoBackupTime!),
                              ),
                            SettingsTile(
                              icon: Icons.play_arrow_rounded,
                              iconColor: colorScheme.primary,
                              title: 'Run Auto-Backup Now',
                              subtitle: 'Trigger and verify background auto-backup immediately',
                              showArrow: true,
                              onTap: () async {
                                AppHaptics.selectionClick();
                                if (context.mounted) {
                                  await BackupService.performAutoBackupNow(context);
                                }
                              },
                            ),
                          ],
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
