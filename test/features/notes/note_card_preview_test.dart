import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:note_taking_app/data/note_model.dart';
import 'package:note_taking_app/providers/note_provider.dart';
import 'package:note_taking_app/features/notes/presentation/widgets/note_card.dart';

class MockNoteProvider extends ChangeNotifier implements NoteProvider {
  @override
  String searchQuery = '';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestCard(Note note, {void Function(int, String)? onChecklistTap}) {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<NoteProvider>.value(
          value: MockNoteProvider(),
          child: NoteCard(
            note: note,
            onTap: () {},
            onChecklistTap: onChecklistTap,
          ),
        ),
      ),
    );
  }

  group('NoteCard Checklist Preview Filtering Tests', () {
    testWidgets('Excludes completed items from preview and displays only pending items', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'note_1',
        title: 'Daily Checklist',
        content: jsonEncode([
          {'insert': 'Pending Task 1\n', 'attributes': {'list': 'unchecked'}},
          {'insert': 'Completed Task 2\n', 'attributes': {'list': 'checked'}},
          {'insert': 'Pending Task 3\n', 'attributes': {'list': 'unchecked'}},
        ]),
        dateCreated: now,
        dateModified: now,
      );

      await tester.pumpWidget(buildTestCard(note));
      await tester.pumpAndSettle();

      // Pending tasks should be rendered
      expect(find.text('Pending Task 1'), findsOneWidget);
      expect(find.text('Pending Task 3'), findsOneWidget);

      // Completed task should NOT be visible in the card preview
      expect(find.text('Completed Task 2'), findsNothing);

      // Unchecked checkboxes should be present
      expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.check_box_rounded), findsNothing);
    });

    testWidgets('Displays celebratory status badge when all tasks are completed', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'note_2',
        title: 'Finished List',
        content: jsonEncode([
          {'insert': 'Task A\n', 'attributes': {'list': 'checked'}},
          {'insert': 'Task B\n', 'attributes': {'list': 'checked'}},
          {'insert': 'Task C\n', 'attributes': {'list': 'checked'}},
        ]),
        dateCreated: now,
        dateModified: now,
      );

      await tester.pumpWidget(buildTestCard(note));
      await tester.pumpAndSettle();

      // Should display celebratory completion chip and header Done chip
      expect(find.text('3/3 Done'), findsOneWidget);
      expect(find.text('All 3 tasks completed'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsNWidgets(2));

      // Individual crossed-out task texts should not be listed
      expect(find.text('Task A'), findsNothing);
      expect(find.text('Task B'), findsNothing);
      expect(find.text('Task C'), findsNothing);
    });

    testWidgets('Tapping checklist item triggers onChecklistTap callback with correct parameters', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'note_3',
        title: 'Action List',
        content: jsonEncode([
          {'insert': 'Buy Groceries\n', 'attributes': {'list': 'unchecked'}},
        ]),
        dateCreated: now,
        dateModified: now,
      );

      int? tappedLineIndex;
      String? tappedText;

      await tester.pumpWidget(buildTestCard(
        note,
        onChecklistTap: (lineIndex, text) {
          tappedLineIndex = lineIndex;
          tappedText = text;
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Buy Groceries'));
      await tester.pumpAndSettle();

      expect(tappedLineIndex, 0);
      expect(tappedText, 'Buy Groceries');
    });
  });
}
