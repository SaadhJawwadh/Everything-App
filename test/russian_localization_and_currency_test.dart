import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/data/category_constants.dart';
import 'package:note_taking_app/data/note_templates.dart';
import 'package:note_taking_app/data/transaction_category.dart';
import 'package:note_taking_app/features/settings/presentation/screens/settings_dialogs.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/l10n/app_localizations.dart';
import 'package:note_taking_app/services/sms_constants.dart';
import 'package:note_taking_app/services/sms_parser.dart';
import 'package:note_taking_app/utils/app_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Russian Localization & Currency Tests', () {
    test('AppConstants includes Russian Ruble (RUB / ₽)', () {
      final rub = AppConstants.getCurrencyInfo('RUB');
      expect(rub.code, equals('RUB'));
      expect(rub.symbol, equals('₽'));
      expect(rub.name, equals('Russian Ruble'));
    });

    test('SettingsDialogs recognizes Russian language display and badge', () {
      expect(SettingsDialogs.getLanguageDisplayName('ru'), equals('Русский (Russian)'));
      expect(SettingsDialogs.getLanguageBadge('ru'), equals('RU'));
    });

    test('AppLocalizations supports Russian with accurate 4-form Slavic pluralization', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(l10n.navNotes, equals('Заметки'));
      expect(l10n.navFinances, equals('Финансы'));
      expect(l10n.navTracker, equals('Цикл'));
      expect(l10n.navSplitBills, equals('Совместные счета'));
      expect(l10n.ledger, equals('Журнал'));

      // Test Slavic 4-form plurals
      expect(l10n.noteCount(0), equals('Нет заметок'));
      expect(l10n.noteCount(1), equals('1 заметка'));
      expect(l10n.noteCount(2), equals('2 заметки'));
      expect(l10n.noteCount(3), equals('3 заметки'));
      expect(l10n.noteCount(4), equals('4 заметки'));
      expect(l10n.noteCount(5), equals('5 заметок'));
      expect(l10n.noteCount(11), equals('11 заметок'));
      expect(l10n.noteCount(20), equals('20 заметок'));
      expect(l10n.noteCount(21), equals('21 заметка'));
      expect(l10n.noteCount(22), equals('22 заметки'));
      expect(l10n.noteCount(25), equals('25 заметок'));
      expect(l10n.noteCount(100), equals('100 заметок'));
      expect(l10n.noteCount(101), equals('101 заметка'));
    });

    testWidgets('TransactionCategory.localizedName translates standard categories in Russian context', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              expect(TransactionCategory.localizedName(context, 'Food & Dining'), equals('Еда и рестораны'));
              expect(TransactionCategory.localizedName(context, 'Transport'), equals('Транспорт'));
              expect(TransactionCategory.localizedName(context, 'Groceries'), equals('Продукты'));
              expect(TransactionCategory.localizedName(context, 'Shopping'), equals('Покупки'));
              expect(TransactionCategory.localizedName(context, 'Custom Crypto'), equals('Custom Crypto'));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    test('SmsConstants and CategoryConstants support generic self-transfer patterns', () {
      expect(SmsConstants.selfTransferRegex.hasMatch('transfer to own account'), isTrue);
      expect(SmsConstants.selfTransferRegex.hasMatch('self transfer'), isTrue);
      expect(CategoryConstants.keywords[CategoryConstants.transfer]!.contains('transfer to own account'), isTrue);
    });

    test('SmsParser parses Russian bank SMS messages (Sberbank, Tinkoff, VTB)', () {
      // 1. Sberbank 900 debit
      const sberBody = 'Покупка 1500р Баланс: 12500.50р';
      final sberParsed = SmsParser.parseMessage(
        body: sberBody,
        address: '900',
        messageId: 101,
        messageDate: DateTime.now().millisecondsSinceEpoch,
        allowedSenderIds: const {},
        blockedSenderIds: const {},
        customExpenseRules: const [],
        customIncomeRules: const [],
        preferredCurrency: '₽',
      );
      expect(sberParsed, isNotNull);
      expect(sberParsed!.amount, equals(1500.0));
      expect(sberParsed.isExpense, isTrue);

      // 2. Tinkoff debit with space separator and ₽ symbol
      const tinkoffBody = 'Списание 2 450 ₽ Карта *1234 Остаток: 50 000 ₽';
      final tinkoffParsed = SmsParser.parseMessage(
        body: tinkoffBody,
        address: 'Tinkoff',
        messageId: 102,
        messageDate: DateTime.now().millisecondsSinceEpoch,
        allowedSenderIds: const {},
        blockedSenderIds: const {},
        customExpenseRules: const [],
        customIncomeRules: const [],
      );
      expect(tinkoffParsed, isNotNull);
      expect(tinkoffParsed!.amount, equals(2450.0));
      expect(tinkoffParsed.isExpense, isTrue);

      // 3. VTB credit salary
      const vtbBody = 'Зачисление 35000 RUB Зарплата Баланс: 40000 RUB';
      final vtbParsed = SmsParser.parseMessage(
        body: vtbBody,
        address: 'VTB',
        messageId: 103,
        messageDate: DateTime.now().millisecondsSinceEpoch,
        allowedSenderIds: const {},
        blockedSenderIds: const {},
        customExpenseRules: const [],
        customIncomeRules: const [],
      );
      expect(vtbParsed, isNotNull);
      expect(vtbParsed!.amount, equals(35000.0));
      expect(vtbParsed.isExpense, isFalse);
    });

    test('locales_config.xml exists and declares all supported locales for Android 13+', () {
      final file = File('android/app/src/main/res/xml/locales_config.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('<locale android:name="en"/>'), isTrue);
      expect(content.contains('<locale android:name="ru"/>'), isTrue);
      expect(content.contains('<locale android:name="zh"/>'), isTrue);
      expect(content.contains('<locale android:name="pt"/>'), isTrue);
      expect(content.contains('<locale android:name="es"/>'), isTrue);
      expect(content.contains('<locale android:name="fr"/>'), isTrue);
      expect(content.contains('<locale android:name="de"/>'), isTrue);
      expect(content.contains('<locale android:name="ta"/>'), isTrue);
    });

    testWidgets('NoteTemplate.all translates templates into Russian when provided l10n', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              final templates = NoteTemplate.all(l10n);
              expect(templates[0].name, equals('Заметки со встречи'));
              expect(templates[0].description, equals('Повестка, обсуждение и задачи'));
              expect(templates[1].name, equals('Список покупок'));
              expect(templates[1].description, equals('Готовый список с флажками'));
              expect(templates[2].name, equals('Дневник'));
              expect(templates[2].description, equals('Вопросы для ежедневных размышлений'));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('Settings Hub Cards and Appearance titles render in Russian', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              expect(l10n.appearance, equals('Оформление и интерфейс'));
              expect(l10n.notesAndEditorWorkspace, equals('Заметки и редактор'));
              expect(l10n.financesAndHealthModules, equals('Финансы и здоровье'));
              expect(l10n.privacyAndSecurity, equals('Конфиденциальность и защита'));
              expect(l10n.syncAndBackups, equals('Синхронизация и копии'));
              expect(l10n.aboutAndDeviceAi, equals('О приложении и ИИ'));
              expect(l10n.preferencesAndWorkspaces, equals('Настройки и разделы'));
              expect(l10n.startFromTemplate, equals('Создать по шаблону'));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('SettingsDialogs.showLanguagePicker renders scrollable ListView with Russian option', (WidgetTester tester) async {
      final settings = SettingsProvider();
      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SettingsDialogs.showLanguagePicker(context, settings),
                child: const Text('Open Language Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Language Picker'));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Русский'),
        100.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Русский'), findsOneWidget);
      expect(find.text('Russian (Россия / СНГ)'), findsOneWidget);
    });

    testWidgets('HomeAppBar and Folder picker keys translate properly in Russian', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              expect(l10n.allNotes, equals('Все заметки'));
              expect(l10n.checklistsAndTasks, equals('Списки и задачи'));
              expect(l10n.archivedNotes, equals('Архивные заметки'));
              expect(l10n.trashBin, equals('Корзина'));
              expect(l10n.sortNotes, equals('Сортировка заметок'));
              expect(l10n.sortByLastModified, equals('По дате изменения'));
              expect(l10n.sortByDateCreated, equals('По дате создания'));
              expect(l10n.sortByTitle, equals('По названию'));
              expect(l10n.sortByColor, equals('По цвету'));
              expect(l10n.importNotes, equals('Импорт заметок'));
              expect(l10n.switchToGridView, equals('Переключить на сетку'));
              expect(l10n.switchToListView, equals('Переключить на список'));
              expect(l10n.createNewFolder, equals('Создать новую папку'));
              expect(l10n.folderName, equals('Название папки'));
              expect(l10n.filterByFolder, equals('Фильтр по папкам'));
              expect(l10n.newFolder, equals('Новая папка'));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('FinanceDateRangeSheet presets translate properly in Russian', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              expect(l10n.selectPeriod, equals('Выберите период'));
              expect(l10n.thisMonth, equals('Этот месяц'));
              expect(l10n.lastMonth, equals('Прошлый месяц'));
              expect(l10n.last90Days, equals('Последние 90 дней'));
              expect(l10n.thisYear, equals('Этот год'));
              expect(l10n.allTime, equals('За все время'));
              expect(l10n.customDateRange, equals('Свой диапазон дат…'));
              expect(l10n.customDateRangeSubtitle, equals('Точные даты начала и конца из календаря'));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('NoteCard checklist item plurals translate properly in Russian', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              expect(l10n.allTasksCompleted(1), equals('Все 1 задача выполнена'));
              expect(l10n.allTasksCompleted(3), equals('Все 3 задачи выполнены'));
              expect(l10n.allTasksCompleted(5), equals('Все 5 задач выполнено'));
              expect(l10n.moreItems(1), equals('+еще 1 пункт'));
              expect(l10n.moreItems(2), equals('+еще 2 пункта'));
              expect(l10n.moreItems(5), equals('+еще 5 пунктов'));
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}
