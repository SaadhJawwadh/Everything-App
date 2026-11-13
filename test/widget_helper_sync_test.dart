import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/data/note_model.dart';
import 'package:note_taking_app/features/notes/data/note_repository.dart';
import 'package:note_taking_app/utils/widget_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.saadhjawwadh.notebook/widget'),
      (MethodCall methodCall) async => null,
    );
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.instance.createTestDatabase(db);
    DatabaseHelper.setMockDatabase(db);
  });

  tearDown(() async {
    DatabaseHelper.setMockDatabase(null);
    await db.close();
  });

  test('syncPendingTodoToggles applies queued toggles and clears processed queue', () async {
    SharedPreferences.setMockInitialValues({});
    final noteId = const Uuid().v4();
    final now = DateTime.now();
    final content = jsonEncode([
      {'insert': 'Buy milk'},
      {'insert': '\n', 'attributes': {'list': 'unchecked'}},
      {'insert': 'Call Alex'},
      {'insert': '\n', 'attributes': {'list': 'unchecked'}},
    ]);

    await NoteRepository.instance.createNote(
      Note(
        id: noteId,
        title: 'Groceries',
        content: content,
        dateCreated: now,
        dateModified: now,
        category: 'Notes',
      ),
    );

    SharedPreferences.setMockInitialValues({
      'widget_pending_toggles': jsonEncode([
        {
          'noteId': noteId,
          'lineIndex': 0,
          'text': 'Buy milk',
          'isDone': true,
          'timestamp': 1000,
        },
      ]),
    });

    await WidgetHelper.syncPendingTodoToggles();

    final updated = await NoteRepository.instance.readNote(noteId);
    expect(updated, isNotNull);
    expect(updated!.content, contains('"list":"checked"'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('widget_pending_toggles'), '[]');
  });
}
