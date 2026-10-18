import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/core/theme/app_layout.dart';
import 'package:note_taking_app/core/theme/app_theme.dart';
import 'package:note_taking_app/widgets/bouncing_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Animation Engineering Invariants & Sub-300ms UI Discipline', () {
    test('Standard UI durations enforce sub-300ms budget', () {
      expect(AppLayout.animMicro.inMilliseconds, lessThanOrEqualTo(300));
      expect(AppLayout.animFast.inMilliseconds, lessThanOrEqualTo(300));
      expect(AppLayout.animShort.inMilliseconds, lessThanOrEqualTo(300));
      expect(AppLayout.animModal.inMilliseconds, lessThanOrEqualTo(300));
      expect(AppLayout.animDefault.inMilliseconds, lessThanOrEqualTo(300));

      expect(AppLayout.animMicro, equals(const Duration(milliseconds: 140)));
      expect(AppLayout.animFast, equals(const Duration(milliseconds: 180)));
      expect(AppLayout.animShort, equals(const Duration(milliseconds: 200)));
      expect(AppLayout.animModal, equals(const Duration(milliseconds: 250)));
      expect(AppLayout.animDefault, equals(const Duration(milliseconds: 300)));
      expect(AppLayout.animTrustBeat, equals(const Duration(milliseconds: 420)));
    });

    test('Strong curves evaluate front-loaded progress (>0.65 at t=0.3)', () {
      const strongEaseOut = AppLayout.curveStrongEaseOut;
      expect(strongEaseOut.transform(0.0), closeTo(0.0, 0.001));
      expect(strongEaseOut.transform(1.0), closeTo(1.0, 0.001));
      expect(
        strongEaseOut.transform(0.3),
        greaterThan(0.65),
        reason: 'Strong ease-out must front-load visual movement in the first 30% of duration',
      );

      const strongEaseInOut = AppLayout.curveStrongEaseInOut;
      expect(strongEaseInOut.transform(0.0), closeTo(0.0, 0.001));
      expect(strongEaseInOut.transform(1.0), closeTo(1.0, 0.001));

      const sheetCurve = AppLayout.curveSheet;
      expect(sheetCurve.transform(0.0), closeTo(0.0, 0.001));
      expect(sheetCurve.transform(1.0), closeTo(1.0, 0.001));
    });

    testWidgets('scaleFadeTransitionBuilder starts at scale 0.92 and opacity 0.0 (never scale 0)', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 200),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppLayout.scaleFadeTransitionBuilder(
            const Text('Test Child'),
            controller,
          ),
        ),
      );

      final scaleWidget = tester.widget<ScaleTransition>(find.byType(ScaleTransition));
      final fadeWidget = tester.widget<FadeTransition>(find.byType(FadeTransition));

      expect(scaleWidget.scale.value, closeTo(0.92, 0.001),
          reason: 'Scale transition must never start from 0.0 volume');
      expect(fadeWidget.opacity.value, closeTo(0.0, 0.001));

      controller.value = 1.0;
      await tester.pump();

      expect(scaleWidget.scale.value, closeTo(1.0, 0.001));
      expect(fadeWidget.opacity.value, closeTo(1.0, 0.001));
    });

    testWidgets('shouldReduceMotion queries MediaQuery.maybeDisableAnimationsOf', (tester) async {
      bool? detectedReducedMotion;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                detectedReducedMotion = AppLayout.shouldReduceMotion(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(detectedReducedMotion, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: false),
            child: Builder(
              builder: (context) {
                detectedReducedMotion = AppLayout.shouldReduceMotion(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(detectedReducedMotion, isFalse);
    });

    testWidgets('BouncingWidget bypasses scale transforms when disableAnimations is true', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: BouncingWidget(
                onTap: () => tapped = true,
                child: const Text('Bounce Target'),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('Bounce Target')));
      await tester.pump(const Duration(milliseconds: 50));

      final bouncingTransformFinder = find.descendant(
        of: find.byType(BouncingWidget),
        matching: find.byType(Transform),
      );
      expect(bouncingTransformFinder, findsNothing,
          reason: 'Reduced motion must bypass scale transforms inside BouncingWidget');

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('BouncingWidget animates to scale 0.97 on press-down when animations enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: false),
            child: Scaffold(
              body: BouncingWidget(
                onTap: () {},
                child: const Text('Bounce Target'),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('Bounce Target')));
      // Allow TapGestureRecognizer kPressTimeout to fire onTapDown and animation to advance
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 60));

      final bouncingTransformFinder = find.descendant(
        of: find.byType(BouncingWidget),
        matching: find.byType(Transform),
      );
      final transform = tester.widget<Transform>(bouncingTransformFinder);
      expect(transform.transform.entry(0, 0), closeTo(0.97, 0.01),
          reason: 'BouncingWidget press-in must scale to 0.97');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    test('Global TooltipThemeData in AppTheme configures skip-delay hygiene', () {
      final lightTheme = AppTheme.createTheme(null, Brightness.light);
      final darkTheme = AppTheme.createTheme(null, Brightness.dark);

      expect(lightTheme.tooltipTheme.waitDuration, equals(const Duration(milliseconds: 500)));
      expect(lightTheme.tooltipTheme.showDuration, equals(const Duration(milliseconds: 1500)));

      expect(darkTheme.tooltipTheme.waitDuration, equals(const Duration(milliseconds: 500)));
      expect(darkTheme.tooltipTheme.showDuration, equals(const Duration(milliseconds: 1500)));
    });
  });
}
