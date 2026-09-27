import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/features/settings/presentation/screens/onboarding_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:note_taking_app/features/sync/providers/p2p_sync_provider.dart';
import 'package:note_taking_app/features/sync/presentation/screens/p2p_sync_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider Onboarding Tests', () {
    late SettingsProvider settings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsProvider();
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('Default value for hasSeenOnboarding is false', () {
      expect(settings.hasSeenOnboarding, isFalse);
    });

    test('setHasSeenOnboarding updates and persists', () async {
      await settings.setHasSeenOnboarding(true);
      expect(settings.hasSeenOnboarding, isTrue);

      final newSettings = SettingsProvider();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(newSettings.hasSeenOnboarding, isTrue);
    });
  });

  group('OnboardingScreen Widget Tests', () {
    late SettingsProvider settings;
    late P2pSyncProvider p2pProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsProvider();
      p2pProvider = P2pSyncProvider();
      await Future.delayed(const Duration(milliseconds: 50));
    });

    Widget buildTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<P2pSyncProvider>.value(value: p2pProvider),
        ],
        child: const MaterialApp(
          home: OnboardingScreen(),
        ),
      );
    }

    testWidgets('Renders onboarding page 1 (Welcome) successfully', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Everything App'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('Navigating next and back pages works', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Page 1 -> Page 2 (Personalization)
      await tester.tap(find.text('Next'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Personalize Your Look'), findsOneWidget);

      // Page 2 -> Page 3 (Modular Powerups)
      await tester.tap(find.text('Next'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Modular Powerups'), findsOneWidget);

      // Page 3 -> Page 4 (On-Device AI Assistant)
      await tester.tap(find.text('Next'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('On-Device AI Assistant'), findsOneWidget);

      // Page 4 -> Page 5 (Ready to Explore!)
      await tester.tap(find.text('Next'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Ready to Explore!'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Back navigation (Page 5 -> Page 4)
      final backFinder = find.byTooltip('Back');
      expect(backFinder, findsOneWidget);
      await tester.tap(backFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('On-Device AI Assistant'), findsOneWidget);
    });

    testWidgets('Toggling theme mode inside onboarding updates settings', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Go to page 2 (Personalization)
      await tester.tap(find.text('Next'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(settings.themeMode, ThemeMode.system);

      // Tap Dark theme tile
      await tester.tap(find.text('Dark'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(settings.themeMode, ThemeMode.dark);
    });

    testWidgets('Toggling modules inside onboarding updates settings', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Go to page 3 (Modular Powerups)
      await tester.tap(find.text('Next'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Test Notes sub-features toggling
      expect(settings.showTagFilterBar, isTrue);
      final tagTileFinder = find.widgetWithText(SwitchListTile, 'Tag Filter Bar');
      expect(tagTileFinder, findsOneWidget);
      await tester.tap(tagTileFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(settings.showTagFilterBar, isFalse);

      expect(settings.minimalEditorMode, isFalse);
      final minimalTileFinder = find.widgetWithText(SwitchListTile, 'Minimal Editor Mode');
      expect(minimalTileFinder, findsOneWidget);
      await tester.tap(minimalTileFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(settings.minimalEditorMode, isTrue);

      // Test Days of Clarity Strip and Collapse Completed Checklists
      expect(settings.showClarityMosaic, isTrue);
      final clarityFinder = find.widgetWithText(SwitchListTile, 'Days of Clarity Strip');
      expect(clarityFinder, findsOneWidget);
      await tester.tap(clarityFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(settings.showClarityMosaic, isFalse);

      expect(settings.moveCompletedChecklistsToBottom, isFalse);
      final collapseFinder = find.widgetWithText(SwitchListTile, 'Collapse Completed Checklists');
      expect(collapseFinder, findsOneWidget);
      await tester.tap(collapseFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(settings.moveCompletedChecklistsToBottom, isTrue);

      expect(settings.showFinancialManager, isFalse);

      // Tap switch tile for Financial Manager
      final tileFinder = find.widgetWithText(SwitchListTile, 'Financial Manager');
      expect(tileFinder, findsOneWidget);
      await tester.tap(tileFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(settings.showFinancialManager, isTrue);
    });

    testWidgets('Toggling Tactile Haptics and selecting language inside onboarding updates settings', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Go to page 2 (Personalization)
      await tester.tap(find.text('Next'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Test Tactile Haptics toggle
      expect(settings.enableHaptics, isTrue);
      final hapticsFinder = find.widgetWithText(SwitchListTile, 'Tactile Haptics');
      expect(hapticsFinder, findsOneWidget);
      await tester.tap(hapticsFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(settings.enableHaptics, isFalse);

      // Test Language selection (e.g. தமிழ்)
      expect(settings.selectedLanguageCode, 'system');
      final tamilFinder = find.widgetWithText(FilterChip, 'தமிழ்');
      expect(tamilFinder, findsOneWidget);
      await tester.ensureVisible(tamilFinder);
      await tester.pumpAndSettle();
      await tester.tap(tamilFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(settings.selectedLanguageCode, 'ta');
    });

    testWidgets('Tapping Configure P2P Sync on page 4 navigates to P2pSyncScreen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Navigate to page 4 (_buildTipsSlide)
      await tester.tap(find.text('Next'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'), warnIfMissed: false);
      await tester.pumpAndSettle();

      final p2pButton = find.text('Configure P2P Sync ➔');
      expect(p2pButton, findsOneWidget);

      await tester.ensureVisible(p2pButton);
      await tester.pumpAndSettle();

      await tester.tap(p2pButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(P2pSyncScreen), findsOneWidget);
    });
  });
}
