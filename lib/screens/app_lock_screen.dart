import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import '../core/ui/app_card.dart';

class AppLockScreen extends StatefulWidget {
  final Widget child;

  const AppLockScreen({super.key, required this.child});

  static final ValueNotifier<bool> sessionAuthenticated = ValueNotifier<bool>(false);
  static bool _ignoreNextResumeLock = false;
  static int _ignoreLockCount = 0;

  /// Media shared into the app that hasn't been turned into a note yet —
  /// either because it arrived while locked, or because it arrived at cold
  /// start before HomeScreen mounted. Consumed by HomeScreen.
  static List<SharedMediaFile>? pendingSharedMedia;

  /// Bumped whenever [pendingSharedMedia] is (re)filled so HomeScreen can
  /// consume it immediately instead of waiting for the next resume.
  static final ValueNotifier<int> sharedMediaTick = ValueNotifier<int>(0);

  // Static helper to manually unlock the session (useful for sharing)
  static void unlockSession() {
    sessionAuthenticated.value = true;
  }

  // Static helper to ignore the next lock check when resuming
  static void ignoreNextResumeLock() {
    _ignoreNextResumeLock = true;
  }

  /// Whether external activities or operations are currently active and app lock should be ignored
  static bool get isLockIgnored => _ignoreLockCount > 0 || _ignoreNextResumeLock;

  /// Run an asynchronous action (such as camera capture, file picker, or system share)
  /// while completely ignoring app lock lifecycle checks until completion.
  static Future<T> withLockIgnored<T>(Future<T> Function() action) async {
    _ignoreLockCount++;
    _ignoreNextResumeLock = true;
    try {
      return await action();
    } finally {
      // Allow a brief post-return grace period for the Activity resume lifecycle to settle
      await Future.delayed(const Duration(milliseconds: 300));
      _ignoreLockCount = (_ignoreLockCount - 1).clamp(0, 999);
      if (_ignoreLockCount == 0) {
        _ignoreNextResumeLock = false;
      }
    }
  }

  @override
  AppLockScreenState createState() => AppLockScreenState();
}

