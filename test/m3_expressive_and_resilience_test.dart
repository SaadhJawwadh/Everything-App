import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/core/theme/app_layout.dart';
import 'package:note_taking_app/core/ui/app_card.dart';
import 'package:note_taking_app/core/ui/app_chip.dart';
import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/features/settings/presentation/screens/settings_dialogs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M3 Expressive Spring Physics Tokens & Curves', () {
    test('ExpressiveSpringCurve maps boundaries strictly', () {
      const curve = AppLayout.curveExpressiveSpatial as ExpressiveSpringCurve;
      expect(curve.transform(0.0), equals(0.0));
      expect(curve.transform(1.0), equals(1.0));
      expect(curve.transformInternal(-0.5), equals(0.0));
      expect(curve.transformInternal(1.5), equals(1.0));
    });

    test('ExpressiveSpringCurve exhibits physical spring overshoot', () {
      // Bouncy spring has higher overshoot
      const bouncyCurve = AppLayout.curveExpressiveBouncy;
      expect(bouncyCurve.transform(0.0), equals(0.0));
      expect(bouncyCurve.transform(1.0), equals(1.0));

      // Sample along [0, 1] to detect overshoot > 1.0
      bool hasOvershoot = false;
      double maxVal = 0.0;
      for (double t = 0.0; t <= 1.0; t += 0.02) {
        final val = bouncyCurve.transform(t);
        if (val > maxVal) maxVal = val;
        if (val > 1.0) {
          hasOvershoot = true;
        }
      }
      expect(hasOvershoot, isTrue, reason: 'Bouncy spring should overshoot 1.0 before settling');
      expect(maxVal, greaterThan(1.02));
    });

    test('ExpressiveSpringCurve effects curve is snappy and monotonically advances near completion', () {
      const effectsCurve = AppLayout.curveExpressiveEffects;
      expect(effectsCurve.transform(0.0), equals(0.0));
      expect(effectsCurve.transform(1.0), equals(1.0));
      // At t=0.5, snappy spring should already have achieved significant progress
      expect(effectsCurve.transform(0.5), greaterThan(0.70));
    });
  });

  group('AppCard Connected Corner Morphing & Radii', () {
    testWidgets('AppCardGroupPosition.first applies rounded top and connected inner bottom corners', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCard(
              groupPosition: AppCardGroupPosition.first,
              child: Text('First Item'),
            ),
          ),
        ),
      );

      final containerFinder = find.byType(AnimatedContainer);
      expect(containerFinder, findsOneWidget);
      final AnimatedContainer container = tester.widget(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      final borderRadius = decoration.borderRadius as BorderRadius;

      expect(borderRadius.topLeft.x, equals(AppLayout.radiusL)); // 16.0
      expect(borderRadius.topRight.x, equals(AppLayout.radiusL));
      expect(borderRadius.bottomLeft.x, equals(6.0));
      expect(borderRadius.bottomRight.x, equals(6.0));
    });

    testWidgets('AppCardGroupPosition.middle applies connected 6dp corners on all sides', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCard(
              groupPosition: AppCardGroupPosition.middle,
              child: Text('Middle Item'),
            ),
          ),
        ),
      );

      final containerFinder = find.byType(AnimatedContainer);
      expect(containerFinder, findsOneWidget);
      final AnimatedContainer container = tester.widget(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      final borderRadius = decoration.borderRadius as BorderRadius;

      expect(borderRadius.topLeft.x, equals(6.0));
      expect(borderRadius.topRight.x, equals(6.0));
      expect(borderRadius.bottomLeft.x, equals(6.0));
      expect(borderRadius.bottomRight.x, equals(6.0));
    });

    testWidgets('AppCardGroupPosition.last applies connected inner top and rounded bottom corners', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCard(
              groupPosition: AppCardGroupPosition.last,
              borderRadius: 20.0,
              child: Text('Last Item'),
            ),
          ),
        ),
      );

      final containerFinder = find.byType(AnimatedContainer);
      expect(containerFinder, findsOneWidget);
      final AnimatedContainer container = tester.widget(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      final borderRadius = decoration.borderRadius as BorderRadius;

      expect(borderRadius.topLeft.x, equals(6.0));
      expect(borderRadius.topRight.x, equals(6.0));
      expect(borderRadius.bottomLeft.x, equals(20.0));
      expect(borderRadius.bottomRight.x, equals(20.0));
    });

    testWidgets('AppCard with isStadium applies 1000dp stadium pill radius', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCard(
              isStadium: true,
              child: Text('Stadium Button'),
            ),
          ),
        ),
      );

      final containerFinder = find.byType(AnimatedContainer);
      expect(containerFinder, findsOneWidget);
      final AnimatedContainer container = tester.widget(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      final borderRadius = decoration.borderRadius as BorderRadius;

      expect(borderRadius.topLeft.x, equals(AppLayout.radiusStadium)); // 1000.0
      expect(borderRadius.bottomRight.x, equals(AppLayout.radiusStadium));
    });

    testWidgets('AppCard with isSelected applies prominent primary border and tint', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          home: const Scaffold(
            body: AppCard(
              isSelected: true,
              child: Text('Selected Item'),
            ),
          ),
        ),
      );

      final containerFinder = find.byType(AnimatedContainer);
      expect(containerFinder, findsOneWidget);
      final AnimatedContainer container = tester.widget(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;

      expect(border.top.width, equals(1.5));
      expect(border.top.color, isNotNull);
    });
  });

  group('Database Snapshots & Rotation Resilience (Issue #4 & #5)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('db_snapshots_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('DatabaseSnapshotInfo holds immutable metadata', () {
      final now = DateTime.now();
      final info = DatabaseSnapshotInfo(
        path: '/data/snapshots/notes_pre_sync_123.db',
        fileName: 'notes_pre_sync_123.db',
        type: 'pre-sync',
        timestamp: now,
        sizeBytes: 1048576,
      );

      expect(info.path, equals('/data/snapshots/notes_pre_sync_123.db'));
      expect(info.fileName, equals('notes_pre_sync_123.db'));
      expect(info.type, equals('pre-sync'));
      expect(info.timestamp, equals(now));
      expect(info.sizeBytes, equals(1048576));
    });

    test('Snapshot rotation retains newest 5 snapshots and deletes older files', () async {
      final now = DateTime.now();
      final files = <File>[];

      // Create 8 snapshot files with distinct timestamps
      for (int i = 0; i < 8; i++) {
        final file = File('${tempDir.path}/snapshot_$i.db');
        await file.writeAsString('snapshot data $i');
        // Set modification time staggered by minutes
        await file.setLastModified(now.subtract(Duration(minutes: (7 - i) * 10)));
        files.add(file);
      }

      var existing = tempDir.listSync().whereType<File>().toList();
      expect(existing.length, equals(8));

      // Run snapshot rotation
      await DatabaseHelper.rotateSnapshotsForTest(tempDir);

      final remaining = tempDir.listSync().whereType<File>().toList();
      expect(remaining.length, equals(5), reason: 'Rotation must prune to max 5 rolling snapshots');

      // Check that the oldest 3 files (i=0, 1, 2) were removed
      expect(await File('${tempDir.path}/snapshot_0.db').exists(), isFalse);
      expect(await File('${tempDir.path}/snapshot_1.db').exists(), isFalse);
      expect(await File('${tempDir.path}/snapshot_2.db').exists(), isFalse);

      // And newest files (i=3, 4, 5, 6, 7) remain intact
      expect(await File('${tempDir.path}/snapshot_3.db').exists(), isTrue);
      expect(await File('${tempDir.path}/snapshot_7.db').exists(), isTrue);
    });

    test('Snapshot rotation gracefully handles non-existent or empty directories', () async {
      final nonExistentDir = Directory('${tempDir.path}/does_not_exist');
      // Should complete without throwing
      await DatabaseHelper.rotateSnapshotsForTest(nonExistentDir);
      expect(await nonExistentDir.exists(), isFalse);
    });
  });

  group('AppChip M3 Expressive Morphing & Variable Font', () {
    testWidgets('AppChip renders label and adapts font weight/grade on selection', (tester) async {
      bool isSelected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AppChip(
                  label: 'Savings Vault',
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      isSelected = !isSelected;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Savings Vault'), findsOneWidget);
      final textWidgetBefore = tester.widget<Text>(find.text('Savings Vault'));
      expect(textWidgetBefore.style?.fontWeight, equals(FontWeight.w500));

      // Tap to toggle selection
      await tester.tap(find.text('Savings Vault'));
      await tester.pumpAndSettle();

      final textWidgetAfter = tester.widget<Text>(find.text('Savings Vault'));
      expect(textWidgetAfter.style?.fontWeight, equals(FontWeight.bold));
    });
  });

  group('Home Screen Widgets Launcher Pinning Sheet', () {
    testWidgets('showPinWidgetSheet renders widget cards and responds to pin action', (tester) async {
      final List<MethodCall> methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.saadhjawwadh.notebook/widget'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          if (methodCall.method == 'requestPinAppWidget') return true;
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SettingsDialogs.showPinWidgetSheet(context, 'todo'),
                child: const Text('Open Pin Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Pin Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Pin to Home Screen'), findsOneWidget);
      expect(find.text('Action Items & Checklist'), findsOneWidget);
      expect(find.text('Financial Manager'), findsOneWidget);
      expect(find.text('Unified Dual-Domain Capsule'), findsOneWidget);

      // Tap the first 'Pin' button
      final pinButtons = find.widgetWithText(FilledButton, 'Pin');
      expect(pinButtons, findsNWidgets(3));
      await tester.tap(pinButtons.first);
      await tester.pumpAndSettle();

      expect(methodCalls.any((c) => c.method == 'requestPinAppWidget' && c.arguments?['type'] == 'todo'), isTrue);
    });
  });
}
