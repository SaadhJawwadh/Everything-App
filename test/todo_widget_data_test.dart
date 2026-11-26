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

      final success = QuillChecklistHelper.toggleChecklistLine(doc, 0, true);
      expect(success, true);

      final itemsAfterFirst = QuillChecklistHelper.extractChecklistData(doc);
      expect(itemsAfterFirst[0].isDone, true);
      expect(itemsAfterFirst[1].isDone, false);

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

    test('Widget notes JSON payload filters pending before take(30) and preserves counts', () {
      final delta = Delta();
      for (int i = 0; i < 32; i++) {
        delta
          ..insert('Done $i')
          ..insert('\n', {'list': 'checked'});
      }
      delta
        ..insert('Pending A')
        ..insert('\n', {'list': 'unchecked'})
        ..insert('Pending B')
        ..insert('\n', {'list': 'unchecked'});
      final doc = Document.fromDelta(delta);

      final items = QuillChecklistHelper.extractChecklistData(doc);
      final totalCount = items.length;
      final checkedCount = items.where((it) => it.isDone).length;
      final pendingItems = items.where((it) => !it.isDone).toList();
      final boundedPending = pendingItems.take(30).toList();

      final widgetNote = {
        'id': 'note_123',
        'title': 'Shopping List',
        'pendingCount': pendingItems.length,
        'checkedCount': checkedCount,
        'totalCount': totalCount,
        'items': boundedPending
            .map((it) => {
                  'lineIndex': it.lineIndex,
                  'text': it.text,
                  'isDone': it.isDone,
                })
            .toList(),
      };

      final parsed = (jsonDecode(jsonEncode([widgetNote])) as List).first as Map<String, dynamic>;
      expect(parsed['pendingCount'], 2);
      expect(parsed['checkedCount'], 32);
      expect(parsed['totalCount'], 34);
      final parsedItems = parsed['items'] as List<dynamic>;
      expect(parsedItems.length, 2);
      expect(parsedItems[0]['text'], 'Pending A');
      expect(parsedItems[1]['text'], 'Pending B');
    });

    test('toggleChecklistLine falls back to expectedText search if lineIndex shifted', () {
      final delta = Delta()
        ..insert('Added line above\n')
        ..insert('Buy groceries')
        ..insert('\n', {'list': 'unchecked'})
        ..insert('Feed cat')
        ..insert('\n', {'list': 'unchecked'});
      final doc = Document.fromDelta(delta);

      final success = QuillChecklistHelper.toggleChecklistLine(
        doc,
        0,
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
        5,
        true,
        expectedText: 'Nonexistent task',
      );
      expect(success, false);
    });

    test('Strict checklist signature supports lowercase and uppercase - [X]', () {
      const regularTextWithPlaylist = 'Listening to my favorite music playlist all day';
      const checklistJson = '{"insert":"Task\\n","attributes":{"list":"unchecked"}}';
      const markdownChecklist = '- [ ] Buy groceries';
      const markdownUpperChecked = '- [X] Done groceries';

      bool hasChecklistSignature(String content) {
        return content.contains('"list":"checked"') ||
            content.contains('"list":"unchecked"') ||
            content.contains('- [ ]') ||
            content.contains('- [x]') ||
            content.contains('- [X]');
      }

      expect(hasChecklistSignature(regularTextWithPlaylist), isFalse);
      expect(hasChecklistSignature(checklistJson), isTrue);
      expect(hasChecklistSignature(markdownChecklist), isTrue);
      expect(hasChecklistSignature(markdownUpperChecked), isTrue);
    });

    test('Pending toggles match by lineIndex >= 0 first without collapsing duplicate text', () {
      final rawToggles = [
        {'noteId': 'note_1', 'lineIndex': 0, 'text': 'Check', 'isDone': true},
        {'noteId': 'note_1', 'lineIndex': 0, 'text': 'Check', 'isDone': false},
        {'noteId': 'note_1', 'lineIndex': 2, 'text': 'Check', 'isDone': true},
      ];

      final Map<String, Map<String, Map<String, dynamic>>> byNoteSquashed = {};
      for (final t in rawToggles) {
        final noteId = t['noteId'] as String?;
        if (noteId != null && noteId.isNotEmpty) {
          final lineIndex = t['lineIndex'] as int? ?? -1;
          final text = (t['text'] as String?)?.trim();
          final itemKey = lineIndex >= 0
              ? 'idx_$lineIndex'
              : ((text != null && text.isNotEmpty) ? 'txt_$text' : '');
          if (itemKey.isNotEmpty) {
            byNoteSquashed.putIfAbsent(noteId, () => {})[itemKey] = Map<String, dynamic>.from(t);
          }
        }
      }

      expect(byNoteSquashed['note_1']!.length, 2);
      expect(byNoteSquashed['note_1']!['idx_0']!['isDone'], false);
      expect(byNoteSquashed['note_1']!['idx_2']!['isDone'], true);
    });

    test('Widget expense calculation excludes reversals and transfers', () {
      final transactions = [
        {'category': 'Food & Dining', 'amount': 250.0, 'isExpense': true},
        {'category': '__reversal__', 'amount': 100.0, 'isExpense': true},
        {'category': 'Transfer', 'amount': 5000.0, 'isExpense': true},
        {'category': 'transfer', 'amount': 2000.0, 'isExpense': true},
        {'category': 'Groceries', 'amount': 750.0, 'isExpense': true},
      ];

      final activeTx = transactions
          .where((t) =>
              t['category'] != '__reversal__' &&
              (t['category'] as String).toLowerCase() != 'transfer')
          .toList();

      expect(activeTx.length, 2);
      final totalSpent = activeTx.fold<double>(0.0, (sum, t) => sum + (t['amount'] as double));
      expect(totalSpent, 1000.0);
    });
  });
}
