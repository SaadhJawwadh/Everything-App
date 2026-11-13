import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../screens/app_lock_screen.dart';
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
import 'package:local_auth/local_auth.dart';
import '../../../../services/local_ai_service.dart';
import 'package:note_taking_app/features/notes/providers/note_provider.dart';
import '../../../../utils/widget_helper.dart';
import '../widgets/note_tag_picker_sheet.dart';
import '../widgets/note_slash_command_overlay.dart';
import '../widgets/note_ai_options_sheet.dart';
import '../../../../core/services/app_haptics.dart';

import '../widgets/note_locked_gate.dart';
import '../widgets/note_editor_top_bar.dart';
import '../widgets/note_ai_summary_panel.dart';
import '../widgets/note_editor_bottom_bar.dart';
import '../widgets/note_editor_canvas.dart';
import '../widgets/note_editor_actions.dart';
import '../../../../utils/quill_cursor_helper.dart';
import '../widgets/note_media_coordinator.dart';


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
      delta = NoteEditorCanvas.buildSharedContentDelta(
            initialSharedText: widget.initialSharedText,
            initialSharedImagePaths: widget.initialSharedImagePaths,
          ) ??
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _isUpdatingProgrammatically) return;
          _isUpdatingProgrammatically = true;
          try {
            NoteEditorCanvas.syncChecklistOnDocumentChange(
              quillController: _quillController,
              moveCompletedChecklistsToBottom:
                  currentSettings.moveCompletedChecklistsToBottom,
              completedItems: _completedItems,
              onStateChanged: () {
                if (mounted) setState(() {});
              },
            );
          } catch (e) {
            debugPrint('Error syncing checklists: $e');
          } finally {
            _isUpdatingProgrammatically = false;
          }
        });
      }
      if (event.source == ChangeSource.local) {
        NoteEditorCanvas.checkCodeBlockAutoExit(_quillController, event.change);
      }
    });
  }

  void _onSelectionChanged() {
    if (!mounted) return;

    final selection = _quillController.selection;
    final newIsImageSelected =
        NoteEditorCanvas.isImageSelected(_quillController);
    final newShowFormattingBar =
        !selection.isCollapsed || _isFormattingBarPinnedManually;

    if (newIsImageSelected != _isImageSelected ||
        newShowFormattingBar != _showFormattingBar) {
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
      if (mounted) _scrollToCursorIfNeeded();
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
  List<String> _extractUrls() => NoteEditorActions.extractUrls(
        _quillController.document.toPlainText(),
        _dismissedUrls,
      );

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
    final (show, query, lineStart) =
        NoteEditorActions.evaluateSlashCommand(_quillController);
    if (show) {
      if (!_showSlashMenu || _slashQuery != query) {
        setState(() {
          _showSlashMenu = true;
          _slashQuery = query;
          _slashLineStart = lineStart;
        });
      }
    } else if (_showSlashMenu) {
      setState(() => _showSlashMenu = false);
    }
  }

  void _executeSlashCommand(String command) {
    setState(() => _showSlashMenu = false);
    NoteEditorActions.executeSlashCommand(
      command: command,
      quillController: _quillController,
      slashLineStart: _slashLineStart,
      selectionRange: _getNormalizedSelectionRange(),
      onShowAiOptions: _showAiOptionsSheet,
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
    setState(() {
      color = NoteEditorActions.resolveColorFromTags(tags, _tagColors);
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
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final (nextHasChanges, nextIsSaved, nextReminder) =
        await NoteEditorActions.persistNote(
      noteId: _noteId,
      initialNote: widget.note,
      isNoteSaved: isNoteSaved,
      currentHasChanges: _hasChanges,
      dateCreated: _dateCreated,
      title: _titleController.text.trim(),
      quillController: _quillController,
      moveCompletedChecklistsToBottom:
          settings.moveCompletedChecklistsToBottom,
      completedItems: _completedItems,
      isPinned: isPinned,
      isArchived: isArchived,
      color: color,
      folder: _folder,
      tags: tags,
      reminderAt: _reminderAt,
      lastScheduledReminder: _lastScheduledReminder,
      isNoteLocked: _isNoteLocked,
    );
    _hasChanges = nextHasChanges;
    isNoteSaved = nextIsSaved;
    _lastScheduledReminder = nextReminder;
  }

  void _jumpToTargetChecklist() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      NoteEditorActions.jumpToTargetChecklist(
        quillController: _quillController,
        focusNode: _focusNode,
        targetLineIndex: widget.targetLineIndex,
        targetChecklistText: widget.targetChecklistText,
        onScrollToCursor: _debounceScrollToCursor,
      );
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
    final picked = await NoteEditorActions.pickReminder(context, _reminderAt);
    if (picked == null || !mounted) return;
    setState(() => _reminderAt = picked);
    _onContentChanged();
  }

  void _clearReminder() {
    AppHaptics.selectionClick();
    setState(() => _reminderAt = null);
    _onContentChanged();
  }

  void _performSearch(String query) {
    final offsets = NoteEditorActions.findSearchOffsets(
      quillController: _quillController,
      query: query,
      isCaseSensitive: _isCaseSensitive,
    );
    setState(() {
      _searchOffsets = offsets;
      _currentSearchIndex = offsets.isNotEmpty ? 0 : -1;
    });
  }

  void _toggleCaseSensitive() {
    AppHaptics.selectionClick();
    setState(() => _isCaseSensitive = !_isCaseSensitive);
    _performSearch(_searchController.text);
  }

  void _nextSearchMatch() {
    if (_searchOffsets.isEmpty) return;
    AppHaptics.selectionClick();
    setState(() {
      _currentSearchIndex = (_currentSearchIndex + 1) % _searchOffsets.length;
      NoteEditorActions.jumpToMatch(
        _quillController,
        _searchOffsets[_currentSearchIndex],
        _searchController.text.length,
      );
    });
  }

  void _previousSearchMatch() {
    if (_searchOffsets.isEmpty) return;
    AppHaptics.selectionClick();
    setState(() {
      _currentSearchIndex =
          (_currentSearchIndex - 1 + _searchOffsets.length) %
              _searchOffsets.length;
      NoteEditorActions.jumpToMatch(
        _quillController,
        _searchOffsets[_currentSearchIndex],
        _searchController.text.length,
      );
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

  Future<void> _showTableInsertionDialog() =>
      NoteEditorActions.showTableInsertionDialog(context, _quillController);

  void _showNoteDetailsSheet() => NoteEditorActions.showNoteDetailsSheet(
        context: context,
        quillController: _quillController,
        folder: _folder,
        createdAt: widget.note?.dateCreated,
        updatedAt: widget.note?.dateModified,
      );

  void _showShareExportSheet() => NoteEditorActions.showShareExportSheet(
        context: context,
        title: _titleController.text.trim(),
        quillController: _quillController,
        onOpenStoryCard: () => _openStoryCardStudio(selectedOnly: false),
      );

  void _openStoryCardStudio({bool selectedOnly = false}) =>
      NoteEditorActions.openStoryCardStudio(
        context: context,
        title: _titleController.text.trim(),
        quillController: _quillController,
        isCustomFolder: _isCustomFolder,
        folder: _folder,
        noteTags: widget.note?.tags ?? const [],
        colorValue: color,
        noteDate: _dateCreated,
        selectedOnly: selectedOnly,
      );

  Future<void> _pickFolder() async {
    final chosen = await NoteEditorActions.pickFolder(context, _folder);
    if (chosen == null || !mounted) return;
    setState(() => _folder = chosen);
    _onContentChanged();
  }

  Future<void> _toggleNoteLock() async {
    final nextLocked =
        await NoteEditorActions.toggleNoteLock(context, _isNoteLocked);
    if (nextLocked == null || !mounted) return;
    setState(() => _isNoteLocked = nextLocked);
    _onContentChanged();
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

  Future<void> _deleteNote() => NoteEditorActions.confirmAndDeleteNote(
        context: context,
        noteId: _noteId,
        isNoteInTrash: _isNoteInTrash,
      );

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
      final (noteScheme, backgroundColor, onBackground) =
          NoteEditorCanvas.resolveNoteTheme(theme, color);

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
                        onMenuSelected: (value) =>
                            NoteEditorActions.handleTopBarMenuSelection(
                          value: value,
                          onPickReminder: _pickReminder,
                          onClearReminder: _clearReminder,
                          onPickFolder: _pickFolder,
                          onShowDetails: _showNoteDetailsSheet,
                          onShowShare: _showShareExportSheet,
                          onToggleLock: _toggleNoteLock,
                          onShowTableDialog: _showTableInsertionDialog,
                          onDeleteNote: _deleteNote,
                          onStartSearch: () {
                            setState(() => _isSearching = true);
                            _searchFocusNode.requestFocus();
                          },
                        ),
                      ),
                      // Trash Warning Banner
                      if (_isNoteInTrash)
                        NoteEditorActions.buildTrashWarningBanner(
                          context: context,
                          onRestore: _restoreNoteFromTrash,
                        ),
                      // Editor Area
                      Expanded(
                        child: NoteEditorCanvas(
                          scrollController: _scrollController,
                          focusNode: _focusNode,
                          quillController: _quillController,
                          titleController: _titleController,
                          isNoteInTrash: _isNoteInTrash,
                          textColor: textColor,
                          hintColor: hintColor,
                          noteScheme: noteScheme,
                          reminderAt: _reminderAt,
                          isNoteLocked: _isNoteLocked,
                          isCustomFolder: _isCustomFolder,
                          folder: _folder,
                          tags: tags,
                          tagColors: _tagColors,
                          completedItems: _completedItems,
                          isCompletedCollapsed: _isCompletedCollapsed,
                          isEditingTableCell: _isEditingTableCell,
                          noteUrls: _noteUrls,
                          isKeyboardOpen: isKeyboardOpen,
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
                          onToggleCompletedCollapse: () {
                            setState(() {
                              _isCompletedCollapsed = !_isCompletedCollapsed;
                            });
                          },
                          onUncheckAllCompleted: () {
                            if (!context.mounted) return;
                            final itemsToRestore =
                                List<String>.from(_completedItems);
                            setState(() => _completedItems.clear());
                            NoteEditorActions.restoreChecklistItemsToEditor(
                              quillController: _quillController,
                              itemsToRestore: itemsToRestore,
                              setUpdatingProgrammatically: (v) =>
                                  _isUpdatingProgrammatically = v,
                              onSave: saveNote,
                              onComplete: () {
                                if (mounted) setState(() {});
                              },
                            );
                          },
                          onDeleteAllCompleted: () async {
                            if (!context.mounted) return;
                            final confirm = await NoteEditorCanvas
                                .confirmDeleteAllCompleted(
                              context,
                              _completedItems.length,
                            );
                            if (confirm) {
                              _completedItems.clear();
                              await saveNote();
                              if (context.mounted) setState(() {});
                            }
                          },
                          onRestoreCompletedItem: (item) {
                            setState(() => _completedItems.remove(item));
                            NoteEditorActions.restoreChecklistItemsToEditor(
                              quillController: _quillController,
                              itemsToRestore: [item],
                              setUpdatingProgrammatically: (v) =>
                                  _isUpdatingProgrammatically = v,
                              onSave: saveNote,
                              onComplete: () {
                                if (mounted) setState(() {});
                              },
                            );
                          },
                          onDeleteCompletedItem: (item) async {
                            _completedItems.remove(item);
                            await saveNote();
                            if (context.mounted) setState(() {});
                          },
                          onTableCellFocusChanged: (isFocused) {
                            setState(() {
                              _isEditingTableCell = isFocused;
                            });
                          },
                          onSelectAllText: _selectAllText,
                          onOpenStoryCardSelected: () =>
                              _openStoryCardStudio(selectedOnly: true),
                          onDismissUrl: (url) {
                            setState(() {
                              _dismissedUrls.add(url);
                              _noteUrls.remove(url);
                            });
                          },
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
                      onCopy: () => NoteEditorActions.copyAiSummary(
                        context,
                        _aiSummary!,
                      ),
                      onAppend: () {
                        NoteEditorActions.appendAiSummary(
                          _quillController,
                          _aiSummary!,
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

