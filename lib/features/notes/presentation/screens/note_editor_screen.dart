import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../../../screens/app_lock_screen.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'dart:math';
import 'dart:async';
import '../../data/note_repository.dart';
import '../../../../data/note_model.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../utils/rich_text_utils.dart';
import '../../../../utils/quill_checklist_helper.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../services/local_ai_service.dart';
import '../../../../services/notification_service.dart';
import 'package:note_taking_app/features/notes/providers/note_provider.dart';
import '../../../../utils/app_globals.dart';
import '../../../../utils/widget_helper.dart';
import 'package:flutter/services.dart';
import '../widgets/note_tag_picker_sheet.dart';
import '../widgets/note_slash_command_overlay.dart';
import '../widgets/note_ai_options_sheet.dart';
import '../../../../core/services/app_haptics.dart';

import '../../../../widgets/editor/editor_table_dialog.dart';
import '../../../../widgets/editor/editor_note_details_sheet.dart';
import '../widgets/story_card_creator_sheet.dart';
import '../../../story_cards/story_cards.dart';
import '../../../../core/ui/app_dialog.dart';
import '../widgets/note_locked_gate.dart';
import '../widgets/note_editor_top_bar.dart';
import '../widgets/note_completed_checklist_card.dart';
import '../widgets/note_share_export_sheet.dart';
import '../widgets/note_folder_dialog.dart';
import '../widgets/note_ai_summary_panel.dart';
import '../widgets/note_metadata_chips_bar.dart';
import '../widgets/note_editor_styles.dart';
import '../widgets/note_editor_bottom_bar.dart';
import '../../../../utils/quill_cursor_helper.dart';
import '../widgets/note_media_coordinator.dart';
import '../widgets/note_embed_builders.dart';


class NoteEditorScreen extends StatefulWidget {
  final Note? note;

  /// Text shared into the app (share sheet / text-selection menu) to prefill a new note.
  final String? initialSharedText;

  /// Image paths shared into the app to embed into a new note.
  final List<String>? initialSharedImagePaths;

  /// Starting title/content (Delta JSON) when creating from a template.
  final String? templateTitle;
  final String? templateContent;
  final String? initialFolder;
  final int? targetLineIndex;
  final String? targetChecklistText;

  const NoteEditorScreen({
    super.key,
    this.note,
    this.initialSharedText,
    this.initialSharedImagePaths,
    this.templateTitle,
    this.templateContent,
    this.initialFolder,
    this.targetLineIndex,
    this.targetChecklistText,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late QuillController _quillController;
  bool isPinned = false;
  bool isArchived = false;
  int color = 0; // 0 = System Default
  List<String> tags = [];
  List<String> _allTags = [];
  Timer? _debounce;
  late String _noteId;
  late DateTime _dateCreated;

  Map<String, int> _tagColors = {}; // Cache for tag colors

  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool isNoteSaved = false;
  bool _isImageSelected = false;
  List<String> _noteUrls = [];
  DateTime? _reminderAt;
  bool _isNoteLocked = false;
  bool _isNoteInTrash = false;
  bool _hasChanges = false;
  DateTime? _lastScheduledReminder;
  String _folder = 'All Notes';

  bool get _isCustomFolder =>
      _folder.isNotEmpty &&
      _folder != 'All Notes' &&
      _folder != 'Notes' &&
      _folder != 'notes';

  /// True once the user has authenticated to view a locked note this session.
  bool _lockAuthPassed = false;

  // AI summary and selection states
  String? _aiSummary;
  final Set<String> _dismissedUrls = {};
  bool _isUpdatingProgrammatically = false;
  StreamSubscription? _docSubscription;
  Timer? _scrollToCursorDebounce;

  // Search and formatting panel state
  bool _showFormattingBar = false;
  bool _isFormattingBarPinnedManually = false;
  bool _isSearching = false;
  bool _isCaseSensitive = false;
  List<int> _searchOffsets = [];
  int _currentSearchIndex = -1;
  bool _isEditingTableCell = false;
  bool _wasKeyboardOpen = false;

  // Slash commands & checklist collapse state
  bool _showSlashMenu = false;
  String _slashQuery = '';
  int _slashLineStart = 0;
  bool _isCompletedCollapsed = true;
  final List<String> _completedItems = [];

  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _noteId = widget.note?.id ?? const Uuid().v4();
    _dateCreated = widget.note?.dateCreated ?? DateTime.now();
    _titleController = TextEditingController(
        text: widget.note?.title ?? widget.templateTitle ?? '');

    // Convert Markdown to Delta for Quill
    final initialContent = widget.note?.content ?? '';
    var delta = RichTextUtils.contentToDelta(initialContent);
    if (widget.note == null) {
      delta = _buildSharedContentDelta() ??
          (widget.templateContent != null
              ? RichTextUtils.contentToDelta(widget.templateContent!)
              : delta);
    }

    // Sanitize delta: ensure inline attributes are safely separated from block newlines
    delta = RichTextUtils.sanitizeDelta(delta);

    _quillController = QuillController(
      document: Document.fromDelta(delta),
      selection: const TextSelection.collapsed(offset: 0),
    );

    isPinned = widget.note?.isPinned ?? false;
    isArchived = widget.note?.isArchived ?? false;
    color = widget.note?.color ?? 0;
    tags = List.from(widget.note?.tags ?? []);
    _reminderAt = widget.note?.reminderAt;
    _isNoteLocked = widget.note?.isLocked ?? false;
    _isNoteInTrash = widget.note?.deletedAt != null;
    if (_isNoteInTrash) {
      _quillController.readOnly = true;
    }
    _folder = widget.note?.category ?? widget.initialFolder ?? 'All Notes';
    _lastScheduledReminder = _reminderAt;
    _lockAuthPassed = !_isNoteLocked;
    if (!_lockAuthPassed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _authenticateForLockedNote();
      });
    } else if (widget.targetLineIndex != null || widget.targetChecklistText != null) {
      _jumpToTargetChecklist();
    } else if (widget.note == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    }
    _loadTags();