class AppLockScreenState extends State<AppLockScreen>
    with WidgetsBindingObserver {
  final LocalAuthentication auth = LocalAuthentication();
  
  bool _isInBackground = false;
  bool _isAuthenticating = false;
  DateTime? _backgroundTime;
  StreamSubscription? _intentDataStreamSubscription;
  String? _authErrorMessage;
  bool _canDisableLockFallback = false;

  bool get _isSessionAuthenticated => AppLockScreen.sessionAuthenticated.value;
  set _isSessionAuthenticated(bool val) => AppLockScreen.sessionAuthenticated.value = val;

  static const MethodChannel _channel = MethodChannel('com.saadhjawwadh.notebook/device_lock');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLockScreen.sessionAuthenticated.addListener(_onAuthChanged);

    // Park shares that arrive while the lock screen is covering the app;
    // HomeScreen isn't mounted then, so its own listener can't see them.
    _intentDataStreamSubscription =
        ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      if (files.isEmpty || !mounted) return;
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final isLocked =
          settings.appLockEnabled && !AppLockScreen.sessionAuthenticated.value;
      if (isLocked) {
        AppLockScreen.pendingSharedMedia = files;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Cold-start shares are read here (single source of truth) and handed
      // to HomeScreen via pendingSharedMedia + sharedMediaTick.
      try {
        final media = await ReceiveSharingIntent.instance.getInitialMedia();
        if (media.isNotEmpty) {
          AppLockScreen.pendingSharedMedia = media;
          AppLockScreen.sharedMediaTick.value++;
        }
        unawaited(ReceiveSharingIntent.instance.reset());
      } catch (e) {
        debugPrint('Error checking initial shared media: $e');
      }
      if (mounted) {
        await _checkAuth(context);
      }
    });
  }

  void _onAuthChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    unawaited(_intentDataStreamSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    AppLockScreen.sessionAuthenticated.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isAuthenticating) {
      // Ignore lifecycle changes caused by the biometric authentication dialog itself
      // (its system UI briefly backgrounds the app on some platforms/OEM skins).
      return;
    }

    final isBackground = state != AppLifecycleState.resumed;
    if (mounted) {
      setState(() {
        _isInBackground = isBackground;
      });
    }

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final shouldIgnoreLock = AppLockScreen._ignoreNextResumeLock || AppLockScreen._ignoreLockCount > 0;

    if (isBackground) {
      if (!shouldIgnoreLock) {
        // Record when the app went to the background
        _backgroundTime ??= DateTime.now();
        // Only lock immediately on true background (paused), NOT on inactive
        // (notification shade, permission dialogs, split-screen transitions).
        if (settings.appLockTimeout == 0 && state == AppLifecycleState.paused) {
          _isSessionAuthenticated = false;
        }
      }
    } else {
      // App is resuming
      if (shouldIgnoreLock) {
        _isSessionAuthenticated = true;
        if (AppLockScreen._ignoreLockCount == 0) {
          AppLockScreen._ignoreNextResumeLock = false;
        }
      } else if (_backgroundTime != null) {
        final elapsed = DateTime.now().difference(_backgroundTime!).inSeconds;
        if (elapsed >= settings.appLockTimeout) {
          _isSessionAuthenticated = false;
        }
      }
      _backgroundTime = null;
    }

    if (state == AppLifecycleState.resumed && !shouldIgnoreLock) {
      unawaited(_checkAuthOnResume());
    }
  }

  Future<void> _checkAuthOnResume() async {
    // Wait 150ms to allow incoming sharing intents to fire and call unlockSession()
    await Future.delayed(const Duration(milliseconds: 150));

    if (!_isSessionAuthenticated) {
      if (mounted) {
        await _checkAuth(context);
      }
    }
  }

  Future<void> _checkAuth(BuildContext context) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    
    // Bypass if lock is disabled or already authenticated in this session
    if (!settings.appLockEnabled || _isSessionAuthenticated) {
      if (mounted) {
        setState(() {
          _isSessionAuthenticated = true;
        });
      }
      return;
    }

    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
    });

    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to access the app',
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: settings.useBiometrics,
        ),
      );

      if (didAuthenticate) {
        if (!kIsWeb && Platform.isAndroid) {
          try {
            await _channel.invokeMethod('resetLockFlag');
          } catch (e) {
            debugPrint('Error invoking resetLockFlag: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _isSessionAuthenticated = didAuthenticate;
          if (didAuthenticate) {
            _authErrorMessage = null;
            _canDisableLockFallback = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Authentication error: $e');
      if (mounted) {
        setState(() {
          if (e is PlatformException &&
              (e.code == 'NotAvailable' ||
                  e.code == 'PasscodeNotSet' ||
                  e.code == 'NotEnrolled')) {
            _authErrorMessage =
                'No screen lock or biometric credentials enrolled on this device.';
            _canDisableLockFallback = true;
          } else {
            _authErrorMessage = 'Authentication failed. Please try again.';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    if (!settings.appLockEnabled) {
      return widget.child;
    }

    if (!_isSessionAuthenticated) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final lockOverlay = Positioned.fill(
        child: Container(
          color: (isDark ? Colors.black : Theme.of(context).colorScheme.surface),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: AppCard.frosted(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(32),
                borderRadius: 28,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 600),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Opacity(
                                opacity: value,
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.7),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.lock_outline,
                              size: 56,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'App Locked',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Authentication required to access content',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        if (_authErrorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.error),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _authErrorMessage!,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onErrorContainer,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (!_isInBackground) ...[
                          FilledButton.icon(
                            onPressed: () => _checkAuth(context),
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Unlock'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(160, 48),
                              shape: const StadiumBorder(),
                            ),
                          ),
                          if (_canDisableLockFallback) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () async {
                                final s = Provider.of<SettingsProvider>(context, listen: false);
                                await s.setAppLockEnabled(false);
                                AppLockScreen.unlockSession();
                              },
                              icon: const Icon(Icons.lock_open_rounded, size: 18),
                              label: const Text('Disable App Lock'),
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );

      return Stack(
        children: [
          ExcludeSemantics(
            excluding: true,
            child: IgnorePointer(
              ignoring: true,
              child: widget.child,
            ),
          ),
          lockOverlay,
        ],
      );
    }

    return widget.child;
  }
}
