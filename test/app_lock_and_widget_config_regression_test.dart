import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:note_taking_app/core/ui/module_lock_gate.dart';
import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/data/period_log_model.dart';
import 'package:note_taking_app/data/transaction_model.dart';
import 'package:note_taking_app/features/finances/data/transaction_repository.dart';
import 'package:note_taking_app/features/health/data/period_repository.dart';
import 'package:note_taking_app/features/notes/providers/note_provider.dart';
import 'package:note_taking_app/features/settings/presentation/screens/sections/security_settings_screen.dart';
import 'package:note_taking_app/features/settings/presentation/screens/sections/sync_backup_settings_screen.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/screens/app_lock_screen.dart';
import 'package:note_taking_app/utils/app_globals.dart';
import 'package:note_taking_app/utils/widget_helper.dart';
import 'package:note_taking_app/widgets/home/a2ui_smart_action_card.dart';
import 'package:note_taking_app/widgets/home/universal_search_overlay.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _StatefulProbe extends StatefulWidget {
  final VoidCallback onInit;

  const _StatefulProbe({required this.onInit});

  @override
  State<_StatefulProbe> createState() => _StatefulProbeState();
}

class _StatefulProbeState extends State<_StatefulProbe> {
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Probe Counter: $_counter'),
          ElevatedButton(
            onPressed: () => setState(() => _counter++),
            child: const Text('Increment'),
          ),
        ],
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const localAuthChannel = MethodChannel('plugins.flutter.io/local_auth');
  const widgetChannel = MethodChannel('com.saadhjawwadh.notebook/widget');

  late Future<Object?> Function(MethodCall call) localAuthHandler;
  final List<MethodCall> widgetCalls = [];
  int authPromptCount = 0;

  setUp(() {
    widgetCalls.clear();
    authPromptCount = 0;
    AppLockScreen.clearIgnoreNextResumeLock();
    AppLockScreen.unlockedModules.clear();
    AppLockScreen.sessionAuthenticated.value = false;

    localAuthHandler = (MethodCall call) async {
      if (call.method == 'isDeviceSupported' || call.method == 'canCheckBiometrics') {
        return true;
      }
      if (call.method == 'getAvailableBiometrics') {
        return <String>['fingerprint'];
      }
      if (call.method == 'authenticate') {
        authPromptCount++;
        return true;
      }
      return null;
    };

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(localAuthChannel, (call) => localAuthHandler(call));

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetChannel, (call) async {
      widgetCalls.add(call);
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(localAuthChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetChannel, null);
  });

  group('Widget Config Cold-Start Race Regression', () {
    test('SettingsProvider pushes persisted showFinancialManager=true once initialized', () async {
      SharedPreferences.setMockInitialValues({
        'showFinancialManager': true,
        'appLockEnabled': true,
        'lockFinances': true,
        'screenshotShieldEnabled': true,
        'useDynamicColor': false,
        'selectedLanguageCode': 'ta',
      });

      final settings = SettingsProvider();
      await settings.initialized;
      await Future.delayed(const Duration(milliseconds: 20));

      final syncCalls =
          widgetCalls.where((c) => c.method == 'syncWidgetConfig').toList();
      expect(syncCalls, isNotEmpty);
      final args = Map<String, dynamic>.from(syncCalls.last.arguments as Map);
      expect(args['showFinancialManager'], isTrue);
      expect(args['appLockEnabled'], isTrue);
      expect(args['lockFinances'], isTrue);
      expect(args['screenshotShieldEnabled'], isTrue);
      expect(args['useDynamicColor'], isFalse);
      expect(args['languageCode'], 'ta');
    });

    test('WidgetHelper.syncWidgetConfig without overrides reads persisted prefs', () async {
      SharedPreferences.setMockInitialValues({
        'showFinancialManager': true,
        'useDynamicColor': false,
      });

      await WidgetHelper.syncWidgetConfig();

      final call = widgetCalls.lastWhere((c) => c.method == 'syncWidgetConfig');
      final args = Map<String, dynamic>.from(call.arguments as Map);
      expect(args['showFinancialManager'], isTrue);
      expect(args['useDynamicColor'], isFalse);
    });

    test('setUseDynamicColor syncs useDynamicColor to native widget config', () async {
      SharedPreferences.setMockInitialValues({
        'showFinancialManager': true,
        'useDynamicColor': true,
      });

      final settings = SettingsProvider();
      await settings.initialized;
      widgetCalls.clear();

      await settings.setUseDynamicColor(false);
      await Future.delayed(const Duration(milliseconds: 20));

      final call = widgetCalls.lastWhere((c) => c.method == 'syncWidgetConfig');
      final args = Map<String, dynamic>.from(call.arguments as Map);
      expect(args['showFinancialManager'], isTrue);
      expect(args['useDynamicColor'], isFalse);
    });
  });

  group('AppLockScreen Lifecycle & Conflict Regression', () {
    testWidgets('Cold start with uninitialized SettingsProvider never bypasses App Lock', (tester) async {
      SharedPreferences.setMockInitialValues({
        'appLockEnabled': true,
        'appLockTimeout': 30,
      });
      localAuthHandler = (call) async {
        if (call.method == 'authenticate') {
          authPromptCount++;
          return false;
        }
        if (call.method == 'isDeviceSupported') return true;
        return null;
      };

      // Deliberately do NOT await loadSettings() before mounting AppLockScreen
      final settings = SettingsProvider();
      AppLockScreen.sessionAuthenticated.value = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            home: AppLockScreen(
              child: Scaffold(body: Text('Private Notes')),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(settings.isInitialized, isTrue);
      expect(AppLockScreen.sessionAuthenticated.value, isFalse);
      expect(find.text('App Locked'), findsOneWidget);
      expect(authPromptCount, 1);
    });

    testWidgets('Immediate timeout (0s) does NOT lock on transient inactive -> resumed (notification shade)', (tester) async {
      SharedPreferences.setMockInitialValues({
        'appLockEnabled': true,
        'appLockTimeout': 0,
      });
      final settings = SettingsProvider();
      await settings.loadSettings();

      AppLockScreen.unlockSession();
      AppLockScreen.unlockedModules.add('finances');

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            home: AppLockScreen(
              child: Scaffold(body: Text('Sensitive Workspace')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate notification shade / permission dialog (inactive -> resumed, never paused)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(AppLockScreen.sessionAuthenticated.value, isTrue);
      expect(AppLockScreen.unlockedModules.contains('finances'), isTrue);
      expect(find.text('App Locked'), findsNothing);
      expect(authPromptCount, 0);
    });

    testWidgets('Cancelling biometric prompt does NOT trigger an infinite re-prompt loop', (tester) async {
      SharedPreferences.setMockInitialValues({
        'appLockEnabled': true,
        'appLockTimeout': 0,
      });
      final settings = SettingsProvider();
      await settings.loadSettings();

      bool shouldSucceed = false;
      localAuthHandler = (call) async {
        if (call.method == 'authenticate') {
          authPromptCount++;
          return shouldSucceed;
        }
        if (call.method == 'isDeviceSupported') return true;
        return null;
      };

      AppLockScreen.unlockSession();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            home: AppLockScreen(
              child: Scaffold(body: Text('Sensitive Workspace')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pause & resume triggers 1 automatic prompt which user cancels
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(authPromptCount, 1);
      expect(find.text('App Locked'), findsOneWidget);

      // Android emits a trailing inactive -> resumed when BiometricPrompt closes
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Must NOT have re-prompted in a loop
      expect(authPromptCount, 1);
      expect(find.text('App Locked'), findsOneWidget);

      // Manual Unlock tap succeeds
      shouldSucceed = true;
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(authPromptCount, 2);
      expect(AppLockScreen.sessionAuthenticated.value, isTrue);
      expect(find.text('App Locked'), findsNothing);
    });

    testWidgets('AppLockScreen preserves child State without reparenting across pause, lock, and unlock', (tester) async {
      SharedPreferences.setMockInitialValues({
        'appLockEnabled': true,
        'appLockTimeout': 0,
      });
      final settings = SettingsProvider();
      await settings.loadSettings();

      bool shouldSucceed = false;
      localAuthHandler = (call) async {
        if (call.method == 'authenticate') {
          authPromptCount++;
          return shouldSucceed;
        }
        if (call.method == 'isDeviceSupported') return true;
        return null;
      };

      AppLockScreen.unlockSession();
      int initCount = 0;

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(
            home: AppLockScreen(
              child: _StatefulProbe(onInit: () => initCount++),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Increment'));
      await tester.pump();
      expect(find.text('Probe Counter: 1'), findsOneWidget);
      expect(initCount, 1);

      // Pause -> lock -> resume -> cancel
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('App Locked'), findsOneWidget);

      // Unlock -> child state must still be intact and initState NOT re-invoked
      shouldSucceed = true;
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(find.text('Probe Counter: 1'), findsOneWidget);
      expect(initCount, 1);
    });

    testWidgets('ModuleLockGate with appLockTimeout=0 does NOT re-lock when PIN fallback pauses activity', (tester) async {
      SharedPreferences.setMockInitialValues({
        'appLockEnabled': false,
        'lockFinances': true,
        'appLockTimeout': 0,
      });
      final settings = SettingsProvider();
      await settings.loadSettings();

      localAuthHandler = (call) async {
        if (call.method == 'authenticate') {
          authPromptCount++;
          // Simulate system PIN activity pausing and resuming MainActivity
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          return true;
        }
        if (call.method == 'isDeviceSupported') return true;
        return null;
      };

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            home: AppLockScreen(
              child: ModuleLockGate(
                moduleKey: 'finances',
                moduleTitle: 'Finances',
                isLockedSettingEnabled: true,
                isActive: true,
                child: Scaffold(body: Text('Finances Ledger')),
              ),
            ),
          ),
        ),
      );

      // Allow auto-prompt and withLockIgnored 300ms grace period to complete
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(authPromptCount, 1);
      expect(AppLockScreen.unlockedModules.contains('finances'), isTrue);
      expect(find.text('Finances Ledger'), findsOneWidget);
      expect(find.text('Finances Locked'), findsNothing);
    });

    testWidgets('Disable App Lock fallback recovers when device reports supported hardware but PasscodeNotSet', (tester) async {
      SharedPreferences.setMockInitialValues({
        'appLockEnabled': true,
        'appLockTimeout': 0,
      });
      final settings = SettingsProvider();
      await settings.loadSettings();

      localAuthHandler = (call) async {
        if (call.method == 'isDeviceSupported') return true;
        if (call.method == 'canCheckBiometrics') return false;
        if (call.method == 'authenticate') {
          authPromptCount++;
          throw PlatformException(
            code: 'PasscodeNotSet',
            message: 'No screen lock enrolled',
          );
        }
        return null;
      };

      AppLockScreen.sessionAuthenticated.value = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            home: AppLockScreen(
              child: Scaffold(body: Text('Sensitive Workspace')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('App Locked'), findsOneWidget);
      expect(find.text('Disable App Lock'), findsOneWidget);

      await tester.tap(find.text('Disable App Lock'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(settings.appLockEnabled, isFalse);
      expect(AppLockScreen.sessionAuthenticated.value, isTrue);
      expect(find.text('App Locked'), findsNothing);
      expect(find.text('Sensitive Workspace'), findsOneWidget);
    });

    testWidgets('SecuritySettingsScreen disabling App Lock with timeout=0 does not self-lock on cancel or success', (tester) async {
      SharedPreferences.setMockInitialValues({
        'appLockEnabled': true,
        'appLockTimeout': 0,
      });
      final settings = SettingsProvider();
      await settings.loadSettings();
      AppLockScreen.unlockSession();

      bool allowDisable = false;
      localAuthHandler = (call) async {
        if (call.method == 'isDeviceSupported') return true;
        if (call.method == 'authenticate') {
          authPromptCount++;
          // Simulate system auth prompt pausing/resuming
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          return allowDisable;
        }
        return null;
      };

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            home: AppLockScreen(
              child: SecuritySettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First attempt: cancel auth -> App Lock stays ON, but app does NOT lock out mid-settings
      final appLockSwitch = find.byType(Switch).first;
      await tester.tap(appLockSwitch);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(settings.appLockEnabled, isTrue);
      expect(AppLockScreen.sessionAuthenticated.value, isTrue);
      expect(find.text('App Locked'), findsNothing);

      // Second attempt: approve auth -> App Lock turns OFF cleanly
      allowDisable = true;
      await tester.tap(appLockSwitch);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(settings.appLockEnabled, isFalse);
      expect(find.text('App Locked'), findsNothing);
    });

    testWidgets('PIN fallback trailing hidden -> inactive -> resumed with timeout=0 does NOT re-lock or loop', (tester) async {
      SharedPreferences.setMockInitialValues({
        'appLockEnabled': true,
        'appLockTimeout': 0,
      });
      final settings = SettingsProvider();
      await settings.loadSettings();

      bool shouldSucceed = false;
      localAuthHandler = (call) async {
        if (call.method == 'isDeviceSupported') return true;
        if (call.method == 'authenticate') {
          authPromptCount++;
          return shouldSucceed;
        }
        return null;
      };

      AppLockScreen.sessionAuthenticated.value = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            home: AppLockScreen(
              child: Scaffold(body: Text('Sensitive Workspace')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(authPromptCount, 1);
      expect(find.text('App Locked'), findsOneWidget);

      // 1. User cancelled PIN fallback -> Android emits trailing hidden -> inactive -> resumed
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // Must NOT re-prompt in a loop on cancel
      expect(authPromptCount, 1);
      expect(find.text('App Locked'), findsOneWidget);

      // 2. User taps Unlock and succeeds via PIN fallback -> trailing hidden -> inactive -> resumed
      shouldSucceed = true;
      await tester.tap(find.text('Unlock'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // Must remain UNLOCKED without re-locking or re-prompting!
      expect(authPromptCount, 2);
      expect(AppLockScreen.sessionAuthenticated.value, isTrue);
      expect(find.text('App Locked'), findsNothing);
      expect(find.text('Sensitive Workspace'), findsOneWidget);

      // 3. Real user backgrounding (paused) immediately afterwards MUST still lock for timeout=0
      shouldSucceed = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(AppLockScreen.sessionAuthenticated.value, isFalse);
      expect(find.text('App Locked'), findsOneWidget);
      expect(authPromptCount, 3);
    });

    testWidgets('ModuleLockGate auto-prompts on resume after background timeout lock', (tester) async {
      SharedPreferences.setMockInitialValues({
        'appLockEnabled': false,
        'lockFinances': true,
        'appLockTimeout': 0,
      });
      final settings = SettingsProvider();
      await settings.loadSettings();

      bool allowAuth = true;
      localAuthHandler = (call) async {
        if (call.method == 'isDeviceSupported') return true;
        if (call.method == 'authenticate') {
          authPromptCount++;
          return allowAuth;
        }
        return null;
      };

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            home: AppLockScreen(
              child: ModuleLockGate(
                moduleKey: 'finances',
                moduleTitle: 'Finances',
                isLockedSettingEnabled: true,
                isActive: true,
                child: Scaffold(body: Text('Finances Ledger')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(authPromptCount, 1);
      expect(AppLockScreen.unlockedModules.contains('finances'), isTrue);
      expect(find.text('Finances Ledger'), findsOneWidget);

      // Background with timeout=0 locks Finances; returning to foreground must auto-prompt once
      allowAuth = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(AppLockScreen.unlockedModules.contains('finances'), isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(authPromptCount, 2);
      expect(find.text('Finances Locked'), findsOneWidget);
    });

    testWidgets('AppLockScreen unfocuses child TextField and excludes focus when locked', (tester) async {
      SharedPreferences.setMockInitialValues({
        'appLockEnabled': true,
        'appLockTimeout': 0,
      });
      final settings = SettingsProvider();
      await settings.loadSettings();
      AppLockScreen.unlockSession();

      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(
            home: AppLockScreen(
              child: Scaffold(
                body: TextField(focusNode: focusNode),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // Lock immediately -> TextField must lose focus and be wrapped in ExcludeFocus(excluding: true)
      AppLockScreen.lockNow();
      await tester.pumpAndSettle();

      expect(find.text('App Locked'), findsOneWidget);
      expect(focusNode.hasFocus, isFalse);
      expect(
        find.ancestor(
          of: find.byType(TextField),
          matching: find.byWidgetPredicate((w) => w is ExcludeFocus && w.excluding),
        ),
        findsOneWidget,
      );
    });

    testWidgets('SecuritySettingsScreen requires auth to disable Lock Finances Tab', (tester) async {
      SharedPreferences.setMockInitialValues({
        'showFinancialManager': true,
        'appLockEnabled': false,
        'lockFinances': true,
        'appLockTimeout': 0,
      });
      final settings = SettingsProvider();
      await settings.loadSettings();

      bool allowDisable = false;
      localAuthHandler = (call) async {
        if (call.method == 'isDeviceSupported') return true;
        if (call.method == 'authenticate') {
          authPromptCount++;
          return allowDisable;
        }
        return null;
      };

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            home: AppLockScreen(
              child: SecuritySettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lockFinancesSwitch = find.byType(Switch).at(1);
      await tester.ensureVisible(lockFinancesSwitch);

      // Cancelled auth -> Lock Finances stays ON
      await tester.tap(lockFinancesSwitch);
      await tester.pumpAndSettle();
      expect(authPromptCount, 1);
      expect(settings.lockFinances, isTrue);

      // Approved auth -> Lock Finances turns OFF
      allowDisable = true;
      await tester.tap(lockFinancesSwitch);
      await tester.pumpAndSettle();
      expect(authPromptCount, 2);
      expect(settings.lockFinances, isFalse);
    });

    testWidgets('UniversalSearchOverlay requires auth to disable App Lock', (tester) async {
      SharedPreferences.setMockInitialValues({
        'appLockEnabled': true,
        'appLockTimeout': 0,
      });
      final settings = SettingsProvider();
      await settings.loadSettings();
      AppLockScreen.unlockSession();

      bool allowDisable = false;
      localAuthHandler = (call) async {
        if (call.method == 'isDeviceSupported') return true;
        if (call.method == 'authenticate') {
          authPromptCount++;
          return allowDisable;
        }
        return null;
      };

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<NoteProvider>(create: (_) => NoteProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: UniversalSearchOverlay(query: 'App Lock'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      // Cancel -> stays enabled
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(authPromptCount, 1);
      expect(settings.appLockEnabled, isTrue);

      // Approve -> disables cleanly
      allowDisable = true;
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(authPromptCount, 2);
      expect(settings.appLockEnabled, isFalse);
    });

    testWidgets(
      'UniversalSearchOverlay does not leak transactions or period logs when module locks are enabled and locked',
      (tester) async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        await tester.runAsync(() => initializeDateFormatting());

        late Database db;
        await tester.runAsync(() async {
          db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
          await DatabaseHelper.instance.createTestDatabase(db);
          DatabaseHelper.setMockDatabase(db);

          await TransactionRepository.instance.createTransaction(
            TransactionModel(
              amount: 1250,
              description: 'Secret Rent Payment',
              date: DateTime(2026, 11, 20),
              isExpense: true,
              category: 'Bills',
            ),
            updateWidgets: false,
          );
          await PeriodRepository.instance.createPeriodLog(
            PeriodLog(
              id: 'period_secret_1',
              startDate: DateTime(2026, 11, 18),
              intensity: 'Heavy',
              notes: 'Secret Cycle Note',
            ),
          );
        });

        try {
          SharedPreferences.setMockInitialValues({
            'showFinancialManager': true,
            'isPeriodTrackerEnabled': true,
            'appLockEnabled': false,
            'lockFinances': true,
            'lockHealth': true,
            'appLockTimeout': 0,
          });
          final settings = SettingsProvider();
          await tester.runAsync(() => settings.loadSettings());

          // Both modules locked (unlockedModules is empty)
          AppLockScreen.unlockedModules.clear();

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<SettingsProvider>.value(value: settings),
                ChangeNotifierProvider<NoteProvider>(create: (_) => NoteProvider()),
              ],
              child: const MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: UniversalSearchOverlay(query: 'Secret'),
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pumpAndSettle();

          // Locked modules must NOT leak transactions or period logs
          expect(find.textContaining('Secret Rent Payment', findRichText: true), findsNothing);
          expect(find.text('Financial Transactions'), findsNothing);
          expect(find.textContaining('Period Log: Heavy', findRichText: true), findsNothing);
          expect(find.text('Health Logs'), findsNothing);

          // Unlock ONLY finances -> transactions appear, health logs stay hidden
          AppLockScreen.unlockedModules.add('finances');
          AppLockScreen.moduleSessionEpoch.value++;
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pumpAndSettle();

          expect(find.textContaining('Secret Rent Payment', findRichText: true), findsOneWidget);
          expect(find.text('Financial Transactions'), findsOneWidget);
          expect(find.textContaining('Period Log: Heavy', findRichText: true), findsNothing);
          expect(find.text('Health Logs'), findsNothing);

          // Re-locking sessions immediately hides previously shown finance records
          AppLockScreen.invalidateModuleSessions();
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pumpAndSettle();

          expect(find.textContaining('Secret Rent Payment', findRichText: true), findsNothing);
          expect(find.text('Financial Transactions'), findsNothing);

          // Unlock ONLY health -> health logs appear, finances stay hidden
          AppLockScreen.unlockedModules.add('health');
          AppLockScreen.moduleSessionEpoch.value++;
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pumpAndSettle();

          expect(find.textContaining('Period Log: Heavy', findRichText: true), findsOneWidget);
          expect(find.text('Health Logs'), findsOneWidget);
          expect(find.textContaining('Secret Rent Payment', findRichText: true), findsNothing);
          expect(find.text('Financial Transactions'), findsNothing);
        } finally {
          await tester.runAsync(() async {
            await db.close();
            DatabaseHelper.setMockDatabase(null);
          });
        }
      },
    );

    test('withLockIgnored clears ignore state immediately on completion or throw without backgrounding', () async {
      expect(AppLockScreen.isLockIgnored, isFalse);

      final val = await AppLockScreen.withLockIgnored(() async {
        expect(AppLockScreen.isLockIgnored, isTrue);
        return 42;
      });
      expect(val, 42);
      expect(AppLockScreen.isLockIgnored, isFalse);

      await expectLater(
        AppLockScreen.withLockIgnored<void>(() async {
          expect(AppLockScreen.isLockIgnored, isTrue);
          throw StateError('external launch failed');
        }),
        throwsStateError,
      );
      expect(AppLockScreen.isLockIgnored, isFalse);
    });

    testWidgets(
      'A2uiSmartActionCard hides financial quick actions while Finances module is locked and reacts to unlock/re-lock',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'showFinancialManager': true,
          'showSplitBills': true,
          'appLockEnabled': false,
          'lockFinances': true,
        });
        final settings = SettingsProvider();
        await settings.loadSettings();
        AppLockScreen.unlockedModules.clear();

        await tester.pumpWidget(
          ChangeNotifierProvider<SettingsProvider>.value(
            value: settings,
            child: const MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    A2uiSmartActionCard(query: 'Spent 450 on coffee'),
                    A2uiSmartActionCard(query: 'Split 1200 dinner by 3'),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Locked Finances -> neither financial quick action card should appear
        expect(find.byKey(const ValueKey('a2ui_smart_action_card')), findsNothing);
        expect(find.text('Log Expense'), findsNothing);
        expect(find.text('Create Split'), findsNothing);

        // Unlock Finances -> both cards appear immediately on moduleSessionEpoch change
        AppLockScreen.unlockedModules.add('finances');
        AppLockScreen.moduleSessionEpoch.value++;
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('a2ui_smart_action_card')), findsNWidgets(2));
        expect(find.text('Log Expense'), findsOneWidget);
        expect(find.text('Create Split'), findsOneWidget);

        // Re-lock Finances -> both cards disappear immediately
        AppLockScreen.invalidateModuleSessions();
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('a2ui_smart_action_card')), findsNothing);
      },
    );

    testWidgets(
      'UniversalSearchOverlay SMS Auto-Sync Test button redirects to locked Finances instead of running sync',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'showFinancialManager': true,
          'appLockEnabled': false,
          'lockFinances': true,
        });
        final settings = SettingsProvider();
        await settings.loadSettings();
        AppLockScreen.unlockedModules.clear();
        appTabNavigationRequest.value = null;

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<NoteProvider>(create: (_) => NoteProvider()),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: UniversalSearchOverlay(query: 'SMS Auto-Sync'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final testButton = find.widgetWithText(OutlinedButton, 'Test');
        expect(testButton, findsOneWidget);

        await tester.tap(testButton);
        await tester.pumpAndSettle();

        expect(appTabNavigationRequest.value, 'finances');
        expect(find.text('SMS Auto-Sync check complete'), findsNothing);
        appTabNavigationRequest.value = null;
      },
    );

    testWidgets(
      'withLockIgnored clears grace immediately when resumed fires before action completes',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'appLockEnabled': true,
          'appLockTimeout': 0,
        });
        final settings = SettingsProvider();
        await settings.loadSettings();
        AppLockScreen.unlockSession();

        await tester.pumpWidget(
          ChangeNotifierProvider<SettingsProvider>.value(
            value: settings,
            child: const MaterialApp(
              home: AppLockScreen(
                child: Scaffold(body: Text('Sensitive Workspace')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final completer = Completer<void>();
        final future = AppLockScreen.withLockIgnored(() => completer.future);

        // External picker backgrounds MainActivity, then returns before Dart resolves
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();

        completer.complete();
        await future;
        await tester.pump(const Duration(milliseconds: 200));

        // No trailing 800ms grace window should linger once resume already happened
        expect(AppLockScreen.isLockIgnored, isFalse);

        // Immediate real backgrounding MUST lock cleanly
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();

        expect(AppLockScreen.sessionAuthenticated.value, isFalse);
      },
    );

    testWidgets(
      'AppLockScreen does not spuriously bump moduleSessionEpoch when returning before timeout with module unlocked',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'appLockEnabled': false,
          'lockFinances': true,
          'appLockTimeout': 30,
        });
        final settings = SettingsProvider();
        await settings.loadSettings();
        AppLockScreen.unlockedModules.add('finances');

        await tester.pumpWidget(
          ChangeNotifierProvider<SettingsProvider>.value(
            value: settings,
            child: const MaterialApp(
              home: AppLockScreen(
                child: Scaffold(body: Text('Finances Workspace')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final epochBefore = AppLockScreen.moduleSessionEpoch.value;

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        expect(AppLockScreen.unlockedModules.contains('finances'), isTrue);
        expect(AppLockScreen.moduleSessionEpoch.value, epochBefore);
      },
    );

    test(
      'SyncBackupSettingsScreen.confirmRecoveryKeyAuth fails closed on LockedOut and allows only unenrolled fallback',
      () async {
        String errorCode = 'LockedOut';
        localAuthHandler = (call) async {
          if (call.method == 'isDeviceSupported' ||
              call.method == 'canCheckBiometrics') {
            return true;
          }
          if (call.method == 'authenticate') {
            authPromptCount++;
            throw PlatformException(
              code: errorCode,
              message: 'Auth error',
            );
          }
          return null;
        };

        final lockedOutAllowed =
            await SyncBackupSettingsScreen.confirmRecoveryKeyAuth(
          'Authenticate to view recovery key',
        );
        expect(lockedOutAllowed, isFalse);
        expect(authPromptCount, 1);

        errorCode = 'PasscodeNotSet';
        final unenrolledAllowed =
            await SyncBackupSettingsScreen.confirmRecoveryKeyAuth(
          'Authenticate to view recovery key',
        );
        expect(unenrolledAllowed, isTrue);
        expect(authPromptCount, 2);
      },
    );
  });
}
