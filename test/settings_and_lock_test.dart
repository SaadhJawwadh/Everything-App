import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/screens/app_lock_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  bool mockAuthResult = true;

  // Mock local_auth method channel calls to prevent native exceptions in tests
  setUpAll(() {
    const channel = MethodChannel('plugins.flutter.io/local_auth');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'authenticate') {
        return mockAuthResult;
      }
      if (methodCall.method == 'isDeviceSupported') {
        return true;
      }
      return null;
    });
  });

  group('SettingsProvider App Lock and Timeout Tests', () {
    late SettingsProvider settings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsProvider();
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('Default values for App Lock are correct', () {
      expect(settings.appLockEnabled, isFalse);
      expect(settings.useBiometrics, isFalse);
      expect(settings.appLockTimeout, 30);
    });

    test('setAppLockTimeout updates value and persists', () async {
      await settings.setAppLockTimeout(30);
      expect(settings.appLockTimeout, 30);

      // Reload settings to verify persistence
      final newSettings = SettingsProvider();
      await Future.delayed(const Duration(milliseconds: 100)); // wait for constructor loadSettings
      expect(newSettings.appLockTimeout, 30);
    });

    test('toBackupMap includes appLockTimeout and smsSyncFrequency', () {
      final map = settings.toBackupMap();
      expect(map.containsKey('appLockTimeout'), isTrue);
      expect(map['appLockTimeout'], 30);
      expect(map['smsSyncFrequency'], '12');
    });

    test('setSmsSyncFrequency updates value, persists and restores', () async {
      await settings.setSmsSyncFrequency('24');
      expect(settings.smsSyncFrequency, '24');

      final backup = settings.toBackupMap();
      expect(backup['smsSyncFrequency'], '24');

      final newSettings = SettingsProvider();
      await Future.delayed(const Duration(milliseconds: 100));
      await newSettings.restoreFromBackupMap({'smsSyncFrequency': '12'});
      expect(newSettings.smsSyncFrequency, '12');
    });

    test('restoreFromBackupMap ignores app lock security configurations', () async {
      // Set initial state
      await settings.setAppLockEnabled(false);
      await settings.setUseBiometrics(false);
      await settings.setAppLockTimeout(0);

      // Create backup map with security configurations set to true / non-zero
      final backup = {
        'appLockEnabled': true,
        'useBiometrics': true,
        'appLockTimeout': 300,
        'textSize': 24.0, // Non-security setting
      };

      await settings.restoreFromBackupMap(backup);

      // Security configurations must remain unchanged (ignored from restore)
      expect(settings.appLockEnabled, isFalse);
      expect(settings.useBiometrics, isFalse);
      expect(settings.appLockTimeout, 300);

      // Non-security settings must be restored
      expect(settings.textSize, 24.0);
    });
  });

  group('AppLockScreen Widget Tests', () {
    late SettingsProvider settings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsProvider();
      await settings.loadSettings();
    });

    Widget buildTestWidget(Widget child) {
      return ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          home: AppLockScreen(child: child),
        ),
      );
    }

    testWidgets('Displays child directly if appLockEnabled is false', (tester) async {
      await settings.setAppLockEnabled(false);

      await tester.pumpWidget(buildTestWidget(
        const Scaffold(body: Text('Sensitive Workspace')),
      ));

      expect(find.text('Sensitive Workspace'), findsOneWidget);
      expect(find.text('App Locked'), findsNothing);
    });

    testWidgets('Locks screen and requires auth if appLockEnabled is true', (tester) async {
      await settings.setAppLockEnabled(true);
      await settings.setAppLockTimeout(0); // Test immediate lock on background
      mockAuthResult = false; // Make authentication fail initially

      // Ensure a fresh clean session authentication state for tests
      AppLockScreen.unlockSession(); // Reset it first to true
      
      // Let's reload settings to verify it prompts
      await tester.pumpWidget(buildTestWidget(
        const Scaffold(body: Text('Sensitive Workspace')),
      ));

      // Initially it bypasses if already authenticated in session, or prompts.
      // Since _isSessionAuthenticated is static and was unlocked, it shows child first.
      expect(find.text('Sensitive Workspace'), findsOneWidget);

      // Simulate sending app to background (paused)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Since timeout is 0 (default), going to background should immediately lock the session
      // on next frame.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('App Locked'), findsOneWidget);
      expect(find.ancestor(of: find.text('Sensitive Workspace'), matching: find.byWidgetPredicate((w) => w is IgnorePointer && w.ignoring)), findsWidgets);

      // Now set mockAuthResult = true and trigger unlock
      mockAuthResult = true;
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(find.text('Sensitive Workspace'), findsOneWidget);
      expect(find.text('App Locked'), findsNothing);
    });

    testWidgets('Does not lock if background elapsed time is less than timeout', (tester) async {
      await settings.setAppLockEnabled(true);
      await settings.setAppLockTimeout(10); // 10 seconds timeout

      // Start authenticated
      AppLockScreen.unlockSession();

      await tester.pumpWidget(buildTestWidget(
        const Scaffold(body: Text('Sensitive Workspace')),
      ));

      expect(find.text('Sensitive Workspace'), findsOneWidget);

      // Simulate pausing app
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Instantly resume (elapsed time is ~0 seconds, which is <= 10 seconds)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Should still be unlocked!
      expect(find.text('Sensitive Workspace'), findsOneWidget);
      expect(find.text('App Locked'), findsNothing);
    });

    test('toBackupMap and restoreFromBackupMap roundtrip preserves all extended settings', () async {
      final sp = SettingsProvider();
      await sp.loadSettings();
      await sp.setShowSplitBills(true);
      await sp.setEnableSavingsVault(false);
      await sp.setAccount1Name('Personal Checking');
      await sp.setAccount2Name('Emergency Fund');
      await sp.setCategoryAccountRouting('Groceries', 'daily');
      await sp.setCategoryAccountRouting('Investments', 'savings');
      await sp.setDefaultPaymentInfo('UPI: test@bank');
      await sp.setTrashAutoPurgeDays(45);

      final backupMap = sp.toBackupMap();
      expect(backupMap['showSplitBills'], isTrue);
      expect(backupMap['enableSavingsVault'], isFalse);
      expect(backupMap['account1Name'], equals('Personal Checking'));
      expect(backupMap['account2Name'], equals('Emergency Fund'));
      expect(backupMap['categoryAccountRouting'], equals({'Groceries': 'daily', 'Investments': 'savings'}));
      expect(backupMap['defaultPaymentInfo'], equals('UPI: test@bank'));
      expect(backupMap['trashAutoPurgeDays'], equals(45));

      // Restore into fresh instance
      final restoredSp = SettingsProvider();
      await restoredSp.loadSettings();
      await restoredSp.restoreFromBackupMap(backupMap);
      expect(restoredSp.showSplitBills, isTrue);
      expect(restoredSp.enableSavingsVault, isFalse);
      expect(restoredSp.account1Name, equals('Personal Checking'));
      expect(restoredSp.account2Name, equals('Emergency Fund'));
      expect(restoredSp.categoryAccountRouting['Groceries'], equals('daily'));
      expect(restoredSp.categoryAccountRouting['Investments'], equals('savings'));
      expect(restoredSp.defaultPaymentInfo, equals('UPI: test@bank'));
      expect(restoredSp.trashAutoPurgeDays, equals(45));
    });
  });
}
