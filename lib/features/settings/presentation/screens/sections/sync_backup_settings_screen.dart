import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../../../../../core/services/app_haptics.dart';
import '../../../../../core/theme/app_layout.dart';
import '../../../../../core/ui/app_bottom_sheet.dart';
import '../../../../../core/ui/expressive_sliver_app_bar.dart';
import '../../../../../services/backup_service.dart';
import '../../../../../services/backup_vault_key_service.dart';
import '../../../../../utils/app_route.dart';
import '../../../../../widgets/settings_widgets.dart';
import '../../../../sync/presentation/screens/p2p_sync_screen.dart';
import '../../../../../l10n/app_localizations.dart';
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
          final l10n = AppLocalizations.of(context);
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              ExpressiveSliverAppBar(
                titleText: l10n?.syncAndBackups ?? l10n?.backupRestore ?? 'Data, Sync & Backups',
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
                      title: l10n?.peerToPeerSync ?? 'Peer-to-Peer Sync',
                      icon: Icons.devices_rounded,
                      accentColor: const Color(0xFF0EA5E9),
                      children: [
                        SettingsTile(
                          icon: Icons.devices_rounded,
                          iconColor: const Color(0xFF0EA5E9),
                          title: l10n?.p2pDeviceSync ?? 'P2P Device Sync',
                          subtitle: l10n?.p2pDeviceSyncSubtitle ?? 'Zero-cloud Wi-Fi sync for notes and financial records',
                          showArrow: true,
                          onTap: () => AppRoute.push(context, const P2pSyncScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppLayout.spaceL),
                    SettingsSection(
                      title: l10n?.encryptedJsonBackups ?? 'Encrypted JSON Backups',
                      icon: Icons.shield_outlined,
                      accentColor: colorScheme.primary,
                      children: [
                        SettingsTile(
                          icon: Icons.download_outlined,
                          iconColor: colorScheme.primary,
                          title: l10n?.exportBackup ?? 'Export Backup',
                          subtitle: l10n?.exportBackupSubtitle ?? 'Save notes and ledgers to an encrypted file',
                          showArrow: true,
                          onTap: () => BackupService.exportBackup(context),
                        ),
                        SettingsTile(
                          icon: Icons.upload_outlined,
                          iconColor: colorScheme.secondary,
                          title: l10n?.importBackup ?? 'Import Backup',
                          subtitle: l10n?.importBackupSubtitle ?? 'Restore from an encrypted JSON backup file',
                          showArrow: true,
                          onTap: () => BackupService.importBackup(context),
                        ),
                        SettingsTile(
                          icon: Icons.restore_rounded,
                          iconColor: colorScheme.tertiary,
                          title: l10n?.snapshotsAndRecovery ?? 'Snapshots & Recovery',
                          subtitle: l10n?.snapshotsAndRecoverySubtitle ?? 'Inspect or restore rolling pre-migration & pre-sync snapshots',
                          showArrow: true,
                          onTap: () => SettingsDialogs.showDatabaseSnapshotsSheet(context),
                        ),
                      ],
                    ),
                    if (!kIsWeb && Platform.isAndroid) ...[
                      const SizedBox(height: AppLayout.spaceL),
                      SettingsSection(
                        title: l10n?.automatedBackgroundBackups ?? 'Automated Background Backups',
                        icon: Icons.cloud_sync_outlined,
                        accentColor: const Color(0xFF0EA5E9),
                        children: [
                          SettingsSwitchTile(
                            icon: Icons.cloud_sync_outlined,
                            iconColor: const Color(0xFF0EA5E9),
                            title: l10n?.automaticBackups ?? 'Automatic Backups',
                            subtitle: l10n?.automaticBackupsSubtitle ?? 'Schedule regular encrypted local backups',
                            value: settings.autoBackupEnabled,
                            onChanged: (value) async {
                              await settings.setAutoBackupEnabled(value);
                              await syncAutoBackupSchedule();
                            },
                          ),
                          AnimatedSize(
                            duration: AppLayout.animModal,
                            curve: AppLayout.curveEmphasizedDecelerate,
                            child: settings.autoBackupEnabled
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SettingsTile(
                                        icon: Icons.schedule_outlined,
                                        iconColor: colorScheme.primary,
                                        title: l10n?.backupFrequency ?? 'Backup Frequency',
                                        subtitle: l10n?.backupFrequencySubtitle ?? 'Frequency of automated backup tasks',
                                        valueBadge: SettingsDialogs.getFrequencyLabel(settings.autoBackupFrequency),
                                        showArrow: true,
                                        onTap: () => SettingsDialogs.showFrequencyPicker(context, settings),
                                      ),
                                      SettingsTile(
                                        icon: Icons.folder_outlined,
                                        iconColor: colorScheme.secondary,
                                        title: l10n?.backupLocation ?? 'Backup Location',
                                        subtitle: settings.autoBackupPath ?? (l10n?.secureAppStorage ?? 'Secure App Storage (Resilient)'),
                                        showArrow: true,
                                        onTap: () => SettingsDialogs.showBackupLocationPicker(context, settings),
                                      ),
                                      if (settings.lastAutoBackupTime != null)
                                        SettingsTile(
                                          icon: Icons.history_outlined,
                                          iconColor: colorScheme.tertiary,
                                          title: l10n?.lastAutoBackup ?? 'Last Auto Backup',
                                          subtitle: l10n?.lastAutoBackupSubtitle ?? 'Most recent successful backup',
                                          valueBadge: SettingsDialogs.formatLastBackupTime(context, settings.lastAutoBackupTime!),
                                        ),
                                      SettingsTile(
                                        icon: Icons.play_arrow_rounded,
                                        iconColor: colorScheme.primary,
                                        title: l10n?.runAutoBackupNow ?? 'Run Auto-Backup Now',
                                        subtitle: l10n?.runAutoBackupNowSubtitle ?? 'Trigger and verify background auto-backup immediately',
                                        showArrow: true,
                                        onTap: () async {
                                          AppHaptics.selectionClick();
                                          if (context.mounted) {
                                            await BackupService.performAutoBackupNow(context);
                                          }
                                        },
                                      ),
                                      SettingsTile(
                                        icon: Icons.vpn_key_outlined,
                                        iconColor: colorScheme.secondary,
                                        title: l10n?.autoBackupRecoveryKey ?? 'Auto-Backup Recovery Key',
                                        subtitle: l10n?.autoBackupRecoveryKeySubtitle ?? 'Copy or import key to restore encrypted auto-backups',
                                        showArrow: true,
                                        onTap: () => _showRecoveryKeySheet(context),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
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

  Future<void> _showRecoveryKeySheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final auth = LocalAuthentication();
    try {
      final canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (canCheck) {
        final didAuth = await auth.authenticate(
          localizedReason: l10n?.appLockAuthReason ?? 'Authenticate to access your Auto-Backup Recovery Key',
          options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
        );
        if (!didAuth) return;
      }
    } catch (_) {}

    final currentKey = await BackupVaultKeyService.instance.getOrCreateVaultKey();
    if (!context.mounted) return;
    final importController = TextEditingController();

    await AppBottomSheet.show(
      context: context,
      title: l10n?.autoBackupRecoveryKey ?? 'Auto-Backup Recovery Key',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Save this key securely outside this phone to decrypt automated backups if you switch or wipe devices.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppLayout.spaceM),
          if (currentKey != null) ...[
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: currentKey));
                AppHaptics.mediumImpact();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Recovery key copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy Recovery Key'),
            ),
            const SizedBox(height: AppLayout.spaceL),
          ],
          TextField(
            controller: importController,
            decoration: InputDecoration(
              labelText: 'Import Recovery Key (New Device)',
              hintText: 'Paste saved key...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
              ),
            ),
          ),
          const SizedBox(height: AppLayout.spaceM),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await BackupVaultKeyService.instance.importVaultKey(importController.text);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Recovery key imported' : 'Invalid recovery key (must be at least 16 characters)'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.key_rounded),
            label: const Text('Import Key'),
          ),
        ],
      ),
    );
    importController.dispose();
  }
}
