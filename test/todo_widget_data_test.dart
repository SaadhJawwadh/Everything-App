import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:note_taking_app/utils/quill_checklist_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuillChecklistHelper Unit Tests', () {
    test('extractChecklistData extracts checked and unchecked items with line indices', () {
      final delta = Delta()
        ..insert('Task 1')
        ..insert('\n', {'list': 'unchecked'})
        ..insert('Task 2')
        ..insert('\n', {'list': 'checked'})
        ..insert('Regular paragraph\n')
        ..insert('Task 3')
        ..insert('\n', {'list': 'unchecked'});
      final doc = Document.fromDelta(delta);

      final items = QuillChecklistHelper.extractChecklistData(doc);
      expect(items.length, 3);
      expect(items[0].text, 'Task 1');
      expect(items[0].isDone, false);
      expect(items[0].lineIndex, 0);

      expect(items[1].text, 'Task 2');
      expect(items[1].isDone, true);
      expect(items[1].lineIndex, 1);

      expect(items[2].text, 'Task 3');
      expect(items[2].isDone, false);
      expect(items[2].lineIndex, 3);
    });

    test('toggleChecklistLine toggles status and applies/clears strikethrough', () {
      final delta = Delta()
        ..insert('Buy milk')
        ..insert('\n', {'list': 'unchecked'})
        ..insert('Walk dog')
        ..insert('\n', {'list': 'unchecked'});
      final doc = Document.fromDelta(delta);

      // Toggle first item to checked
      final success = QuillChecklistHelper.toggleChecklistLine(doc, 0, true);
      expect(success, true);

      final itemsAfterFirst = QuillChecklistHelper.extractChecklistData(doc);
      expect(itemsAfterFirst[0].isDone, true);
      expect(itemsAfterFirst[1].isDone, false);

      // Toggle first item back to unchecked
      final successBack = QuillChecklistHelper.toggleChecklistLine(doc, 0, false);
      expect(successBack, true);

      final itemsAfterBack = QuillChecklistHelper.extractChecklistData(doc);
      expect(itemsAfterBack[0].isDone, false);
      expect(itemsAfterBack[1].isDone, false);
    });

    test('appendChecklistItem appends unchecked items to empty and populated docs', () {
      final docEmpty = Document();
      QuillChecklistHelper.appendChecklistItem(docEmpty, 'First item');
      final items1 = QuillChecklistHelper.extractChecklistData(docEmpty);
      expect(items1.length, 1);
      expect(items1[0].text, 'First item');
      expect(items1[0].isDone, false);

      QuillChecklistHelper.appendChecklistItem(docEmpty, 'Second item');
      final items2 = QuillChecklistHelper.extractChecklistData(docEmpty);
      expect(items2.length, 2);
      expect(items2[1].text, 'Second item');
      expect(items2[1].isDone, false);
    });

    test('getChecklistStats calculates counts and percentages accurately', () {
      final delta = Delta()
        ..insert('A')
        ..insert('\n', {'list': 'checked'})
        ..insert('B')
        ..insert('\n', {'list': 'checked'})
        ..insert('C')
        ..insert('\n', {'list': 'unchecked'})
        ..insert('D')
        ..insert('\n', {'list': 'unchecked'});
      final doc = Document.fromDelta(delta);

      final stats = QuillChecklistHelper.getChecklistStats(doc);
      expect(stats.totalCount, 4);
      expect(stats.checkedCount, 2);
      expect(stats.uncheckedCount, 2);
      expect(stats.completionPercentage, 0.5);
      expect(stats.completionPercentInt, 50);
    });
  });

  group('TODO Widget Data Serialization Parity Tests', () {
    test('ChecklistItemData serializes to JSON expected by Android TodoWidgetService', () {
      const item = ChecklistItemData(
        lineIndex: 2,
        text: 'Review PR',
        isDone: false,
        documentOffset: 24,
      );

      final jsonMap = item.toJson();
      expect(jsonMap['lineIndex'], 2);
      expect(jsonMap['text'], 'Review PR');
      expect(jsonMap['isDone'], false);
      expect(jsonMap['documentOffset'], 24);

      final decoded = ChecklistItemData.fromJson(jsonMap);
      expect(decoded.lineIndex, item.lineIndex);
      expect(decoded.text, item.text);
      expect(decoded.isDone, item.isDone);
    });

    test('Widget notes JSON payload matches Android contract', () {
      final doc = Document();
      doc.insert(0, 'Groceries:\nApples\nBananas\n');
      doc.format(17, 1, Attribute.unchecked);
      doc.format(25, 1, Attribute.checked);

      final items = QuillChecklistHelper.extractChecklistData(doc);
      final widgetNote = {
        'id': 'note_123',
        'title': 'Shopping List',
        'items': items.map((it) => it.toJson()).toList(),
      };

      final serialized = jsonEncode([widgetNote]);
      final List<dynamic> parsed = jsonDecode(serialized);

      expect(parsed.length, 1);
      final firstNote = parsed.first as Map<String, dynamic>;
      expect(firstNote['id'], 'note_123');
      expect(firstNote['title'], 'Shopping List');

      final parsedItems = firstNote['items'] as List<dynamic>;
      expect(parsedItems.length, 2);
      expect(parsedItems[0]['text'], 'Apples');
      expect(parsedItems[0]['isDone'], false);
      expect(parsedItems[1]['text'], 'Bananas');
      expect(parsedItems[1]['isDone'], true);
    });

    test('toggleChecklistLine falls back to expectedText search if lineIndex shifted', () {
      final delta = Delta()
        ..insert('Added line above\n')
        ..insert('Buy groceries')
        ..insert('\n', {'list': 'unchecked'})
        ..insert('Feed cat')
        ..insert('\n', {'list': 'unchecked'});
      final doc = Document.fromDelta(delta);

      // Line index 0 is "Added line above", but expectedText is "Buy groceries" which is at line 1
      final success = QuillChecklistHelper.toggleChecklistLine(
        doc,
        0, // stale lineIndex
        true,
        expectedText: 'Buy groceries',
      );
      expect(success, true);

      final items = QuillChecklistHelper.extractChecklistData(doc);
      expect(items.length, 2);
      expect(items[0].text, 'Buy groceries');
      expect(items[0].isDone, true);
      expect(items[1].text, 'Feed cat');
      expect(items[1].isDone, false);
    });

    test('toggleChecklistLine returns false if neither lineIndex nor expectedText matches', () {
      final delta = Delta()
        ..insert('Line 1\n')
        ..insert('Line 2\n');
      final doc = Document.fromDelta(delta);

      final success = QuillChecklistHelper.toggleChecklistLine(
        doc,
        5, // out of bounds
        true,
        expectedText: 'Nonexistent task',
      );
      expect(success, false);
    });

    test('Strict checklist signature prevents false-positive matches on regular text', () {
      const regularTextWithPlaylist = 'Listening to my favorite music playlist all day';
      const checklistJson = '{"insert":"Task\\n","attributes":{"list":"unchecked"}}';
      const markdownChecklist = '- [ ] Buy groceries';

      bool hasChecklistSignature(String content) {
        return content.contains('"list":"checked"') ||
            content.contains('"list":"unchecked"') ||
            content.contains('- [ ]') ||
            content.contains('- [x]');
      }

      expect(hasChecklistSignature(regularTextWithPlaylist), isFalse);
      expect(hasChecklistSignature(checklistJson), isTrue);
      expect(hasChecklistSignature(markdownChecklist), isTrue);
    });

    test('Pending toggles deduplicate/squash by distinct itemKey', () {
      final rawToggles = [
        {'noteId': 'note_1', 'lineIndex': 0, 'text': 'Buy milk', 'isDone': true},
        {'noteId': 'note_1', 'lineIndex': 0, 'text': 'Buy milk', 'isDone': false},
        {'noteId': 'note_1', 'lineIndex': 0, 'text': 'Buy milk', 'isDone': true},
        {'noteId': 'note_1', 'lineIndex': 1, 'text': 'Call plumber', 'isDone': true},
      ];

      final Map<String, Map<String, Map<String, dynamic>>> byNoteSquashed = {};
      for (final t in rawToggles) {
        final noteId = t['noteId'] as String?;
        if (noteId != null && noteId.isNotEmpty) {
          final lineIndex = t['lineIndex'] as int? ?? -1;
          final text = (t['text'] as String?)?.trim();
          final itemKey = (text != null && text.isNotEmpty) ? text : 'idx_$lineIndex';
          byNoteSquashed.putIfAbsent(noteId, () => {})[itemKey] = Map<String, dynamic>.from(t);
        }
      }

      expect(byNoteSquashed.length, 1);
      final note1Toggles = byNoteSquashed['note_1']!;
      expect(note1Toggles.length, 2);
      expect(note1Toggles['Buy milk']!['isDone'], true);
      expect(note1Toggles['Call plumber']!['isDone'], true);
    });
  });
}
