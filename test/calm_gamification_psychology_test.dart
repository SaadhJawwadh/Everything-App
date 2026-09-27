import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/features/finances/data/models/savings_goal_model.dart';
import 'package:note_taking_app/widgets/clarity_mosaic_strip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Calm Gamification & Interaction Psychology Unit Tests', () {
    test('SettingsProvider showMilestoneDelight and showClarityMosaic default to true and toggle', () async {
      final settings = SettingsProvider();
      await settings.loadSettings();

      expect(settings.showMilestoneDelight, isTrue);
      expect(settings.showClarityMosaic, isTrue);

      await settings.setShowMilestoneDelight(false);
      expect(settings.showMilestoneDelight, isFalse);

      await settings.setShowClarityMosaic(false);
      expect(settings.showClarityMosaic, isFalse);

      // Verify persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('showMilestoneDelight'), isFalse);
      expect(prefs.getBool('showClarityMosaic'), isFalse);
    });

    test('SavingsGoal Goal Gradient Effect (>=75% and remainingAmount)', () {
      final goal = SavingsGoal(
        id: 'goal_test_1',
        title: 'New Laptop',
        targetAmount: 1000.0,
        currentAmount: 800.0,
        createdAt: DateTime.now(),
      );

      expect(goal.progressPercent, 80);
      expect(goal.remainingAmount, 200.0);
      expect(goal.progressPercent >= 75, isTrue);
      expect(goal.isCompleted, isFalse);
    });

    test('SavingsGoal 100% Achieved milestone state', () {
      final completedGoal = SavingsGoal(
        id: 'goal_test_2',
        title: 'Emergency Fund',
        targetAmount: 500.0,
        currentAmount: 500.0,
        createdAt: DateTime.now(),
      );

      expect(completedGoal.progressPercent, 100);
      expect(completedGoal.remainingAmount, 0.0);
      expect(completedGoal.milestoneTier, 4);
      expect(completedGoal.milestoneLabel, 'Completed!');
    });

    testWidgets('ClarityMosaicStrip hides completely when showClarityMosaic is disabled', (tester) async {
      final settings = SettingsProvider();
      await settings.loadSettings();
      await settings.setShowClarityMosaic(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ],
              child: const ClarityMosaicStrip(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ClarityMosaicStrip), findsOneWidget);
      expect(find.textContaining('mindful days'), findsNothing);
    });

    testWidgets('ClarityMosaicStrip renders calm mindful day count when enabled', (tester) async {
      final settings = SettingsProvider();
      await settings.loadSettings();
      await settings.setShowClarityMosaic(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ],
              child: const ClarityMosaicStrip(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ClarityMosaicStrip), findsOneWidget);
      expect(find.textContaining('mindful days'), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
    });
  });
}
