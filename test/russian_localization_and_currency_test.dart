import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/data/category_constants.dart';
import 'package:note_taking_app/data/transaction_category.dart';
import 'package:note_taking_app/features/settings/presentation/screens/settings_dialogs.dart';
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
  });
}