    _noteUrls = _extractUrls();

    // Initial checklist extraction (only if moveCompletedChecklistsToBottom is enabled)
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.moveCompletedChecklistsToBottom) {
      final initialCompleted = QuillChecklistHelper.extractAndRemoveCheckedLines(_quillController);
      if (initialCompleted.isNotEmpty) {
        _completedItems.addAll(initialCompleted);
      }
    }

    // Auto-save & change listeners
    _titleController.addListener(_onContentChanged);
    _quillController.addListener(_onSelectionChanged); // Add selection listener

    _docSubscription = _quillController.document.changes.listen((event) {
      if (event.source == ChangeSource.local) {
        _onContentChanged();
      }
      if (_isUpdatingProgrammatically) return;

      final hasListOrNewlineChange = event.change.operations.any((op) =>
          (op.attributes != null && op.attributes!.containsKey('list')) ||
          (op.data is String && (op.data as String).contains('\n')));

      if (hasListOrNewlineChange) {
        if (!mounted) return;
        final currentSettings = Provider.of<SettingsProvider>(context, listen: false);
        if (currentSettings.moveCompletedChecklistsToBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _isUpdatingProgrammatically) return;
            _isUpdatingProgrammatically = true;
            try {
              final newlyChecked = QuillChecklistHelper.extractAndRemoveCheckedLines(_quillController);
              if (newlyChecked.isNotEmpty) {
                _completedItems.addAll(newlyChecked);
                if (mounted) setState(() {});
              }
            } catch (e) {
              debugPrint('Error syncing checklists: $e');
            } finally {
              _isUpdatingProgrammatically = false;
            }
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _isUpdatingProgrammatically) return;
            _isUpdatingProgrammatically = true;
            try {
              final lines = QuillChecklistHelper.getDocumentLines(_quillController.document);
              for (final line in lines) {
                final listAttr = line.style.attributes['list']?.value;
                if (listAttr == 'checked' || listAttr == 'unchecked') {
                  final isChecked = listAttr == 'checked';
                  final hasStrike = line.children.any((node) =>
                      node is Leaf && (node.style.attributes['strike']?.value == true));
                  if (isChecked && !hasStrike) {
                    final textLen = (line.length - 1).clamp(0, double.infinity).toInt();
                    if (textLen > 0) {
                      _quillController.document.format(
                        line.documentOffset,
                        textLen,
                        Attribute.strikeThrough,
                      );
                    }
                  } else if (!isChecked && hasStrike) {
                    final textLen = (line.length - 1).clamp(0, double.infinity).toInt();
                    if (textLen > 0) {
                      _quillController.document.format(
                        line.documentOffset,
                        textLen,
                        Attribute.clone(Attribute.strikeThrough, null),
                      );
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('Error syncing checklist strikethrough formatting: $e');
            } finally {
              _isUpdatingProgrammatically = false;
            }
          });
        }
      }
      if (event.source == ChangeSource.local) {
        _checkCodeBlockAutoExit(event.change);
      }
    });
  }

  void _checkCodeBlockAutoExit(Delta change) {
    final hasNewlineInsert =
        change.operations.any((op) => op.isInsert && op.data == '\n');
    if (!hasNewlineInsert) return;

    final sel = _quillController.selection;
    if (!sel.isCollapsed) return;

    final style = _quillController.getSelectionStyle();
    if (!style.containsKey(Attribute.codeBlock.key)) return;

    final pos = sel.baseOffset;
    final text = _quillController.document.toPlainText();
    if (pos < 2 || pos > text.length) return;

    if (text[pos - 1] == '\n' && text[pos - 2] == '\n') {
      _quillController.formatSelection(
          Attribute.clone(Attribute.codeBlock, null));
      _quillController.replaceText(pos - 1, 1, '', null);
      _quillController.updateSelection(
        TextSelection.collapsed(offset: pos - 1),
        ChangeSource.local,
      );
    }
  }


  /// Builds the starting document for a note created from shared content
  /// (share sheet text/links/images or the text-selection context menu).
  /// Returns null when nothing was shared.
  Delta? _buildSharedContentDelta() {
    final sharedText = widget.initialSharedText?.trim();
    final imagePaths = widget.initialSharedImagePaths ?? const [];
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

  void _onSelectionChanged() {
    if (!mounted) return;

    final selection = _quillController.selection;
    final newIsImageSelected = _checkIfImageSelected();
    final newShowFormattingBar = !selection.isCollapsed || _isFormattingBarPinnedManually;

    // Only trigger setState if visual layout state actually changed
    if (newIsImageSelected != _isImageSelected || newShowFormattingBar != _showFormattingBar) {
      setState(() {
        _isImageSelected = newIsImageSelected;
        _showFormattingBar = newShowFormattingBar;
      });
    }

    _debounceScrollToCursor();
  }

  void _debounceScrollToCursor() {
    _scrollToCursorDebounce?.cancel();
    _scrollToCursorDebounce = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        _scrollToCursorIfNeeded();
      }
    });
  }

  void _scrollToCursorIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      QuillCursorHelper.scrollToCursorIfNeeded(
        focusNode: _focusNode,
        scrollController: _scrollController,
        quillController: _quillController,
      );
    });
  }

  bool _checkIfImageSelected() {
    final index = _quillController.selection.baseOffset;
    if (index < 0 || index >= _quillController.document.length) return false;

    final leaf = _quillController.document.querySegmentLeafNode(index).leaf;
    if (leaf != null && leaf.value is BlockEmbed) {
      return (leaf.value as BlockEmbed).type == 'image';
    }
    return false;
  }

  (int start, int length) _getNormalizedSelectionRange() {
    final selection = _quillController.selection;
    if (!selection.isValid) return (0, 0);
    final docLen = _quillController.document.length;
    final start = min(selection.baseOffset, selection.extentOffset).clamp(0, docLen > 0 ? docLen - 1 : 0);
    final end = max(selection.baseOffset, selection.extentOffset).clamp(0, docLen > 0 ? docLen - 1 : 0);
    return (start, end - start);
  }

  void _nudgeSelectionLeft({bool byWord = false}) =>
      QuillCursorHelper.nudgeLeft(
        controller: _quillController,
        focusNode: _focusNode,
        byWord: byWord,
        isEditingTableCell: _isEditingTableCell,
      );

  void _nudgeSelectionRight({bool byWord = false}) =>
      QuillCursorHelper.nudgeRight(
        controller: _quillController,
        focusNode: _focusNode,
        byWord: byWord,
        isEditingTableCell: _isEditingTableCell,
      );

  void _nudgeSelectionUp() =>
      QuillCursorHelper.nudgeUp(
        controller: _quillController,
        focusNode: _focusNode,
        isEditingTableCell: _isEditingTableCell,
      );

  void _nudgeSelectionDown() =>
      QuillCursorHelper.nudgeDown(
        controller: _quillController,
        focusNode: _focusNode,
        isEditingTableCell: _isEditingTableCell,
      );

  void _selectAllText() =>
      QuillCursorHelper.selectAll(_quillController);

  Future<void> _loadTags() async {
    final t = await NoteRepository.instance.getAllTags();
    final c = await NoteRepository.instance.getAllTagColors();
    if (mounted) {
      setState(() {
        _allTags = t;
        _tagColors = c;
      });
    }
  }

  /// Up to three distinct links in the note, for rich preview cards.
  List<String> _extractUrls() {
    final plainText = _quillController.document.toPlainText();
    final urlRegExp = RegExp(r'https?:\/\/[^\s]+');
    final urls = <String>[];
    for (final match in urlRegExp.allMatches(plainText)) {
      var url = match.group(0)!;
      if (RegExp(r'[.,;:)\]]+$').hasMatch(url)) {
        url = url.replaceAll(RegExp(r'[.,;:)\]]+$'), '');
      }
      if (url.isNotEmpty && !urls.contains(url) && !_dismissedUrls.contains(url)) {
        urls.add(url);
      }
      if (urls.length >= 3) break;
    }
    return urls;
  }

  void _onContentChanged() {
    if (_isNoteInTrash) return;
    _checkSlashCommands();

    if (_debounce?.isActive ?? false) _debounce?.cancel();

    _debounce = Timer(const Duration(seconds: 2), () {
      final urls = _extractUrls();
      if (!listEquals(urls, _noteUrls)) {
        if (mounted) setState(() => _noteUrls = urls);
      }
      saveNote();
    });
  }

  void _checkSlashCommands() {
    final selection = _quillController.selection;
    if (selection.isCollapsed && selection.baseOffset > 0) {
      final cursor = selection.baseOffset;
      if (cursor <= _quillController.document.length) {
        final nodeResult = _quillController.document.queryChild(cursor - 1);
        final line = nodeResult.node;
        if (line is Line) {
          final lineOffset = line.documentOffset;
          final lineText = line.toPlainText();
          final relativeCursor = (cursor - lineOffset).clamp(0, lineText.length);
          final linePrefix = lineText.substring(0, relativeCursor);
          if (linePrefix.startsWith('/')) {
            final query = linePrefix.substring(1).toLowerCase();
            if (!_showSlashMenu || _slashQuery != query) {
              setState(() {
                _showSlashMenu = true;
                _slashQuery = query;
                _slashLineStart = lineOffset;
              });
            }
            return;
          }
        }
      }
    }
    if (_showSlashMenu) {
      setState(() {
        _showSlashMenu = false;
      });
    }
  }

  void _executeSlashCommand(String command) {
    AppHaptics.lightImpact();
    final currentCursor = _quillController.selection.baseOffset;
    final deleteLength = currentCursor - _slashLineStart;
    if (deleteLength > 0 && deleteLength <= currentCursor) {
      _quillController.replaceText(
        _slashLineStart,
        deleteLength,
        '',
        TextSelection.collapsed(offset: _slashLineStart),
      );
    }
    setState(() => _showSlashMenu = false);

    switch (command) {
      case 'ai':
        _showAiOptionsSheet();
        break;
      case 'todo':
        _quillController.formatSelection(Attribute.unchecked);
        break;
      case 'table':
        _insertTableDirect();
        break;
      case 'code':
        _quillController.formatSelection(Attribute.codeBlock);
        break;
      case 'h1':
        _quillController.formatSelection(Attribute.h1);
        break;
      case 'h2':
        _quillController.formatSelection(Attribute.h2);
        break;
      case 'quote':
        _quillController.formatSelection(Attribute.blockQuote);
        break;
      case 'bullet':
        _quillController.formatSelection(Attribute.ul);
        break;
      case 'number':
        _quillController.formatSelection(Attribute.ol);
        break;
    }
  }

  void _insertTableDirect({int rows = 3, int cols = 3}) {
    final rowsList = List.generate(
      rows,
      (rIndex) => List.generate(
        cols,
        (cIndex) => rIndex == 0 ? 'Header ${cIndex + 1}' : 'Cell',
      ),
    );
    final jsonStr = jsonEncode(rowsList);

    final (index, length) = _getNormalizedSelectionRange();

    _quillController.replaceText(
      index,
      length,
      TableBlockEmbed(jsonStr),
      null,
    );

    _quillController.updateSelection(
      TextSelection.collapsed(offset: index + 1),
      ChangeSource.local,
    );
  }



  @override
  void dispose() {
    _titleController.removeListener(_onContentChanged);
    _quillController.removeListener(_onSelectionChanged);
    _docSubscription?.cancel();
    _debounce?.cancel();
    _scrollToCursorDebounce?.cancel();
    _titleController.dispose();
    _quillController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _updateColorFromTags() {
    int newColor = 0; // Default
    for (final tag in tags.reversed) {
      final c = _tagColors[tag];
      if (c != null && c != 0) {
        newColor = c;
        break;
      }
    }
    setState(() {
      color = newColor;
    });
  }

  void _showTagPicker() {
    NoteTagPickerSheet.show(
      context,
      currentTags: tags,
      allTags: _allTags,
      tagColors: _tagColors,
      onTagToggled: (t, isSelected) {
        setState(() {
          if (isSelected) {
            tags.add(t);
          } else {
            tags.remove(t);
          }
          _updateColorFromTags();
        });
      },
      onTagCreated: (newTag, colorVal) {
        setState(() {
          if (!tags.contains(newTag)) {
            tags.add(newTag);
            _updateColorFromTags();
          }
          if (!_allTags.contains(newTag)) {
            _allTags.add(newTag);
          }
          if (colorVal != 0) {
            _tagColors[newTag] = colorVal;
          }
        });
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final imagePath = await NoteMediaCoordinator.pickAndSaveImage(source);
    if (imagePath != null && mounted) {
      final (index, length) = _getNormalizedSelectionRange();
      _quillController.replaceText(
          index, length, BlockEmbed.image(imagePath), null);
      Navigator.pop(context);
    }
  }

  void _showImageOptions() =>
      NoteMediaCoordinator.showImageOptions(
        context: context,
        onPickImage: _pickImage,
      );

  Future saveNote() async {
    if (_isNoteInTrash) return;
    final title = _titleController.text.trim();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    var delta = _quillController.document.toDelta();
    if (settings.moveCompletedChecklistsToBottom && _completedItems.isNotEmpty) {
      if (delta.length == 1 &&
          delta.first.data == '\n' &&
          (delta.first.attributes == null || delta.first.attributes!.isEmpty)) {
        delta = Delta();
      }
      for (final text in _completedItems) {
        if (text.trim().isEmpty) continue;
        delta = delta.concat(Delta()
          ..insert(text, {'strike': true})
          ..insert('\n', {'list': 'checked'}));
      }
    }
    final content = RichTextUtils.deltaToJson(delta);
    final plainText = _quillController.document.toPlainText().trim();
    final isEmpty = title.isEmpty && plainText.isEmpty && _completedItems.isEmpty && tags.isEmpty;
    final exists = widget.note != null || isNoteSaved;

    if (isEmpty) {
      if (exists) {
        _hasChanges = true;
        await NoteRepository.instance.deleteNote(_noteId);
      }
      return;
    }

    final initialNote = widget.note;
    bool hasChanges = false;
    if (initialNote == null) {
      hasChanges = true;
    } else {
      final titleChanged = title != initialNote.title;
      final contentChanged = content != initialNote.content;
      final pinnedChanged = isPinned != initialNote.isPinned;
      final archivedChanged = isArchived != initialNote.isArchived;
      final colorChanged = color != initialNote.color;
      final tagsChanged = !listEquals(tags, initialNote.tags);
      final reminderChanged = _reminderAt != initialNote.reminderAt;
      final lockChanged = _isNoteLocked != initialNote.isLocked;
      final folderChanged = _folder != initialNote.category;
      hasChanges = titleChanged ||
          contentChanged ||
          pinnedChanged ||
          archivedChanged ||
          colorChanged ||
          tagsChanged ||
          reminderChanged ||
          lockChanged ||
          folderChanged;
    }

    if (!hasChanges) {
      return;
    }
    _hasChanges = true;

    final note = Note(
      id: _noteId,
      title: title,
      content: content,
      dateCreated: _dateCreated,
      dateModified: DateTime.now(),
      isPinned: isPinned,
      isArchived: isArchived,
      color: color,
      imagePath: widget.note?.imagePath,
      category: _folder,
      tags: tags,
      reminderAt: _reminderAt,
      isLocked: _isNoteLocked,
    );

    if (exists) {
      await NoteRepository.instance.updateNote(note);
    } else {
      await NoteRepository.instance.createNote(note);
      isNoteSaved = true;
    }
    unawaited(WidgetHelper.updateTodoWidgetData());

    // Keep the scheduled notification in sync (only when it actually changed
    // — this runs on every autosave debounce).
    if (_lastScheduledReminder != _reminderAt) {
      _lastScheduledReminder = _reminderAt;
      if (_reminderAt != null) {
        await NotificationService.scheduleNoteReminder(
          noteId: _noteId,
          noteTitle: title,
          when: _reminderAt!,
        );
      } else {
        await NotificationService.cancelNoteReminder(_noteId);
      }
    }
  }

  void _jumpToTargetChecklist() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final plainText = _quillController.document.toPlainText();
        final lines = plainText.split('\n');
        int? targetIndex = widget.targetLineIndex;

        // If targetChecklistText is provided, verify or find matching line
        if (widget.targetChecklistText != null &&
            widget.targetChecklistText!.trim().isNotEmpty) {
          final query = widget.targetChecklistText!.trim();
          bool matched = false;
          if (targetIndex != null && targetIndex >= 0 && targetIndex < lines.length) {
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

        if (targetIndex != null && targetIndex >= 0 && targetIndex < lines.length) {
          int charOffset = 0;
          for (int i = 0; i < targetIndex; i++) {
            charOffset += lines[i].length + 1;
          }
          final clampedOffset = charOffset.clamp(0, _quillController.document.length - 1);
          _quillController.updateSelection(
            TextSelection.collapsed(offset: clampedOffset),
            ChangeSource.local,
          );
          _focusNode.requestFocus();
          _debounceScrollToCursor();
        }
      } catch (e) {
        debugPrint('Error jumping to target checklist item: $e');
      }
    });
  }

  /// Authenticates before revealing a locked note's content.
  Future<void> _authenticateForLockedNote() async {
    try {
      AppLockScreen.ignoreNextResumeLock();
      final didAuthenticate = await LocalAuthentication().authenticate(
        localizedReason: 'This note is locked',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (!mounted) return;
      if (didAuthenticate) {
        setState(() => _lockAuthPassed = true);
        if (widget.targetLineIndex != null || widget.targetChecklistText != null) {
          _jumpToTargetChecklist();
        }
      }
    } catch (e) {
      debugPrint('Locked-note auth error: $e');
    }
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final initial = _reminderAt ?? now.add(const Duration(hours: 1));

    if (!mounted) return;
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? initial : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
      helpText: 'Remind me about this note',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!picked.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder time must be in the future')),
      );
      return;
    }

    setState(() => _reminderAt = picked);
    _onContentChanged(); // persist through the normal autosave path
  }

  void _clearReminder() {
    AppHaptics.selectionClick();
    setState(() => _reminderAt = null);
    _onContentChanged();
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchOffsets = [];
        _currentSearchIndex = -1;
      });
      return;
    }

    final text = _quillController.document.toPlainText();
    final escapedQuery = RegExp.escape(query);
    final matches = RegExp(escapedQuery, caseSensitive: _isCaseSensitive).allMatches(text);
    
    final offsets = matches.map((m) => m.start).toList();
    
    setState(() {
      _searchOffsets = offsets;
      if (offsets.isNotEmpty) {
        _currentSearchIndex = 0;
        _jumpToMatch(offsets[0], query.length);
      } else {
        _currentSearchIndex = -1;
      }
    });
  }

  void _toggleCaseSensitive() {
    AppHaptics.selectionClick();
    setState(() {
      _isCaseSensitive = !_isCaseSensitive;
    });
    _performSearch(_searchController.text);
  }

  void _jumpToMatch(int offset, int length) {
    final docLen = _quillController.document.length;
    if (docLen <= 0) return;
    final maxOffset = docLen - 1;
    final clampedBase = offset.clamp(0, maxOffset);
    final clampedExtent = (offset + length).clamp(0, maxOffset);
    _quillController.updateSelection(
      TextSelection(baseOffset: clampedBase, extentOffset: clampedExtent),
      ChangeSource.local,
    );
  }

  void _nextSearchMatch() {
    if (_searchOffsets.isEmpty) return;
    AppHaptics.selectionClick();
    setState(() {
      _currentSearchIndex = (_currentSearchIndex + 1) % _searchOffsets.length;
      _jumpToMatch(_searchOffsets[_currentSearchIndex], _searchController.text.length);
    });
  }

  void _previousSearchMatch() {
    if (_searchOffsets.isEmpty) return;
    AppHaptics.selectionClick();
    setState(() {
      _currentSearchIndex = (_currentSearchIndex - 1 + _searchOffsets.length) % _searchOffsets.length;
      _jumpToMatch(_searchOffsets[_currentSearchIndex], _searchController.text.length);
    });
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchOffsets = [];
      _currentSearchIndex = -1;
    });
    final sel = _quillController.selection;
    if (sel.isValid) {
      _quillController.updateSelection(
        TextSelection.collapsed(offset: sel.extentOffset),
        ChangeSource.local,
      );
    }
  }

  Future<void> _showTableInsertionDialog() async {
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

      final index = _quillController.selection.baseOffset;
      final length = _quillController.selection.extentOffset - index;
      
      _quillController.replaceText(
        index,
        length,
        TableBlockEmbed(jsonStr),
        null,
      );
      
      _quillController.updateSelection(
        TextSelection.collapsed(offset: index + 1),
        ChangeSource.local,
      );
    }
  }





  /// Jump-to-heading navigation for long notes.
  /// Displays word count, character count, reading time, and note timestamps.
  void _showNoteDetailsSheet() {
    final plainText = _quillController.document.toPlainText();
    EditorNoteDetailsSheet.show(
      context,
      plainText: plainText,
      folder: _folder,
      createdAt: widget.note?.dateCreated,
      updatedAt: widget.note?.dateModified,
    );
  }

  /// Displays sharing options for exporting plain text, markdown, or copying to clipboard.
  void _showShareExportSheet() {
    final title = _titleController.text.trim();
    final delta = _quillController.document.toDelta();
    final plainText = _quillController.document.toPlainText().trim();

    NoteShareExportSheet.show(
      context: context,
      title: title,
      delta: delta,
      plainText: plainText,
      onOpenStoryCard: () => _openStoryCardStudio(selectedOnly: false),
    );
  }

  void _openStoryCardStudio({bool selectedOnly = false}) {
    final title = _titleController.text.trim();
    String textToExport = '';

    if (selectedOnly && !_quillController.selection.isCollapsed) {
      final sel = _quillController.selection;
      final start = sel.start;
      final len = sel.end - sel.start;
      textToExport = _quillController.document.getPlainText(start, len).trim();
    }

    if (textToExport.isEmpty) {
      if (!_quillController.selection.isCollapsed) {
        final sel = _quillController.selection;
        final start = sel.start;
        final len = sel.end - sel.start;
        textToExport = _quillController.document.getPlainText(start, len).trim();
      }
      if (textToExport.isEmpty) {
        textToExport = _quillController.document.toPlainText().trim();
      }
    }

    final category = _isCustomFolder
        ? _folder
        : (widget.note?.tags.isNotEmpty == true ? widget.note!.tags.first : 'Note');

    StoryCardStudioSheet.show(
      context: context,
      initialText: textToExport,
      noteTitle: title,
      category: category,
      noteColorValue: color,
      noteDate: _dateCreated,
    );
  }

  /// Lets the user file the note into a folder (or create a new one).
  Future<void> _pickFolder() async {
    final folders = await NoteRepository.instance.getAllFolders();
    if (!mounted) return;

    final chosen = await NoteFolderDialog.show(
      context: context,
      currentFolder: _folder,
      folders: folders,
    );

    if (chosen == null || chosen == _folder || !mounted) return;
    setState(() => _folder = chosen);
    _onContentChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(chosen == 'All Notes'
            ? 'Removed from folder'
            : 'Moved to "$chosen"'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Toggles the per-note biometric lock; toggling in either direction
  /// requires device authentication so a bystander can't unlock a note.
  Future<void> _toggleNoteLock() async {
    AppHaptics.selectionClick();
    try {
      AppLockScreen.ignoreNextResumeLock();
      final didAuthenticate = await LocalAuthentication().authenticate(
        localizedReason: _isNoteLocked ? 'Unlock this note' : 'Lock this note',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (!didAuthenticate || !mounted) return;
      setState(() => _isNoteLocked = !_isNoteLocked);
      _onContentChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isNoteLocked
              ? 'Note locked — it will require authentication to open'
              : 'Note unlocked'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Set up a device screen lock or biometrics to lock notes'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _restoreNoteFromTrash() async {
    await NoteRepository.instance.restoreNote(_noteId);
    if (!mounted) return;
    setState(() {
      _isNoteInTrash = false;
      _quillController.readOnly = false;
    });
    _hasChanges = true;
    await context.read<NoteProvider>().refreshNotes();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note restored from Trash'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: _isNoteInTrash ? 'Delete Permanently?' : 'Move to Trash?',
        content: Text(_isNoteInTrash
            ? 'This note will be permanently deleted. This action cannot be undone.'
            : 'This note will be moved to Trash.'),
        cancelLabel: 'Cancel',
        confirmLabel: _isNoteInTrash ? 'Delete Forever' : 'Move to Trash',
        isDestructive: true,
        onCancel: () => Navigator.pop(context, false),
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (confirmed == true) {
      if (_isNoteInTrash) {
        await NoteRepository.instance.deleteNote(_noteId);
        if (mounted) Navigator.pop(context, true);
        appScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Note permanently deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        await NoteRepository.instance.softDeleteNote(_noteId);
        if (mounted) Navigator.pop(context, true);

        // The editor is gone after the pop, so surface the undo on the
        // app-level messenger.
        final noteId = _noteId;
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

  void _showAiOptionsSheet() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.isAiActive) return;
    final aiService = Provider.of<LocalAiService>(context, listen: false);

    NoteAiOptionsSheet.showOptions(
      context: context,
      quillController: _quillController,
      aiService: aiService,
      settings: settings,
      onTitleSuggested: (newTitle) {
        if (mounted) {
          setState(() {
            _titleController.text = newTitle;
          });
          _onContentChanged();
          saveNote();
        }
      },
      onTagsSuggested: (newTags) {
        if (mounted) {
          setState(() {
            for (final tag in newTags) {
              if (!tags.contains(tag)) {
                tags.add(tag);
              }
            }
            _updateColorFromTags();
          });
          _onContentChanged();
          saveNote();
        }
      },
      onSummaryGenerated: (summary) {
        if (mounted) {
          setState(() {
            _aiSummary = summary;
          });
          _onContentChanged();
          saveNote();
        }
      },
      onContentModified: () {
        if (mounted) {
          _onContentChanged();
          saveNote();
        }
      },
    );
  }

  Widget _buildSlashMenuOverlay(ThemeData theme, ColorScheme colorScheme) {
    final isAiActive = Provider.of<SettingsProvider>(context, listen: false).isAiActive;
    return NoteSlashCommandOverlay(
      query: _slashQuery,
      isAiActive: isAiActive,
      onCommandSelected: _executeSlashCommand,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_lockAuthPassed) {
      return NoteLockedGate(
        onUnlockPressed: _authenticateForLockedNote,
        onBackPressed: () => Navigator.maybePop(context),
      );
    }

    return Consumer<SettingsProvider>(builder: (context, settings, child) {
      final theme = Theme.of(context);
      final isSystemDefault = color == 0;

      Color backgroundColor;
      Color onBackground;

      ColorScheme noteScheme;

      if (isSystemDefault) {
        noteScheme = theme.colorScheme;
        backgroundColor = theme.colorScheme.surface;
        onBackground = theme.colorScheme.onSurface;
      } else {
        noteScheme = ColorScheme.fromSeed(
          seedColor: Color(color),
          brightness: theme.brightness,
        );
        backgroundColor = noteScheme.surfaceContainerHigh;
        onBackground = noteScheme.onSurface;
      }

      final textColor = onBackground;
      final hintColor = onBackground.withValues(alpha: 0.6);
      final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 100;
      if (isKeyboardOpen && !_wasKeyboardOpen) {
        _wasKeyboardOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToCursorIfNeeded();
        });
      } else if (!isKeyboardOpen && _wasKeyboardOpen) {
        _wasKeyboardOpen = false;
      }

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          try {
            _debounce?.cancel();
            if (!_isNoteInTrash) {
              await saveNote();
            }
            if (context.mounted) {
              await context.read<NoteProvider>().refreshNotes();
            }
          } catch (e) {
            debugPrint('Error saving note on pop: $e');
          } finally {
            unawaited(WidgetHelper.updateTodoWidgetData());
            if (context.mounted) Navigator.pop(context, _hasChanges);
          }
        },
        child: Scaffold(
          // The AnimatedContainer below owns the color so switching note
          // colors eases instead of snapping.
          backgroundColor: Colors.transparent,
          body: AnimatedContainer(
            duration: AppLayout.animLong,
            curve: Curves.easeOutCubic,
            color: backgroundColor,
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Top Bar
                      NoteEditorTopBar(
                        isSearching: _isSearching,
                        searchController: _searchController,
                        searchFocusNode: _searchFocusNode,
                        isCaseSensitive: _isCaseSensitive,
                        searchOffsets: _searchOffsets,
                        currentSearchIndex: _currentSearchIndex,
                        onCloseSearch: _closeSearch,
                        onSearchChanged: _performSearch,
                        onSearchSubmitted: (_) => _nextSearchMatch(),
                        onToggleCaseSensitive: _toggleCaseSensitive,
                        onPreviousSearchMatch: _previousSearchMatch,
                        onNextSearchMatch: _nextSearchMatch,
                        onBackPressed: () => Navigator.maybePop(context),
                        textColor: textColor,
                        quillController: _quillController,
                        onTagPicker: _showTagPicker,
                        reminderAt: _reminderAt,
                        isNoteLocked: _isNoteLocked,
                        isNoteInTrash: _isNoteInTrash,
                        minimalEditorMode: settings.minimalEditorMode,
                        onMenuSelected: (value) async {
                          switch (value) {
                            case 'reminder':
                              await _pickReminder();
                              break;
                            case 'clear_reminder':
                              _clearReminder();
                              break;
                            case 'folder':
                              await _pickFolder();
                              break;
                            case 'details':
                              _showNoteDetailsSheet();
                              break;
                            case 'share':
                              _showShareExportSheet();
                              break;
                            case 'lock':
                              await _toggleNoteLock();
                              break;
                            case 'table':
                              await _showTableInsertionDialog();
                              break;
                            case 'delete':
                              await _deleteNote();
                              break;
                            case 'search':
                              setState(() {
                                _isSearching = true;
                              });
                              _searchFocusNode.requestFocus();
                              break;
                          }
                        },
                      ),
                      // Trash Warning Banner
                      if (_isNoteInTrash)
                        Container(
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
                              Icon(Icons.delete_outline_rounded, size: 20, color: theme.colorScheme.onErrorContainer),
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
                                onPressed: _restoreNoteFromTrash,
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
                        ),
                      // Editor Area
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () {
                                if (!_focusNode.hasFocus) {
                                  _focusNode.requestFocus();
                                }
                                final docLen = _quillController.document.length;
                                final endOffset = (docLen - 1).clamp(0, docLen);
                                _quillController.updateSelection(
                                  TextSelection.collapsed(offset: endOffset),
                                  ChangeSource.local,
                                );
                                final style = _quillController.getSelectionStyle();
                                if (style.containsKey(Attribute.codeBlock.key)) {
                                  _quillController.replaceText(endOffset, 0, '\n', null);
                                  _quillController.updateSelection(
                                    TextSelection.collapsed(offset: endOffset + 1),
                                    ChangeSource.local,
                                  );
                                  _quillController.formatSelection(
                                      Attribute.clone(Attribute.codeBlock, null));
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: _titleController,
                                      readOnly: _isNoteInTrash,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            color: textColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                      decoration: InputDecoration(
                                        hintText: 'Title',
                                        filled: false,
                                        fillColor: Colors.transparent,
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                        hintStyle: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
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
                                      reminderAt: _reminderAt,
                                      isNoteLocked: _isNoteLocked,
                                      isCustomFolder: _isCustomFolder,
                                      folder: _folder,
                                      tags: tags,
                                      tagColors: _tagColors,
                                      textColor: textColor,
                                      onPickReminder: _pickReminder,
                                      onClearReminder: _clearReminder,
                                      onPickFolder: _pickFolder,
                                      onDeleteTag: (tag) {
                                        setState(() {
                                          tags.remove(tag);
                                          _updateColorFromTags();
                                        });
                                        saveNote();
                                      },
                                    ),
                                    NoteCompletedChecklistCard(
                                      completedItems: _completedItems,
                                      isCollapsed: _isCompletedCollapsed,
                                      onToggleCollapse: () {
                                        setState(() {
                                          _isCompletedCollapsed = !_isCompletedCollapsed;
                                        });
                                      },
                                      onUncheckAll: () async {
                                        if (!context.mounted) return;
                                        final itemsToRestore = List<String>.from(_completedItems);
                                        setState(() {
                                          _completedItems.clear();
                                        });
                                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                                          if (!mounted) return;
                                          _isUpdatingProgrammatically = true;
                                          try {
                                            for (final text in itemsToRestore) {
                                              QuillChecklistHelper.restoreUncheckedItem(_quillController, text);
                                            }
                                            await saveNote();
                                            if (mounted) setState(() {});
                                          } finally {
                                            _isUpdatingProgrammatically = false;
                                          }
                                        });
                                      },
                                      onDeleteAll: () async {
                                        if (!context.mounted) return;
                                        final confirm = await AppDialog.showConfirm(
                                          context: context,
                                          title: 'Delete Completed Items?',
                                          message:
                                              'This will permanently remove ${_completedItems.length} finished items from this note.',
                                          confirmLabel: 'Delete',
                                          isDestructive: true,
                                        );
                                        if (confirm == true) {
                                          _completedItems.clear();
                                          await saveNote();
                                          if (context.mounted) setState(() {});
                                        }
                                      },
                                      onRestoreItem: (item) async {
                                        final itemToRestore = item;
                                        setState(() {
                                          _completedItems.remove(itemToRestore);
                                        });
                                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                                          if (!mounted) return;
                                          _isUpdatingProgrammatically = true;
                                          try {
                                            QuillChecklistHelper.restoreUncheckedItem(
                                                _quillController, itemToRestore);
                                            await saveNote();
                                            if (mounted) setState(() {});
                                          } finally {
                                            _isUpdatingProgrammatically = false;
                                          }
                                        });
                                      },
                                      onDeleteItem: (item) async {
                                        _completedItems.remove(item);
                                        await saveNote();
                                        if (context.mounted) setState(() {});
                                      },
                                      noteScheme: noteScheme,
                                      textColor: textColor,
                                    ),
                                    NotificationListener<TableCellFocusNotification>(
                                      onNotification: (notification) {
                                        setState(() {
                                          _isEditingTableCell = notification.isFocused;
                                        });
                                        return true;
                                      },
                                      child: CallbackShortcuts(
                                        bindings: {
                                          const SingleActivator(LogicalKeyboardKey.keyA, control: true): () => _selectAllText(),
                                          const SingleActivator(LogicalKeyboardKey.keyA, meta: true): () => _selectAllText(),
                                        },
                                        child: QuillEditor.basic(
                                          controller: _quillController,
                                          focusNode: _focusNode,
                                          config: QuillEditorConfig(
                                            padding: const EdgeInsets.only(bottom: 16),
                                            autoFocus: false,
                                            showCursor: !_isEditingTableCell,
                                            enableInteractiveSelection: true,
                                            enableSelectionToolbar: true,
                                            contextMenuBuilder: (context, rawEditorState) {
                                              final buttonItems = rawEditorState.contextMenuButtonItems;
                                              return AdaptiveTextSelectionToolbar.buttonItems(
                                                anchors: rawEditorState.contextMenuAnchors,
                                                buttonItems: [
                                                  ...buttonItems,
                                                  ContextMenuButtonItem(
                                                    onPressed: () {
                                                      rawEditorState.hideToolbar();
                                                      _openStoryCardStudio(selectedOnly: true);
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
                                                      controller.selection.baseOffset - 2, 2, '\n', null);
                                                  final base = controller.selection.baseOffset - 2;
                                                  controller.updateSelection(
                                                    controller.selection.copyWith(baseOffset: base, extentOffset: base),
                                                    ChangeSource.local,
                                                  );
                                                  controller
                                                    ..formatSelection(Attribute.unchecked)
                                                    ..replaceText(controller.selection.baseOffset + 1, 1, '', null);
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
                                    ..._noteUrls.map(
                                      (url) => Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Stack(
                                          children: [
                                            AnyLinkPreview(
                                              link: url,
                                              displayDirection:
                                                  UIDirection.uiDirectionHorizontal,
                                              cache: const Duration(hours: 1),
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainer,
                                              errorWidget: const SizedBox.shrink(),
                                              errorImage:
                                                  "https://via.placeholder.com/150",
                                              removeElevation: true,
                                              borderRadius: 12,
                                            ),
                                            Positioned(
                                              top: 6,
                                              right: 6,
                                              child: Tooltip(
                                                message: 'Remove Link Preview',
                                                child: Material(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest
                                                      .withValues(alpha: 0.9),
                                                  shape: const CircleBorder(),
                                                  elevation: 2,
                                                  child: InkWell(
                                                    customBorder:
                                                        const CircleBorder(),
                                                    onTap: () {
                                                      AppHaptics.selectionClick();
                                                      setState(() {
                                                        _dismissedUrls.add(url);
                                                        _noteUrls.remove(url);
                                                      });
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
                          ),
                        ),
                      // Slash Commands Overlay Card
                      if (_showSlashMenu && !_isImageSelected && !_isNoteInTrash)
                        _buildSlashMenuOverlay(theme, noteScheme),

                      // Note Editor Bottom Bar (Formatting sub-tier + Main Pill Toolbar)
                      if (!_isNoteInTrash)
                        NoteEditorBottomBar(
                        quillController: _quillController,
                        showFormattingBar: _showFormattingBar,
                        isImageSelected: _isImageSelected,
                        isSystemDefault: isSystemDefault,
                        color: color,
                        textColor: textColor,
                        noteScheme: noteScheme,
                        isKeyboardOpen: isKeyboardOpen,
                        isAiActive: settings.isAiActive,
                        minimalEditorMode: settings.minimalEditorMode,
                        onToggleFormattingBar: () {
                          setState(() {
                            _isFormattingBarPinnedManually = !_isFormattingBarPinnedManually;
                            _showFormattingBar = _isFormattingBarPinnedManually;
                          });
                        },
                        onNudgeLeft: _nudgeSelectionLeft,
                        onNudgeRight: _nudgeSelectionRight,
                        onNudgeUp: _nudgeSelectionUp,
                        onNudgeDown: _nudgeSelectionDown,
                        onShowAiOptions: _showAiOptionsSheet,
                        onInsertTable: _showTableInsertionDialog,
                        onShowImageOptions: _showImageOptions,
                        onHideKeyboard: () {
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    ],
                  ),
                  // AI Summary Panel Overlay
                  if (_aiSummary != null)
                    NoteAiSummaryPanel(
                      summary: _aiSummary!,
                      noteScheme: noteScheme,
                      onClose: () => setState(() => _aiSummary = null),
                      onCopy: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        AppHaptics.selectionClick();
                        await Clipboard.setData(ClipboardData(text: _aiSummary!));
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Summary copied to clipboard'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      onAppend: () async {
                        AppHaptics.mediumImpact();
                        final currentLength = _quillController.document.length;
                        _quillController.replaceText(
                          currentLength - 1,
                          0,
                          '\n\n=== AI SUMMARY ===\n${_aiSummary!.trim()}\n',
                          null,
                        );
                        _onContentChanged();
                        setState(() => _aiSummary = null);
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

