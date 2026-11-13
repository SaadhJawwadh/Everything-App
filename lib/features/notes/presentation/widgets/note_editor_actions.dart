import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_dialog.dart';
import '../../../../data/note_model.dart';
import '../../../../screens/app_lock_screen.dart';
import '../../../../services/notification_service.dart';
import '../../../../utils/app_globals.dart';
import '../../../../utils/quill_checklist_helper.dart';
import '../../../../utils/rich_text_utils.dart';
import '../../../../utils/widget_helper.dart';
import '../../../../widgets/editor/editor_note_details_sheet.dart';
import '../../../../widgets/editor/editor_table_dialog.dart';
import '../../../story_cards/story_cards.dart';
import '../../data/note_repository.dart';
import '../../providers/note_provider.dart';
import 'note_folder_dialog.dart';
import 'note_share_export_sheet.dart';
import 'story_card_creator_sheet.dart';

class NoteEditorActions {
  NoteEditorActions._();

  /// Builds the Trash Warning Banner when viewing a soft-deleted note.
  static Widget buildTrashWarningBanner({
    required BuildContext context,
    required VoidCallback onRestore,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppLayout.radiusM),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.delete_outline_rounded,
            size: 20,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Note is in Trash. Restore to make edits.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onRestore,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusS),
              ),
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  /// Up to three distinct links in the note, for rich preview cards.
  static List<String> extractUrls(
    String plainText,
    Set<String> dismissedUrls,
  ) {
    final urlRegExp = RegExp(r'https?:\/\/[^\s]+');
    final urls = <String>[];
    for (final match in urlRegExp.allMatches(plainText)) {
      var url = match.group(0)!;
      if (RegExp(r'[.,;:)\]]+$').hasMatch(url)) {
        url = url.replaceAll(RegExp(r'[.,;:)\]]+$'), '');
      }
      if (url.isNotEmpty &&
          !urls.contains(url) &&
          !dismissedUrls.contains(url)) {
        urls.add(url);
      }
      if (urls.length >= 3) break;
    }
    return urls;
  }

  /// Prompts the user for a future date and time reminder.
  static Future<DateTime?> pickReminder(
    BuildContext context,
    DateTime? currentReminder,
  ) async {
    final now = DateTime.now();
    final initial = currentReminder ?? now.add(const Duration(hours: 1));

    if (!context.mounted) return null;
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? initial : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
      helpText: 'Remind me about this note',
    );
    if (date == null || !context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !context.mounted) return null;

    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!picked.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder time must be in the future')),
      );
      return null;
    }
    return picked;
  }

  /// Shows the table insertion dialog and inserts the `TableBlockEmbed` into `quillController`.
  static Future<void> showTableInsertionDialog(
    BuildContext context,
    QuillController quillController,
  ) async {
    final result = await EditorTableDialog.show(context);
    if (result != null) {
      final rowsList = List.generate(
        result.rows,
        (rIndex) => List.generate(
          result.cols,
          (cIndex) => rIndex == 0 ? 'Header ${cIndex + 1}' : 'Cell',
        ),
      );
      final jsonStr = jsonEncode(rowsList);
      final index = quillController.selection.baseOffset;
      final length = quillController.selection.extentOffset - index;

      quillController.replaceText(
        index,
        length,
        TableBlockEmbed(jsonStr),
        null,
      );

      quillController.updateSelection(
        TextSelection.collapsed(offset: index + 1),
        ChangeSource.local,
      );
    }
  }

  /// Displays word count, character count, reading time, and note timestamps.
  static void showNoteDetailsSheet({
    required BuildContext context,
    required QuillController quillController,
    required String folder,
    required DateTime? createdAt,
    required DateTime? updatedAt,
  }) {
    final plainText = quillController.document.toPlainText();
    EditorNoteDetailsSheet.show(
      context,
      plainText: plainText,
      folder: folder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Displays sharing options for exporting plain text, markdown, or copying to clipboard.
  static void showShareExportSheet({
    required BuildContext context,
    required String title,
    required QuillController quillController,
    required VoidCallback onOpenStoryCard,
  }) {
    final delta = quillController.document.toDelta();
    final plainText = quillController.document.toPlainText().trim();

    NoteShareExportSheet.show(
      context: context,
      title: title,
      delta: delta,
      plainText: plainText,
      onOpenStoryCard: onOpenStoryCard,
    );
  }

  static void openStoryCardStudio({
    required BuildContext context,
    required String title,
    required QuillController quillController,
    required bool isCustomFolder,
    required String folder,
    required List<String> noteTags,
    required int colorValue,
    required DateTime noteDate,
    bool selectedOnly = false,
  }) {
    String textToExport = '';

    if (selectedOnly && !quillController.selection.isCollapsed) {
      final sel = quillController.selection;
      final start = sel.start;
      final len = sel.end - sel.start;
      textToExport = quillController.document.getPlainText(start, len).trim();
    }

    if (textToExport.isEmpty) {
      if (!quillController.selection.isCollapsed) {
        final sel = quillController.selection;
        final start = sel.start;
        final len = sel.end - sel.start;
        textToExport = quillController.document.getPlainText(start, len).trim();
      }
      if (textToExport.isEmpty) {
        textToExport = quillController.document.toPlainText().trim();
      }
    }

    final category = isCustomFolder
        ? folder
        : (noteTags.isNotEmpty ? noteTags.first : 'Note');

    StoryCardStudioSheet.show(
      context: context,
      initialText: textToExport,
      noteTitle: title,
      category: category,
      noteColorValue: colorValue,
      noteDate: noteDate,
    );
  }

  /// Lets the user file the note into a folder (or create a new one).
  static Future<String?> pickFolder(
    BuildContext context,
    String currentFolder,
  ) async {
    final folders = await NoteRepository.instance.getAllFolders();
    if (!context.mounted) return null;

    final chosen = await NoteFolderDialog.show(
      context: context,
      currentFolder: currentFolder,
      folders: folders,
    );

    if (chosen == null || chosen == currentFolder || !context.mounted) {
      return null;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          chosen == 'All Notes' ? 'Removed from folder' : 'Moved to "$chosen"',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return chosen;
  }

  /// Toggles the per-note biometric lock; toggling in either direction
  /// requires device authentication so a bystander can't unlock a note.
  static Future<bool?> toggleNoteLock(
    BuildContext context,
    bool isCurrentlyLocked,
  ) async {
    AppHaptics.selectionClick();
    try {
      AppLockScreen.ignoreNextResumeLock();
      final didAuthenticate = await LocalAuthentication().authenticate(
        localizedReason:
            isCurrentlyLocked ? 'Unlock this note' : 'Lock this note',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (!didAuthenticate || !context.mounted) return null;
      final nextLocked = !isCurrentlyLocked;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextLocked
                ? 'Note locked — it will require authentication to open'
                : 'Note unlocked',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return nextLocked;
    } catch (e) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Set up a device screen lock or biometrics to lock notes'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }
  }

  /// Confirms and deletes (or moves to Trash) a note, showing an Undo SnackBar.
  static Future<void> confirmAndDeleteNote({
    required BuildContext context,
    required String noteId,
    required bool isNoteInTrash,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: isNoteInTrash ? 'Delete Permanently?' : 'Move to Trash?',
        content: Text(
          isNoteInTrash
              ? 'This note will be permanently deleted. This action cannot be undone.'
              : 'This note will be moved to Trash.',
        ),
        cancelLabel: 'Cancel',
        confirmLabel: isNoteInTrash ? 'Delete Forever' : 'Move to Trash',
        isDestructive: true,
        onCancel: () => Navigator.pop(context, false),
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (confirmed == true) {
      if (isNoteInTrash) {
        await NoteRepository.instance.deleteNote(noteId);
        if (context.mounted) Navigator.pop(context, true);
        appScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Note permanently deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        await NoteRepository.instance.softDeleteNote(noteId);
        if (context.mounted) Navigator.pop(context, true);

        appScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: const Text('Note moved to Trash'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await NoteRepository.instance.restoreNote(noteId);
                final ctx = appScaffoldMessengerKey.currentContext;
                if (ctx != null && ctx.mounted) {
                  await Provider.of<NoteProvider>(ctx, listen: false)
                      .refreshNotes();
                }
              },
            ),
          ),
        );
      }
    }
  }

  /// Checks whether the current cursor position triggers a `/` slash command.
  /// Returns `(showMenu, query, lineStart)`.
  static (bool, String, int) evaluateSlashCommand(
    QuillController quillController,
  ) {
    final selection = quillController.selection;
    if (selection.isCollapsed && selection.baseOffset > 0) {
      final cursor = selection.baseOffset;
      if (cursor <= quillController.document.length) {
        final nodeResult = quillController.document.queryChild(cursor - 1);
        final line = nodeResult.node;
        if (line is Line) {
          final lineOffset = line.documentOffset;
          final lineText = line.toPlainText();
          final relativeCursor =
              (cursor - lineOffset).clamp(0, lineText.length);
          final linePrefix = lineText.substring(0, relativeCursor);
          if (linePrefix.startsWith('/')) {
            final query = linePrefix.substring(1).toLowerCase();
            return (true, query, lineOffset);
          }
        }
      }
    }
    return (false, '', 0);
  }

  /// Executes the chosen `/` slash command on `quillController`.
  static void executeSlashCommand({
    required String command,
    required QuillController quillController,
    required int slashLineStart,
    required (int, int) selectionRange,
    required VoidCallback onShowAiOptions,
  }) {
    AppHaptics.lightImpact();
    final currentCursor = quillController.selection.baseOffset;
    final deleteLength = currentCursor - slashLineStart;
    if (deleteLength > 0 && deleteLength <= currentCursor) {
      quillController.replaceText(
        slashLineStart,
        deleteLength,
        '',
        TextSelection.collapsed(offset: slashLineStart),
      );
    }

    switch (command) {
      case 'ai':
        onShowAiOptions();
        break;
      case 'todo':
        quillController.formatSelection(Attribute.unchecked);
        break;
      case 'table':
        insertTableDirect(
          quillController: quillController,
          selectionRange: selectionRange,
        );
        break;
      case 'code':
        quillController.formatSelection(Attribute.codeBlock);
        break;
      case 'h1':
        quillController.formatSelection(Attribute.h1);
        break;
      case 'h2':
        quillController.formatSelection(Attribute.h2);
        break;
      case 'quote':
        quillController.formatSelection(Attribute.blockQuote);
        break;
      case 'bullet':
        quillController.formatSelection(Attribute.ul);
        break;
      case 'number':
        quillController.formatSelection(Attribute.ol);
        break;
    }
  }

  /// Directly inserts a `rows x cols` table embed at `selectionRange`.
  static void insertTableDirect({
    required QuillController quillController,
    required (int, int) selectionRange,
    int rows = 3,
    int cols = 3,
  }) {
    final rowsList = List.generate(
      rows,
      (rIndex) => List.generate(
        cols,
        (cIndex) => rIndex == 0 ? 'Header ${cIndex + 1}' : 'Cell',
      ),
    );
    final jsonStr = jsonEncode(rowsList);
    final (index, length) = selectionRange;

    quillController.replaceText(
      index,
      length,
      TableBlockEmbed(jsonStr),
      null,
    );

    quillController.updateSelection(
      TextSelection.collapsed(offset: index + 1),
      ChangeSource.local,
    );
  }

  /// Jumps the editor selection to a specific checklist line or matching text.
  static void jumpToTargetChecklist({
    required QuillController quillController,
    required FocusNode focusNode,
    required int? targetLineIndex,
    required String? targetChecklistText,
    required VoidCallback onScrollToCursor,
  }) {
    try {
      final plainText = quillController.document.toPlainText();
      final lines = plainText.split('\n');
      int? targetIndex = targetLineIndex;

      if (targetChecklistText != null &&
          targetChecklistText.trim().isNotEmpty) {
        final query = targetChecklistText.trim();
        bool matched = false;
        if (targetIndex != null &&
            targetIndex >= 0 &&
            targetIndex < lines.length) {
          if (lines[targetIndex].trim() == query) {
            matched = true;
          }
        }
        if (!matched) {
          for (int i = 0; i < lines.length; i++) {
            if (lines[i].trim() == query || lines[i].contains(query)) {
              targetIndex = i;
              break;
            }
          }
        }
      }

      if (targetIndex != null &&
          targetIndex >= 0 &&
          targetIndex < lines.length) {
        int charOffset = 0;
        for (int i = 0; i < targetIndex; i++) {
          charOffset += lines[i].length + 1;
        }
        final clampedOffset =
            charOffset.clamp(0, quillController.document.length - 1);
        quillController.updateSelection(
          TextSelection.collapsed(offset: clampedOffset),
          ChangeSource.local,
        );
        focusNode.requestFocus();
        onScrollToCursor();
      }
    } catch (e) {
      debugPrint('Error jumping to target checklist item: $e');
    }
  }

  /// Persists the note to `NoteRepository`, updates the Android widget, and syncs reminders.
  /// Returns `(hasChanges, isNoteSaved, lastScheduledReminder)`.
  static Future<(bool, bool, DateTime?)> persistNote({
    required String noteId,
    required Note? initialNote,
    required bool isNoteSaved,
    required bool currentHasChanges,
    required DateTime dateCreated,
    required String title,
    required QuillController quillController,
    required bool moveCompletedChecklistsToBottom,
    required List<String> completedItems,
    required bool isPinned,
    required bool isArchived,
    required int color,
    required String folder,
    required List<String> tags,
    required DateTime? reminderAt,
    required DateTime? lastScheduledReminder,
    required bool isNoteLocked,
  }) async {
    var delta = quillController.document.toDelta();
    if (moveCompletedChecklistsToBottom && completedItems.isNotEmpty) {
      if (delta.length == 1 &&
          delta.first.data == '\n' &&
          (delta.first.attributes == null || delta.first.attributes!.isEmpty)) {
        delta = Delta();
      }
      for (final text in completedItems) {
        if (text.trim().isEmpty) continue;
        delta = delta.concat(
          Delta()
            ..insert(text, {'strike': true})
            ..insert('\n', {'list': 'checked'}),
        );
      }
    }
    final content = RichTextUtils.deltaToJson(delta);
    final plainText = quillController.document.toPlainText().trim();
    final isEmpty = title.isEmpty &&
        plainText.isEmpty &&
        completedItems.isEmpty &&
        tags.isEmpty;
    final exists = initialNote != null || isNoteSaved;

    if (isEmpty) {
      if (exists) {
        await NoteRepository.instance.deleteNote(noteId);
        return (true, isNoteSaved, lastScheduledReminder);
      }
      return (currentHasChanges, isNoteSaved, lastScheduledReminder);
    }

    bool hasChanges = false;
    if (initialNote == null) {
      hasChanges = true;
    } else {
      hasChanges = title != initialNote.title ||
          content != initialNote.content ||
          isPinned != initialNote.isPinned ||
          isArchived != initialNote.isArchived ||
          color != initialNote.color ||
          !listEquals(tags, initialNote.tags) ||
          reminderAt != initialNote.reminderAt ||
          isNoteLocked != initialNote.isLocked ||
          folder != initialNote.category;
    }

    if (!hasChanges) {
      return (currentHasChanges, isNoteSaved, lastScheduledReminder);
    }

    final note = Note(
      id: noteId,
      title: title,
      content: content,
      dateCreated: dateCreated,
      dateModified: DateTime.now(),
      isPinned: isPinned,
      isArchived: isArchived,
      color: color,
      imagePath: initialNote?.imagePath,
      category: folder,
      tags: tags,
      reminderAt: reminderAt,
      isLocked: isNoteLocked,
    );

    bool nextIsSaved = isNoteSaved;
    if (exists) {
      await NoteRepository.instance.updateNote(note);
    } else {
      await NoteRepository.instance.createNote(note);
      nextIsSaved = true;
    }
    unawaited(WidgetHelper.updateTodoWidgetData());

    DateTime? nextScheduledReminder = lastScheduledReminder;
    if (lastScheduledReminder != reminderAt) {
      nextScheduledReminder = reminderAt;
      if (reminderAt != null) {
        await NotificationService.scheduleNoteReminder(
          noteId: noteId,
          noteTitle: title,
          when: reminderAt,
        );
      } else {
        await NotificationService.cancelNoteReminder(noteId);
      }
    }
    return (true, nextIsSaved, nextScheduledReminder);
  }

  /// Finds all match offsets for `query` in `quillController` and jumps to the first match.
  static List<int> findSearchOffsets({
    required QuillController quillController,
    required String query,
    required bool isCaseSensitive,
  }) {
    if (query.isEmpty) return const [];
    final text = quillController.document.toPlainText();
    final escapedQuery = RegExp.escape(query);
    final matches =
        RegExp(escapedQuery, caseSensitive: isCaseSensitive).allMatches(text);
    final offsets = matches.map((m) => m.start).toList();
    if (offsets.isNotEmpty) {
      jumpToMatch(quillController, offsets[0], query.length);
    }
    return offsets;
  }

  /// Selects a search match range inside `quillController`.
  static void jumpToMatch(
    QuillController quillController,
    int offset,
    int length,
  ) {
    final docLen = quillController.document.length;
    if (docLen <= 0) return;
    final maxOffset = docLen - 1;
    final clampedBase = offset.clamp(0, maxOffset);
    final clampedExtent = (offset + length).clamp(0, maxOffset);
    quillController.updateSelection(
      TextSelection(baseOffset: clampedBase, extentOffset: clampedExtent),
      ChangeSource.local,
    );
  }

  /// Restores unchecked items into `quillController` and triggers `onSave`.
  static void restoreChecklistItemsToEditor({
    required QuillController quillController,
    required List<String> itemsToRestore,
    required ValueChanged<bool> setUpdatingProgrammatically,
    required Future<void> Function() onSave,
    required VoidCallback onComplete,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setUpdatingProgrammatically(true);
      try {
        for (final text in itemsToRestore) {
          QuillChecklistHelper.restoreUncheckedItem(quillController, text);
        }
        await onSave();
        onComplete();
      } finally {
        setUpdatingProgrammatically(false);
      }
    });
  }

  /// Dispatches top-bar menu selections.
  static Future<void> handleTopBarMenuSelection({
    required String value,
    required Future<void> Function() onPickReminder,
    required VoidCallback onClearReminder,
    required Future<void> Function() onPickFolder,
    required VoidCallback onShowDetails,
    required VoidCallback onShowShare,
    required Future<void> Function() onToggleLock,
    required Future<void> Function() onShowTableDialog,
    required Future<void> Function() onDeleteNote,
    required VoidCallback onStartSearch,
  }) async {
    switch (value) {
      case 'reminder':
        await onPickReminder();
        break;
      case 'clear_reminder':
        onClearReminder();
        break;
      case 'folder':
        await onPickFolder();
        break;
      case 'details':
        onShowDetails();
        break;
      case 'share':
        onShowShare();
        break;
      case 'lock':
        await onToggleLock();
        break;
      case 'table':
        await onShowTableDialog();
        break;
      case 'delete':
        await onDeleteNote();
        break;
      case 'search':
        onStartSearch();
        break;
    }
  }

  /// Resolves the dominant tag color for a note's current tags list.
  static int resolveColorFromTags(
    List<String> tags,
    Map<String, int> tagColors,
  ) {
    for (final tag in tags.reversed) {
      final c = tagColors[tag];
      if (c != null && c != 0) {
        return c;
      }
    }
    return 0;
  }

  /// Copies the AI summary to clipboard and displays a confirmation SnackBar.
  static Future<void> copyAiSummary(
    BuildContext context,
    String summary,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    AppHaptics.selectionClick();
    await Clipboard.setData(ClipboardData(text: summary));
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Summary copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Appends the AI summary to the end of `quillController`.
  static void appendAiSummary(
    QuillController quillController,
    String summary,
  ) {
    AppHaptics.mediumImpact();
    final currentLength = quillController.document.length;
    quillController.replaceText(
      currentLength - 1,
      0,
      '\n\n=== AI SUMMARY ===\n${summary.trim()}\n',
      null,
    );
  }
}
