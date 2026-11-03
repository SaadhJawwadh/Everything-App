import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../core/services/app_haptics.dart';
import '../core/theme/app_layout.dart';

/// Helper methods for cursor positioning, selection nudging, and scrolling to caret in FlutterQuill.
class QuillCursorHelper {
  static void nudgeLeft({
    required QuillController controller,
    required FocusNode focusNode,
    bool byWord = false,
    bool isEditingTableCell = false,
  }) {
    if (isEditingTableCell) return;
    final selection = controller.selection;
    final docLen = controller.document.length;
    if (!selection.isValid || docLen <= 0) return;

    AppHaptics.selectionClick();
    focusNode.requestFocus();

    final currentExtent = selection.extentOffset;
    final int newExtent;
    if (byWord) {
      final text = controller.document.toPlainText();
      int idx = currentExtent.clamp(0, text.length) - 1;
      while (idx > 0 && text[idx].trim().isEmpty) {
        idx--;
      }
      while (idx > 0 && text[idx - 1].trim().isNotEmpty) {
        idx--;
      }
      newExtent = idx.clamp(0, docLen - 1);
    } else {
      newExtent = (currentExtent - 1).clamp(0, docLen - 1);
    }

    controller.updateSelection(
      selection.isCollapsed
          ? TextSelection.collapsed(offset: newExtent)
          : TextSelection(baseOffset: selection.baseOffset, extentOffset: newExtent),
      ChangeSource.local,
    );
  }

  static void nudgeRight({
    required QuillController controller,
    required FocusNode focusNode,
    bool byWord = false,
    bool isEditingTableCell = false,
  }) {
    if (isEditingTableCell) return;
    final selection = controller.selection;
    final docLen = controller.document.length;
    if (!selection.isValid || docLen <= 0) return;

    AppHaptics.selectionClick();
    focusNode.requestFocus();

    final currentExtent = selection.extentOffset;
    final int newExtent;
    if (byWord) {
      final text = controller.document.toPlainText();
      int idx = currentExtent.clamp(0, text.length);
      while (idx < text.length && text[idx].trim().isNotEmpty) {
        idx++;
      }
      while (idx < text.length && text[idx].trim().isEmpty && text[idx] != '\n') {
        idx++;
      }
      newExtent = idx.clamp(0, docLen - 1);
    } else {
      newExtent = (currentExtent + 1).clamp(0, docLen - 1);
    }

    controller.updateSelection(
      selection.isCollapsed
          ? TextSelection.collapsed(offset: newExtent)
          : TextSelection(baseOffset: selection.baseOffset, extentOffset: newExtent),
      ChangeSource.local,
    );
  }

  static void nudgeUp({
    required QuillController controller,
    required FocusNode focusNode,
    bool isEditingTableCell = false,
  }) {
    if (isEditingTableCell) return;
    final selection = controller.selection;
    final text = controller.document.toPlainText();
    if (!selection.isValid || text.isEmpty) return;

    AppHaptics.selectionClick();
    focusNode.requestFocus();

    final currentOffset = selection.extentOffset.clamp(0, text.length - 1);
    final prevLineEnd = text.lastIndexOf('\n', currentOffset > 0 ? currentOffset - 1 : 0);
    if (prevLineEnd >= 0) {
      final prevLineStart = text.lastIndexOf('\n', prevLineEnd > 0 ? prevLineEnd - 1 : 0) + 1;
      final currentLineStart = text.lastIndexOf('\n', currentOffset > 0 ? currentOffset - 1 : 0) + 1;
      final column = currentOffset - currentLineStart;
      final newOffset = (prevLineStart + column).clamp(0, prevLineEnd);
      controller.updateSelection(
        selection.isCollapsed
            ? TextSelection.collapsed(offset: newOffset)
            : TextSelection(baseOffset: selection.baseOffset, extentOffset: newOffset),
        ChangeSource.local,
      );
    } else {
      controller.updateSelection(
        selection.isCollapsed
            ? const TextSelection.collapsed(offset: 0)
            : TextSelection(baseOffset: selection.baseOffset, extentOffset: 0),
        ChangeSource.local,
      );
    }
  }

