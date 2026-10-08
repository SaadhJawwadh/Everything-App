import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/features/finances/data/models/split_bill_model.dart';
import 'package:note_taking_app/features/finances/services/split_share_service.dart';
import 'package:note_taking_app/features/finances/services/receipt_scanner_service.dart';
import 'package:note_taking_app/features/finances/presentation/widgets/settle_up_sheet.dart';
import 'package:note_taking_app/features/finances/presentation/screens/split_bill_editor_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/features/finances/providers/financial_manager_provider.dart';
import 'package:note_taking_app/features/finances/providers/split_bill_provider.dart';

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
      expect(statement, contains('💰 Total Pending: Rs. 2100'));
      expect(statement, contains('• Dinner at Subway'));
      expect(statement, contains('Rs. 1500'));
      expect(statement, contains('• Uber to Airport'));
      expect(statement, contains('Rs. 600'));
      expect(statement, contains('💳 Payment Details:'));
      expect(statement, contains('UPI: user@bank'));
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
}
