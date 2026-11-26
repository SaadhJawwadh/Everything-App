import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../features/settings/providers/settings_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../screens/app_lock_screen.dart';
import '../services/app_haptics.dart';
import '../theme/app_layout.dart';
import 'app_card.dart';

/// Session-scoped privacy gate for individual modules (e.g. Finances, Health)
/// when full App Lock is disabled. Prompts only when [isActive] is true so
/// `IndexedStack` never triggers startup biometric storms.
class ModuleLockGate extends StatefulWidget {
  final String moduleKey;
  final String moduleTitle;
  final bool isLockedSettingEnabled;
  final bool isActive;
  final Widget child;

  const ModuleLockGate({
    super.key,
    required this.moduleKey,
    required this.moduleTitle,
    required this.isLockedSettingEnabled,
    required this.isActive,
    required this.child,
  });

  static bool isModuleCurrentlyLocked(SettingsProvider settings, String moduleKey) {
    if (settings.appLockEnabled) return false;
    final enabled = switch (moduleKey) {
      'finances' => settings.lockFinances,
      'health' => settings.lockHealth,
      _ => false,
    };
    if (!enabled) return false;
    return !AppLockScreen.unlockedModules.contains(moduleKey);
  }

  @override
  State<ModuleLockGate> createState() => _ModuleLockGateState();
}

class _ModuleLockGateState extends State<ModuleLockGate> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticating = false;
  bool _promptedForEpoch = false;

  @override
  void initState() {
    super.initState();
    AppLockScreen.moduleSessionEpoch.addListener(_onEpochChanged);
    _maybeAutoPrompt();
  }

  @override
  void didUpdateWidget(covariant ModuleLockGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _maybeAutoPrompt();
    }
  }

  @override
  void dispose() {
    AppLockScreen.moduleSessionEpoch.removeListener(_onEpochChanged);
    super.dispose();
  }

  void _onEpochChanged() {
    _promptedForEpoch = false;
    if (mounted) {
      setState(() {});
      _maybeAutoPrompt();
    }
  }

  void _maybeAutoPrompt() {
    if (!widget.isActive || _promptedForEpoch || _isAuthenticating) return;
    if (!widget.isLockedSettingEnabled) return;
    if (AppLockScreen.unlockedModules.contains(widget.moduleKey)) return;
    if (AppLockScreen.isLockIgnored || AppLockScreen.isInTrueBackground) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive || _promptedForEpoch || _isAuthenticating) {
        return;
      }
      if (AppLockScreen.isLockIgnored || AppLockScreen.isInTrueBackground) {
        return;
      }
      if (ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      final settings = context.read<SettingsProvider>();
      if (!settings.isInitialized || settings.appLockEnabled) return;
      _promptedForEpoch = true;
      unawaited(_authenticate(settings));
    });
  }

  Future<void> _authenticate(SettingsProvider settings) async {
    if (_isAuthenticating) return;
    final reason = AppLocalizations.of(context)?.appLockAuthReason ??
        'Authenticate to unlock ${widget.moduleTitle}';
    setState(() => _isAuthenticating = true);
    try {
      final didAuth = await AppLockScreen.withLockIgnored<bool>(() async {
        bool useBiometricOnly = settings.useBiometrics;
        if (useBiometricOnly) {
          final canCheck = await _auth.canCheckBiometrics;
          final available =
              canCheck ? await _auth.getAvailableBiometrics() : <BiometricType>[];
          if (available.isEmpty) {
            useBiometricOnly = false;
          }
        }

        try {
          return await _auth.authenticate(
            localizedReason: reason,
            options: AuthenticationOptions(
              stickyAuth: true,
              biometricOnly: useBiometricOnly,
            ),
          );
        } on PlatformException catch (e) {
          if (useBiometricOnly &&
              (e.code == 'NotEnrolled' ||
                  e.code == 'LockedOut' ||
                  e.code == 'PermanentlyLockedOut' ||
                  e.code == 'NotAvailable')) {
            return await _auth.authenticate(
              localizedReason: reason,
              options: const AuthenticationOptions(
                stickyAuth: true,
                biometricOnly: false,
              ),
            );
          }
          rethrow;
        }
      });

      if (didAuth) {
        await AppLockScreen.resetNativeLockFlag();
      }

      if (didAuth && mounted) {
        AppHaptics.mediumImpact();
        AppLockScreen.unlockedModules.add(widget.moduleKey);
        AppLockScreen.moduleSessionEpoch.value++;
        setState(() {});
      }
    } on PlatformException catch (e) {
      debugPrint('[ModuleLockGate] Auth error for ${widget.moduleKey}: $e');
      if (mounted &&
          (e.code == 'NotAvailable' ||
              e.code == 'PasscodeNotSet' ||
              e.code == 'NotEnrolled')) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.appLockNoCredentials ??
                  'No screen lock or biometric credentials enrolled on this device.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ModuleLockGate] Auth error for ${widget.moduleKey}: $e');
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isUnlocked = !widget.isLockedSettingEnabled ||
        settings.appLockEnabled ||
        AppLockScreen.unlockedModules.contains(widget.moduleKey);

    if (isUnlocked) {
      return widget.child;
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppLayout.spaceXXL),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: AppCard(
              padding: const EdgeInsets.all(AppLayout.spaceXXL),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppLayout.spaceL),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 36,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppLayout.spaceL),
                  Text(
                    '${widget.moduleTitle} Locked',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppLayout.spaceS),
                  Text(
                    l10n?.appLockAuthReason ?? 'Authenticate to view this private section.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppLayout.spaceXL),
                  FilledButton.icon(
                    onPressed: _isAuthenticating ? null : () => _authenticate(settings),
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: Text('Unlock ${widget.moduleTitle}'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
