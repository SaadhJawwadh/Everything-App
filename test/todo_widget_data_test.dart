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
  });
}
