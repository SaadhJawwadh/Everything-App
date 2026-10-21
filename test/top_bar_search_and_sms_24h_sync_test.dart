import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:note_taking_app/core/theme/app_theme.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/providers/note_provider.dart';
import 'package:note_taking_app/features/sync/providers/p2p_sync_provider.dart';
import 'package:note_taking_app/features/finances/providers/financial_manager_provider.dart';
import 'package:note_taking_app/features/finances/presentation/screens/financial_manager_screen.dart';
import 'package:note_taking_app/widgets/home/home_app_bar.dart';
import 'package:note_taking_app/features/finances/presentation/widgets/sms_import_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Top Bar Scope Pill & Contrast Tests', () {
    testWidgets('HomeAppBar renders Folder Scope Pill with M3 Tonal Container styling', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => NoteProvider()),
            ChangeNotifierProvider(create: (_) => P2pSyncProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.createTheme(null, Brightness.light),
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  HomeAppBar(
                    onClearSelection: () {},
                    onBulkArchive: () {},
                    onBulkDelete: () {},
                    onBulkTag: () {},
                    onBulkMoveToFolder: () {},
                    onCycleViewMode: () {},
                    onRefresh: () async {},
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 200),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify folder scope pill text is rendered
      expect(find.text('Notes'), findsWidgets);
      final chevronFinder = find.byIcon(Icons.keyboard_arrow_down_rounded);
      expect(chevronFinder, findsWidgets);

      // Verify pill container decoration
      final containerFinder = find.ancestor(
        of: chevronFinder.first,
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);

      for (final element in containerFinder.evaluate()) {
        final widget = element.widget as Container;
        final decoration = widget.decoration as BoxDecoration?;
        if (decoration?.border != null) {
          expect(decoration!.border, isNotNull);
          return;
        }
      }
      fail('No Container with border found in ancestor tree of chevron');
    });

    testWidgets('HomeAppBar renders dedicated Sort button and opens sort menu', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => NoteProvider()),
            ChangeNotifierProvider(create: (_) => P2pSyncProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.createTheme(null, Brightness.light),
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  HomeAppBar(
                    onClearSelection: () {},
                    onBulkArchive: () {},
                    onBulkDelete: () {},
                    onBulkTag: () {},
                    onBulkMoveToFolder: () {},
                    onCycleViewMode: () {},
                    onRefresh: () async {},
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 200),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify dedicated sort button exists
      final sortButton = find.byIcon(Icons.sort_rounded);
      expect(sortButton, findsOneWidget);

      // Verify Notes Tools button exists
      final toolsButton = find.byIcon(Icons.more_vert_rounded);
      expect(toolsButton, findsOneWidget);

      // Tap sort button and verify sort options appear
      await tester.tap(sortButton);
      await tester.pumpAndSettle();

      expect(find.text('Sort by Last Modified'), findsOneWidget);
      expect(find.text('Sort by Date Created'), findsOneWidget);
      expect(find.text('Sort by Title'), findsOneWidget);
      expect(find.text('Sort by Color'), findsOneWidget);
      // Tools items should NOT be in the sort menu
      expect(find.text('Manage Folders'), findsNothing);
      expect(find.text('Trash Bin'), findsNothing);
    });
  });

  group('Finances Top Bar Search Mode Tests', () {
    testWidgets('Tapping search icon opens top bar search field and hides normal pill', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => NoteProvider()),
            ChangeNotifierProvider(create: (_) => FinancialManagerProvider()),
            ChangeNotifierProvider(create: (_) => P2pSyncProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.createTheme(null, Brightness.light),
            home: const FinancialManagerScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Initial state: normal header is present
      expect(find.text('Finances'), findsOneWidget);
      expect(find.byTooltip('Search transactions'), findsOneWidget);

      // Tap search icon
      await tester.tap(find.byTooltip('Search transactions'));
      await tester.pump(const Duration(milliseconds: 300));

      // In search mode: search TextField is visible, normal title is hidden
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Exit search'), findsOneWidget);
      expect(find.text('Finances'), findsNothing);

      // Exit search mode
      await tester.tap(find.byTooltip('Exit search'));
      await tester.pump(const Duration(milliseconds: 300));

      // Returns to normal mode
      expect(find.text('Finances'), findsOneWidget);
      expect(find.byTooltip('Search transactions'), findsOneWidget);
    });
  });

  group('SMS 24-Hour Default & Import Sheet Tests', () {
    testWidgets('SmsImportSheet options start with Last 24 hours (Default) and omit incremental fetch', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SmsImportSheet(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify "Last 24 hours (Default)" is present
      expect(find.text('Last 24 hours (Default)'), findsOneWidget);
      // Verify "Since Last Sync (Incremental)" is completely removed
      expect(find.textContaining('Since Last Sync'), findsNothing);
    });
  });
}
