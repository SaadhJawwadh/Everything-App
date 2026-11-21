import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/features/finances/data/models/split_bill_model.dart';
import 'package:note_taking_app/features/finances/services/debt_simplifier_service.dart';
import 'package:note_taking_app/features/finances/services/split_share_service.dart';
import 'package:note_taking_app/features/notes/presentation/widgets/note_slash_command_overlay.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/features/story_cards/presentation/widgets/story_card_studio_sheet.dart';
import 'package:note_taking_app/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DebtSimplifierService & SplitShareService', () {
    test('simplifies circular 3-person group debts into minimal transfers', () {
      final bills = [
        SplitBillModel(
          id: 'b1',
          title: 'Dinner',
          totalAmount: 300,
          payerName: 'You',
          isPayerUser: true,
          splitMode: SplitMode.equal,
          groupTag: 'Trip',
          date: DateTime(2026, 11, 1),
          participants: const [
            SplitParticipantModel(id: 'p1', billId: 'b1', contactName: 'You', shareAmount: 100, hasPaid: true),
            SplitParticipantModel(id: 'p2', billId: 'b1', contactName: 'Alice', shareAmount: 100, hasPaid: false),
            SplitParticipantModel(id: 'p3', billId: 'b1', contactName: 'Bob', shareAmount: 100, hasPaid: false),
          ],
        ),
        SplitBillModel(
          id: 'b2',
          title: 'Cab',
          totalAmount: 300,
          payerName: 'alice',
          isPayerUser: false,
          splitMode: SplitMode.equal,
          groupTag: 'Trip',
          date: DateTime(2026, 11, 2),
          participants: const [
            SplitParticipantModel(id: 'p4', billId: 'b2', contactName: 'Alice', shareAmount: 100, hasPaid: true),
            SplitParticipantModel(id: 'p5', billId: 'b2', contactName: 'You', shareAmount: 100, hasPaid: false),
            SplitParticipantModel(id: 'p6', billId: 'b2', contactName: 'Bob', shareAmount: 100, hasPaid: false),
          ],
        ),
      ];

      // Net: You = +100, Alice = +100, Bob = -200 -> 2 transfers instead of 4!
      final transfers = DebtSimplifierService.simplifyGroupDebts(bills);
      expect(transfers.length, 2);
      expect(transfers.every((t) => t.from.toLowerCase() == 'bob' && t.amount == 100.0), isTrue);

      final formatted = SplitShareService.formatGroupSettlementMessage('Trip', transfers, currencySymbol: 'LKR');
      expect(formatted, contains('Trip'));
      expect(formatted, contains('LKR 100'));
    });

    test('synthesizes legacy friend-paid user share when You omitted from participants', () {
      final legacyBill = SplitBillModel(
        id: 'b_legacy',
        title: 'Coffee',
        totalAmount: 50,
        payerName: 'Sam',
        isPayerUser: false,
        splitMode: SplitMode.exact,
        groupTag: 'Work',
        date: DateTime(2026, 11, 3),
        participants: const [
          SplitParticipantModel(id: 'p1', billId: 'b_legacy', contactName: 'Sam', shareAmount: 25, hasPaid: true),
        ],
      );

      final transfers = DebtSimplifierService.simplifyGroupDebts([legacyBill]);
      expect(transfers.length, 1);
      expect(transfers.first.from, 'You');
      expect(transfers.first.to, 'Sam');
      expect(transfers.first.amount, 25.0);
    });
  });

  group('Deterministic Finance Notification IDs & ISO Week', () {
    test('fnv1a24 and namespaced finance IDs are deterministic and separated', () {
      final b1 = NotificationService.budgetNotificationId('Food', 80);
      final b2 = NotificationService.budgetNotificationId(' food ', 80);
      final b3 = NotificationService.budgetNotificationId('Food', 100);
      final r1 = NotificationService.billNotificationId('rule_abc');

      expect(b1, equals(b2));
      expect(b1, isNot(equals(b3)));
      expect(b1 & 0xFF000000, equals(0x46000000));
      expect(r1 & 0xFF000000, equals(0x47000000));
      expect(NotificationService.isoWeekKey(DateTime(2026, 11, 22)), startsWith('2026-W'));
    });
  });

  group('Note /scan Slash Command & Story Card Multi-Slide Batch Export UI', () {
    testWidgets('NoteSlashCommandOverlay shows /scan command', (tester) async {
      String? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteSlashCommandOverlay(
              query: 'sc',
              isAiActive: false,
              onCommandSelected: (cmd) => picked = cmd,
            ),
          ),
        ),
      );
      expect(find.text('Scan Text (OCR)'), findsOneWidget);
      await tester.tap(find.text('Scan Text (OCR)'));
      expect(picked, 'scan');
    });

    testWidgets('StoryCardStudioSheet shows Share All & Save All for multi-slide notes', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();
      await settings.loadSettings();

      final longText = List.generate(120, (i) => 'Sentence number $i about offline privacy and notes.').join(' ');
      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(
            home: Scaffold(
              body: StoryCardStudioSheet(
                initialText: longText,
                noteTitle: 'Long Essay',
                category: 'Notes',
                noteColorValue: 0xFF252529,
                noteDate: DateTime(2026, 11, 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Share All ('), findsOneWidget);
      expect(find.textContaining('Save All ('), findsOneWidget);
    });
  });
}