  static void nudgeDown({
    required QuillController controller,
    required FocusNode focusNode,
    bool isEditingTableCell = false,
  }) {
    if (isEditingTableCell) return;
    final selection = controller.selection;
    final text = controller.document.toPlainText();
    if (!selection.isValid || text.isEmpty) return;

    AppHaptics.selectionClick();
    focusNode.requestFocus();

    final currentOffset = selection.extentOffset.clamp(0, text.length - 1);
    final currentLineStart = text.lastIndexOf('\n', currentOffset > 0 ? currentOffset - 1 : 0) + 1;
    final column = currentOffset - currentLineStart;
    final nextLineStart = text.indexOf('\n', currentOffset);
    if (nextLineStart >= 0 && nextLineStart + 1 < text.length) {
      final nextLineEnd = text.indexOf('\n', nextLineStart + 1);
      final lineEnd = nextLineEnd >= 0 ? nextLineEnd : text.length - 1;
      final newOffset = (nextLineStart + 1 + column).clamp(0, lineEnd);
      controller.updateSelection(
        selection.isCollapsed
            ? TextSelection.collapsed(offset: newOffset)
            : TextSelection(baseOffset: selection.baseOffset, extentOffset: newOffset),
        ChangeSource.local,
      );
    } else {
      controller.updateSelection(
        selection.isCollapsed
            ? TextSelection.collapsed(offset: text.length - 1)
            : TextSelection(baseOffset: selection.baseOffset, extentOffset: text.length - 1),
        ChangeSource.local,
      );
    }
  }

  static void selectAll(QuillController controller) {
    final docLen = controller.document.length;
    if (docLen <= 1) return;
    controller.updateSelection(
      TextSelection(baseOffset: 0, extentOffset: docLen - 1),
      ChangeSource.local,
    );
  }

  static RenderBox? findRenderEditor(RenderObject? object) {
    if (object == null) return null;
    if (object.runtimeType.toString().contains('RenderEditor')) {
      return object as RenderBox;
    }
    RenderBox? result;
    object.visitChildren((child) {
      if (result != null) return;
      result = findRenderEditor(child);
    });
    return result;
  }

  static void scrollToCursorIfNeeded({
    required FocusNode focusNode,
    required ScrollController scrollController,
    required QuillController quillController,
  }) {
    if (!focusNode.hasFocus || !scrollController.hasClients) return;
    final selection = quillController.selection;
    if (selection.baseOffset < 0) return;

    final docLength = quillController.document.length;
    if (docLength <= 1) return;

    try {
      final focusContext = focusNode.context;
      if (focusContext == null) return;

      final rootRenderObject = focusContext.findRenderObject();
      final editorRenderObject = findRenderEditor(rootRenderObject);
      if (editorRenderObject == null || !editorRenderObject.attached) return;

      final scrollableState = Scrollable.of(focusContext);
      final scrollRenderObject = scrollableState.context.findRenderObject();
      if (scrollRenderObject is! RenderBox || !scrollRenderObject.attached) return;

      final dynamic dynamicRender = editorRenderObject;
      final TextPosition pos = TextPosition(offset: selection.baseOffset);
      Rect? caretRect;
      try {
        caretRect = dynamicRender.getLocalRectForCaret(pos);
      } catch (_) {
        try {
          final endpoints = dynamicRender.getEndpointsForSelection(selection);
          if (endpoints.isNotEmpty) {
            final ep = endpoints.first;
            caretRect = Rect.fromLTWH(ep.point.dx, ep.point.dy, 2.0, ep.handleHeight);
          }
        } catch (_) {}
      }

      final double caretTop = caretRect?.top ??
          (editorRenderObject.size.height * (selection.baseOffset / docLength));
      final double caretHeight = (caretRect != null && caretRect.height > 0)
          ? caretRect.height
          : 24.0;

      final Offset editorOffsetInScrollable = editorRenderObject.localToGlobal(
        Offset.zero,
        ancestor: scrollRenderObject,
      );

      final double cursorYInContent =
          scrollController.offset + editorOffsetInScrollable.dy + caretTop;

      final double currentScroll = scrollController.offset;
      final double viewportHeight = scrollController.position.viewportDimension;

      const double topPadding = 60.0;
      const double bottomPadding = 160.0;

      final double visibleTop = currentScroll + topPadding;
      final double visibleBottom = currentScroll + viewportHeight - bottomPadding;

      double? targetScroll;

      if (cursorYInContent + caretHeight > visibleBottom) {
        targetScroll = (cursorYInContent + caretHeight) - (viewportHeight - bottomPadding);
      } else if (cursorYInContent < visibleTop) {
        targetScroll = cursorYInContent - topPadding;
      }

      if (targetScroll != null) {
        final maxScroll = scrollController.position.maxScrollExtent;
        final clampedTarget = targetScroll.clamp(0.0, maxScroll);

        if ((clampedTarget - currentScroll).abs() > 2.0) {
          scrollController.animateTo(
            clampedTarget,
            duration: AppLayout.animFast,
            curve: Curves.easeOutCubic,
          );
        }
      }
    } catch (e) {
      debugPrint('Error scrolling to cursor: $e');
    }
  }
}
