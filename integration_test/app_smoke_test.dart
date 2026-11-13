import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:note_taking_app/data/changelog_data.dart';
import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/data/note_model.dart';
import 'package:note_taking_app/data/transaction_model.dart';
import 'package:note_taking_app/features/finances/data/transaction_repository.dart';
import 'package:note_taking_app/features/notes/data/note_repository.dart';
import 'package:note_taking_app/screens/changelog_screen.dart';
import 'package:note_taking_app/services/backup_service.dart';
import 'package:note_taking_app/utils/widget_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SQLCipher, repositories, backup JSON, widget sync, and changelog smoke test', (tester) async {
    final db = await DatabaseHelper.instance.database;
    expect(db.isOpen, isTrue);

    final now = DateTime.now();
    final testNoteId = 'integration_smoke_note_${now.microsecondsSinceEpoch}';
    final testNote = Note(
      id: testNoteId,
      title: 'Integration Smoke Checklist',
      content: '- [ ] Verify SQLCipher\n- [ ] Verify WidgetHelper',
      dateCreated: now,
      dateModified: now,
    );

    TransactionModel? createdTx;
    try {
      await NoteRepository.instance.createNote(testNote);
      final fetchedNote = await NoteRepository.instance.readNote(testNoteId);
      expect(fetchedNote, isNotNull);
      expect(fetchedNote!.title, equals('Integration Smoke Checklist'));

      createdTx = await TransactionRepository.instance.createTransaction(
        TransactionModel(
          amount: 42.50,
          description: 'Integration Smoke Expense',
          date: now,
          isExpense: true,
        ),
      );
      expect(createdTx.id, isNotNull);

      final backupJsonString = await generateBackupJson();
      final backupData = jsonDecode(backupJsonString) as Map<String, dynamic>;
      expect(backupData['notes'], isA<List<dynamic>>());
      expect(backupData['transactions'], isA<List<dynamic>>());

      await WidgetHelper.updateTodoWidgetData();
      await WidgetHelper.updateWidgetData();
      await WidgetHelper.syncPendingTodoToggles();

      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(prefs.getString('widget_todo_notes_json'), isNotNull);
    } finally {
      await NoteRepository.instance.deleteNote(testNoteId);
      if (createdTx?.id != null) {
        await TransactionRepository.instance.deleteTransaction(createdTx!.id!);
      }
    }

    await tester.pumpWidget(const MaterialApp(home: ChangelogScreen()));
    expect(find.text(kLatestChangelog.version), findsOneWidget);

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('v3.4.0'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('v3.4.0'), findsOneWidget);
  });
}
