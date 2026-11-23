import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:provider/provider.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'services/sms_service.dart';
import 'package:note_taking_app/core/theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/app_lock_screen.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:workmanager/workmanager.dart';
import 'package:note_taking_app/features/notes/providers/note_provider.dart';
import 'features/sync/providers/p2p_sync_provider.dart';
import 'package:note_taking_app/features/finances/providers/financial_manager_provider.dart';
import 'package:note_taking_app/features/finances/providers/split_bill_provider.dart';
import 'package:note_taking_app/features/finances/providers/savings_goal_provider.dart';
import 'package:note_taking_app/features/health/providers/period_tracker_provider.dart';
import 'l10n/app_localizations.dart';

import 'package:flutter/foundation.dart';
import 'services/notification_service.dart';
import 'services/backup_service.dart' as backup;

import 'services/local_ai_service.dart';
import 'services/hybrid_local_ai_service.dart';
import 'data/repositories/recurring_rule_repository.dart';
import 'utils/widget_helper.dart';
import 'utils/app_globals.dart';

Future<void> _unlockHighRefreshRate() async {
  if (!kIsWeb && Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      debugPrint('DisplayMode error: $e');
    }
  }
}

Future<void> _initializeBackgroundServices() async {
  try {
    await _unlockHighRefreshRate();
    await Future.wait([
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
        Workmanager().initialize(backup.callbackDispatcher).catchError((e) => debugPrint('Workmanager error: $e')),
      SmsService.init().catchError((e) => debugPrint('SmsService init error: $e')),
      RecurringRuleRepository.instance.materializeDueRules().catchError((e) {
        debugPrint('Materialize rules error: $e');
        return 0;
      }),
      if (!kIsWeb)
        NotificationService.initialize().catchError((e) => debugPrint('NotificationService error: $e')),
    ]).timeout(const Duration(seconds: 10), onTimeout: () {
      debugPrint('Background startup init timed out');
      return const [];
    });

    // Keep the finance widget's TODAY figure fresh across midnight even when
    // the app isn't opened; the widget redraws from prefs on its own cycle.
    // initialDelay keeps the task's first run (which opens the encrypted DB in
    // a background isolate) from racing the main isolate's DB open at cold
    // start — without it the two opens can deadlock before the first frame.
    if (!kIsWeb && Platform.isAndroid) {
      unawaited(
        Workmanager()
            .registerPeriodicTask(
              kWidgetRefreshTaskName,
              kWidgetRefreshTaskName,
              frequency: const Duration(hours: 4),
              initialDelay: const Duration(hours: 1),
              constraints: Constraints(networkType: NetworkType.notRequired),
              existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
            )
            .catchError((e) => debugPrint('Widget refresh task error: $e')),
      );
    }
  } catch (e) {
    debugPrint('Background initialization error: $e');
  }
}

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Optimize image cache limits to prevent memory pressure & OOM pauses
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100 MB
    PaintingBinding.instance.imageCache.maximumSize = 100;

    // Edge-to-edge: draw behind the system bars with a transparent nav bar
    // (also the enforced default on Android 15+; this keeps older versions
    // consistent).
    if (!kIsWeb && Platform.isAndroid) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
          systemStatusBarContrastEnforced: false,
        ),
      );
    }
  } catch (e) {
    debugPrint('Critical initialization error: $e');
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeBackgroundServices());
  });

  runApp(
    MultiProvider(
      providers: [
        Provider<LocalAiService>(create: (_) => HybridLocalAiService()),
        ChangeNotifierProvider(
          create: (context) {
            final settings = SettingsProvider();
            final aiService = Provider.of<LocalAiService>(context, listen: false);
            settings.checkAiCoreSupport(aiService);
            return settings;
          },
        ),
        ChangeNotifierProvider(create: (_) => NoteProvider()),
        ChangeNotifierProvider(create: (_) => FinancialManagerProvider()),
        ChangeNotifierProvider(create: (_) => SplitBillProvider()..loadSplitBills()),
        ChangeNotifierProvider(create: (_) => SavingsGoalProvider()..loadGoals()),
        ChangeNotifierProvider(create: (_) => PeriodTrackerProvider()),
        ChangeNotifierProvider(
          create: (_) => P2pSyncProvider(),
        ),
      ],
      child: const NoteApp(),
    ),
  );
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    switch (getPlatform(context)) {
      case TargetPlatform.android:
        return StretchingOverscrollIndicator(
          axisDirection: details.direction,
          child: child,
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return child;
      default:
        return super.buildOverscrollIndicator(context, child, details);
    }
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics();
      case TargetPlatform.android:
      default:
        return const ClampingScrollPhysics();
    }
  }
}

class NoteApp extends StatelessWidget {
  const NoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appConfig = context.select<SettingsProvider,
        ({ThemeMode themeMode, bool useDynamicColor, Locale? currentLocale, double textSize})>(
      (s) => (
        themeMode: s.themeMode,
        useDynamicColor: s.useDynamicColor,
        currentLocale: s.currentLocale,
        textSize: s.textSize,
      ),
    );

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp(
          title: 'Everything App',
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
          scaffoldMessengerKey: appScaffoldMessengerKey,
          scrollBehavior: const AppScrollBehavior(),
          theme: AppTheme.createTheme(
              appConfig.useDynamicColor ? lightDynamic : null, Brightness.light),
          darkTheme: AppTheme.createTheme(
              appConfig.useDynamicColor ? darkDynamic : null, Brightness.dark),
          themeMode: appConfig.themeMode,
          locale: appConfig.currentLocale,
          home: const HomeScreen(),
          builder: (context, child) {
            final mediaQueryData = MediaQuery.of(context);
            final deviceFontScale = mediaQueryData.textScaler.scale(1.0);
            return MediaQuery(
              data: mediaQueryData.copyWith(
                textScaler: TextScaler.linear(deviceFontScale * (appConfig.textSize / 16.0)),
              ),
              child: AppLockScreen(child: child!),
            );
          },
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            if (appConfig.currentLocale != null) {
              Intl.defaultLocale = appConfig.currentLocale!.languageCode;
              return appConfig.currentLocale;
            }
            if (deviceLocale != null) {
              Intl.defaultLocale = deviceLocale.languageCode;
            }
            return deviceLocale;
          },
        );
      },
    );
  }
}
