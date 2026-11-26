import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:note_taking_app/data/category_definition.dart';
import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/data/note_model.dart';
import 'package:note_taking_app/data/transaction_model.dart';
import 'package:note_taking_app/features/finances/data/models/savings_goal_model.dart';
import 'package:note_taking_app/features/finances/data/models/split_bill_model.dart';
import 'package:note_taking_app/features/finances/data/repositories/split_bill_repository.dart';
import 'package:note_taking_app/features/finances/data/transaction_repository.dart';
import 'package:note_taking_app/features/notes/data/note_repository.dart';
import 'package:note_taking_app/features/notes/presentation/widgets/note_editor_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.instance.createTestDatabase(db);
    DatabaseHelper.setMockDatabase(db);
  });

  tearDownAll(() async {
    await db.close();
    DatabaseHelper.setMockDatabase(null);
  });

  group('Finances & Notes Save Integrity Regression Tests', () {
    test('TransactionModel.copy preserves uuid, smsId, and sets isAiRefined = true', () async {
      final repo = TransactionRepository.instance;
      final now = DateTime.now();
      final original = TransactionModel(
        amount: 2700,
        description: 'Google Purchase',
        date: now,
        isExpense: true,
        category: 'Shopping',
        smsId: 'sms_google_123',
        isAiRefined: false,
      );

      final created = await repo.createTransaction(original, updateWidgets: false);
      expect(created.id, isNotNull);
      expect(created.isAiRefined, isFalse);

      // Simulate TransactionEditorScreen edit saving via .copy(..., isAiRefined: true)
      final edited = created.copy(
        category: 'Subscriptions',
        description: 'Google Purchase',
        isAiRefined: true,
      );
      await repo.updateTransaction(edited);

      final fetched = await repo.readTransaction(created.id!);
      expect(fetched, isNotNull);
      expect(fetched!.category, 'Subscriptions');
      expect(fetched.smsId, 'sms_google_123');
      expect(fetched.isAiRefined, isTrue);

      await repo.permanentlyDeleteTransaction(created.id!);
    });

    test('TransactionRepository.bulkUpdateCategory sets isAiRefined = 1 and renameCategoryDefinition updates dateModified', () async {
      final repo = TransactionRepository.instance;
      final oldDate = DateTime(2026, 1, 1, 10, 0);
      final tx = await repo.createTransaction(
        TransactionModel(
          amount: 500,
          description: 'SMS Merchant',
          date: oldDate,
          isExpense: true,
          category: 'TempCatA',
          smsId: 'sms_bulk_cat_1',
          isAiRefined: false,
          dateModified: oldDate,
        ),
        updateWidgets: false,
      );

      await repo.bulkUpdateCategory([tx.id!], 'TempCatB');
      final afterBulk = await repo.readTransaction(tx.id!);
      expect(afterBulk!.category, 'TempCatB');
      expect(afterBulk.isAiRefined, isTrue);

      await repo.upsertCategoryDefinition(
        const CategoryDefinition(name: 'TempCatB', colorValue: 0xFF123456, iconCodePoint: 0xe3b8, keywords: []),
      );
      await repo.renameCategoryDefinition(
        'TempCatB',
        const CategoryDefinition(name: 'TempCatC', colorValue: 0xFF123456, iconCodePoint: 0xe3b8, keywords: []),
      );

      final afterRename = await repo.readTransaction(tx.id!);
      expect(afterRename!.category, 'TempCatC');
      expect(afterRename.dateModified, isNotNull);
      expect(afterRename.dateModified!.isAfter(oldDate), isTrue);

      await repo.deleteCategoryDefinition('TempCatC');
      await repo.permanentlyDeleteTransaction(tx.id!);
    });

    test('SplitBillRepository.updateSplitBill preserves participant settlementTransactionId', () async {
      final splitRepo = SplitBillRepository.instance;
      final bill = SplitBillModel(
        id: 'split_reg_test_1',
        title: 'Dinner',
        totalAmount: 1000,
        payerName: 'You',
        isPayerUser: true,
        date: DateTime.now(),
        status: SplitStatus.partial,
        participants: [
          SplitParticipantModel(
            id: 'p_reg_1',
            billId: 'split_reg_test_1',
            contactName: 'Alex',
            shareAmount: 500,
            hasPaid: true,
            paidAt: DateTime.now(),
            settlementTransactionId: 9991,
          ),
        ],
      );

      await splitRepo.insertSplitBill(bill);
      final updatedBill = bill.copyWith(title: 'Team Dinner');
      await splitRepo.updateSplitBill(updatedBill);

      final loaded = await splitRepo.getBillById('split_reg_test_1');
      expect(loaded, isNotNull);
      expect(loaded!.title, 'Team Dinner');
      expect(loaded.participants.first.settlementTransactionId, 9991);

      await splitRepo.softDeleteSplitBill('split_reg_test_1');
    });

    test('SavingsGoalModel.copyWith(clearCompletedAt: true) clears completedAt', () {
      final now = DateTime.now();
      final goal = SavingsGoalModel(
        id: 'goal_1',
        title: 'Laptop',
        targetAmount: 1000,
        currentAmount: 1000,
        isCompleted: true,
        createdAt: now,
        completedAt: now,
      );

      final withdrawn = goal.copyWith(
        currentAmount: 800,
        isCompleted: false,
        clearCompletedAt: true,
      );
      expect(withdrawn.isCompleted, isFalse);
      expect(withdrawn.completedAt, isNull);
    });

    test('NoteEditorActions.persistNote preserves image-only note without deleting it', () async {
      final noteRepo = NoteRepository.instance;
      final controller = QuillController.basic();
      controller.document.insert(0, BlockEmbed.image('/tmp/sample_receipt.png'));

      final (hasChanges, isSaved, _, savedNote) = await NoteEditorActions.persistNote(
        noteId: 'image_only_note_reg_1',
        initialNote: null,
        isNoteSaved: false,
        currentHasChanges: false,
        dateCreated: DateTime.now(),
        title: '',
        quillController: controller,
        moveCompletedChecklistsToBottom: false,
        completedItems: const [],
        isPinned: false,
        isArchived: false,
        color: 0,
        folder: 'All Notes',
        tags: const [],
        reminderAt: null,
        lastScheduledReminder: null,
        isNoteLocked: false,
      );

      expect(hasChanges, isTrue);
      expect(isSaved, isTrue);
      expect(savedNote, isNotNull);

      final fromDb = await noteRepo.readNote('image_only_note_reg_1');
      expect(fromDb, isNotNull);
      expect(fromDb!.content, contains('sample_receipt.png'));

      await noteRepo.deleteNote('image_only_note_reg_1');
      controller.dispose();
    });

    test('Note.copyWith(clearReminderAt: true) clears reminderAt', () {
      final now = DateTime.now();
      final note = Note(
        id: 'note_rem_1',
        title: 'Reminder Test',
        content: '[{"insert":"Hi\\n"}]',
        dateCreated: now,
        dateModified: now,
        reminderAt: now.add(const Duration(hours: 2)),
      );

      final cleared = note.copyWith(clearReminderAt: true);
      expect(cleared.reminderAt, isNull);
    });
  });
}
