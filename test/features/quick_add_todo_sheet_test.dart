import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/data/note_model.dart';
import 'package:note_taking_app/features/notes/data/note_repository.dart';
import 'package:note_taking_app/features/notes/providers/note_provider.dart';
import 'package:note_taking_app/utils/quill_checklist_helper.dart';
import 'package:note_taking_app/utils/rich_text_utils.dart';
import 'package:note_taking_app/utils/widget_helper.dart';
import 'package:note_taking_app/widgets/home/quick_add_todo_sheet.dart';

class _MockNoteProvider extends ChangeNotifier implements NoteProvider {
  int refreshCalls = 0;

  @override
  Future<void> refreshNotes({
    bool showLoading = true,
    bool preserveLoadedCount = false,
  }) async {
    refreshCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const widgetChannel = MethodChannel('com.saadhjawwadh.notebook/widget');

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('QuickAddTodoSheet UX & Persistence Tests', () {
    late Database db;
    late _MockNoteProvider mockNoteProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseHelper.instance.createTestDatabase(db);
      DatabaseHelper.setMockDatabase(db);
      mockNoteProvider = _MockNoteProvider();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(widgetChannel, (call) async {
        switch (call.method) {
          case 'getPendingTodoQuickAdds':
          case 'getPendingTodoToggles':
            return '[]';
          case 'getWidgetActiveNoteIds':
            return <String, String>{};
          default:
            return true;
        }
      });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(widgetChannel, null);
      await db.close();
      DatabaseHelper.setMockDatabase(null);
    });

    testWidgets('uses initialNoteTitle immediately, gates empty submit, and shows floating AppSnackBar', (tester) async {
      final now = DateTime.now();
      await tester.runAsync(() async {
        await NoteRepository.instance.createNote(
          Note(
            id: 'shopping_1',
            title: 'Shopping List',
            content: jsonEncode([
              {'insert': 'Milk powder\n', 'attributes': {'list': 'unchecked'}},
            ]),
            dateCreated: now,
            dateModified: now,
          ),
        );
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<NoteProvider>.value(
          value: mockNoteProvider,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => QuickAddTodoSheet.show(
                    context,
                    'shopping_1',
                    initialNoteTitle: 'Shopping List',
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Header uses initialNoteTitle immediately without flicker
      expect(find.text('Add Task: Shopping List'), findsOneWidget);

      // Both primary and secondary submit buttons are disabled while input is empty
      final addTaskBtn = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Add Task'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      final addAnotherBtn = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '+ Add another'),
      );
      expect(addTaskBtn.onPressed, isNull);
      expect(addAnotherBtn.onPressed, isNull);

      // Type a task and verify buttons enable
      await tester.enterText(find.byType(TextField), 'Buy some food');
      await tester.pump();

      final enabledAddBtn = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Add Task'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(enabledAddBtn.onPressed, isNotNull);

      await tester.tap(find.text('Add Task'));
      for (int i = 0; i < 40; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump(const Duration(milliseconds: 20));
        if (find.text('Task added: Buy some food').evaluate().isNotEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();

      // Sheet closed and AppSnackBar (floating + success icon) is shown
      expect(find.byType(QuickAddTodoSheet), findsNothing);
      expect(find.text('Task added: Buy some food'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      final saved = await tester.runAsync(() => NoteRepository.instance.readNote('shopping_1'));
      expect(saved, isNotNull);
      final items = QuillChecklistHelper.extractChecklistData(
        Document.fromDelta(RichTextUtils.contentToDelta(saved!.content)),
      );
      expect(items.map((e) => e.text).toList(), ['Milk powder', 'Buy some food']);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump();
    });

    testWidgets('+ Add another adds task, clears field, keeps sheet open, and shows confirmation', (tester) async {
      final now = DateTime.now();
      await tester.runAsync(() async {
        await NoteRepository.instance.createNote(
          Note(
            id: 'shopping_2',
            title: 'Shopping List',
            content: jsonEncode([
              {'insert': 'Bread\n', 'attributes': {'list': 'unchecked'}},
            ]),
            dateCreated: now,
            dateModified: now,
          ),
        );
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<NoteProvider>.value(
          value: mockNoteProvider,
          child: const MaterialApp(
            home: Scaffold(
              body: QuickAddTodoSheet(
                activeNoteId: 'shopping_2',
                initialNoteTitle: 'Shopping List',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Eggs');
      await tester.pump();
      await tester.tap(find.text('+ Add another'));
      for (int i = 0; i < 40; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump(const Duration(milliseconds: 20));
        if (find.text('Added: Eggs').evaluate().isNotEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();

      // Sheet remains open, field is cleared, inline confirmation is displayed
      expect(find.byType(QuickAddTodoSheet), findsOneWidget);
      expect(find.text('Added: Eggs'), findsOneWidget);
      final controller = tester.widget<TextField>(find.byType(TextField)).controller!;
      expect(controller.text, isEmpty);

      final saved = await tester.runAsync(() => NoteRepository.instance.readNote('shopping_2'));
      final items = QuillChecklistHelper.extractChecklistData(
        Document.fromDelta(RichTextUtils.contentToDelta(saved!.content)),
      );
      expect(items.map((e) => e.text).toList(), ['Bread', 'Eggs']);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump();
    });
  });

  group('WidgetHelper pending_quick_adds sync ordering & deduplication', () {
    late Database db;
    late String pendingQuickAddsJson;
    late String pendingTogglesJson;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseHelper.instance.createTestDatabase(db);
      DatabaseHelper.setMockDatabase(db);
      pendingQuickAddsJson = '[]';
      pendingTogglesJson = '[]';

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(widgetChannel, (call) async {
        switch (call.method) {
          case 'getPendingTodoQuickAdds':
            return pendingQuickAddsJson;
          case 'setPendingTodoQuickAdds':
            pendingQuickAddsJson = call.arguments as String? ?? '[]';
            return true;
          case 'getPendingTodoToggles':
            return pendingTogglesJson;
          case 'setPendingTodoToggles':
            pendingTogglesJson = call.arguments as String? ?? '[]';
            return true;
          case 'getWidgetActiveNoteIds':
            return <String, String>{};
          default:
            return null;
        }
      });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(widgetChannel, null);
      await db.close();
      DatabaseHelper.setMockDatabase(null);
    });

    test('drains quick-adds before toggles, deduplicates by id, and preserves chronological order', () async {
      final now = DateTime.now();
      await NoteRepository.instance.createNote(
        Note(
          id: 'note_shop',
          title: 'Shopping List',
          content: jsonEncode([
            {'insert': 'Milk powder\n', 'attributes': {'list': 'unchecked'}},
          ]),
          dateCreated: now,
          dateModified: now,
        ),
      );
      // Let createNote's background widget sync settle before queuing native items
      await WidgetHelper.updateTodoWidgetData();

      pendingQuickAddsJson = jsonEncode([
        {
          'id': 'qa_2',
          'noteId': 'note_shop',
          'text': 'Coffee beans',
          'timestamp': 2000,
        },
        {
          'id': 'qa_1',
          'noteId': 'note_shop',
          'text': 'Buy some food',
          'timestamp': 1000,
        },
        // Duplicate id should be ignored
        {
          'id': 'qa_1',
          'noteId': 'note_shop',
          'text': 'Buy some food',
          'timestamp': 1000,
        },
      ]);

      // User also checked off "Buy some food" on the widget right after adding it
      pendingTogglesJson = jsonEncode([
        {
          'noteId': 'note_shop',
          'lineIndex': -1,
          'text': 'Buy some food',
          'isDone': true,
          'timestamp': 3000,
        },
      ]);

      await WidgetHelper.syncPendingTodoToggles();

      expect(pendingQuickAddsJson, '[]');
      expect(pendingTogglesJson, '[]');

      final updated = await NoteRepository.instance.readNote('note_shop');
      final items = QuillChecklistHelper.extractChecklistData(
        Document.fromDelta(RichTextUtils.contentToDelta(updated!.content)),
      );
      expect(
        items.map((e) => '${e.text}:${e.isDone}').toList(),
        [
          'Milk powder:false',
          'Buy some food:true',
          'Coffee beans:false',
        ],
      );
    });
  });
}
