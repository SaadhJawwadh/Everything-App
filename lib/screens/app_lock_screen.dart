import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import '../core/theme/app_layout.dart';
import '../l10n/app_localizations.dart';

class AppLockScreen extends StatefulWidget {
  final Widget child;

  const AppLockScreen({super.key, required this.child});

  static final ValueNotifier<bool> sessionAuthenticated = ValueNotifier<bool>(false);
  static final ValueNotifier<int> moduleSessionEpoch = ValueNotifier<int>(0);
  static final Set<String> unlockedModules = <String>{};
  static bool _ignoreNextResumeLock = false;
  static DateTime? _ignoreNextResumeLockTimestamp;
  static DateTime? _ignoreLockGraceUntil;
  static bool _backgroundedDuringLockIgnore = false;
  static int _ignoreLockCount = 0;
  static bool _isInTrueBackground = false;
  static Completer<void>? _resumeLockCheckCompleter;

  /// True while the app has entered true background (`hidden` / `paused`) and
  /// has not yet completed its resume lock evaluation.
  static bool get isInTrueBackground => _isInTrueBackground;

  /// Resolves once any in-flight resume lock check (including native Android
  /// screen-off / keyguard verification) has finished.
  static Future<void> waitForResumeLockCheck() =>
      _resumeLockCheckCompleter?.future ?? Future.value();

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

  /// Immediately locks both the app and all per-module session unlocks.
  static void lockNow() {
    sessionAuthenticated.value = false;
    unlockedModules.clear();
    moduleSessionEpoch.value++;
  }

  static void invalidateModuleSessions() {
    if (unlockedModules.isNotEmpty) {
      unlockedModules.clear();
      moduleSessionEpoch.value++;
    }
  }

  /// Whether the single-resume bypass is still valid (expires after 60 seconds)
  static bool get isIgnoreNextResumeLockValid {
    if (!_ignoreNextResumeLock) return false;
    if (_ignoreNextResumeLockTimestamp != null &&
        DateTime.now().difference(_ignoreNextResumeLockTimestamp!) > const Duration(seconds: 60)) {
      _ignoreNextResumeLock = false;
      _ignoreNextResumeLockTimestamp = null;
      return false;
    }
    return true;
  }

  // Static helper to ignore the next lock check when resuming
  static void ignoreNextResumeLock() {
    _ignoreNextResumeLock = true;
    _ignoreNextResumeLockTimestamp = DateTime.now();
  }

  static void clearIgnoreNextResumeLock() {
    _ignoreNextResumeLock = false;
    _ignoreNextResumeLockTimestamp = null;
    if (_ignoreLockCount == 0) {
      _ignoreLockGraceUntil = null;
      _backgroundedDuringLockIgnore = false;
    }
  }

