import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:note_taking_app/utils/quill_checklist_helper.dart';

void main() {
  group('QuillChecklistHelper Tests', () {
    test('getChecklistStats - calculates correct totals and completion percentages', () {
      final doc = Document.fromDelta(Delta()
        ..insert('Task 1\n', {'list': 'checked'})
        ..insert('Task 2\n', {'list': 'checked'})
        ..insert('Task 3\n', {'list': 'unchecked'})
        ..insert('Task 4\n', {'list': 'unchecked'})
      );

      final stats = QuillChecklistHelper.getChecklistStats(doc);
      expect(stats.totalCount, equals(4));
      expect(stats.checkedCount, equals(2));
      expect(stats.uncheckedCount, equals(2));
      expect(stats.completionPercentage, equals(0.5));
      expect(stats.completionPercentInt, equals(50));
    });

    test('extractAndRemoveCheckedLines - extracts checked text and cleans document', () {
      final doc = Document.fromDelta(Delta()
        ..insert('Task 1\n', {'list': 'unchecked'})
        ..insert('Task 2\n', {'list': 'checked'})
      );
      final controller = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );

      final extracted = QuillChecklistHelper.extractAndRemoveCheckedLines(controller);
      expect(extracted, equals(['Task 2']));
      expect(controller.document.toPlainText().trim(), equals('Task 1'));
    });

    test('restoreUncheckedItem - inserts text as unchecked item at end of document', () {
      final doc = Document.fromDelta(Delta()
        ..insert('Task 1\n', {'list': 'unchecked'})
      );
      final controller = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );

      QuillChecklistHelper.restoreUncheckedItem(controller, 'Task 2');

      final stats = QuillChecklistHelper.getChecklistStats(controller.document);
      expect(stats.uncheckedCount, equals(2));
      expect(controller.document.toPlainText().startsWith('Task 1\nTask 2\n'), isTrue);
    });

    test('reorderChecklistLines - reorders checklist items correctly in document', () {
      final doc = Document.fromDelta(Delta()
        ..insert('Task A\n', {'list': 'unchecked'})
        ..insert('Task B\n', {'list': 'checked'})
        ..insert('Task C\n', {'list': 'unchecked'})
      );

      // Reorder to: Task C (idx 2), Task A (idx 0), Task B (idx 1)
      QuillChecklistHelper.reorderChecklistLines(doc, [2, 0, 1]);

      final items = QuillChecklistHelper.extractChecklistData(doc);
      expect(items.length, equals(3));
      expect(items[0].text, equals('Task C'));
      expect(items[0].isDone, isFalse);
      expect(items[1].text, equals('Task A'));
      expect(items[1].isDone, isFalse);
      expect(items[2].text, equals('Task B'));
      expect(items[2].isDone, isTrue);
    });
  });
}
