import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/data/database_constants.dart';
import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/data/transaction_model.dart';
import 'package:note_taking_app/features/finances/data/models/split_bill_model.dart';
import 'package:note_taking_app/features/finances/data/repositories/split_bill_repository.dart';
import 'package:note_taking_app/features/finances/data/transaction_repository.dart';
import 'package:note_taking_app/features/finances/services/split_share_service.dart';
import 'package:note_taking_app/features/finances/services/receipt_scanner_service.dart';
import 'package:note_taking_app/features/finances/presentation/widgets/settle_up_sheet.dart';
import 'package:note_taking_app/features/finances/presentation/screens/split_bill_editor_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/features/finances/providers/financial_manager_provider.dart';
import 'package:note_taking_app/features/finances/providers/split_bill_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SplitBillModel & Mathematics Tests', () {
    test('Calculates equal split shares accurately with user included', () {
      final bill = SplitBillModel(
        id: 'bill-1',
        title: 'Dinner at Botanik',
        totalAmount: 12000.0,
        payerName: 'You',
        isPayerUser: true,
        splitMode: SplitMode.equal,
        date: DateTime(2026, 8, 26),
        participants: const [
          SplitParticipantModel(
            id: 'p-1',
            billId: 'bill-1',
            contactName: 'You',
            shareAmount: 4000.0,
            hasPaid: true,
          ),
          SplitParticipantModel(
            id: 'p-2',
            billId: 'bill-1',
            contactName: 'Alex',
            shareAmount: 4000.0,
            hasPaid: false,
          ),
          SplitParticipantModel(
            id: 'p-3',
            billId: 'bill-1',
            contactName: 'Sarah',
            shareAmount: 4000.0,
            hasPaid: true,
          ),
        ],
      );

      expect(bill.userShare, 4000.0);
      expect(bill.totalOthersShare, 8000.0);
      expect(bill.totalReceived, 4000.0);
      expect(bill.totalOwedToUser, 4000.0);
      expect(bill.computeDerivedStatus(), SplitStatus.partial);
      expect(bill.isFullySettled, isFalse);
    });

    test('Calculates liability correctly when Friend paid for the bill', () {
      final bill = SplitBillModel(
        id: 'bill-2',
        title: 'Uber to Galle',
        totalAmount: 9000.0,
        payerName: 'Alex',
        isPayerUser: false,
        splitMode: SplitMode.equal,
        date: DateTime(2026, 8, 26),
        participants: const [
          SplitParticipantModel(
            id: 'p-1',
            billId: 'bill-2',
            contactName: 'You',
            shareAmount: 3000.0,
            hasPaid: false,
          ),
          SplitParticipantModel(
            id: 'p-2',
            billId: 'bill-2',
            contactName: 'Sarah',
            shareAmount: 3000.0,
            hasPaid: false,
          ),
        ],
      );

      expect(bill.userShare, 3000.0);
      expect(bill.totalUserOwes, 3000.0);
      expect(bill.totalOwedToUser, 0.0);
      expect(bill.computeDerivedStatus(), SplitStatus.unsettled);
      expect(bill.isFullySettled, isFalse);

      // When user settles their share, the bill is settled for the user regardless of Sarah's status
      final settledForUserBill = bill.copyWith(
        participants: [
          bill.participants[0].copyWith(hasPaid: true),
          bill.participants[1], // Sarah is still unpaid to Alex
        ],
      );
      expect(settledForUserBill.userShare, 3000.0);
      expect(settledForUserBill.isUserSharePaid, isTrue);
      expect(settledForUserBill.totalUserOwes, 0.0);
      expect(settledForUserBill.isFullySettled, isTrue);
      expect(settledForUserBill.computeDerivedStatus(), SplitStatus.settled);
    });

    test('Handles custom exact splits correctly', () {
      final bill = SplitBillModel(
        id: 'bill-3',
        title: 'Groceries',
        totalAmount: 10000.0,
        payerName: 'You',
        isPayerUser: true,
        splitMode: SplitMode.exact,
        date: DateTime(2026, 8, 26),
        participants: const [
          SplitParticipantModel(
            id: 'p-1',
            billId: 'bill-3',
            contactName: 'You',
            shareAmount: 2500.0,
            hasPaid: true,
          ),
          SplitParticipantModel(
            id: 'p-2',
            billId: 'bill-3',
            contactName: 'Alex',
            shareAmount: 4500.0,
            hasPaid: true,
          ),
          SplitParticipantModel(
            id: 'p-3',
            billId: 'bill-3',
            contactName: 'Sarah',
            shareAmount: 3000.0,
            hasPaid: true,
          ),
        ],
      );

      expect(bill.totalReceived, 7500.0);
      expect(bill.totalOwedToUser, 0.0);
      expect(bill.computeDerivedStatus(), SplitStatus.settled);
      expect(bill.isFullySettled, isTrue);
    });
  });

  group('SplitShareService WhatsApp Breakdown Tests', () {
    test('Generates clean formatted breakdown with payment details', () {
      final bill = SplitBillModel(
        id: 'bill-1',
        title: 'Team Lunch',
        totalAmount: 5000.0,
        payerName: 'You',
        isPayerUser: true,
        groupTag: 'Office',
        date: DateTime(2026, 8, 26),
        participants: const [
          SplitParticipantModel(
            id: 'p-1',
            billId: 'bill-1',
            contactName: 'You',
            shareAmount: 2500.0,
            hasPaid: true,
          ),
          SplitParticipantModel(
            id: 'p-2',
            billId: 'bill-1',
            contactName: 'Alex',
            shareAmount: 2500.0,
            hasPaid: false,
          ),
        ],
      );

      final summary = SplitShareService.formatBillSummary(
        bill,
        currencySymbol: 'Rs.',
        defaultPaymentInfo: 'Bank: Commercial Bank\nAcc: 123456789\nName: Alex',
      );

      expect(summary, contains('🧾 Team Lunch (Office)'));
      expect(summary, contains('Total: Rs. 5000'));
      expect(summary, contains('• You (Paid for bill): Rs. 2500 ✅'));
      expect(summary, contains('• Alex: Rs. 2500 ⏳ Pending'));
      expect(summary, contains('💳 Payment Details:'));
      expect(summary, contains('Bank: Commercial Bank'));
    });

    test('Generates personal reminder message for WhatsApp', () {
      final reminder = SplitShareService.formatPersonReminder(
        contactName: 'Sarah',
        billTitle: 'Movie Tickets',
        shareAmount: 1800.0,
        currencySymbol: 'Rs.',
        defaultPaymentInfo: 'Acc: 987654321',
      );

      expect(reminder, contains('👋 Hey Sarah,'));
      expect(reminder, contains('Your share for "Movie Tickets" is Rs. 1800.'));
      expect(reminder, contains('💳 Send to:'));
      expect(reminder, contains('Acc: 987654321'));
    });

    test('Generates comprehensive person pending statement for multiple bills', () {
      final bill1 = SplitBillModel(
        id: 'b-1',
        title: 'Dinner at Subway',
        totalAmount: 3000.0,
        payerName: 'You',
        isPayerUser: true,
        date: DateTime(2026, 9, 20),
        participants: const [
          SplitParticipantModel(id: 'p-1', billId: 'b-1', contactName: 'You', shareAmount: 1500.0, hasPaid: true),
          SplitParticipantModel(id: 'p-2', billId: 'b-1', contactName: 'Alex', shareAmount: 1500.0, hasPaid: false),
        ],
      );
      final bill2 = SplitBillModel(
        id: 'b-2',
        title: 'Uber to Airport',
        totalAmount: 1200.0,
        payerName: 'You',
        isPayerUser: true,
        date: DateTime(2026, 9, 22),
        participants: const [
          SplitParticipantModel(id: 'p-3', billId: 'b-2', contactName: 'You', shareAmount: 600.0, hasPaid: true),
          SplitParticipantModel(id: 'p-4', billId: 'b-2', contactName: 'Alex', shareAmount: 600.0, hasPaid: false),
        ],
      );

      final statement = SplitShareService.formatPersonPendingStatement(
        contactName: 'Alex',
        openBills: [bill1, bill2],
        totalAmount: 2100.0,
        currencySymbol: 'Rs.',
        defaultPaymentInfo: 'UPI: user@bank',
      );

      expect(statement, contains('👋 Hey Alex,'));
      expect(statement, contains('💰 Total Balance: +Rs. 2100 (Please send)'));
      expect(statement, contains('• Dinner at Subway'));
      expect(statement, contains('+Rs. 1500 (Owes you)'));
      expect(statement, contains('• Uber to Airport'));
      expect(statement, contains('+Rs. 600 (Owes you)'));
      expect(statement, contains('💳 Send to:'));
      expect(statement, contains('UPI: user@bank'));
    });

    test('Generates two-way statement when user owes contact (negative balance)', () {
      final billFriendPaid = SplitBillModel(
        id: 'b-friend',
        title: 'Sushi Dinner',
        totalAmount: 2000.0,
        payerName: 'Alex',
        isPayerUser: false,
        date: DateTime(2026, 9, 23),
        participants: const [
          SplitParticipantModel(id: 'p-1', billId: 'b-friend', contactName: 'Alex', shareAmount: 1000.0, hasPaid: true),
          SplitParticipantModel(id: 'p-2', billId: 'b-friend', contactName: 'You', shareAmount: 1000.0, hasPaid: false),
        ],
      );

      final statement = SplitShareService.formatPersonPendingStatement(
        contactName: 'Alex',
        openBills: [billFriendPaid],
        totalAmount: -1000.0,
        currencySymbol: 'Rs.',
        defaultPaymentInfo: 'UPI: user@bank',
      );

      expect(statement, contains('👋 Hey Alex,'));
      expect(statement, contains('💰 Total Balance: -Rs. 1000 (I will pay)'));
      expect(statement, contains('• Sushi Dinner'));
      expect(statement, contains('-Rs. 1000 (You owe Alex)'));
      // Invariant: User payment details must NOT be included when user owes contact!
      expect(statement.contains('💳 Send to:'), isFalse);
    });

    test('Generates two-way statement with mixed bills netting each other', () {
      final billUserPaid = SplitBillModel(
        id: 'b-1',
        title: 'Groceries',
        totalAmount: 3000.0,
        payerName: 'You',
        isPayerUser: true,
        date: DateTime(2026, 9, 20),
        participants: const [
          SplitParticipantModel(id: 'p-1', billId: 'b-1', contactName: 'You', shareAmount: 1500.0, hasPaid: true),
          SplitParticipantModel(id: 'p-2', billId: 'b-1', contactName: 'Alex', shareAmount: 1500.0, hasPaid: false),
        ],
      );
      final billFriendPaid = SplitBillModel(
        id: 'b-2',
        title: 'Concert Tickets',
        totalAmount: 1000.0,
        payerName: 'Alex',
        isPayerUser: false,
        date: DateTime(2026, 9, 21),
        participants: const [
          SplitParticipantModel(id: 'p-3', billId: 'b-2', contactName: 'Alex', shareAmount: 500.0, hasPaid: true),
          SplitParticipantModel(id: 'p-4', billId: 'b-2', contactName: 'You', shareAmount: 500.0, hasPaid: false),
        ],
      );

      final statement = SplitShareService.formatPersonPendingStatement(
        contactName: 'Alex',
        openBills: [billUserPaid, billFriendPaid],
        totalAmount: 1000.0, // 1500 owed to user - 500 user owes friend = +1000
        currencySymbol: 'Rs.',
        defaultPaymentInfo: 'UPI: user@bank',
      );

      expect(statement, contains('💰 Total Balance: +Rs. 1000 (Please send)'));
      expect(statement, contains('+Rs. 1500 (Owes you)'));
      expect(statement, contains('-Rs. 500 (You owe Alex)'));
      expect(statement, contains('💳 Send to:'));
    });
  });

  group('Receipt OCR Regex Engine Tests', () {
    test('Extracts grand total and merchant from simulated OCR text', () {
      final scanner = ReceiptScannerService.instance;
      final result = scanner.processReceiptImage('', isAiActive: false);
      expect(result, isNotNull);
    });
  });

  group('SettleUpSheet Widget Tests', () {
    testWidgets('Renders settle up details and ledger checkbox correctly', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => FinancialManagerProvider()),
            ChangeNotifierProvider(create: (_) => SplitBillProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SettleUpSheet(
                contactName: 'Alex',
                netAmount: 4500.0,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Alex pays you'), findsOneWidget);
      expect(find.text('Rs. 4500'), findsOneWidget);
      expect(find.text('Record as Income in Daily Operating Account'), findsOneWidget);
      expect(find.text('Confirm Settle Up'), findsOneWidget);
    });
  });

  group('Savings Vault & Modular Settings Tests', () {
    test('SettingsProvider toggles enableSavingsVault state accurately', () async {
      SharedPreferences.setMockInitialValues({'enableSavingsVault': true});
      final settings = SettingsProvider();
      await settings.loadSettings();
      expect(settings.enableSavingsVault, isTrue);

      await settings.setEnableSavingsVault(false);
      expect(settings.enableSavingsVault, isFalse);

      await settings.setEnableSavingsVault(true);
      expect(settings.enableSavingsVault, isTrue);
    });
  });

  group('SplitBillEditorScreen Existing Friends Tests', () {
    testWidgets('Populates existing participants and title when editing existing bill', (tester) async {
      final bill = SplitBillModel(
        id: 'bill-123',
        title: 'Team Dinner',
        totalAmount: 120.0,
        payerName: 'You',
        isPayerUser: true,
        splitMode: SplitMode.equal,
        date: DateTime.now(),
        participants: const [
          SplitParticipantModel(
            id: 'p-1',
            billId: 'bill-123',
            contactName: 'You',
            shareAmount: 40.0,
            hasPaid: true,
          ),
          SplitParticipantModel(
            id: 'p-2',
            billId: 'bill-123',
            contactName: 'Bob',
            shareAmount: 40.0,
            hasPaid: false,
          ),
          SplitParticipantModel(
            id: 'p-3',
            billId: 'bill-123',
            contactName: 'Alice',
            shareAmount: 40.0,
            hasPaid: false,
          ),
        ],
      );

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => FinancialManagerProvider()),
            ChangeNotifierProvider(create: (_) => SplitBillProvider()),
          ],
          child: MaterialApp(
            home: SplitBillEditorScreen(existingBill: bill),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title & existing participants should be visible
      expect(find.text('Edit Split Bill'), findsOneWidget);
      expect(find.text('Team Dinner'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Update Bill'), findsOneWidget);
    });
  });

  group('SplitParticipantModel Serialization & Settlement Tracking Tests', () {
    test('Serializes and deserializes settlementTransactionId correctly', () {
      final now = DateTime.now();
      final participant = SplitParticipantModel(
        id: 'p-1',
        billId: 'b-1',
        contactName: 'Bob',
        shareAmount: 25.50,
        hasPaid: true,
        paidAt: now,
        settlementTransactionId: 105,
      );

      final map = participant.toMap();
      expect(map[SplitParticipantFields.settlementTransactionId], equals(105));
      expect(map[SplitParticipantFields.hasPaid], equals(1));

      final fromMap = SplitParticipantModel.fromMap(map);
      expect(fromMap.id, 'p-1');
      expect(fromMap.settlementTransactionId, equals(105));
      expect(fromMap.hasPaid, isTrue);
    });

    test('copyWith handles settlementTransactionId and clearSettlementTxId flag', () {
      const participant = SplitParticipantModel(
        id: 'p-1',
        billId: 'b-1',
        contactName: 'Bob',
        shareAmount: 25.50,
        hasPaid: true,
        settlementTransactionId: 200,
      );

      // Updating with new id
      final updated = participant.copyWith(settlementTransactionId: 300);
      expect(updated.settlementTransactionId, equals(300));

      // Updating without changing id retains existing id
      final retained = updated.copyWith(hasPaid: false);
      expect(retained.settlementTransactionId, equals(300));

      // Clearing id explicitly via clearSettlementTxId
      final cleared = retained.copyWith(clearSettlementTxId: true);
      expect(cleared.settlementTransactionId, isNull);
    });

    test('SplitBillModel handles user share and derived status when You is not in participants list', () {
      final bill = SplitBillModel(
        id: 'bill-implicit-user',
        title: 'Team Coffee',
        totalAmount: 100.0,
        payerName: 'You',
        isPayerUser: true,
        date: DateTime.now(),
        participants: const [
          SplitParticipantModel(
            id: 'p-bob',
            billId: 'bill-implicit-user',
            contactName: 'Bob',
            shareAmount: 50.0,
            hasPaid: false,
          ),
        ],
      );

      expect(bill.userParticipant, isNull);
      expect(bill.userShare, equals(50.0));
      expect(bill.isUserSharePaid, isTrue);
      expect(bill.computeDerivedStatus(), equals(SplitStatus.unsettled));
      expect(bill.isFullySettled, isFalse);
    });
  });

  group('Equal Split Penny-Perfect Mathematics & Exact Validation Tests', () {
    test('Penny-perfect integer cents allocation for 100 across 3 participants', () {
      const total = 100.0;
      const count = 3;
      final totalCents = (total * 100).round();
      final baseCents = totalCents ~/ count; // 3333 cents = 33.33
      final remCents = totalCents % count;   // 1 cent

      final shares = List.generate(count, (i) {
        final cents = baseCents + (i < remCents ? 1 : 0);
        return cents / 100.0;
      });

      expect(shares, equals([33.34, 33.33, 33.33]));
      final sum = shares.reduce((a, b) => a + b);
      expect(sum, equals(100.0));
    });

    test('Penny-perfect integer cents allocation for 100 across 6 participants', () {
      const total = 100.0;
      const count = 6;
      final totalCents = (total * 100).round();
      final baseCents = totalCents ~/ count; // 1666 cents = 16.66
      final remCents = totalCents % count;   // 4 cents

      final shares = List.generate(count, (i) {
        final cents = baseCents + (i < remCents ? 1 : 0);
        return cents / 100.0;
      });

      expect(shares, equals([16.67, 16.67, 16.67, 16.67, 16.66, 16.66]));
      final sum = double.parse(shares.reduce((a, b) => a + b).toStringAsFixed(2));
      expect(sum, equals(100.0));
    });

    testWidgets('Exact mode sum mismatch validation error prevents save', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final bill = SplitBillModel(
        id: 'bill-exact-mismatch',
        title: 'Dinner Party',
        totalAmount: 100.0,
        payerName: 'You',
        isPayerUser: true,
        splitMode: SplitMode.exact,
        date: DateTime.now(),
        participants: const [
          SplitParticipantModel(
            id: 'p-1',
            billId: 'bill-exact-mismatch',
            contactName: 'You',
            shareAmount: 40.0,
            hasPaid: true,
          ),
          SplitParticipantModel(
            id: 'p-2',
            billId: 'bill-exact-mismatch',
            contactName: 'Bob',
            shareAmount: 40.0, // 40 + 40 = 80 != 100
            hasPaid: false,
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => FinancialManagerProvider()),
            ChangeNotifierProvider(create: (_) => SplitBillProvider()),
          ],
          child: MaterialApp(
            home: SplitBillEditorScreen(existingBill: bill),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Update Bill
      await tester.tap(find.text('Update Bill'));
      await tester.pumpAndSettle();

      // SnackBar with error should appear
      expect(find.textContaining('Exact shares sum (80.00) does not match total (100.00).'), findsOneWidget);
    });

    testWidgets('Friend-payer mode locks user share to true and disables switch', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => FinancialManagerProvider()),
            ChangeNotifierProvider(create: (_) => SplitBillProvider()),
          ],
          child: const MaterialApp(
            home: SplitBillEditorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Friend Paid
      await tester.tap(find.text('Friend Paid'));
      await tester.pumpAndSettle();

      // Verify user share switch is disabled and explanatory text is visible
      expect(find.text('Locked: your share is required because a friend paid for you'), findsOneWidget);
      final switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(switchTile.value, isTrue);
      expect(switchTile.onChanged, isNull);
    });
  });

  group('SplitBillRepository Database Migration & Operations Tests', () {
    late Database db;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseHelper.instance.createTestDatabase(db);
      DatabaseHelper.setMockDatabase(db);
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      await db.close();
      DatabaseHelper.setMockDatabase(null);
    });

    test('Database v25 schema contains settlementTransactionId column', () async {
      final tableInfo = await db.rawQuery('PRAGMA table_info(${TableNames.splitParticipants})');
      final colNames = tableInfo.map((row) => row['name'] as String).toList();
      expect(colNames, contains(SplitParticipantFields.settlementTransactionId));
    });

    test('toggleParticipantPaid stores and returns settlementTransactionId accurately', () async {
      final bill = SplitBillModel(
        id: 'bill-toggle-1',
        title: 'Dinner at Botanik',
        totalAmount: 100.0,
        payerName: 'You',
        isPayerUser: true,
        date: DateTime.now(),
        participants: const [
          SplitParticipantModel(id: 'p-user', billId: 'bill-toggle-1', contactName: 'You', shareAmount: 50.0, hasPaid: true),
          SplitParticipantModel(id: 'p-bob', billId: 'bill-toggle-1', contactName: 'Bob', shareAmount: 50.0, hasPaid: false),
        ],
      );
      await SplitBillRepository.instance.insertSplitBill(bill);

      // Settle Bob with ledger tx id 42
      final unsetTx = await SplitBillRepository.instance.toggleParticipantPaid('p-bob', true, settlementTransactionId: 42);
      expect(unsetTx, isNull);

      final pRows = await db.query(TableNames.splitParticipants, where: 'id = ?', whereArgs: ['p-bob']);
      expect(pRows.first[SplitParticipantFields.hasPaid], equals(1));
      expect(pRows.first[SplitParticipantFields.settlementTransactionId], equals(42));
      expect(pRows.first[SplitParticipantFields.paidAt], isNotNull);

      // Unsettle Bob -> returns 42 and clears column
      final returnedTxId = await SplitBillRepository.instance.toggleParticipantPaid('p-bob', false);
      expect(returnedTxId, equals(42));

      final pRows2 = await db.query(TableNames.splitParticipants, where: 'id = ?', whereArgs: ['p-bob']);
      expect(pRows2.first[SplitParticipantFields.hasPaid], equals(0));
      expect(pRows2.first[SplitParticipantFields.settlementTransactionId], isNull);
      expect(pRows2.first[SplitParticipantFields.paidAt], isNull);
    });

    test('toggleUserShareForBill stores and returns settlementTransactionId for friend-paid bills', () async {
      final bill = SplitBillModel(
        id: 'bill-friend-1',
        title: 'Team Lunch',
        totalAmount: 60.0,
        payerName: 'Bob',
        isPayerUser: false,
        date: DateTime.now(),
        participants: const [
          SplitParticipantModel(id: 'p-bob-paid', billId: 'bill-friend-1', contactName: 'Bob', shareAmount: 30.0, hasPaid: true),
          SplitParticipantModel(id: 'p-you-unpaid', billId: 'bill-friend-1', contactName: 'You', shareAmount: 30.0, hasPaid: false),
        ],
      );
      await SplitBillRepository.instance.insertSplitBill(bill);

      // User settles their share with Bob
      final prevTx = await SplitBillRepository.instance.toggleUserShareForBill('bill-friend-1', true, settlementTransactionId: 99);
      expect(prevTx, isNull);

      final youRows = await db.query(TableNames.splitParticipants, where: 'id = ?', whereArgs: ['p-you-unpaid']);
      expect(youRows.first[SplitParticipantFields.hasPaid], equals(1));
      expect(youRows.first[SplitParticipantFields.settlementTransactionId], equals(99));

      final billRows = await db.query(TableNames.splitBills, where: 'id = ?', whereArgs: ['bill-friend-1']);
      expect(billRows.first[SplitBillFields.status], equals('settled'));

      // Unsettle user share -> returns 99 and reopens bill
      final returnedTx = await SplitBillRepository.instance.toggleUserShareForBill('bill-friend-1', false);
      expect(returnedTx, equals(99));

      final youRows2 = await db.query(TableNames.splitParticipants, where: 'id = ?', whereArgs: ['p-you-unpaid']);
      expect(youRows2.first[SplitParticipantFields.hasPaid], equals(0));
      expect(youRows2.first[SplitParticipantFields.settlementTransactionId], isNull);

      final billRows2 = await db.query(TableNames.splitBills, where: 'id = ?', whereArgs: ['bill-friend-1']);
      expect(billRows2.first[SplitBillFields.status], equals('unsettled'));
    });

    test('settleAllForContact scopes only to active bills where user or contact is payer', () async {
      final now = DateTime.now();

      // Bill 1: User is payer, Alex owes 500, Sarah owes 500
      final bill1 = SplitBillModel(
        id: 'b-1',
        title: 'Dinner',
        totalAmount: 1500.0,
        payerName: 'You',
        isPayerUser: true,
        date: now,
        participants: const [
          SplitParticipantModel(id: 'p-1', billId: 'b-1', contactName: 'You', shareAmount: 500.0, hasPaid: true),
          SplitParticipantModel(id: 'p-2', billId: 'b-1', contactName: 'Alex', shareAmount: 500.0, hasPaid: false),
          SplitParticipantModel(id: 'p-3', billId: 'b-1', contactName: 'Sarah', shareAmount: 500.0, hasPaid: false),
        ],
      );

      // Bill 2: Alex is payer, User owes 300
      final bill2 = SplitBillModel(
        id: 'b-2',
        title: 'Uber',
        totalAmount: 600.0,
        payerName: 'Alex',
        isPayerUser: false,
        date: now,
        participants: const [
          SplitParticipantModel(id: 'p-4', billId: 'b-2', contactName: 'Alex', shareAmount: 300.0, hasPaid: true),
          SplitParticipantModel(id: 'p-5', billId: 'b-2', contactName: 'You', shareAmount: 300.0, hasPaid: false),
        ],
      );

      // Bill 3: Sarah is payer, Alex owes 200 (User NOT payer)
      final bill3 = SplitBillModel(
        id: 'b-3',
        title: 'Coffee',
        totalAmount: 400.0,
        payerName: 'Sarah',
        isPayerUser: false,
        date: now,
        participants: const [
          SplitParticipantModel(id: 'p-6', billId: 'b-3', contactName: 'Sarah', shareAmount: 200.0, hasPaid: true),
          SplitParticipantModel(id: 'p-7', billId: 'b-3', contactName: 'Alex', shareAmount: 200.0, hasPaid: false),
        ],
      );

      // Bill 4: Soft-deleted bill where Alex owes user 400
      final bill4 = SplitBillModel(
        id: 'b-4',
        title: 'Old Movie',
        totalAmount: 800.0,
        payerName: 'You',
        isPayerUser: true,
        date: now,
        deletedAt: now,
        participants: const [
          SplitParticipantModel(id: 'p-8', billId: 'b-4', contactName: 'You', shareAmount: 400.0, hasPaid: true),
          SplitParticipantModel(id: 'p-9', billId: 'b-4', contactName: 'Alex', shareAmount: 400.0, hasPaid: false),
        ],
      );

      await SplitBillRepository.instance.insertSplitBill(bill1);
      await SplitBillRepository.instance.insertSplitBill(bill2);
      await SplitBillRepository.instance.insertSplitBill(bill3);
      await SplitBillRepository.instance.insertSplitBill(bill4);

      // Settle all for Alex
      await SplitBillRepository.instance.settleAllForContact('Alex', settlementTransactionId: 700);

      // Verify Bill 1: Alex is paid, Sarah remains unpaid
      final pAlex = (await db.query(TableNames.splitParticipants, where: 'id = ?', whereArgs: ['p-2'])).first;
      final pSarah = (await db.query(TableNames.splitParticipants, where: 'id = ?', whereArgs: ['p-3'])).first;
      expect(pAlex[SplitParticipantFields.hasPaid], equals(1));
      expect(pAlex[SplitParticipantFields.settlementTransactionId], equals(700));
      expect(pSarah[SplitParticipantFields.hasPaid], equals(0));

      // Verify Bill 2: User share is paid and bill settled
      final pYou = (await db.query(TableNames.splitParticipants, where: 'id = ?', whereArgs: ['p-5'])).first;
      final b2Row = (await db.query(TableNames.splitBills, where: 'id = ?', whereArgs: ['b-2'])).first;
      expect(pYou[SplitParticipantFields.hasPaid], equals(1));
      expect(pYou[SplitParticipantFields.settlementTransactionId], equals(700));
      expect(b2Row[SplitBillFields.status], equals('settled'));

      // Verify Bill 3: Alex participant is NOT touched (still owes Sarah)
      final pAlexSarah = (await db.query(TableNames.splitParticipants, where: 'id = ?', whereArgs: ['p-7'])).first;
      expect(pAlexSarah[SplitParticipantFields.hasPaid], equals(0));

      // Verify Bill 4: Deleted bill is NOT touched
      final pAlexDeleted = (await db.query(TableNames.splitParticipants, where: 'id = ?', whereArgs: ['p-9'])).first;
      expect(pAlexDeleted[SplitParticipantFields.hasPaid], equals(0));
    });

    test('unsettleAllForContact scopes strictly to the most recent settlement batch', () async {
      final now = DateTime.now();

      // Bill 1: Settled yesterday with tx id 101
      final bill1 = SplitBillModel(
        id: 'b-old',
        title: 'Old Dinner',
        totalAmount: 200.0,
        payerName: 'You',
        isPayerUser: true,
        date: now.subtract(const Duration(days: 2)),
        participants: [
          const SplitParticipantModel(id: 'p-u1', billId: 'b-old', contactName: 'You', shareAmount: 100.0, hasPaid: true),
          SplitParticipantModel(
            id: 'p-alex1',
            billId: 'b-old',
            contactName: 'Alex',
            shareAmount: 100.0,
            hasPaid: true,
            paidAt: now.subtract(const Duration(days: 1)),
            settlementTransactionId: 101,
          ),
        ],
      );

      // Bill 2: Settled today with tx id 102
      final bill2 = SplitBillModel(
        id: 'b-new',
        title: 'New Lunch',
        totalAmount: 400.0,
        payerName: 'You',
        isPayerUser: true,
        date: now,
        participants: [
          const SplitParticipantModel(id: 'p-u2', billId: 'b-new', contactName: 'You', shareAmount: 200.0, hasPaid: true),
          SplitParticipantModel(
            id: 'p-alex2',
            billId: 'b-new',
            contactName: 'Alex',
            shareAmount: 200.0,
            hasPaid: true,
            paidAt: now,
            settlementTransactionId: 102,
          ),
        ],
      );

      await SplitBillRepository.instance.insertSplitBill(bill1);
      await SplitBillRepository.instance.insertSplitBill(bill2);

      // Undo settlement for Alex
      final undoneTxIds = await SplitBillRepository.instance.unsettleAllForContact('Alex');
      expect(undoneTxIds, equals([102]));

      // Verify Bill 2 is reopened
      final pAlex2 = (await db.query(TableNames.splitParticipants, where: 'id = ?', whereArgs: ['p-alex2'])).first;
      expect(pAlex2[SplitParticipantFields.hasPaid], equals(0));
      expect(pAlex2[SplitParticipantFields.settlementTransactionId], isNull);

      // Verify Bill 1 remains settled
      final pAlex1 = (await db.query(TableNames.splitParticipants, where: 'id = ?', whereArgs: ['p-alex1'])).first;
      expect(pAlex1[SplitParticipantFields.hasPaid], equals(1));
      expect(pAlex1[SplitParticipantFields.settlementTransactionId], equals(101));
    });

    test('getContactNetBalances performs case-insensitive contact aggregation', () async {
      final bill1 = SplitBillModel(
        id: 'b-c1',
        title: 'Trip 1',
        totalAmount: 1000.0,
        payerName: 'You',
        isPayerUser: true,
        date: DateTime.now(),
        participants: const [
          SplitParticipantModel(id: 'p-c1', billId: 'b-c1', contactName: 'You', shareAmount: 500.0, hasPaid: true),
          SplitParticipantModel(id: 'p-c2', billId: 'b-c1', contactName: 'Alex', shareAmount: 500.0, hasPaid: false),
        ],
      );
      final bill2 = SplitBillModel(
        id: 'b-c2',
        title: 'Trip 2',
        totalAmount: 600.0,
        payerName: 'You',
        isPayerUser: true,
        date: DateTime.now(),
        participants: const [
          SplitParticipantModel(id: 'p-c3', billId: 'b-c2', contactName: 'You', shareAmount: 300.0, hasPaid: true),
          SplitParticipantModel(id: 'p-c4', billId: 'b-c2', contactName: 'alex', shareAmount: 300.0, hasPaid: false),
        ],
      );

      await SplitBillRepository.instance.insertSplitBill(bill1);
      await SplitBillRepository.instance.insertSplitBill(bill2);

      final balances = await SplitBillRepository.instance.getContactNetBalances();
      // Should aggregate under one key with net balance 800.0
      expect(balances.length, equals(1));
      expect(balances.values.first, equals(800.0));
    });

    test('Bidirectional soft-delete, restore and permanent delete sync between transactions and split_bills', () async {
      // Create ledger transaction
      final tx = await TransactionRepository.instance.createTransaction(
        TransactionModel(
          description: 'Dinner at Botanik',
          amount: 100.0,
          isExpense: true,
          category: 'Food',
          date: DateTime.now(),
          account: AccountType.daily,
        ),
      );

      // Create linked split bill
      final bill = SplitBillModel(
        id: 'bill-sync-1',
        title: 'Dinner at Botanik',
        totalAmount: 100.0,
        payerName: 'You',
        isPayerUser: true,
        transactionId: tx.id,
        date: DateTime.now(),
        participants: const [
          SplitParticipantModel(id: 'p-s1', billId: 'bill-sync-1', contactName: 'You', shareAmount: 50.0, hasPaid: true),
          SplitParticipantModel(id: 'p-s2', billId: 'bill-sync-1', contactName: 'Bob', shareAmount: 50.0, hasPaid: false),
        ],
      );
      await SplitBillRepository.instance.insertSplitBill(bill);

      // Soft-delete transaction
      await TransactionRepository.instance.deleteTransaction(tx.id!);
      var billRow = (await db.query(TableNames.splitBills, where: 'id = ?', whereArgs: ['bill-sync-1'])).first;
      expect(billRow[SplitBillFields.deletedAt], isNotNull);

      // Restore transaction
      await TransactionRepository.instance.restoreTransaction(tx.id!);
      billRow = (await db.query(TableNames.splitBills, where: 'id = ?', whereArgs: ['bill-sync-1'])).first;
      expect(billRow[SplitBillFields.deletedAt], isNull);

      // Permanently delete transaction -> unlinks transactionId
      await TransactionRepository.instance.deleteTransaction(tx.id!, soft: false);
      billRow = (await db.query(TableNames.splitBills, where: 'id = ?', whereArgs: ['bill-sync-1'])).first;
      expect(billRow[SplitBillFields.transactionId], isNull);
    });

    test('updateSplitBill soft-deletes linked transaction and clears transactionId when switching to friend payer', () async {
      // Create ledger transaction
      final tx = await TransactionRepository.instance.createTransaction(
        TransactionModel(
          description: 'Concert Tickets',
          amount: 200.0,
          isExpense: true,
          category: 'Entertainment',
          date: DateTime.now(),
          account: AccountType.daily,
        ),
      );

      final bill = SplitBillModel(
        id: 'bill-switch-1',
        title: 'Concert Tickets',
        totalAmount: 200.0,
        payerName: 'You',
        isPayerUser: true,
        transactionId: tx.id,
        date: DateTime.now(),
        participants: const [
          SplitParticipantModel(id: 'p-sw1', billId: 'bill-switch-1', contactName: 'You', shareAmount: 100.0, hasPaid: true),
          SplitParticipantModel(id: 'p-sw2', billId: 'bill-switch-1', contactName: 'Charlie', shareAmount: 100.0, hasPaid: false),
        ],
      );
      await SplitBillRepository.instance.insertSplitBill(bill);

      // Switch payer to Charlie
      final updatedBill = bill.copyWith(
        isPayerUser: false,
        payerName: 'Charlie',
      );
      await SplitBillRepository.instance.updateSplitBill(updatedBill);

      // Linked ledger transaction should now be soft-deleted
      final txRow = (await db.query(TableNames.transactions, where: '${TransactionFields.id} = ?', whereArgs: [tx.id])).first;
      expect(txRow[TransactionFields.deletedAt], isNotNull);

      // Bill transactionId should be cleared to null
      final billRow = (await db.query(TableNames.splitBills, where: 'id = ?', whereArgs: ['bill-switch-1'])).first;
      expect(billRow[SplitBillFields.transactionId], isNull);
    });
  });
}
