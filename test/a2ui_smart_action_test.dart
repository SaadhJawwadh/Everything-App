import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:note_taking_app/data/category_constants.dart';
import 'package:note_taking_app/data/transaction_model.dart';
import 'package:note_taking_app/features/finances/providers/financial_manager_provider.dart';
import 'package:note_taking_app/features/finances/providers/split_bill_provider.dart';
import 'package:note_taking_app/features/notes/providers/note_provider.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/services/local_ai_service.dart';
import 'package:note_taking_app/services/offline_ai_fallback_service.dart';
import 'package:note_taking_app/widgets/home/a2ui_smart_action_card.dart';
import 'package:note_taking_app/widgets/home/keyboard_shortcuts_dialog.dart';

class _FakeLocalAiService implements LocalAiService {
  final bool supported;
  _FakeLocalAiService({this.supported = false});

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<String?> generateText(String prompt) async => null;

  @override
  Future<String?> summarize(String text) async =>
      OfflineAiFallbackService.summarize(text);

  @override
  Future<List<String>> suggestTags(
    String noteContent,
    List<String> existingTags,
  ) async =>
      OfflineAiFallbackService.suggestTags(noteContent, existingTags);

  @override
  Future<Map<String, dynamic>?> parseSmsTransaction(
    String smsBody,
    List<String> categories,
  ) async =>
      OfflineAiFallbackService.parseSmsTransaction(smsBody, categories);

  @override
  Future<String?> refineTransactionDescription(
    String rawDescription,
    String smsBody,
  ) async =>
      rawDescription;

  @override
  Future<String?> refineText(String text, String mode) async => text;

  @override
  Future<Map<String, dynamic>?> parseNaturalLanguageAction(
    String query,
    List<String> categories,
  ) async {
    final base = OfflineAiFallbackService.parseNaturalLanguageAction(
      query,
      categories,
    );
    if (base != null && base['type'] == 'transaction') {
      return {
        ...base,
        'description': 'AI Refined Coffee',
      };
    }
    return base;
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'showFinancialManager': true,
      'showSplitBills': true,
      'isPeriodTrackerEnabled': true,
      'useOnDeviceAi': true,
    });
  });

  group('OfflineAiFallbackService.parseNaturalLanguageAction', () {
    const categories = CategoryConstants.all;

    test('parses expense intent with verb and category matching', () {
      final res = OfflineAiFallbackService.parseNaturalLanguageAction(
        'Spent 450 on coffee',
        categories,
      );
      expect(res, isNotNull);
      expect(res!['type'], 'transaction');
      expect(res['amount'], 450.0);
      expect(res['description'], 'Coffee');
      expect(res['category'], CategoryConstants.food);
      expect(res['isExpense'], isTrue);
      expect(res['accountType'], AccountType.daily);
    });

    test('parses income and savings vault deposit intent', () {
      final res = OfflineAiFallbackService.parseNaturalLanguageAction(
        'Saved 5000 salary into savings',
        categories,
      );
      expect(res, isNotNull);
      expect(res!['type'], 'transaction');
      expect(res['amount'], 5000.0);
      expect(res['isExpense'], isFalse);
      expect(res['accountType'], AccountType.savings);
    });

    test('parses split bill intent with participant count', () {
      final res = OfflineAiFallbackService.parseNaturalLanguageAction(
        'split 1200 dinner by 3',
        categories,
      );
      expect(res, isNotNull);
      expect(res!['type'], 'split_bill');
      expect(res['amount'], 1200.0);
      expect(res['title'], 'Dinner');
      expect(res['participantCount'], 3);
    });

    test('parses checklist / todo intent', () {
      final res = OfflineAiFallbackService.parseNaturalLanguageAction(
        'todo buy groceries',
        categories,
      );
      expect(res, isNotNull);
      expect(res!['type'], 'todo');
      expect(res['taskText'], 'Buy groceries');
    });

    test('parses quick note intent', () {
      final res = OfflineAiFallbackService.parseNaturalLanguageAction(
        'note flight confirmation AB123',
        categories,
      );
      expect(res, isNotNull);
      expect(res!['type'], 'note');
      expect(res['content'], 'Flight confirmation AB123');
    });

    test('ignores plain non-actionable search queries like years', () {
      final res = OfflineAiFallbackService.parseNaturalLanguageAction(
        '2026 roadmap',
        categories,
      );
      expect(res, isNull);
    });
  });

  group('A2uiSmartActionCard & KeyboardShortcutsDialog widgets', () {
    Widget buildTestHarness(
      Widget child, {
      bool aiSupported = false,
      bool showFinances = true,
      bool showSplitBills = true,
    }) {
      SharedPreferences.setMockInitialValues({
        'showFinancialManager': showFinances,
        'showSplitBills': showSplitBills,
        'useOnDeviceAi': aiSupported,
      });
      final aiService = _FakeLocalAiService(supported: aiSupported);
      final settings = SettingsProvider();
      settings.checkAiCoreSupport(aiService);

      return MultiProvider(
        providers: [
          Provider<LocalAiService>.value(value: aiService),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<NoteProvider>(create: (_) => NoteProvider()),
          ChangeNotifierProvider<FinancialManagerProvider>(
            create: (_) => FinancialManagerProvider(),
          ),
          ChangeNotifierProvider<SplitBillProvider>(
            create: (_) => SplitBillProvider(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('renders expense A2uiSmartActionCard and toggles Daily/Savings account', (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          const A2uiSmartActionCard(query: 'Spent 450 on coffee'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('a2ui_smart_action_card')), findsOneWidget);
      expect(find.textContaining('Coffee'), findsOneWidget);
      expect(find.text('Log Expense'), findsOneWidget);
      expect(find.text('Daily Account'), findsOneWidget);

      // Tap account toggle chip to switch to Savings Vault
      await tester.tap(find.byKey(const ValueKey('a2ui_account_toggle_chip')));
      await tester.pumpAndSettle();

      expect(find.text('Savings Vault'), findsOneWidget);
    });

    testWidgets('hides financial A2uiSmartActionCard when showFinancialManager is false', (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          const A2uiSmartActionCard(query: 'Spent 450 on coffee'),
          showFinances: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('a2ui_smart_action_card')), findsNothing);
    });

    testWidgets('renders KeyboardShortcutsDialog with expected shortcut pills', (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          const KeyboardShortcutsDialog(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Keyboard Shortcuts'), findsOneWidget);
      expect(find.text('Ctrl + N'), findsOneWidget);
      expect(find.text('Ctrl + T'), findsOneWidget);
      expect(find.text('Ctrl + F'), findsOneWidget);
      expect(find.text('Ctrl + /'), findsOneWidget);
      expect(find.text('Esc'), findsOneWidget);
    });
  });
}
