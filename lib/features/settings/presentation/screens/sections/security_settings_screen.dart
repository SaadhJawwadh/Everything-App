import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../../core/theme/app_layout.dart';
import '../../../../../core/ui/expressive_sliver_app_bar.dart';
import '../../../../../screens/app_lock_screen.dart';
import '../../../../../widgets/settings_widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../providers/settings_provider.dart';
import '../settings_dialogs.dart';

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});

  static Future<bool> _confirmDisableLockAuth(String reason) async {
    final auth = LocalAuthentication();
    try {
      final canCheck = await auth.canCheckBiometrics ||
          await auth.isDeviceSupported();
      if (!canCheck) return true;
      final didAuth = await AppLockScreen.withLockIgnored(
        () => auth.authenticate(
          localizedReason: reason,
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false,
          ),
        ),
      );
      if (didAuth) {
        await AppLockScreen.resetNativeLockFlag();
      }
      return didAuth;
    } on PlatformException catch (e) {
      // Only allow bypass if the device has no enrolled credentials.
      if (e.code == 'NotAvailable' ||
          e.code == 'PasscodeNotSet' ||
          e.code == 'NotEnrolled') {
        return true;
      }
      debugPrint('Auth error disabling lock: $e');
      return false;
    } catch (e) {
      debugPrint('Auth error disabling lock: $e');
      return false;
    }
  }

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
                titleText: l10n?.privacyAndSecurity ?? l10n?.security ?? 'Privacy & Security',
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
                      title: 'App Lock & Biometrics',
                      icon: Icons.security_outlined,
                      accentColor: colorScheme.primary,
                      children: [
                        SettingsSwitchTile(
                          icon: Icons.lock_outline,
                          iconColor: colorScheme.primary,
                          title: 'App Lock',
                          subtitle: l10n?.appLockSubtitle ??
                              'Require authentication to open app. Home screen widgets still display your info.',
                          value: settings.appLockEnabled,
                          onChanged: (enabled) async {
                            if (!enabled) {
                              final ok = await _confirmDisableLockAuth(
                                l10n?.appLockAuthReason ??
                                    'Authenticate to disable App Lock',
                              );
                              if (!ok) return;
                            } else {
                              // Mark current session authenticated so enabling App Lock
                              // never immediately locks the user out of Settings.
                              AppLockScreen.unlockSession();
                            }
                            await settings.setAppLockEnabled(enabled);
                          },
                        ),
                        AnimatedSize(
                          duration: AppLayout.shouldReduceMotion(context)
                              ? Duration.zero
                              : AppLayout.animShort,
                          curve: AppLayout.curveStrongEaseOut,
                          child: settings.appLockEnabled
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SettingsSwitchTile(
                                      icon: Icons.fingerprint_outlined,
                                      iconColor: colorScheme.secondary,
                                      title: 'Use Biometrics',
                                      subtitle: 'Require biometric scan specifically',
                                      value: settings.useBiometrics,
                                      onChanged: settings.setUseBiometrics,
                                    ),
                                    SettingsTile(
                                      icon: Icons.timer_outlined,
                                      iconColor: colorScheme.tertiary,
                                      title: 'Auto-Lock Timeout',
                                      subtitle: 'Inactivity delay before locking',
                                      valueBadge: SettingsDialogs.getTimeoutLabel(context, settings.appLockTimeout),
                                      showArrow: true,
                                      onTap: () => SettingsDialogs.showTimeoutPicker(context, settings),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppLayout.spaceL),
                    SettingsSection(
                      title: l10n?.perModulePrivacyLocks ?? 'Module Locks & Screen Protection',
                      icon: Icons.shield_outlined,
                      accentColor: colorScheme.secondary,
                      children: [
                        if (settings.showFinancialManager)
                          SettingsSwitchTile(
                            icon: Icons.account_balance_wallet_outlined,
                            iconColor: colorScheme.primary,
                            title: l10n?.lockFinances ?? 'Lock Finances Tab',
                            subtitle: settings.appLockEnabled
                                ? 'Covered while full App Lock is active'
                                : (l10n?.lockFinancesSubtitle ??
                                    'Require authentication to open Finances. Finance widgets still display summaries.'),
                            value: settings.lockFinances,
                            onChanged: (enabled) async {
                              if (!enabled && !settings.appLockEnabled) {
                                final ok = await _confirmDisableLockAuth(
                                  l10n?.appLockAuthReason ??
                                      'Authenticate to unlock Finances protection',
                                );
                                if (!ok) return;
                              }
                              await settings.setLockFinances(enabled);
                            },
                          ),
                        if (settings.isPeriodTrackerEnabled)
                          SettingsSwitchTile(
                            icon: Icons.favorite_border_rounded,
                            iconColor: colorScheme.tertiary,
                            title: l10n?.lockHealth ?? 'Lock Health Tab',
                            subtitle: settings.appLockEnabled
                                ? 'Covered while full App Lock is active'
                                : (l10n?.lockHealthSubtitle ?? 'Require authentication to open Health'),
                            value: settings.lockHealth,
                            onChanged: (enabled) async {
                              if (!enabled && !settings.appLockEnabled) {
                                final ok = await _confirmDisableLockAuth(
                                  l10n?.appLockAuthReason ??
                                      'Authenticate to unlock Health protection',
                                );
                                if (!ok) return;
                              }
                              await settings.setLockHealth(enabled);
                            },
                          ),
                        if (!kIsWeb && Platform.isAndroid)
                          SettingsSwitchTile(
                            icon: Icons.no_photography_outlined,
                            iconColor: colorScheme.error,
                            title: l10n?.screenshotShield ?? 'Screenshot Shield',
                            subtitle: l10n?.screenshotShieldSubtitle ?? 'Block screenshots and screen recording on Android',
                            value: settings.screenshotShieldEnabled,
                            onChanged: settings.setScreenshotShieldEnabled,
                          ),
                        if (settings.appLockEnabled || settings.hasAnyModuleLockEnabled)
                          SettingsTile(
                            icon: Icons.lock_reset_rounded,
                            iconColor: colorScheme.primary,
                            title: l10n?.lockAppNow ?? 'Lock App Now',
                            subtitle: 'Immediately clear unlocked session state',
                            showArrow: true,
                            onTap: () {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                              AppLockScreen.lockNow();
                            },
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
