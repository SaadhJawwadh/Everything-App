import 'package:any_link_preview/any_link_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/ui/app_dialog.dart';
import '../../../../utils/quill_checklist_helper.dart';
import 'note_completed_checklist_card.dart';
import 'note_editor_styles.dart';
import 'note_embed_builders.dart';
import 'note_metadata_chips_bar.dart';

class NoteEditorCanvas extends StatelessWidget {
  final ScrollController scrollController;
  final FocusNode focusNode;
  final QuillController quillController;
  final TextEditingController titleController;
  final bool isNoteInTrash;
  final Color textColor;
  final Color hintColor;
  final ColorScheme noteScheme;
  final DateTime? reminderAt;
  final bool isNoteLocked;
  final bool isCustomFolder;
  final String folder;
  final List<String> tags;
  final Map<String, int> tagColors;
  final List<String> completedItems;
  final bool isCompletedCollapsed;
  final bool isEditingTableCell;
  final List<String> noteUrls;
  final bool isKeyboardOpen;
  final VoidCallback onPickReminder;
  final VoidCallback onClearReminder;
  final VoidCallback onPickFolder;
  final ValueChanged<String> onDeleteTag;
  final VoidCallback onToggleCompletedCollapse;
  final VoidCallback onUncheckAllCompleted;
  final VoidCallback onDeleteAllCompleted;
  final ValueChanged<String> onRestoreCompletedItem;
  final ValueChanged<String> onDeleteCompletedItem;
  final ValueChanged<bool> onTableCellFocusChanged;
  final VoidCallback onSelectAllText;
  final VoidCallback onOpenStoryCardSelected;
  final ValueChanged<String> onDismissUrl;

