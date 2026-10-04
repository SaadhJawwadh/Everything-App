import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/data/transaction_model.dart';
import 'package:note_taking_app/data/custom_sms_rule.dart';
import 'package:note_taking_app/services/sms_parser.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/features/finances/presentation/widgets/account_transfer_sheet.dart';
import 'package:note_taking_app/features/finances/providers/financial_manager_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TransactionModel & isAiRefined', () {
    test('defaults isAiRefined to false and serializes properly', () {
      final tx = TransactionModel(
        amount: 1500.0,
        description: 'Supermarket Grocery',
        date: DateTime(2026, 8, 27),
        isExpense: true,
        category: 'Food',
        account: AccountType.daily,
      );

      expect(tx.isAiRefined, isFalse);
      final json = tx.toJson();
      expect(json['isAiRefined'], equals(0));

      final fromJson = TransactionModel.fromJson(json);
      expect(fromJson.isAiRefined, isFalse);

      final refinedTx = tx.copy(isAiRefined: true);
      expect(refinedTx.isAiRefined, isTrue);
      expect(refinedTx.toJson()['isAiRefined'], equals(1));
      expect(TransactionModel.fromJson(refinedTx.toJson()).isAiRefined, isTrue);
    });
  });

  group('CustomSmsRule & targetAccount', () {
    test('stores and serializes targetAccount', () {
      final rule = CustomSmsRule(
        id: 'rule_123',
        keyword: 'Salary',
        type: RuleTransactionType.income,
        category: 'Salary',
        targetAccount: 'savings',
        createdAt: DateTime(2026, 8, 27),
      );

      final map = rule.toMap();
      expect(map['targetAccount'], equals('savings'));

      final fromMap = CustomSmsRule.fromMap(map);
      expect(fromMap.targetAccount, equals('savings'));
    });
  });

  group('SmsParser Account Resolution & Routing', () {
    test('rule targetAccount overrides category and keywords', () {
      final rule = CustomSmsRule(
        id: 'rule_1',
        keyword: 'Vault Deposit',
        type: RuleTransactionType.expense,
        category: 'Savings',
        targetAccount: 'daily',
        createdAt: DateTime(2026, 8, 27),
      );

      final account = SmsParser.resolveAccount(
        body: 'Transferred to Vault Deposit LKR 50,000',
        category: 'Savings',
        matchingRule: rule,
        categoryAccountRouting: {'Savings': 'savings'},
      );

      expect(account, equals('daily'));
    });

    test('category routing applies when no explicit rule target exists', () {
      final account = SmsParser.resolveAccount(
        body: 'Monthly ETF Investment LKR 20,000',
        category: 'Investments',
        categoryAccountRouting: {'Investments': 'savings'},
      );

      expect(account, equals('savings'));
    });

    test('keyword fallback recognizes savings keywords when unrouted', () {
      final account = SmsParser.resolveAccount(
        body: 'Fixed deposit credit interest LKR 4,200',
        category: 'Other',
      );

      expect(account, equals('savings'));
    });

    test('defaults to daily for ordinary expenses', () {
      final account = SmsParser.resolveAccount(
        body: 'Paid LKR 1,200 at Keells Supermarket',
        category: 'Food',
      );

      expect(account, equals('daily'));
    });
  });

  group('SettingsProvider Account Customization', () {
    test('persists custom account names and returns dynamic display name', () async {
      final settings = SettingsProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(settings.account1Name, equals('Daily'));
      expect(settings.account2Name, equals('Savings'));
      expect(settings.getAccountDisplayName(AccountType.daily), equals('Daily'));
      expect(settings.getAccountDisplayName(AccountType.savings), equals('Savings'));

      await settings.setAccount1Name('Commercial Bank');
      await settings.setAccount2Name('HNB Vault');

      expect(settings.account1Name, equals('Commercial Bank'));
      expect(settings.account2Name, equals('HNB Vault'));
      expect(settings.getAccountDisplayName(AccountType.daily), equals('Commercial Bank'));
      expect(settings.getAccountDisplayName(AccountType.savings), equals('HNB Vault'));

      await settings.setCategoryAccountRouting('Investments', 'savings');
      expect(settings.categoryAccountRouting['Investments'], equals('savings'));

      await settings.setCategoryAccountRouting('Investments', null);
      expect(settings.categoryAccountRouting.containsKey('Investments'), isFalse);
    });
  });

  group('AccountTransferSheet Widget Tests', () {
    late Database testDb;

    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      testDb = await openDatabase(
        inMemoryDatabasePath,
        version: 19,
        onCreate: (db, version) async {
          await DatabaseHelper.instance.createTestDatabase(db);
        },
      );
      DatabaseHelper.setMockDatabase(testDb);
    });

    tearDown(() async {
      await testDb.close();
      DatabaseHelper.setMockDatabase(null);
    });

    testWidgets('Renders connected flow card, swaps accounts, and responds to preset chips', (tester) async {
      final settings = SettingsProvider();
      final finance = FinancialManagerProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<FinancialManagerProvider>.value(value: finance),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AccountTransferSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check account headers
      expect(find.text('FROM ACCOUNT'), findsOneWidget);
      expect(find.text('TO ACCOUNT'), findsOneWidget);

      // Check preset chips
      expect(find.text('+100'), findsOneWidget);
      expect(find.text('+500'), findsOneWidget);
      expect(find.text('+1,000'), findsOneWidget);
      expect(find.text('+5,000'), findsOneWidget);

      // Tap preset chip +500
      await tester.tap(find.text('+500'));
      await tester.pumpAndSettle();

      // Verify amount updated to 500
      expect(find.text('500'), findsOneWidget);

      // Tap swap accounts button
      await tester.tap(find.byIcon(Icons.swap_vert_rounded));
      await tester.pumpAndSettle();

      // Check CTA label
      expect(find.text('Transfer to Daily'), findsOneWidget);
    });
  });
}
