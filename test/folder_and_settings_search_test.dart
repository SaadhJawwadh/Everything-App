import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:note_taking_app/features/notes/providers/note_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NoteProvider - Active Folder and Tag Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('setFolder updates state and persists lastActiveFolder to SharedPreferences', () async {
      final noteProvider = NoteProvider();
      noteProvider.setFolder('Work');
      expect(noteProvider.selectedFolder, equals('Work'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lastActiveFolder'), equals('Work'));
    });

    test('setTag updates state and persists lastActiveTag to SharedPreferences', () async {
      final noteProvider = NoteProvider();
      noteProvider.setTag('Important');
      expect(noteProvider.selectedTag, equals('Important'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lastActiveTag'), equals('Important'));
    });
  });
}
