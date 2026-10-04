import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../core/ui/app_chip.dart';
import '../../../../data/note_model.dart';
import '../../../../utils/quill_checklist_helper.dart';
import '../../../../utils/rich_text_utils.dart';
import '../../data/note_repository.dart';
import '../../providers/note_provider.dart';

/// Modal bottom sheet providing tactile drag-and-drop reordering for checklist items.
///
/// Can be invoked with an existing [Note] (from NoteCard) or an active [QuillController]
/// (from NoteEditorScreen).
class ChecklistReorderSheet extends StatefulWidget {
  final Note? note;
  final QuillController? controller;
  final VoidCallback? onReordered;

  const ChecklistReorderSheet({
    super.key,
    this.note,
    this.controller,
    this.onReordered,
  }) : assert(note != null || controller != null, 'Either note or controller must be provided');

  /// Displays the reorder sheet for an existing note in the list/grid view.
  static Future<void> showWithNote({
    required BuildContext context,
    required Note note,
  }) {
    return AppBottomSheet.show<void>(
      context: context,
      title: 'Reorder Checklist',
      child: ChecklistReorderSheet(note: note),
    );
  }

  /// Displays the reorder sheet for an active note editor session.
  static Future<void> showWithController({
    required BuildContext context,
    required QuillController controller,
    VoidCallback? onReordered,
  }) {
    return AppBottomSheet.show<void>(
      context: context,
      title: 'Reorder Checklist',
      child: ChecklistReorderSheet(
        controller: controller,
        onReordered: onReordered,
      ),
    );
  }

  @override
  State<ChecklistReorderSheet> createState() => _ChecklistReorderSheetState();
}

class _ChecklistReorderSheetState extends State<ChecklistReorderSheet> {
  late Document _doc;
  late List<ChecklistItemData> _items;
  late List<int> _itemMapping; // Maps current list position to original index
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _doc = widget.controller!.document;
    } else {
      final delta = RichTextUtils.contentToDelta(widget.note!.content);
      _doc = Document.fromDelta(delta);
    }

    _items = QuillChecklistHelper.extractChecklistData(_doc);
    _itemMapping = List.generate(_items.length, (i) => i);
  }

  void _onReorderItem(int oldIndex, int newIndex) {
    AppHaptics.selectionClick();
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);

      final mappingItem = _itemMapping.removeAt(oldIndex);
      _itemMapping.insert(newIndex, mappingItem);

      _hasChanges = true;
    });
  }

  Future<void> _applyAndSave() async {
    if (!_hasChanges || _isSaving) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);
    AppHaptics.mediumImpact();

    try {
      if (widget.controller != null) {
        // Reorder directly in the active editor controller's document
        QuillChecklistHelper.reorderChecklistLines(widget.controller!.document, _itemMapping);
        widget.onReordered?.call();
      } else if (widget.note != null) {
        // Reorder in note delta and save via NoteRepository
        QuillChecklistHelper.reorderChecklistLines(_doc, _itemMapping);
        final newJson = jsonEncode(_doc.toDelta().toJson());
        final updatedNote = widget.note!.copyWith(
          content: newJson,
          dateModified: DateTime.now(),
        );
        await NoteRepository.instance.updateNote(updatedNote);
        if (mounted) {
          await context.read<NoteProvider>().refreshNotes();
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checklist reordered successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reorder checklist: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceXXL),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.checklist_rounded, size: 48, color: cs.outlineVariant),
              const SizedBox(height: AppLayout.spaceM),
              Text(
                'No checklist items found',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppLayout.spaceS),
              Text(
                'Add tasks to your note to reorder them.',
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline),
              ),
            ],
          ),
        ),
      );
    }

    final checkedCount = _items.where((i) => i.isDone).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Sub-header with Stats Pill ──
        Row(
          children: [
            AppChip(
              label: '${_items.length} Tasks • $checkedCount Done',
              icon: Icons.sort_rounded,
              backgroundColor: cs.secondaryContainer.withValues(alpha: isDark ? 0.35 : 0.5),
              textColor: cs.onSecondaryContainer,
            ),
            const Spacer(),
            Text(
              'Drag handles to prioritize',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppLayout.spaceM),

        // ── Reorderable Tasks List ──
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.48,
          ),
          child: Theme(
            data: theme.copyWith(
              canvasColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              itemCount: _items.length,
              onReorderItem: _onReorderItem,
              proxyDecorator: (child, index, animation) {
                return Material(
                  color: Colors.transparent,
                  elevation: 6,
                  shadowColor: cs.shadow.withValues(alpha: 0.2),
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final item = _items[index];
                return Padding(
                  key: ValueKey('item_${item.lineIndex}_${item.documentOffset}'),
                  padding: const EdgeInsets.only(bottom: AppLayout.spaceS),
                  child: AppCard.tonal(
                    color: cs.surfaceContainerHigh.withValues(alpha: isDark ? 0.35 : 0.65),
                    borderColor: cs.outlineVariant.withValues(alpha: 0.35),
                    borderRadius: AppLayout.radiusL,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppLayout.spaceM,
                        vertical: AppLayout.spaceS,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.isDone
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: item.isDone ? Colors.green : cs.outline,
                          ),
                          const SizedBox(width: AppLayout.spaceM),
                          Expanded(
                            child: Text(
                              item.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: item.isDone
                                    ? cs.onSurfaceVariant.withValues(alpha: 0.6)
                                    : cs.onSurface,
                                decoration: item.isDone ? TextDecoration.lineThrough : null,
                                decorationColor: cs.onSurfaceVariant.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppLayout.spaceS),
                          ReorderableDragStartListener(
                            index: index,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.drag_handle_rounded,
                                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppLayout.spaceL),

        // ── Apply CTA ──
        FilledButton.icon(
          onPressed: _hasChanges && !_isSaving ? _applyAndSave : () => Navigator.pop(context),
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(_hasChanges ? Icons.check_rounded : Icons.close_rounded),
          label: Text(_hasChanges ? 'Save New Order' : 'Close'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
            ),
          ),
        ),
      ],
    );
  }
}
