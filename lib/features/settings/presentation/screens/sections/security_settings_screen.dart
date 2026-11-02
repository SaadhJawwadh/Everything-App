import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../../core/theme/app_layout.dart';
import '../../../../../core/ui/expressive_sliver_app_bar.dart';
import '../../../../../widgets/settings_widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../providers/settings_provider.dart';
import '../settings_dialogs.dart';

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});

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
                          subtitle: 'Require authentication to open app',
                          value: settings.appLockEnabled,
                          onChanged: (enabled) async {
                            if (!enabled) {
                              final auth = LocalAuthentication();
                              try {
                                final canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
                                if (canCheck) {
                                  final didAuth = await auth.authenticate(
                                    localizedReason: l10n?.appLockAuthReason ?? 'Authenticate to disable App Lock',
                                    options: const AuthenticationOptions(
                                      stickyAuth: true,
                                      biometricOnly: false,
                                    ),
                                  );
                                  if (!didAuth) return;
                                }
                              } catch (e) {
                                debugPrint('Auth error disabling app lock: $e');
                              }
                            }
                            await settings.setAppLockEnabled(enabled);
                          },
                        ),
                        AnimatedSize(
                          duration: AppLayout.animModal,
                          curve: AppLayout.curveEmphasizedDecelerate,
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