  const NoteEditorCanvas({
    super.key,
    required this.scrollController,
    required this.focusNode,
    required this.quillController,
    required this.titleController,
    required this.isNoteInTrash,
    required this.textColor,
    required this.hintColor,
    required this.noteScheme,
    required this.reminderAt,
    required this.isNoteLocked,
    required this.isCustomFolder,
    required this.folder,
    required this.tags,
    required this.tagColors,
    required this.completedItems,
    required this.isCompletedCollapsed,
    required this.isEditingTableCell,
    required this.noteUrls,
    required this.isKeyboardOpen,
    required this.onPickReminder,
    required this.onClearReminder,
    required this.onPickFolder,
    required this.onDeleteTag,
    required this.onToggleCompletedCollapse,
    required this.onUncheckAllCompleted,
    required this.onDeleteAllCompleted,
    required this.onRestoreCompletedItem,
    required this.onDeleteCompletedItem,
    required this.onTableCellFocusChanged,
    required this.onSelectAllText,
    required this.onOpenStoryCardSelected,
    required this.onDismissUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (!focusNode.hasFocus) {
            focusNode.requestFocus();
          }
          final docLen = quillController.document.length;
          final endOffset = (docLen - 1).clamp(0, docLen);
          quillController.updateSelection(
            TextSelection.collapsed(offset: endOffset),
            ChangeSource.local,
          );
          final style = quillController.getSelectionStyle();
          if (style.containsKey(Attribute.codeBlock.key)) {
            quillController.replaceText(endOffset, 0, '\n', null);
            quillController.updateSelection(
              TextSelection.collapsed(offset: endOffset + 1),
              ChangeSource.local,
            );
            quillController
                .formatSelection(Attribute.clone(Attribute.codeBlock, null));
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                readOnly: isNoteInTrash,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: 'Title',
                  filled: false,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintStyle: theme.textTheme.headlineMedium?.copyWith(
                    color: hintColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                enableInteractiveSelection: true,
                textCapitalization: TextCapitalization.sentences,
                autocorrect: true,
                maxLines: null,
              ),
              NoteMetadataChipsBar(
                reminderAt: reminderAt,
                isNoteLocked: isNoteLocked,
                isCustomFolder: isCustomFolder,
                folder: folder,
                tags: tags,
                tagColors: tagColors,
                textColor: textColor,
                onPickReminder: onPickReminder,
                onClearReminder: onClearReminder,
                onPickFolder: onPickFolder,
                onDeleteTag: onDeleteTag,
              ),
              NoteCompletedChecklistCard(
                completedItems: completedItems,
                isCollapsed: isCompletedCollapsed,
                onToggleCollapse: onToggleCompletedCollapse,
                onUncheckAll: onUncheckAllCompleted,
                onDeleteAll: onDeleteAllCompleted,
                onRestoreItem: onRestoreCompletedItem,
                onDeleteItem: onDeleteCompletedItem,
                noteScheme: noteScheme,
                textColor: textColor,
              ),
              NotificationListener<TableCellFocusNotification>(
                onNotification: (notification) {
                  onTableCellFocusChanged(notification.isFocused);
                  return true;
                },
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.keyA, control: true):
                        onSelectAllText,
                    const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
                        onSelectAllText,
                  },
                  child: QuillEditor.basic(
                    controller: quillController,
                    focusNode: focusNode,
                    config: QuillEditorConfig(
                      padding: const EdgeInsets.only(bottom: 16),
                      autoFocus: false,
                      showCursor: !isEditingTableCell,
                      enableInteractiveSelection: true,
                      enableSelectionToolbar: true,
                      contextMenuBuilder: (context, rawEditorState) {
                        final buttonItems =
                            rawEditorState.contextMenuButtonItems;
                        return AdaptiveTextSelectionToolbar.buttonItems(
                          anchors: rawEditorState.contextMenuAnchors,
                          buttonItems: [
                            ...buttonItems,
                            ContextMenuButtonItem(
                              onPressed: () {
                                rawEditorState.hideToolbar();
                                onOpenStoryCardSelected();
                              },
                              label: 'Story Card',
                            ),
                          ],
                        );
                      },
                      // ignore: experimental_member_use
                      characterShortcutEvents: standardCharactersShortcutEvents,
                      // ignore: experimental_member_use
                      spaceShortcutEvents: [
                        ...standardSpaceShorcutEvents,
                        // ignore: experimental_member_use
                        SpaceShortcutEvent(
                          character: '[]',
                          handler: (node, controller) {
                            controller.replaceText(
                              controller.selection.baseOffset - 2,
                              2,
                              '\n',
                              null,
                            );
                            final base = controller.selection.baseOffset - 2;
                            controller.updateSelection(
                              controller.selection.copyWith(
                                baseOffset: base,
                                extentOffset: base,
                              ),
                              ChangeSource.local,
                            );
                            controller
                              ..formatSelection(Attribute.unchecked)
                              ..replaceText(
                                controller.selection.baseOffset + 1,
                                1,
                                '',
                                null,
                              );
                            return true;
                          },
                        ),
                      ],
                      expands: false,
                      scrollable: false,
                      placeholder: 'Start typing...',
                      embedBuilders: [
                        const RoundedImageEmbedBuilder(),
                        const TableEmbedBuilder(),
                        ...FlutterQuillEmbeds.editorBuilders(),
                      ],
                      customStyles: NoteEditorStyles.build(
                        theme: theme,
                        noteScheme: noteScheme,
                      ),
                    ),
                  ),
                ),
              ),
              ...noteUrls.map(
                (url) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Stack(
                    children: [
                      AnyLinkPreview(
                        link: url,
                        displayDirection: UIDirection.uiDirectionHorizontal,
                        cache: const Duration(hours: 1),
                        backgroundColor: theme.colorScheme.surfaceContainer,
                        errorWidget: const SizedBox.shrink(),
                        errorImage: "https://via.placeholder.com/150",
                        removeElevation: true,
                        borderRadius: 12,
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Tooltip(
                          message: 'Remove Link Preview',
                          child: Material(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.9),
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                AppHaptics.selectionClick();
                                onDismissUrl(url);
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isKeyboardOpen ? 220 : 100),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper for syncing document checklist state when `QuillController.document.changes` fires.
  static void syncChecklistOnDocumentChange({
    required QuillController quillController,
    required bool moveCompletedChecklistsToBottom,
    required List<String> completedItems,
    required VoidCallback onStateChanged,
  }) {
    if (moveCompletedChecklistsToBottom) {
      final newlyChecked =
          QuillChecklistHelper.extractAndRemoveCheckedLines(quillController);
      if (newlyChecked.isNotEmpty) {
        completedItems.addAll(newlyChecked);
        onStateChanged();
      }
    } else {
      final lines =
          QuillChecklistHelper.getDocumentLines(quillController.document);
      for (final line in lines) {
        final listAttr = line.style.attributes['list']?.value;
        if (listAttr == 'checked' || listAttr == 'unchecked') {
          final isChecked = listAttr == 'checked';
          final hasStrike = line.children.any((node) =>
              node is Leaf && (node.style.attributes['strike']?.value == true));
          if (isChecked && !hasStrike) {
            final textLen =
                (line.length - 1).clamp(0, double.infinity).toInt();
            if (textLen > 0) {
              quillController.document.format(
                line.documentOffset,
                textLen,
                Attribute.strikeThrough,
              );
            }
          } else if (!isChecked && hasStrike) {
            final textLen =
                (line.length - 1).clamp(0, double.infinity).toInt();
            if (textLen > 0) {
              quillController.document.format(
                line.documentOffset,
                textLen,
                Attribute.clone(Attribute.strikeThrough, null),
              );
            }
          }
        }
      }
    }
  }

  /// Helper to confirm and delete all completed items.
  static Future<bool> confirmDeleteAllCompleted(
    BuildContext context,
    int count,
  ) async {
    final confirm = await AppDialog.showConfirm(
      context: context,
      title: 'Delete Completed Items?',
      message:
          'This will permanently remove $count finished items from this note.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    return confirm == true;
  }

  /// Auto-exits a code block when the user presses Enter twice on an empty trailing line.
  static void checkCodeBlockAutoExit(
    QuillController quillController,
    Delta change,
  ) {
    final hasNewlineInsert =
        change.operations.any((op) => op.isInsert && op.data == '\n');
    if (!hasNewlineInsert) return;

    final sel = quillController.selection;
    if (!sel.isCollapsed) return;

    final style = quillController.getSelectionStyle();
    if (!style.containsKey(Attribute.codeBlock.key)) return;

    final pos = sel.baseOffset;
    final text = quillController.document.toPlainText();
    if (pos < 2 || pos > text.length) return;

    if (text[pos - 1] == '\n' && text[pos - 2] == '\n') {
      quillController
          .formatSelection(Attribute.clone(Attribute.codeBlock, null));
      quillController.replaceText(pos - 1, 1, '', null);
      quillController.updateSelection(
        TextSelection.collapsed(offset: pos - 1),
        ChangeSource.local,
      );
    }
  }

  /// Builds the starting document for a note created from shared content.
  static Delta? buildSharedContentDelta({
    required String? initialSharedText,
    required List<String>? initialSharedImagePaths,
  }) {
    final sharedText = initialSharedText?.trim();
    final imagePaths = initialSharedImagePaths ?? const [];
    if ((sharedText == null || sharedText.isEmpty) && imagePaths.isEmpty) {
      return null;
    }

    final delta = Delta();
    if (sharedText != null && sharedText.isNotEmpty) {
      delta.insert('$sharedText\n');
    }
    for (final path in imagePaths) {
      delta.insert({'image': path});
      delta.insert('\n');
    }
    return delta;
  }

  /// Checks whether an image `BlockEmbed` is currently selected at `baseOffset`.
  static bool isImageSelected(QuillController quillController) {
    final index = quillController.selection.baseOffset;
    if (index < 0 || index >= quillController.document.length) return false;

    final leaf = quillController.document.querySegmentLeafNode(index).leaf;
    if (leaf != null && leaf.value is BlockEmbed) {
      return (leaf.value as BlockEmbed).type == 'image';
    }
    return false;
  }

  /// Resolves the theme-aware `(noteScheme, backgroundColor, onBackground)` for a note color integer.
  static (ColorScheme, Color, Color) resolveNoteTheme(
    ThemeData theme,
    int color,
  ) {
    if (color == 0) {
      return (
        theme.colorScheme,
        theme.colorScheme.surface,
        theme.colorScheme.onSurface,
      );
    }
    final scheme = ColorScheme.fromSeed(
      seedColor: Color(color),
      brightness: theme.brightness,
    );
    return (scheme, scheme.surfaceContainerHigh, scheme.onSurface);
  }
}