  static bool get _isInLockIgnoreGrace {
    final until = _ignoreLockGraceUntil;
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _ignoreLockGraceUntil = null;
      _backgroundedDuringLockIgnore = false;
      return false;
    }
    return true;
  }

  /// Whether external activities or operations are currently active and app lock should be ignored
  static bool get isLockIgnored =>
      _ignoreLockCount > 0 || _isInLockIgnoreGrace || isIgnoreNextResumeLockValid;

  static const MethodChannel _deviceLockChannel =
      MethodChannel('com.saadhjawwadh.notebook/device_lock');

  /// Clears any pending native Android screen-off lock latch after a fresh
  /// successful device authentication (App Lock, Module Lock, or Security settings).
  static Future<void> resetNativeLockFlag() async {
    if (kIsWeb ||
        !Platform.isAndroid ||
        Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    try {
      await _deviceLockChannel.invokeMethod('resetLockFlag');
    } catch (e) {
      debugPrint('Error invoking resetLockFlag: $e');
    }
  }

  /// Run an asynchronous action (such as camera capture, file picker, or system share)
  /// while completely ignoring app lock lifecycle checks until completion.
  static Future<T> withLockIgnored<T>(Future<T> Function() action) async {
    _ignoreLockCount++;
    ignoreNextResumeLock();
    try {
      return await action();
    } finally {
      _ignoreLockCount = (_ignoreLockCount - 1).clamp(0, 999);
      if (_ignoreLockCount == 0) {
        // Only hold a brief settle window if the external activity actually
        // backgrounded MainActivity and `resumed` has not yet arrived (so
        // trailing `hidden -> inactive -> resumed` after `onActivityResult`
        // settles without adding UI latency).
        if (_backgroundedDuringLockIgnore) {
          _ignoreLockGraceUntil =
              DateTime.now().add(const Duration(milliseconds: 800));
          _backgroundedDuringLockIgnore = false;
        } else {
          _ignoreLockGraceUntil = null;
        }
        _ignoreNextResumeLock = false;
        _ignoreNextResumeLockTimestamp = null;
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
  // True only once the app is truly backgrounded (paused/hidden). Drives a blank
  // cover so content doesn't leak into the Recents thumbnail on Android < 13.
  // Deliberately NOT set on `inactive` so the notification shade never flashes it.
  bool _showPrivacyCover = false;
  bool? _lastRecentsHide;
  bool _isAuthenticating = false;
  // Prevents infinite biometric re-prompt loops when the user dismisses/cancels
  // the system prompt (which emits a trailing `resumed` lifecycle event).
  bool _userDismissedPromptInCurrentForeground = false;
  DateTime? _postAuthSettleUntil;
  bool _wasPaused = false;
  bool _wasObscuringChild = false;
  int _resumeCheckGeneration = 0;
  // Monotonic timer for the auto-lock grace period — immune to wall-clock skew / tampering.
  Stopwatch? _backgroundStopwatch;
  StreamSubscription? _intentDataStreamSubscription;
  String? _authErrorMessage;
  bool _canDisableLockFallback = false;
  bool _wasAuthenticatedBeforePause = false;
  bool _capturedPrePauseAuth = false;
  bool? _lastFlagSecure;

  bool get _isInPostAuthSettle {
    final until = _postAuthSettleUntil;
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _postAuthSettleUntil = null;
      return false;
    }
    return true;
  }

  bool get _isSessionAuthenticated => AppLockScreen.sessionAuthenticated.value;
  set _isSessionAuthenticated(bool val) => AppLockScreen.sessionAuthenticated.value = val;

  static const MethodChannel _channel = MethodChannel('com.saadhjawwadh.notebook/device_lock');

  @override
  void initState() {
    super.initState();
    AppLockScreen._isInTrueBackground = false;
    WidgetsBinding.instance.addObserver(this);
    AppLockScreen.sessionAuthenticated.addListener(_onAuthChanged);

    // Park shares that arrive while the lock screen is covering the app;
    // HomeScreen isn't mounted then, so its own listener can't see them.
    _intentDataStreamSubscription =
        ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      if (files.isEmpty || !mounted) return;
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final isLocked =
          (!settings.isInitialized || settings.appLockEnabled) &&
          !AppLockScreen.sessionAuthenticated.value;
      if (isLocked) {
        AppLockScreen.pendingSharedMedia = files;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Cold-start shares are read here (single source of truth) and handed
      // to HomeScreen via pendingSharedMedia + sharedMediaTick. Run unawaited
      // so slow or unavailable platform share channels never delay/block App Lock.
      unawaited(() async {
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
      }());
      if (!mounted) return;
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (!settings.isInitialized) {
        await settings.initialized;
      }
      if (mounted) {
        await _checkAuth(context, isManual: false);
      }
    });
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (_isSessionAuthenticated) {
      _authErrorMessage = null;
      _canDisableLockFallback = false;
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    setState(() {});
  }

  @override
  void dispose() {
    unawaited(_intentDataStreamSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    AppLockScreen.sessionAuthenticated.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    if (!mounted) return super.didPopRoute();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.isInitialized &&
        settings.appLockEnabled &&
        !_isSessionAuthenticated) {
      await SystemNavigator.pop();
      return true;
    }
    return super.didPopRoute();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isAuthenticating) {
      // Ignore lifecycle changes caused by our own biometric / PIN prompt.
      // Only clear transient background flags on resume without scheduling a
      // duplicate auth prompt (which would trap cancel in an infinite loop).
      if (state == AppLifecycleState.resumed && mounted) {
        AppLockScreen._isInTrueBackground = false;
        _wasPaused = false;
        if (_isInBackground || _showPrivacyCover) {
          setState(() {
            _isInBackground = false;
            _showPrivacyCover = false;
          });
        }
      }
      return;
    }

    // Transient system overlays (notification shade, permission dialogs,
    // autofill, biometric sheets from other widgets) emit `inactive` without
    // ever reaching `hidden` / `paused`. Never start the lock timer or flash
    // the privacy cover on `inactive`.
    if (state == AppLifecycleState.inactive) {
      return;
    }

    // On Flutter 3.13+ Android, returning from ConfirmDeviceCredentialActivity
    // (device PIN fallback) resolves `auth.authenticate()` on `onActivityResult`
    // BEFORE `MainActivity` finishes emitting `hidden -> inactive -> resumed`.
    // Ignore that trailing `hidden` so PIN unlock/cancel under timeout=0 never
    // starts the background timer, flashes the privacy cover, or re-locks.
    if (state == AppLifecycleState.hidden && _isInPostAuthSettle && !_wasPaused) {
      return;
    }

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    // Returning from an external activity only emits `hidden -> inactive -> resumed`,
    // never `paused`. A real `paused` after `withLockIgnored` finished must NOT be
    // suppressed by the post-return grace window.
    final bool shouldIgnoreLock = state == AppLifecycleState.paused
        ? (AppLockScreen._ignoreLockCount > 0 ||
            AppLockScreen.isIgnoreNextResumeLockValid)
        : AppLockScreen.isLockIgnored;
    final bool isTrueBackground = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;

    if (isTrueBackground) {
      if (AppLockScreen._ignoreLockCount > 0) {
        AppLockScreen._backgroundedDuringLockIgnore = true;
      }
      if (state == AppLifecycleState.paused) {
        _wasPaused = true;
        _postAuthSettleUntil = null;
        if (AppLockScreen._ignoreLockCount == 0) {
          AppLockScreen._ignoreLockGraceUntil = null;
          AppLockScreen._backgroundedDuringLockIgnore = false;
        }
      }
      AppLockScreen._isInTrueBackground = true;
      _userDismissedPromptInCurrentForeground = false;
      _authErrorMessage = null;
      _canDisableLockFallback = false;

      if (!_capturedPrePauseAuth) {
        _wasAuthenticatedBeforePause = _isSessionAuthenticated;
        _capturedPrePauseAuth = true;
      }

      if (mounted) {
        setState(() {
          _isInBackground = true;
          _showPrivacyCover = !shouldIgnoreLock;
        });
      }

      if (!shouldIgnoreLock) {
        FocusManager.instance.primaryFocus?.unfocus();
        // Record elapsed background time with a monotonic stopwatch
        _backgroundStopwatch ??= (Stopwatch()..start());
        // Lock immediately on true background (`paused`) when timeout is 0.
        if (settings.appLockTimeout == 0 && state == AppLifecycleState.paused) {
          if (settings.appLockEnabled) {
            _isSessionAuthenticated = false;
          }
          AppLockScreen.invalidateModuleSessions();
        }
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final bool cameFromTrueBackground =
          AppLockScreen._isInTrueBackground || _backgroundStopwatch != null;
      final bool wasPaused = _wasPaused;
      final bool inPostAuthSettle = _isInPostAuthSettle;
      _wasPaused = false;
      _postAuthSettleUntil = null;
      _capturedPrePauseAuth = false;

      // Guard against a trailing `resumed` event emitted immediately after the
      // system biometric / PIN dialog closes when the app never truly backgrounded.
      if (!cameFromTrueBackground && !wasPaused && inPostAuthSettle) {
        AppLockScreen._isInTrueBackground = false;
        if (mounted && (_isInBackground || _showPrivacyCover)) {
          setState(() {
            _isInBackground = false;
            _showPrivacyCover = false;
          });
        }
        return;
      }

      if (shouldIgnoreLock) {
        // Only restore authenticated state if the app was actually authenticated before pausing!
        if (_wasAuthenticatedBeforePause) {
          _isSessionAuthenticated = true;
        }
        // Resume from the backgrounded external activity has now arrived, so
        // `withLockIgnored.finally` does not need a trailing 800ms grace window.
        AppLockScreen._backgroundedDuringLockIgnore = false;
        if (AppLockScreen._ignoreLockCount == 0) {
          AppLockScreen.clearIgnoreNextResumeLock();
        }
      } else if (_backgroundStopwatch != null) {
        final elapsed = _backgroundStopwatch!.elapsed.inSeconds;
        if (elapsed >= settings.appLockTimeout) {
          if (settings.appLockEnabled) {
            _isSessionAuthenticated = false;
          }
          AppLockScreen.invalidateModuleSessions();
        }
      }
      _backgroundStopwatch?.stop();
      _backgroundStopwatch = null;

      final bool needsAndroidScreenOffCheck = !kIsWeb &&
          Platform.isAndroid &&
          !Platform.environment.containsKey('FLUTTER_TEST');

      if (mounted) {
        setState(() {
          _isInBackground = false;
          // On Android, keep the privacy cover up for the ~2ms native screen-off
          // check when returning from true background so content cannot flash.
          if (!needsAndroidScreenOffCheck ||
              !cameFromTrueBackground ||
              (!settings.appLockEnabled && !settings.hasAnyModuleLockEnabled)) {
            _showPrivacyCover = false;
          }
        });
      }

      final completer = Completer<void>();
      AppLockScreen._resumeLockCheckCompleter = completer;
      final generation = ++_resumeCheckGeneration;
      unawaited(
        _checkAuthOnResume(
          generation: generation,
          resumeCompleter: completer,
          cameFromTrueBackground: cameFromTrueBackground,
          wasLockIgnored: shouldIgnoreLock,
        ),
      );
    }
  }

  /// Android only: asks the native side whether the screen turned off since the
  /// last resume or the keyguard is locked. If so, locks immediately regardless of timeout.
  /// Returns `true` if this check triggered a lock.
  Future<bool> _lockIfScreenWasOff() async {
    if (kIsWeb ||
        !Platform.isAndroid ||
        Platform.environment.containsKey('FLUTTER_TEST')) {
      return false;
    }
    try {
      final wasOff = await _channel.invokeMethod<bool>('consumeScreenOff') ?? false;
      final isDeviceLocked = await _channel.invokeMethod<bool>('isDeviceLocked') ?? false;
      if (!wasOff && !isDeviceLocked) return false;
      if (!mounted) return false;
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (!settings.appLockEnabled && !settings.hasAnyModuleLockEnabled) return false;
      _backgroundStopwatch?.stop();
      _backgroundStopwatch = null;
      // Screen-off or keyguard lock invalidates any bypass/grace period
      AppLockScreen._ignoreLockCount = 0;
      AppLockScreen._ignoreLockGraceUntil = null;
      AppLockScreen._backgroundedDuringLockIgnore = false;
      AppLockScreen.clearIgnoreNextResumeLock();
      if (settings.appLockEnabled) {
        _isSessionAuthenticated = false;
      }
      AppLockScreen.invalidateModuleSessions();
      return true;
    } catch (e) {
      debugPrint('Error checking screen-off state: $e');
      return false;
    }
  }

  /// Android 13+: hides app content from the Recents thumbnail while app lock is on.
  void _syncRecentsPrivacy(bool hide) {
    if (_lastRecentsHide == hide) return;
    _lastRecentsHide = hide;
    if (kIsWeb || !Platform.isAndroid || Platform.environment.containsKey('FLUTTER_TEST')) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _channel.invokeMethod('setSecureRecents', {'hide': hide});
      } catch (e) {
        debugPrint('Error updating Recents privacy: $e');
      }
    });
  }

  Future<void> _checkAuthOnResume({
    required int generation,
    required Completer<void> resumeCompleter,
    required bool cameFromTrueBackground,
    required bool wasLockIgnored,
  }) async {
    bool lockedByScreenOff = false;
    try {
      if (mounted) {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        if (!settings.isInitialized) {
          await settings.initialized;
        }
      }
      // 1. A screen-off or device lock always ends the session immediately.
      lockedByScreenOff = await _lockIfScreenWasOff();
    } finally {
      AppLockScreen._isInTrueBackground = false;
      if (!resumeCompleter.isCompleted) {
        resumeCompleter.complete();
      }
      if (mounted && _showPrivacyCover) {
        setState(() => _showPrivacyCover = false);
      }
    }

    if (!mounted || generation != _resumeCheckGeneration) return;
    if (lockedByScreenOff) {
      _userDismissedPromptInCurrentForeground = false;
    }

    // 2. Wait 150ms to allow incoming sharing intents to settle before prompting.
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted || generation != _resumeCheckGeneration) return;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.isInitialized) return;
    if (!settings.appLockEnabled) {
      if (!_isSessionAuthenticated) {
        setState(() => _isSessionAuthenticated = true);
      }
      // Now that `_isInTrueBackground` is false, notify any active ModuleLockGate
      // if this resume followed a real background / screen-off cycle and at least
      // one enabled module lock is currently locked so it can cleanly auto-prompt.
      final hasCurrentlyLockedModule =
          (settings.lockFinances &&
              !AppLockScreen.unlockedModules.contains('finances')) ||
          (settings.lockHealth &&
              !AppLockScreen.unlockedModules.contains('health'));
      if (hasCurrentlyLockedModule &&
          (lockedByScreenOff || (cameFromTrueBackground && !wasLockIgnored))) {
        AppLockScreen.moduleSessionEpoch.value++;
      }
      return;
    }

    final shouldIgnoreLock = AppLockScreen.isLockIgnored;
    if (!_isSessionAuthenticated &&
        !shouldIgnoreLock &&
        !_userDismissedPromptInCurrentForeground) {
      await _checkAuth(context, isManual: false);
    }
  }

  Future<void> _checkAuth(BuildContext context, {bool isManual = true}) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.isInitialized) return;

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
    if (isManual) {
      _userDismissedPromptInCurrentForeground = false;
    }
    final reason = AppLocalizations.of(context)?.appLockAuthReason ??
        'Please authenticate to access the app';

    setState(() {
      _isAuthenticating = true;
    });

    try {
      bool useBiometricOnly = settings.useBiometrics;
      if (useBiometricOnly) {
        final canCheck = await auth.canCheckBiometrics;
        final available = canCheck ? await auth.getAvailableBiometrics() : <BiometricType>[];
        if (available.isEmpty) {
          useBiometricOnly = false;
        }
      }

      bool didAuthenticate;
      try {
        didAuthenticate = await auth.authenticate(
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
          didAuthenticate = await auth.authenticate(
            localizedReason: reason,
            options: const AuthenticationOptions(
              stickyAuth: true,
              biometricOnly: false,
            ),
          );
        } else {
          rethrow;
        }
      }

      if (didAuthenticate) {
        await AppLockScreen.resetNativeLockFlag();
      }

      if (mounted) {
        setState(() {
          _isSessionAuthenticated = didAuthenticate;
          if (didAuthenticate) {
            _authErrorMessage = null;
            _canDisableLockFallback = false;
            _userDismissedPromptInCurrentForeground = false;
          } else {
            _userDismissedPromptInCurrentForeground = true;
          }
        });
      }
    } catch (e) {
      debugPrint('Authentication error: $e');
      if (mounted) {
        if (e is PlatformException && e.code == 'auth_in_progress') {
          return;
        }
        setState(() {
          _userDismissedPromptInCurrentForeground = true;
          if (e is PlatformException &&
              (e.code == 'NotAvailable' ||
                  e.code == 'PasscodeNotSet' ||
                  e.code == 'NotEnrolled')) {
            _authErrorMessage = AppLocalizations.of(context)?.appLockNoCredentials ??
                'No screen lock or biometric credentials enrolled on this device.';
            _canDisableLockFallback = true;
          } else {
            _authErrorMessage = AppLocalizations.of(context)?.appLockAuthFailed ??
                'Authentication failed. Please try again.';
          }
        });
      }
    } finally {
      _postAuthSettleUntil =
          DateTime.now().add(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  void _syncFlagSecure(bool enabled) {
    if (_lastFlagSecure == enabled) return;
    _lastFlagSecure = enabled;
    if (kIsWeb || !Platform.isAndroid || Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _channel.invokeMethod('setFlagSecure', {'enabled': enabled});
      } catch (e) {
        debugPrint('Error updating FLAG_SECURE: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lockPrefs = context.select<
        SettingsProvider,
        ({
          bool isInitialized,
          bool appLockEnabled,
          bool hasAnyModuleLockEnabled,
          bool screenshotShieldEnabled,
        })>(
      (s) => (
        isInitialized: s.isInitialized,
        appLockEnabled: s.appLockEnabled,
        hasAnyModuleLockEnabled: s.hasAnyModuleLockEnabled,
        screenshotShieldEnabled: s.screenshotShieldEnabled,
      ),
    );

    if (lockPrefs.isInitialized) {
      _syncRecentsPrivacy(
        lockPrefs.appLockEnabled || lockPrefs.hasAnyModuleLockEnabled,
      );
      _syncFlagSecure(lockPrefs.screenshotShieldEnabled);
    }

    final bool isInitializing = !lockPrefs.isInitialized;
    final bool isLocked = lockPrefs.isInitialized &&
        lockPrefs.appLockEnabled &&
        !_isSessionAuthenticated;
    final bool showPrivacyCover = !isLocked &&
        lockPrefs.isInitialized &&
        (lockPrefs.appLockEnabled || lockPrefs.hasAnyModuleLockEnabled) &&
        _showPrivacyCover;
    final bool obscureChild = isInitializing || isLocked || showPrivacyCover;
    if (obscureChild && !_wasObscuringChild) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusManager.instance.primaryFocus?.unfocus();
      });
    }
    _wasObscuringChild = obscureChild;

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget? overlay;
    if (isLocked) {
      overlay = Positioned.fill(
        child: Container(
          color: (isDark ? Colors.black : scheme.surface),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppLayout.spaceXXL),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          // Shown on every resume (high frequency): fast ease-out
                          // entrance from 0.92 scale — never from scale(0).
                          duration: AppLayout.shouldReduceMotion(context)
                              ? Duration.zero
                              : AppLayout.animShort,
                          curve: AppLayout.curveStrongEaseOut,
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: 0.92 + (0.08 * value),
                              child: Opacity(
                                opacity: value,
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.primaryContainer.withValues(alpha: 0.65),
                            ),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              size: 40,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppLayout.spaceXL),
                        Text(
                          AppLocalizations.of(context)?.appLocked ?? 'App Locked',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppLayout.spaceS),
                        Text(
                          AppLocalizations.of(context)?.appLockSubtitle ??
                              'Verify your identity to open your private workspace.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        if (_authErrorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: scheme.error.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 16,
                                    color: scheme.error),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _authErrorMessage!,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: scheme.onErrorContainer,
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
                            onPressed: _isAuthenticating
                                ? null
                                : () => _checkAuth(context, isManual: true),
                            icon: const Icon(Icons.fingerprint),
                            label: Text(AppLocalizations.of(context)?.unlock ?? 'Unlock'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(160, 48),
                              shape: const StadiumBorder(),
                            ),
                          ),
                          if (_canDisableLockFallback) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _isAuthenticating
                                  ? null
                                  : () async {
                                      final s = Provider.of<SettingsProvider>(context, listen: false);
                                      final authReason = AppLocalizations.of(context)?.appLockAuthReason ??
                                          'Authenticate to disable App Lock';
                                      setState(() => _isAuthenticating = true);
                                      try {
                                        final canCheck = await auth.canCheckBiometrics ||
                                            await auth.isDeviceSupported();
                                        if (canCheck) {
                                          try {
                                            final didAuth = await AppLockScreen.withLockIgnored(
                                              () => auth.authenticate(
                                                localizedReason: authReason,
                                                options: const AuthenticationOptions(
                                                  stickyAuth: true,
                                                  biometricOnly: false,
                                                ),
                                              ),
                                            );
                                            if (!didAuth) return;
                                            await AppLockScreen.resetNativeLockFlag();
                                          } on PlatformException catch (e) {
                                            // Hardware may report supported while no screen lock
                                            // or biometric credential is enrolled; allow recovery.
                                            if (e.code != 'NotAvailable' &&
                                                e.code != 'PasscodeNotSet' &&
                                                e.code != 'NotEnrolled') {
                                              rethrow;
                                            }
                                          }
                                        }
                                        await s.setAppLockEnabled(false);
                                        AppLockScreen.unlockSession();
                                      } catch (e) {
                                        debugPrint('Failed to disable app lock: $e');
                                        if (mounted) {
                                          setState(() {
                                            _authErrorMessage = e is PlatformException
                                                ? (e.message ?? 'Authentication error')
                                                : 'Failed to verify identity to disable App Lock';
                                          });
                                        }
                                      } finally {
                                        _postAuthSettleUntil = DateTime.now()
                                            .add(const Duration(milliseconds: 800));
                                        if (mounted) {
                                          setState(() => _isAuthenticating = false);
                                        }
                                      }
                                    },
                              icon: const Icon(Icons.lock_open_rounded, size: 18),
                              label: Text(AppLocalizations.of(context)?.disableAppLock ?? 'Disable App Lock'),
                              style: TextButton.styleFrom(
                                foregroundColor: scheme.error,
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
          ),
        ),
      );
    } else if (isInitializing) {
      overlay = Positioned.fill(
        child: ColoredBox(
          color: isDark ? Colors.black : scheme.surface,
        ),
      );
    } else if (showPrivacyCover) {
      overlay = Positioned.fill(
        child: ColoredBox(
          color: scheme.surface,
          child: Center(
            child: Icon(Icons.lock_outline, size: 56, color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    // Keep widget.child in a constant tree slot across lock/cover transitions so
    // the Navigator, editors, focus nodes, and scroll controllers are never
    // reparented or torn down when backgrounding or locking the app.
    return PopScope(
      canPop: !isLocked,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isLocked) {
          SystemNavigator.pop();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeFocus(
            excluding: obscureChild,
            child: ExcludeSemantics(
              excluding: obscureChild,
              child: IgnorePointer(
                ignoring: obscureChild,
                child: widget.child,
              ),
            ),
          ),
          if (overlay != null) overlay,
        ],
      ),
    );
  }
}
