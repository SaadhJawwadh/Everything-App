import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:note_taking_app/features/notes/data/note_repository.dart';
import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/data/note_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:note_taking_app/providers/note_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Note Scroll, Retention and Trash UX Tests', () {
    late Database db;
    late NoteRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseHelper.instance.createTestDatabase(db);
      DatabaseHelper.setMockDatabase(db);
      repository = NoteRepository();
    });

    tearDown(() async {
      await db.close();
      DatabaseHelper.setMockDatabase(null);
    });

    test('NoteRepository.getChecklistNotesCount counts notes matching checklist format and respects folder filter', () async {
      final now = DateTime.now();

      // Note 1: In Work folder with checklist
      final note1 = Note(
        id: 'n1',
        title: 'Work Checklist',
        content: '[{"insert":"Item 1\\n","attributes":{"list":"unchecked"}}]',
        dateCreated: now,
        dateModified: now,
        category: 'Work',
      );
      // Note 2: In Personal folder with checked checklist
      final note2 = Note(
        id: 'n2',
        title: 'Personal Checklist',
        content: '[{"insert":"Item 2\\n","attributes":{ "list" : "checked" }}]',
        dateCreated: now,
        dateModified: now,
        category: 'Personal',
      );
      // Note 3: In Work folder, regular text
      final note3 = Note(
        id: 'n3',
        title: 'Work Regular Note',
        content: '[{"insert":"Just plain text\\n"}]',
        dateCreated: now,
        dateModified: now,
        category: 'Work',
      );

      await repository.createNote(note1);
      await repository.createNote(note2);
      await repository.createNote(note3);

      final totalChecklists = await repository.getChecklistNotesCount();
      expect(totalChecklists, equals(2));

      final workChecklists = await repository.getChecklistNotesCount(folder: 'Work');
      expect(workChecklists, equals(1));

      final personalChecklists = await repository.getChecklistNotesCount(folder: 'Personal');
      expect(personalChecklists, equals(1));
    });

    test('NoteProvider retains loadedCount when preserveLoadedCount is true', () async {
      final now = DateTime.now();
      // Insert 25 notes
      for (int i = 0; i < 25; i++) {
        await repository.createNote(Note(
          id: 'note_$i',
          title: 'Note $i',
          content: 'Content $i',
          dateCreated: now.subtract(Duration(minutes: i)),
          dateModified: now.subtract(Duration(minutes: i)),
        ));
      }

      final provider = NoteProvider();
      await provider.refreshNotes();
      expect(provider.filteredNotes.length, equals(20)); // initial batch

      // Load more
      await provider.loadMoreNotes();
      expect(provider.filteredNotes.length, equals(25)); // loaded all 25

      // Refresh with preserveLoadedCount: true (default)
      await provider.refreshNotes();
      expect(provider.filteredNotes.length, equals(25)); // preserved loaded count!

      // Refresh with preserveLoadedCount: false
      await provider.refreshNotes(preserveLoadedCount: false);
      expect(provider.filteredNotes.length, equals(20)); // reset to initial batch
    });

    test('NoteProvider filterNotes excludes locked notes when query matches content only', () async {
      final now = DateTime.now();
      await repository.createNote(Note(
        id: 'unlocked_note',
        title: 'Secret Recipe',
        content: 'Baking cookies',
        dateCreated: now,
        dateModified: now,
        isLocked: false,
      ));
      await repository.createNote(Note(
        id: 'locked_note',
        title: 'Private Vault',
        content: 'Top secret bank password',
        dateCreated: now,
        dateModified: now,
        isLocked: true,
      ));

      final provider = NoteProvider();
      await provider.refreshNotes();

      provider.setSearchQuery('secret');
      expect(provider.filteredNotes.length, equals(1));
      expect(provider.filteredNotes.first.id, equals('unlocked_note'));
    });

    test('Soft deleting and restoring note preserves identity without collision', () async {
      final now = DateTime.now();
      final note = Note(
        id: 'trash_test_note',
        title: 'To Be Trashed',
        content: 'Content',
        dateCreated: now,
        dateModified: now,
      );
      await repository.createNote(note);

      // Move to trash
      await repository.softDeleteNote('trash_test_note');
      var trashed = await repository.readTrashedNotes();
      expect(trashed.length, equals(1));
      expect(trashed.first.id, equals('trash_test_note'));

      var active = await repository.readAllNotes();
      expect(active.any((n) => n.id == 'trash_test_note'), isFalse);

      // Restore from trash
      await repository.restoreNote('trash_test_note');
      trashed = await repository.readTrashedNotes();
      expect(trashed.isEmpty, isTrue);

      active = await repository.readAllNotes();
      expect(active.any((n) => n.id == 'trash_test_note'), isTrue);
      expect(active.firstWhere((n) => n.id == 'trash_test_note').deletedAt, isNull);
    });
  });
}
