import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../../../screens/app_lock_screen.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'dart:async';
import '../../data/note_repository.dart';
import '../../../../data/note_model.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_chip.dart';
import '../../../../utils/rich_text_utils.dart';
import '../../../../utils/quill_checklist_helper.dart';
import 'dart:io';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:local_auth/local_auth.dart';
import 'package:intl/intl.dart';
import '../../../../services/local_ai_service.dart';
import '../../../../services/offline_ai_fallback_service.dart';
import '../../../../services/notification_service.dart';
import '../../../../providers/note_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../utils/app_globals.dart';
import 'package:flutter/services.dart';
import '../../../../widgets/bouncing_widget.dart';
import '../../../../core/services/app_haptics.dart';

import '../../../../widgets/editor/editor_table_dialog.dart';
import '../../../../widgets/editor/editor_note_details_sheet.dart';
import '../widgets/story_card_creator_sheet.dart';
import '../../../story_cards/story_cards.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../core/ui/app_snack_bar.dart';
import '../widgets/note_editor_bottom_bar.dart';


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

  const NoteEditorScreen({
    super.key,
    this.note,
    this.initialSharedText,
    this.initialSharedImagePaths,
    this.templateTitle,
    this.templateContent,
    this.initialFolder,
    this.targetLineIndex,
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

  static final List<({String label, String command, IconData icon, String description})> _slashCommands = [
    (label: 'AI Assist', command: 'ai', icon: Icons.auto_awesome, description: 'Launch Gemini AI tools'),
    (label: 'Checklist', command: 'todo', icon: Icons.check_box_outlined, description: 'Interactive to-do checkbox'),
    (label: 'Table', command: 'table', icon: Icons.table_chart_outlined, description: 'Insert 3x3 data grid'),
    (label: 'Code Block', command: 'code', icon: Icons.code, description: 'Monospace code container'),
    (label: 'Heading 1', command: 'h1', icon: Icons.title, description: 'Large main heading'),
    (label: 'Heading 2', command: 'h2', icon: Icons.text_fields, description: 'Medium section heading'),
    (label: 'Quote', command: 'quote', icon: Icons.format_quote, description: 'Callout blockquote'),
    (label: 'Bullet List', command: 'bullet', icon: Icons.format_list_bulleted, description: 'Unordered bullet points'),
    (label: 'Numbered List', command: 'number', icon: Icons.format_list_numbered, description: 'Sequential numbered list'),
  ];

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
    _folder = widget.note?.category ?? widget.initialFolder ?? 'All Notes';
    _lastScheduledReminder = _reminderAt;
    _lockAuthPassed = !_isNoteLocked;
    if (!_lockAuthPassed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _authenticateForLockedNote();
      });
    } else if (widget.targetLineIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          final targetIndex = widget.targetLineIndex!;
          final plainText = _quillController.document.toPlainText();
          final lines = plainText.split('\n');
          if (targetIndex >= 0 && targetIndex < lines.length) {
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
          }
        } catch (e) {
          debugPrint('Error jumping to targetLineIndex: $e');
        }
      });
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

  RenderBox? _findRenderEditor(RenderObject? object) {
    if (object == null) return null;
    if (object.runtimeType.toString().contains('RenderEditor')) {
      return object as RenderBox;
    }
    RenderBox? result;
    object.visitChildren((child) {
      if (result != null) return;
      result = _findRenderEditor(child);
    });
    return result;
  }

  void _scrollToCursorIfNeeded() {
    if (!_focusNode.hasFocus || !_scrollController.hasClients) return;
    final selection = _quillController.selection;
    if (selection.baseOffset < 0) return;

    final docLength = _quillController.document.length;
    if (docLength <= 1) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || !_focusNode.hasFocus) return;

      try {
        final focusContext = _focusNode.context;
        if (focusContext == null) return;

        final rootRenderObject = focusContext.findRenderObject();
        final editorRenderObject = _findRenderEditor(rootRenderObject);
        if (editorRenderObject == null || !editorRenderObject.attached) return;

        final scrollableState = Scrollable.of(focusContext);
        final scrollRenderObject = scrollableState.context.findRenderObject();
        if (scrollRenderObject is! RenderBox || !scrollRenderObject.attached) return;

        // Obtain caret rectangle relative to RenderEditor top-left
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

        // Convert editor top-left to scrollable coordinate space
        final Offset editorOffsetInScrollable = editorRenderObject.localToGlobal(
          Offset.zero,
          ancestor: scrollRenderObject,
        );

        // Calculate absolute Y position of cursor inside scrollable content
        final double cursorYInContent =
            _scrollController.offset + editorOffsetInScrollable.dy + caretTop;

        final double currentScroll = _scrollController.offset;
        final double viewportHeight = _scrollController.position.viewportDimension;

        // Safety margins so typing line is not covered by top bar or bottom toolbar/keyboard
        const double topPadding = 60.0;
        const double bottomPadding = 160.0; // Keeps active typing line well above soft keyboard + formatting pill

        final double visibleTop = currentScroll + topPadding;
        final double visibleBottom = currentScroll + viewportHeight - bottomPadding;

        double? targetScroll;

        if (cursorYInContent + caretHeight > visibleBottom) {
          // Cursor is below visible area or covered by keyboard -> scroll down
          targetScroll = (cursorYInContent + caretHeight) - (viewportHeight - bottomPadding);
        } else if (cursorYInContent < visibleTop) {
          // Cursor is above visible area -> scroll up
          targetScroll = cursorYInContent - topPadding;
        }

        if (targetScroll != null) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          final clampedTarget = targetScroll.clamp(0.0, maxScroll);

          if ((clampedTarget - currentScroll).abs() > 2.0) {
            _scrollController.animateTo(
              clampedTarget,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
            );
          }
        }
      } catch (e) {
        debugPrint('Error scrolling to cursor: $e');
      }
    });
  }

  bool _checkIfImageSelected() {
    final index = _quillController.selection.baseOffset;
    if (index < 0 || index >= _quillController.document.length) return false;

    // This is valid for many versions of Quill where images are embeds
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

  void _nudgeSelectionLeft({bool byWord = false}) {
    if (_isEditingTableCell) return;
    final selection = _quillController.selection;
    final docLen = _quillController.document.length;
    if (!selection.isValid || docLen <= 0) return;

    AppHaptics.selectionClick();
    _focusNode.requestFocus();

    final currentExtent = selection.extentOffset;
    final int newExtent;
    if (byWord) {
      final text = _quillController.document.toPlainText();
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

    _quillController.updateSelection(
      selection.isCollapsed
          ? TextSelection.collapsed(offset: newExtent)
          : TextSelection(baseOffset: selection.baseOffset, extentOffset: newExtent),
      ChangeSource.local,
    );
  }

  void _nudgeSelectionRight({bool byWord = false}) {
    if (_isEditingTableCell) return;
    final selection = _quillController.selection;
    final docLen = _quillController.document.length;
    if (!selection.isValid || docLen <= 0) return;

    AppHaptics.selectionClick();
    _focusNode.requestFocus();

    final currentExtent = selection.extentOffset;
    final int newExtent;
    if (byWord) {
      final text = _quillController.document.toPlainText();
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

    _quillController.updateSelection(
      selection.isCollapsed
          ? TextSelection.collapsed(offset: newExtent)
          : TextSelection(baseOffset: selection.baseOffset, extentOffset: newExtent),
      ChangeSource.local,
    );
  }

  void _nudgeSelectionUp() {
    if (_isEditingTableCell) return;
    final selection = _quillController.selection;
    final text = _quillController.document.toPlainText();
    if (!selection.isValid || text.isEmpty) return;

    AppHaptics.selectionClick();
    _focusNode.requestFocus();

    final currentOffset = selection.extentOffset.clamp(0, text.length - 1);
    final prevLineEnd = text.lastIndexOf('\n', currentOffset > 0 ? currentOffset - 1 : 0);
    if (prevLineEnd >= 0) {
      final prevLineStart = text.lastIndexOf('\n', prevLineEnd > 0 ? prevLineEnd - 1 : 0) + 1;
      final currentLineStart = text.lastIndexOf('\n', currentOffset > 0 ? currentOffset - 1 : 0) + 1;
      final column = currentOffset - currentLineStart;
      final newOffset = (prevLineStart + column).clamp(0, prevLineEnd);
      _quillController.updateSelection(
        selection.isCollapsed
            ? TextSelection.collapsed(offset: newOffset)
            : TextSelection(baseOffset: selection.baseOffset, extentOffset: newOffset),
        ChangeSource.local,
      );
    } else {
      _quillController.updateSelection(
        selection.isCollapsed
            ? const TextSelection.collapsed(offset: 0)
            : TextSelection(baseOffset: selection.baseOffset, extentOffset: 0),
        ChangeSource.local,
      );
    }
  }

  void _nudgeSelectionDown() {
    if (_isEditingTableCell) return;
    final selection = _quillController.selection;
    final text = _quillController.document.toPlainText();
    if (!selection.isValid || text.isEmpty) return;

    AppHaptics.selectionClick();
    _focusNode.requestFocus();

    final currentOffset = selection.extentOffset.clamp(0, text.length - 1);
    final currentLineStart = text.lastIndexOf('\n', currentOffset > 0 ? currentOffset - 1 : 0) + 1;
    final column = currentOffset - currentLineStart;
    final nextLineStart = text.indexOf('\n', currentOffset);
    if (nextLineStart >= 0 && nextLineStart + 1 < text.length) {
      final nextLineEnd = text.indexOf('\n', nextLineStart + 1);
      final lineEnd = nextLineEnd >= 0 ? nextLineEnd : text.length - 1;
      final newOffset = (nextLineStart + 1 + column).clamp(0, lineEnd);
      _quillController.updateSelection(
        selection.isCollapsed
            ? TextSelection.collapsed(offset: newOffset)
            : TextSelection(baseOffset: selection.baseOffset, extentOffset: newOffset),
        ChangeSource.local,
      );
    } else {
      _quillController.updateSelection(
        selection.isCollapsed
            ? TextSelection.collapsed(offset: text.length - 1)
            : TextSelection(baseOffset: selection.baseOffset, extentOffset: text.length - 1),
        ChangeSource.local,
      );
    }
  }

  void _selectAllText() {
    final docLen = _quillController.document.length;
    if (docLen <= 1) return;
    _quillController.updateSelection(
      TextSelection(baseOffset: 0, extentOffset: docLen - 1),
      ChangeSource.local,
    );
  }

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
    _quillController.removeListener(_onContentChanged);
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        String enteredTag = '';
        int newTagColor = 0;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final mediaQuery = MediaQuery.of(context);
            final maxHeight = mediaQuery.size.height * 0.75;

            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: mediaQuery.viewInsets.bottom + 16,
                  left: 16,
                  right: 16,
                  top: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Manage Tags',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Create new tag',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () async {
                            if (enteredTag.isNotEmpty) {
                              if (newTagColor != 0) {
                                await NoteRepository.instance
                                    .setTagColor(enteredTag, newTagColor);
                                _tagColors[enteredTag] = newTagColor;
                              }
                              setState(() {
                                if (!tags.contains(enteredTag)) {
                                  tags.add(enteredTag);
                                  _updateColorFromTags();
                                }
                                if (!_allTags.contains(enteredTag)) {
                                  _allTags.add(enteredTag);
                                }
                              });
                              if (context.mounted) Navigator.pop(context);
                            }
                          },
                        ),
                      ),
                      onChanged: (v) => enteredTag = v.trim(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'TAG COLOR',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        ...AppTheme.noteColors.map((c) {
                          final bool isSystem = c.toARGB32() == 0;
                          final bool isSelected =
                              !isSystem && newTagColor == c.toARGB32();
                          return Semantics(
                            label: isSystem ? 'Random Color' : 'Color option',
                            selected: isSelected,
                            button: true,
                            child: GestureDetector(
                              onTap: () {
                                if (isSystem) {
                                  final nonZeroColors = AppTheme.noteColors
                                      .where((color) => color.toARGB32() != 0)
                                      .toList();
                                  final randomColor =
                                      (nonZeroColors..shuffle()).first;
                                  setModalState(
                                      () => newTagColor = randomColor.toARGB32());
                                } else {
                                  setModalState(() => newTagColor = c.toARGB32());
                                }
                              },
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Center(
                                  child: Container(
                                    width: isSelected ? 34 : 30,
                                    height: isSelected ? 34 : 30,
                                    decoration: BoxDecoration(
                                      color: isSystem
                                          ? Theme.of(context).colorScheme.surfaceContainerHigh
                                          : c,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .outlineVariant,
                                        width: isSelected ? 3 : 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: c.withValues(alpha: 0.4),
                                                blurRadius: 6,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: isSystem
                                        ? const Icon(Icons.shuffle, size: 16)
                                        : (isSelected
                                            ? Icon(Icons.check,
                                                size: 16,
                                                color: c.computeLuminance() > 0.5
                                                    ? Colors.black
                                                    : Colors.white)
                                            : null),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_allTags.isNotEmpty) ...[
                      Text(
                        'SELECT TAGS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _allTags.map((t) {
                              final isSelected = tags.contains(t);
                              final tagColorVal = _tagColors[t];
                              final colors = AppChip.getTagColors(context, tagColorVal,
                                  isSelected: isSelected);

                              return AppChip(
                                label: t,
                                icon: isSelected ? Icons.check : null,
                                isSelected: isSelected,
                                backgroundColor: colors.bg,
                                selectedBackgroundColor: colors.bg,
                                textColor: colors.fg,
                                border: colors.border,
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      tags.remove(t);
                                    } else {
                                      tags.add(t);
                                    }
                                    _updateColorFromTags();
                                  });
                                  setModalState(() {});
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      AppLockScreen.ignoreNextResumeLock();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(p.join(appDir.path, 'note_images'));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }
        final ext = p.extension(pickedFile.path);
        final uniqueName = '${const Uuid().v4()}$ext';
        final savedFile = await File(pickedFile.path).copy(p.join(imagesDir.path, uniqueName));

        final (index, length) = _getNormalizedSelectionRange();
        _quillController.replaceText(
            index, length, BlockEmbed.image(savedFile.path), null);
        if (mounted) {
          Navigator.pop(context); // Close the modal
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) Navigator.pop(context); // Ensure modal closes on error
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final textColor = Theme.of(context).colorScheme.onSurface;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: textColor),
                title: Text('Gallery', style: TextStyle(color: textColor)),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: textColor),
                title: Text('Camera', style: TextStyle(color: textColor)),
                onTap: () => _pickImage(ImageSource.camera),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future saveNote() async {
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
    _quillController.updateSelection(
      TextSelection(baseOffset: offset, extentOffset: offset + length),
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
    final markdown = RichTextUtils.deltaToMarkdown(delta);
    final plainText = _quillController.document.toPlainText().trim();
    final shareContent = title.isEmpty ? plainText : '$title\n\n$plainText';

    final colorScheme = Theme.of(context).colorScheme;

    AppBottomSheet.show(
      context: context,
      title: 'Share & Export Note',
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_back_rounded, color: colorScheme.primary),
              title: const Text('Create Story Card'),
              subtitle: const Text('Export quote as a stylish image for social stories'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
              ),
              onTap: () {
                Navigator.pop(context);
                _openStoryCardStudio(selectedOnly: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: const Text('Share as Plain Text'),
              subtitle: const Text('Send text to other apps or messaging'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
              ),
              onTap: () {
                Navigator.pop(context);
                if (shareContent.isNotEmpty) {
                  Share.share(shareContent, subject: title.isEmpty ? 'Note' : title);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.code_outlined),
              title: const Text('Share as Markdown'),
              subtitle: const Text('Preserve bold, lists, and headers formatting'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
              ),
              onTap: () {
                Navigator.pop(context);
                final mdContent = title.isEmpty ? markdown : '# $title\n\n$markdown';
                if (mdContent.isNotEmpty) {
                  Share.share(mdContent, subject: title.isEmpty ? 'Note' : title);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Export as Text File'),
              subtitle: const Text('Save note as a .txt document'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
              ),
              onTap: () async {
                Navigator.pop(context);
                final tempDir = await getTemporaryDirectory();
                final safeTitle = (title.isEmpty ? 'Note' : title).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
                final file = File('${tempDir.path}/$safeTitle.txt');
                await file.writeAsString(shareContent);
                await Share.shareXFiles([XFile(file.path)], text: title.isEmpty ? 'Note Export' : title);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy to Clipboard'),
              subtitle: const Text('Copy note content to clipboard'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
              ),
              onTap: () async {
                Navigator.pop(context);
                if (shareContent.isNotEmpty) {
                  await Clipboard.setData(ClipboardData(text: shareContent));
                  if (mounted) {
                    AppSnackBar.show(context, message: 'Note copied to clipboard');
                  }
                }
              },
            ),
          ],
        ),
      ),
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

    final controller = TextEditingController();
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to folder'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.notes_outlined),
                      title: const Text('All Notes'),
                      selected: _folder == 'All Notes',
                      onTap: () => Navigator.pop(ctx, 'All Notes'),
                    ),
                    ...folders.map(
                      (f) => ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(f),
                        selected: _folder == f,
                        onTap: () => Navigator.pop(ctx, f),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'New folder name',
                  prefixIcon: Icon(Icons.create_new_folder_outlined),
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: const Text('Create & Move'),
          ),
        ],
      ),
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

  Future<void> _deleteNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Trash?'),
        content: const Text('This note will be moved to Trash.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await NoteRepository.instance.softDeleteNote(_noteId);
      if (mounted) Navigator.pop(context, true);

      // The editor is gone after the pop, so surface the undo on the
      // app-level messenger.
      final noteId = _noteId;
      appScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: const Text('Note moved to Trash'),
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

  Future<void> _showAiResultSheet({
    required BuildContext context,
    required String title,
    required String resultText,
    required bool isSelection,
    required TextSelection? selection,
  }) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.amber, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 240),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppLayout.radiusM),
                    border: Border.all(
                      color: colorScheme.secondary.withValues(alpha: 0.30),
                      width: 1.2,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      resultText,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      label: const Text('Copy'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: resultText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied result to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        Navigator.of(ctx).pop();
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.post_add_outlined, size: 18),
                      label: const Text('Insert Below'),
                      onPressed: () {
                        final docLen = _quillController.document.length;
                        final safeLen = docLen > 0 ? docLen - 1 : 0;
                        final insertPos = isSelection && selection != null
                            ? selection.end.clamp(0, safeLen)
                            : safeLen;
                        _quillController.replaceText(
                          insertPos,
                          0,
                          '\n$resultText',
                          null,
                        );
                        _onContentChanged();
                        saveNote();
                        Navigator.of(ctx).pop();
                      },
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(isSelection ? 'Replace Selection' : 'Replace All'),
                      onPressed: () {
                        final docLen = _quillController.document.length;
                        final safeLen = docLen > 0 ? docLen - 1 : 0;
                        if (isSelection && selection != null) {
                          final start = selection.start.clamp(0, safeLen);
                          final end = selection.end.clamp(start, safeLen);
                          _quillController.replaceText(
                            start,
                            end - start,
                            resultText,
                            null,
                          );
                        } else {
                          _quillController.replaceText(
                            0,
                            safeLen,
                            resultText,
                            null,
                          );
                        }
                        _onContentChanged();
                        saveNote();
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAiOptionsSheet() {
    final aiService = Provider.of<LocalAiService>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    bool isLoading = false;
    String? statusText;

    final sel = _quillController.selection;
    final bool isSelection = sel.isValid && !sel.isCollapsed;
    final String targetText = isSelection
        ? _quillController.document.getPlainText(sel.start, sel.end - sel.start).trim()
        : _quillController.document.toPlainText().trim();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final theme = Theme.of(sheetContext);
            final colorScheme = theme.colorScheme;

            Widget buildSectionHeader(String title, IconData icon) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(2, 10, 2, 4),
                child: Row(
                  children: [
                    Icon(icon, size: 14, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      title.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.7,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        (() {
                          final badgeColor = settings.isDeviceAiSupported
                              ? (theme.extension<AppSemanticColors>()?.success ?? colorScheme.primary)
                              : colorScheme.tertiary;
                          return Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppLayout.radiusMAX),
                                border: Border.all(
                                  color: badgeColor.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: badgeColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    settings.isDeviceAiSupported
                                        ? 'NPU Hardware Ready • 100% Offline'
                                        : 'Offline NLP Engines • 100% Offline',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: badgeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        })(),
                        const SizedBox(height: 10),
                        // Header Avatar Ring
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              size: 20,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'On-Device Gemini AI',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          settings.isDeviceAiSupported
                              ? 'Powered by Android AI Core • 100% Offline & Private'
                              : 'Powered by offline rules & patterns • 100% Offline & Private',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),

                        // Context Badge
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSelection
                                  ? colorScheme.primaryContainer.withValues(alpha: 0.7)
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(AppLayout.radiusMAX),
                              border: Border.all(
                                color: isSelection
                                    ? colorScheme.primary.withValues(alpha: 0.3)
                                    : colorScheme.outlineVariant.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSelection ? Icons.select_all_rounded : Icons.description_outlined,
                                  size: 13,
                                  color: isSelection
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isSelection
                                      ? 'Targeting selected text (${targetText.length} chars)'
                                      : 'Targeting entire note content',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isSelection
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),

                        if (statusText != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            statusText!,
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],

                        if (isLoading) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(AppLayout.radiusM),
                              border: Border.all(
                                color: colorScheme.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                LinearProgressIndicator(
                                  backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(AppLayout.radiusMAX),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  statusText ?? 'Processing with Gemini Nano…',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Section 1: Refine & Rewrite
                          buildSectionHeader('Refine & Rewrite', Icons.edit_note_rounded),
                          _buildAiTile(
                            context: context,
                            icon: Icons.check_box_outlined,
                            title: 'Extract Action Items',
                            subtitle: isSelection
                                ? 'Find to-dos in selection and create checkboxes'
                                : 'Find to-dos in note and create checkboxes',
                            onTap: () async {
                              final editorContext = context;
                              final navigator = Navigator.of(editorContext);
                              if (targetText.isEmpty) {
                                setModalState(() {
                                  statusText = 'No text to analyze.';
                                });
                                return;
                              }
                              setModalState(() {
                                isLoading = true;
                                statusText = 'Extracting tasks...';
                              });
                              final prompt =
                                  "Extract all actionable tasks, to-dos, or action items from the following text. Format each item on a new line prefixed with '☐ '. Respond ONLY with the list of items:\n\n$targetText";
                              String actionItemsText = await aiService.generateText(prompt) ?? '';
                              if (actionItemsText.trim().isEmpty) {
                                actionItemsText = OfflineAiFallbackService.extractActionItems(targetText);
                              }
                              if (actionItemsText.trim().isNotEmpty) {
                                navigator.pop();
                                if (mounted) {
                                  await _showAiResultSheet(
                                    context: context,
                                    title: 'Extracted Action Items',
                                    resultText: actionItemsText.trim(),
                                    isSelection: isSelection,
                                    selection: isSelection ? sel : null,
                                  );
                                }
                              } else {
                                setModalState(() {
                                  isLoading = false;
                                  statusText = 'No action items found.';
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 6),
                          _buildAiTile(
                            context: context,
                            icon: Icons.auto_fix_high_rounded,
                            title: 'Proofread & Polish',
                            subtitle: 'Correct grammar, spelling, and style',
                            onTap: () async {
                              final navigator = Navigator.of(context);
                              if (targetText.isEmpty) {
                                setModalState(() {
                                  statusText = 'No text to polish.';
                                });
                                return;
                              }
                              setModalState(() {
                                isLoading = true;
                                statusText = 'Polishing grammar...';
                              });
                              final res = await aiService.refineText(targetText, 'polish');
                              if (res != null && res.trim().isNotEmpty) {
                                navigator.pop();
                                if (mounted) {
                                  await _showAiResultSheet(
                                    context: context,
                                    title: 'Polished Text',
                                    resultText: res.trim(),
                                    isSelection: isSelection,
                                    selection: isSelection ? sel : null,
                                  );
                                }
                              } else {
                                setModalState(() {
                                  isLoading = false;
                                  statusText = 'Failed to polish text.';
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 6),
                          _buildAiTile(
                            context: context,
                            icon: Icons.compress_rounded,
                            title: 'Make Shorter / Simplify',
                            subtitle: 'Condense into clear, direct key points',
                            onTap: () async {
                              final navigator = Navigator.of(context);
                              if (targetText.isEmpty) {
                                setModalState(() {
                                  statusText = 'No text to shorten.';
                                });
                                return;
                              }
                              setModalState(() {
                                isLoading = true;
                                statusText = 'Simplifying text...';
                              });
                              final res = await aiService.refineText(targetText, 'shorten');
                              if (res != null && res.trim().isNotEmpty) {
                                navigator.pop();
                                if (mounted) {
                                  await _showAiResultSheet(
                                    context: context,
                                    title: 'Simplified Text',
                                    resultText: res.trim(),
                                    isSelection: isSelection,
                                    selection: isSelection ? sel : null,
                                  );
                                }
                              } else {
                                setModalState(() {
                                  isLoading = false;
                                  statusText = 'Failed to shorten text.';
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 6),
                          _buildAiTile(
                            context: context,
                            icon: Icons.unfold_more_rounded,
                            title: 'Elaborate & Expand',
                            subtitle: 'Flesh out quick notes into structured paragraphs',
                            onTap: () async {
                              final navigator = Navigator.of(context);
                              if (targetText.isEmpty) {
                                setModalState(() {
                                  statusText = 'No text to expand.';
                                });
                                return;
                              }
                              setModalState(() {
                                isLoading = true;
                                statusText = 'Expanding text...';
                              });
                              final res = await aiService.refineText(targetText, 'expand');
                              if (res != null && res.trim().isNotEmpty) {
                                navigator.pop();
                                if (mounted) {
                                  await _showAiResultSheet(
                                    context: context,
                                    title: 'Expanded Text',
                                    resultText: res.trim(),
                                    isSelection: isSelection,
                                    selection: isSelection ? sel : null,
                                  );
                                }
                              } else {
                                setModalState(() {
                                  isLoading = false;
                                  statusText = 'Failed to expand text.';
                                });
                              }
                            },
                          ),

                          // Section 2: Smart Metadata & Organization
                          if (!isSelection) ...[
                            buildSectionHeader('Smart Metadata & Organization', Icons.auto_awesome_mosaic_rounded),
                            _buildAiTile(
                              context: context,
                              icon: Icons.title_rounded,
                              title: 'Suggest Title',
                              subtitle: 'Generate a clean title from note content',
                              onTap: () async {
                                final navigator = Navigator.of(context);
                                if (targetText.isEmpty) {
                                  setModalState(() {
                                    statusText = 'Note is empty.';
                                  });
                                  return;
                                }
                                setModalState(() {
                                  isLoading = true;
                                  statusText = 'Analyzing content...';
                                });
                                final prompt =
                                    "Generate a short, concise title (maximum 4-5 words) for the following text. Respond ONLY with the title:\n\n$targetText";
                                String? suggested = await aiService.generateText(prompt);
                                if (suggested == null || suggested.trim().isEmpty) {
                                  final lines = targetText.split(RegExp(r'\r?\n|\.'));
                                  final firstLine = lines.firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
                                  if (firstLine.trim().isNotEmpty) {
                                    final clean = firstLine.trim().replaceAll(RegExp(r'^[•\-\*\d+\.\s]+'), '');
                                    suggested = clean.length > 35 ? '${clean.substring(0, 35)}…' : clean;
                                  }
                                }
                                if (suggested != null && suggested.trim().isNotEmpty) {
                                  if (mounted) {
                                    setState(() {
                                      _titleController.text = suggested!.trim().replaceAll('"', '');
                                    });
                                    _onContentChanged();
                                    await saveNote();
                                    navigator.pop();
                                  }
                                } else {
                                  setModalState(() {
                                    isLoading = false;
                                    statusText = 'Failed to generate title.';
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 6),
                            _buildAiTile(
                              context: context,
                              icon: Icons.label_outline_rounded,
                              title: 'Suggest Tags',
                              subtitle: 'Auto-detect topics and apply tags',
                              onTap: () async {
                                final navigator = Navigator.of(context);
                                if (targetText.isEmpty) {
                                  setModalState(() {
                                    statusText = 'Note is empty.';
                                  });
                                  return;
                                }
                                setModalState(() {
                                  isLoading = true;
                                  statusText = 'Identifying topics...';
                                });
                                final suggested = await aiService.suggestTags(targetText, _allTags);
                                if (suggested.isNotEmpty) {
                                  if (mounted) {
                                    setState(() {
                                      for (final tag in suggested) {
                                        if (!tags.contains(tag)) {
                                          tags.add(tag);
                                        }
                                      }
                                      _updateColorFromTags();
                                    });
                                    _onContentChanged();
                                    await saveNote();
                                    navigator.pop();
                                  }
                                } else {
                                  setModalState(() {
                                    isLoading = false;
                                    statusText = 'No new tags suggested.';
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 6),
                            _buildAiTile(
                              context: context,
                              icon: Icons.short_text_rounded,
                              title: 'Summarize Note',
                              subtitle: 'Append a bulleted summary to the note',
                              onTap: () async {
                                final navigator = Navigator.of(context);
                                if (targetText.isEmpty) {
                                  setModalState(() {
                                    statusText = 'Note is empty.';
                                  });
                                  return;
                                }
                                setModalState(() {
                                  isLoading = true;
                                  statusText = 'Generating summary...';
                                });
                                final summary = await aiService.summarize(targetText);
                                if (summary != null && summary.trim().isNotEmpty) {
                                  if (mounted) {
                                    setState(() {
                                      _aiSummary = summary.trim();
                                    });
                                    navigator.pop();
                                  }
                                } else {
                                  setModalState(() {
                                    isLoading = false;
                                    statusText = 'Failed to generate summary.';
                                  });
                                }
                              },
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAiTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppLayout.radiusM),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppLayout.radiusM)),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppLayout.radiusS),
          ),
          child: Icon(icon, size: 18, color: colorScheme.primary),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
            fontSize: 13.5,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 11.5,
            height: 1.15,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded,
            size: 18, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSlashMenuOverlay(ThemeData theme, ColorScheme colorScheme) {
    final filteredCommands = _slashCommands
        .where((cmd) =>
            cmd.command.startsWith(_slashQuery) ||
            cmd.label.toLowerCase().contains(_slashQuery))
        .toList();

    if (filteredCommands.isEmpty) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: AppLayout.animShort,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppLayout.radiusXL),
        boxShadow: AppLayout.softShadow(context),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: [
                    Icon(Icons.bolt, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Slash Commands',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Type to filter',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6.0),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: filteredCommands.length,
                  itemBuilder: (context, index) {
                    final cmd = filteredCommands[index];
                    return ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(AppLayout.radiusS),
                        ),
                        child: Icon(cmd.icon, size: 18, color: colorScheme.primary),
                      ),
                      title: Row(
                        children: [
                          Text(
                            cmd.label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius:
                                  BorderRadius.circular(AppLayout.radiusS),
                            ),
                            child: Text(
                              '/${cmd.command}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontFamily: 'monospace',
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        cmd.description,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onTap: () => _executeSlashCommand(cmd.command),
                    );
                  },
                ),
              ),
            ],
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    if (!_lockAuthPassed) {
      final cs = Theme.of(context).colorScheme;
      return Scaffold(
        backgroundColor: cs.surface,
        body: Stack(
            children: [
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary.withValues(alpha: 0.15),
                  ),
                ),
              ),
              Positioned(
                bottom: -150,
                left: -150,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.tertiary.withValues(alpha: 0.1),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.maybePop(context),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(AppLayout.radiusL),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.35),
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 600),
                                tween: Tween(begin: 0.0, end: 1.0),
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: child,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.lock_outline, size: 48, color: cs.primary),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Note Locked',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This note is protected with a password or biometrics.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 32),
                              FilledButton.icon(
                                onPressed: _authenticateForLockedNote,
                                icon: const Icon(Icons.fingerprint),
                                label: const Text('Unlock Note'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: const StadiumBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
            await saveNote();
            if (context.mounted) {
              await context.read<NoteProvider>().refreshNotes();
            }
          } catch (e) {
            debugPrint('Error saving note on pop: $e');
          } finally {
            if (context.mounted) Navigator.pop(context, true);
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
                          child: _isSearching
                              ? CallbackShortcuts(
                                  bindings: <ShortcutActivator, VoidCallback>{
                                    const SingleActivator(LogicalKeyboardKey.escape): _closeSearch,
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.arrow_back),
                                          color: theme.colorScheme.onSurfaceVariant,
                                          tooltip: 'Close search',
                                          onPressed: _closeSearch,
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller: _searchController,
                                            focusNode: _searchFocusNode,
                                            style: TextStyle(color: theme.colorScheme.onSurface),
                                            decoration: InputDecoration(
                                              hintText: 'Search in note...',
                                              hintStyle: TextStyle(
                                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                              ),
                                              filled: false,
                                              fillColor: Colors.transparent,
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                              isDense: true,
                                            ),
                                            onChanged: _performSearch,
                                            onSubmitted: (_) => _nextSearchMatch(),
                                          ),
                                        ),
                                        Tooltip(
                                          message: 'Match case',
                                          child: InkWell(
                                            onTap: _toggleCaseSensitive,
                                            borderRadius: BorderRadius.circular(AppLayout.radiusS),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 150),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _isCaseSensitive
                                                    ? theme.colorScheme.primaryContainer
                                                    : Colors.transparent,
                                                borderRadius: BorderRadius.circular(AppLayout.radiusS),
                                                border: Border.all(
                                                  color: _isCaseSensitive
                                                      ? theme.colorScheme.primary
                                                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                                                ),
                                              ),
                                              child: Text(
                                                'Aa',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: _isCaseSensitive ? FontWeight.bold : FontWeight.normal,
                                                  color: _isCaseSensitive
                                                      ? theme.colorScheme.onPrimaryContainer
                                                      : theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        if (_searchController.text.isNotEmpty)
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 150),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            margin: const EdgeInsets.symmetric(horizontal: 2),
                                            decoration: BoxDecoration(
                                              color: _searchOffsets.isNotEmpty
                                                  ? theme.colorScheme.secondaryContainer
                                                  : theme.colorScheme.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(AppLayout.radiusM),
                                            ),
                                            child: Text(
                                              _searchOffsets.isNotEmpty
                                                  ? '${_currentSearchIndex + 1}/${_searchOffsets.length}'
                                                  : '0/0',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: _searchOffsets.isNotEmpty
                                                    ? theme.colorScheme.onSecondaryContainer
                                                    : theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        if (_searchOffsets.isNotEmpty) ...[
                                          IconButton(
                                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                                            color: theme.colorScheme.onSurfaceVariant,
                                            tooltip: 'Previous match',
                                            onPressed: _previousSearchMatch,
                                          ),
                                          IconButton(
                                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                                            color: theme.colorScheme.onSurfaceVariant,
                                            tooltip: 'Next match',
                                            onPressed: _nextSearchMatch,
                                          ),
                                        ],
                                        if (_searchController.text.isNotEmpty)
                                          IconButton(
                                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.close_rounded, size: 20),
                                            color: theme.colorScheme.onSurfaceVariant,
                                            tooltip: 'Clear search text',
                                            onPressed: () {
                                              _searchController.clear();
                                              _performSearch('');
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                )
                              : Row(
                                  children: [
                                    BouncingWidget(
                                      onTap: () => Navigator.maybePop(context),
                                      child: IconButton(
                                        icon: const Icon(Icons.arrow_back),
                                        color: textColor,
                                        onPressed: () => Navigator.maybePop(context),
                                      ),
                                    ),
                                    const SizedBox(width: AppLayout.spaceS),
                                    QuillToolbarHistoryButton(
                                      isUndo: true,
                                      controller: _quillController,
                                      options: QuillToolbarHistoryButtonOptions(
                                          iconTheme: QuillIconTheme(
                                              iconButtonUnselectedData:
                                                  IconButtonData(
                                                      style: IconButton.styleFrom(
                                                          foregroundColor:
                                                              textColor)))),
                                    ),
                                    QuillToolbarHistoryButton(
                                      isUndo: false,
                                      controller: _quillController,
                                      options: QuillToolbarHistoryButtonOptions(
                                          iconTheme: QuillIconTheme(
                                              iconButtonUnselectedData:
                                                  IconButtonData(
                                                      style: IconButton.styleFrom(
                                                          foregroundColor:
                                                              textColor)))),
                                    ),
                                    const Spacer(),
                                    BouncingWidget(
                                      onTap: _showTagPicker,
                                      child: IconButton(
                                        icon: const Icon(Icons.label_outline),
                                        tooltip: 'Tags',
                                        color: textColor,
                                        onPressed: _showTagPicker,
                                      ),
                                    ),
                                    const SizedBox(width: 4.0),
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert_rounded, color: textColor),
                                      tooltip: 'More',
                                      elevation: 3,
                                      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.15),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppLayout.radiusXL),
                                        side: BorderSide(
                                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                                          width: 1,
                                        ),
                                      ),
                                      color: theme.colorScheme.surfaceContainerHigh,
                                      onSelected: (value) async {
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
                                      itemBuilder: (context) {
                                        final colorScheme = theme.colorScheme;
                                        return [
                                          PopupMenuItem(
                                            value: 'search',
                                            height: 48,
                                            child: Row(
                                              children: [
                                                Icon(Icons.search_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                                                const SizedBox(width: 12),
                                                Text('Find in Note', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                          if (settings.minimalEditorMode)
                                            PopupMenuItem(
                                              value: 'table',
                                              height: 48,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.table_chart_outlined, size: 20, color: colorScheme.onSurfaceVariant),
                                                  const SizedBox(width: 12),
                                                  Text('Insert Table', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                                                ],
                                              ),
                                            ),
                                          PopupMenuItem(
                                            value: 'reminder',
                                            height: 48,
                                            child: Row(
                                              children: [
                                                Icon(_reminderAt != null ? Icons.alarm_on_rounded : Icons.alarm_add_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                                                const SizedBox(width: 12),
                                                Text(_reminderAt != null ? 'Change reminder' : 'Set reminder', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                          if (_reminderAt != null)
                                            PopupMenuItem(
                                              value: 'clear_reminder',
                                              height: 48,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.alarm_off_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                                                  const SizedBox(width: 12),
                                                  Text('Remove reminder', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                                                ],
                                              ),
                                            ),
                                          PopupMenuItem(
                                            value: 'folder',
                                            height: 48,
                                            child: Row(
                                              children: [
                                                Icon(Icons.folder_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                                                const SizedBox(width: 12),
                                                Text('Move to folder', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'details',
                                            height: 48,
                                            child: Row(
                                              children: [
                                                Icon(Icons.info_outline_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                                                const SizedBox(width: 12),
                                                Text('Note Details & Stats', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'share',
                                            height: 48,
                                            child: Row(
                                              children: [
                                                Icon(Icons.share_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                                                const SizedBox(width: 12),
                                                Text('Share & Export', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'lock',
                                            height: 48,
                                            child: Row(
                                              children: [
                                                Icon(_isNoteLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                                                const SizedBox(width: 12),
                                                Text(_isNoteLocked ? 'Unlock note' : 'Lock note', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            height: 48,
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete_outline_rounded, size: 20, color: colorScheme.error),
                                                const SizedBox(width: 12),
                                                Text('Move to Trash', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.error, fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                        ];
                                      },
                                    ),
                                  ],
                                ),
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
                                    if (_reminderAt != null || _isNoteLocked || _isCustomFolder || tags.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            if (_reminderAt != null)
                                              InputChip(
                                                avatar: Icon(Icons.alarm,
                                                    size: 16, color: textColor),
                                                label: Text(
                                                  DateFormat('EEE, d MMM • h:mm a')
                                                      .format(_reminderAt!),
                                                  style: TextStyle(
                                                      color: textColor, fontSize: 12),
                                                ),
                                                onPressed: _pickReminder,
                                                onDeleted: _clearReminder,
                                                deleteIconColor: textColor,
                                              ),
                                            if (_isNoteLocked)
                                              Chip(
                                                avatar: Icon(Icons.lock,
                                                    size: 16, color: textColor),
                                                label: Text(
                                                  'Locked',
                                                  style: TextStyle(
                                                      color: textColor, fontSize: 12),
                                                ),
                                              ),
                                            if (_isCustomFolder)
                                              InputChip(
                                                avatar: Icon(Icons.folder_outlined,
                                                    size: 16, color: textColor),
                                                label: Text(
                                                  _folder,
                                                  style: TextStyle(
                                                      color: textColor, fontSize: 12),
                                                ),
                                                onPressed: _pickFolder,
                                              ),
                                            ...tags.map((tag) {
                                              final tagColorValue = _tagColors[tag];
                                              final tagColor = tagColorValue != null &&
                                                      tagColorValue != 0
                                                  ? Color(tagColorValue)
                                                  : null;
                                              Color? chipBgColor;
                                              Color? chipLabelColor;
                                              if (tagColor != null) {
                                                final scheme = ColorScheme.fromSeed(
                                                  seedColor: tagColor,
                                                  brightness:
                                                      Theme.of(context).brightness,
                                                );
                                                chipBgColor = scheme.primaryContainer;
                                                chipLabelColor =
                                                    scheme.onPrimaryContainer;
                                              }
                                              return Chip(
                                                label: Text(tag,
                                                    style: TextStyle(
                                                        color: chipLabelColor)),
                                                backgroundColor: chipBgColor,
                                                shape: const StadiumBorder(),
                                                side: BorderSide.none,
                                                onDeleted: () {
                                                  setState(() {
                                                    tags.remove(tag);
                                                    _updateColorFromTags();
                                                  });
                                                  saveNote();
                                                },
                                                deleteIconColor: chipLabelColor,
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    Builder(
                                      builder: (context) {
                                        if (_completedItems.isEmpty) return const SizedBox.shrink();

                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8, bottom: 12),
                                          child: AnimatedContainer(
                                            duration: AppLayout.animShort,
                                            decoration: BoxDecoration(
                                              color: noteScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(AppLayout.radiusXL),
                                              border: Border.all(
                                                color: noteScheme.outlineVariant.withValues(alpha: 0.3),
                                                width: 1.0,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      _isCompletedCollapsed = !_isCompletedCollapsed;
                                                    });
                                                  },
                                                  borderRadius: BorderRadius.circular(AppLayout.radiusXL),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          _isCompletedCollapsed
                                                              ? Icons.keyboard_arrow_right_rounded
                                                              : Icons.keyboard_arrow_down_rounded,
                                                          size: 22,
                                                          color: noteScheme.onSurfaceVariant,
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          '${_completedItems.length} completed ${_completedItems.length == 1 ? 'item' : 'items'}',
                                                          style: theme.textTheme.titleSmall?.copyWith(
                                                            color: noteScheme.onSurfaceVariant,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                        const Spacer(),
                                                        Tooltip(
                                                          message: 'Uncheck All',
                                                          child: IconButton(
                                                            icon: const Icon(Icons.restart_alt_rounded, size: 18),
                                                            padding: EdgeInsets.zero,
                                                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                                            visualDensity: VisualDensity.compact,
                                                            color: noteScheme.onSurfaceVariant,
                                                            onPressed: () async {
                                                              AppHaptics.mediumImpact();
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
                                                          ),
                                                        ),
                                                        Tooltip(
                                                          message: 'Delete Completed',
                                                          child: IconButton(
                                                            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                                                            padding: EdgeInsets.zero,
                                                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                                            visualDensity: VisualDensity.compact,
                                                            color: theme.colorScheme.error,
                                                            onPressed: () async {
                                                              AppHaptics.mediumImpact();
                                                              if (!context.mounted) return;
                                                              final confirm = await showDialog<bool>(
                                                                context: context,
                                                                builder: (ctx) => AlertDialog(
                                                                  title: const Text('Delete Completed Items?'),
                                                                  content: Text(
                                                                      'This will permanently remove ${_completedItems.length} finished items from this note.'),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed: () => Navigator.pop(ctx, false),
                                                                      child: const Text('Cancel'),
                                                                    ),
                                                                    TextButton(
                                                                      onPressed: () => Navigator.pop(ctx, true),
                                                                      style: TextButton.styleFrom(
                                                                          foregroundColor: theme.colorScheme.error),
                                                                      child: const Text('Delete'),
                                                                    ),
                                                                  ],
                                                                ),
                                                              );
                                                              if (confirm == true) {
                                                                _completedItems.clear();
                                                                await saveNote();
                                                                if (context.mounted) setState(() {});
                                                              }
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                if (!_isCompletedCollapsed)
                                                  Column(
                                                    children: [
                                                       const SizedBox(height: 6.0),
                                                      ..._completedItems.map((item) {
                                                        return Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          child: Row(
                                                            children: [
                                                              Checkbox(
                                                                value: true,
                                                                onChanged: (val) async {
                                                                  AppHaptics.selectionClick();
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
                                                                activeColor: theme.colorScheme.primary,
                                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                              ),
                                                              Expanded(
                                                                child: Text(
                                                                  item,
                                                                  style: theme.textTheme.bodyMedium?.copyWith(
                                                                    color: textColor.withValues(alpha: 0.6),
                                                                    decoration: TextDecoration.lineThrough,
                                                                  ),
                                                                ),
                                                              ),
                                                              IconButton(
                                                                icon: Icon(Icons.close_rounded,
                                                                    size: 16, color: noteScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                                                                padding: EdgeInsets.zero,
                                                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                                onPressed: () async {
                                                                  AppHaptics.selectionClick();
                                                                  _completedItems.remove(item);
                                                                  await saveNote();
                                                                  if (context.mounted) setState(() {});
                                                                },
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
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
                                            customStyles: DefaultStyles(
                                              inlineCode: InlineCodeStyle(
                                                style: TextStyle(
                                                  color: noteScheme.onSurface,
                                                  backgroundColor: noteScheme.onSurface.withValues(alpha: 0.15),
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                              h1: DefaultTextBlockStyle(
                                                theme.textTheme.displaySmall!.copyWith(
                                                  color: noteScheme.onSurface,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                const HorizontalSpacing(0, 0),
                                                const VerticalSpacing(16, 0),
                                                const VerticalSpacing(0, 0),
                                                null,
                                              ),
                                              h2: DefaultTextBlockStyle(
                                                theme.textTheme.headlineMedium!.copyWith(
                                                  color: noteScheme.onSurface,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                const HorizontalSpacing(0, 0),
                                                const VerticalSpacing(14, 0),
                                                const VerticalSpacing(0, 0),
                                                null,
                                              ),
                                              h3: DefaultTextBlockStyle(
                                                theme.textTheme.headlineSmall!.copyWith(
                                                  color: noteScheme.onSurface,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                const HorizontalSpacing(0, 0),
                                                const VerticalSpacing(12, 0),
                                                const VerticalSpacing(0, 0),
                                                null,
                                              ),
                                              quote: DefaultTextBlockStyle(
                                                TextStyle(
                                                  color: noteScheme.onSurface.withValues(alpha: 0.7),
                                                  fontStyle: FontStyle.italic,
                                                  fontSize: 16,
                                                ),
                                                const HorizontalSpacing(16, 0),
                                                const VerticalSpacing(8, 8),
                                                const VerticalSpacing(0, 0),
                                                BoxDecoration(
                                                  border: Border(
                                                    left: BorderSide(
                                                      width: 4,
                                                      color: noteScheme.primary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              code: DefaultTextBlockStyle(
                                                TextStyle(
                                                  color: noteScheme.onSurface,
                                                  fontFamily: 'monospace',
                                                  fontSize: 13.5,
                                                  height: 1.4,
                                                ),
                                                const HorizontalSpacing(12, 12),
                                                const VerticalSpacing(8, 8),
                                                const VerticalSpacing(0, 0),
                                                BoxDecoration(
                                                  color: noteScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                                  borderRadius: BorderRadius.circular(AppLayout.radiusM),
                                                  border: Border.all(
                                                    color: noteScheme.outlineVariant.withValues(alpha: 0.4),
                                                    width: 1.0,
                                                  ),
                                                ),
                                              ),
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
                      if (_showSlashMenu && !_isImageSelected)
                        _buildSlashMenuOverlay(theme, noteScheme),

                      // Note Editor Bottom Bar (Formatting sub-tier + Main Pill Toolbar)
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
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 80, // Elevated above bottom formatting bar
                      child: Card(
                        color: noteScheme.surfaceContainerHigh,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppLayout.radiusL),
                          side: BorderSide(
                            color: noteScheme.outlineVariant
                                .withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome,
                                      color: noteScheme.primary, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'AI Summary',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () =>
                                        setState(() => _aiSummary = null),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxHeight: 120),
                                child: SingleChildScrollView(
                                  child: Text(
                                    _aiSummary!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      height: 1.4,
                                      color: noteScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.copy, size: 16),
                                    label: const Text('Copy'),
                                    onPressed: () async {
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      AppHaptics.selectionClick();
                                      await Clipboard.setData(
                                          ClipboardData(text: _aiSummary!));
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Summary copied to clipboard'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Append'),
                                    onPressed: () async {
                                      AppHaptics.mediumImpact();
                                      final currentLength =
                                          _quillController.document.length;
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
                            ],
                          ),
                        ),
                      ),
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

class RoundedImageEmbedBuilder extends EmbedBuilder {
  const RoundedImageEmbedBuilder();

  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final node = embedContext.node;
    final controller = embedContext.controller;

    final imageUrl = node.value.data;
    final isUrl = imageUrl.startsWith('http');
    final file = isUrl ? null : File(imageUrl);

    Widget imageWidget = isUrl
        ? Image.network(
            imageUrl,
            cacheWidth: 1080,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(
                child: Icon(Icons.broken_image_outlined, size: 36),
              ),
            ),
          )
        : Image.file(
            file!,
            cacheWidth: 1080,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(
                child: Icon(Icons.broken_image_outlined, size: 36),
              ),
            ),
          );

    return GestureDetector(
      onTap: () {
        // View Full Image
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _FullScreenImageViewer(
              imageProvider: isUrl
                  ? NetworkImage(imageUrl)
                  : FileImage(file!) as ImageProvider,
            ),
          ),
        );
      },
      onLongPress: () {
        if (!embedContext.readOnly) {
          AppHaptics.mediumImpact();
          if (context.mounted) {
            _showImageActions(context, controller, node, imageUrl, isUrl, file);
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        width: double.infinity, // Mobile friendly: use full width
        height: 200,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppLayout.radiusL),
          child: imageWidget,
        ),
      ),
    );
  }

  void _showImageActions(
      BuildContext context,
      QuillController controller,
      Embed node,
      String imageUrl,
      bool isUrl,
      File? file) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.fullscreen),
                title: const Text('View Full Image'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _FullScreenImageViewer(
                        imageProvider: isUrl
                            ? NetworkImage(imageUrl)
                            : FileImage(file!) as ImageProvider,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error),
                title: Text('Remove Image',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () {
                  final offset = node.documentOffset;
                  controller.replaceText(offset, 1, '', null);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final ImageProvider imageProvider;
  const _FullScreenImageViewer({required this.imageProvider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: InteractiveViewer(
        child: Center(
          child: Image(image: imageProvider),
        ),
      ),
    );
  }
}

class TableCellFocusNotification extends Notification {
  final bool isFocused;
  const TableCellFocusNotification(this.isFocused);
}

class TableEmbedBuilder extends EmbedBuilder {
  const TableEmbedBuilder();

  @override
  String get key => TableBlockEmbed.tableType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final node = embedContext.node;
    final controller = embedContext.controller;
    final readOnly = embedContext.readOnly;

    return TableWidget(
      node: node,
      rawData: node.value.data,
      controller: controller,
      readOnly: readOnly,
    );
  }
}

class TableWidget extends StatefulWidget {
  final Embed node;
  final String rawData;
  final QuillController controller;
  final bool readOnly;

  const TableWidget({
    super.key,
    required this.node,
    required this.rawData,
    required this.controller,
    required this.readOnly,
  });

  @override
  State<TableWidget> createState() => _TableWidgetState();
}

class _TableWidgetState extends State<TableWidget> {
  List<List<String>> _cells = [];
  List<List<TextEditingController>> _controllers = [];
  List<List<FocusNode>> _focusNodes = [];
  Timer? _debounce;

  static String _cleanText(String text) {
    return text
        .replaceAll('\uFFFC', '')
        .replaceAll('\uFFFD', '')
        .replaceAll('\uFEFF', '');
  }

  @override
  void initState() {
    super.initState();
    _parseData();
  }

  void _parseData() {
    try {
      final List<dynamic> outer = jsonDecode(widget.rawData);
      _cells = outer
          .map((r) => (r as List).map((c) => _cleanText(c.toString())).toList())
          .toList();
    } catch (e) {
      _cells = [
        ['Header 1', 'Header 2'],
        ['Cell 1', 'Cell 2']
      ];
    }
    _initControllers();
  }

  void _initControllers() {
    for (final row in _controllers) {
      for (final controller in row) {
        controller.dispose();
      }
    }
    for (final row in _focusNodes) {
      for (final node in row) {
        node.dispose();
      }
    }
    _controllers = _cells
        .map((row) => row
            .map((cellText) => TextEditingController(text: _cleanText(cellText)))
            .toList())
        .toList();
    _focusNodes = _cells
        .map((row) => row.map((_) {
              final node = FocusNode();
              node.addListener(() {
                if (!mounted) return;
                debugPrint("TABLE_CELL: node.hasFocus = ${node.hasFocus}");
                if (node.hasFocus) {
                  const TableCellFocusNotification(true).dispatch(context);
                } else {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final anyFocused =
                        _focusNodes.any((r) => r.any((n) => n.hasFocus));
                    debugPrint("TABLE_CELL: anyFocused = $anyFocused");
                    if (!anyFocused) {
                      const TableCellFocusNotification(false)
                          .dispatch(context);
                    }
                  });
                }
              });
              return node;
            }).toList())
        .toList();
  }

  @override
  void didUpdateWidget(covariant TableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawData != widget.rawData) {
      try {
        final List<dynamic> outer = jsonDecode(widget.rawData);
        final newCells = outer
            .map((r) => (r as List).map((c) => _cleanText(c.toString())).toList())
            .toList();
        if (!_areCellsEqual(_cells, newCells)) {
          _cells = newCells;
          _initControllers();
        }
      } catch (_) {}
    }
  }

  bool _areCellsEqual(List<List<String>> a, List<List<String>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].length != b[i].length) return false;
      for (int j = 0; j < a[i].length; j++) {
        if (a[i][j] != b[i][j]) return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final row in _controllers) {
      for (final controller in row) {
        controller.dispose();
      }
    }
    for (final row in _focusNodes) {
      for (final node in row) {
        node.dispose();
      }
    }
    super.dispose();
  }

  void _onCellChanged(int rowIndex, int colIndex, String text) {
    final cleaned = _cleanText(text);
    if (cleaned != text) {
      final controller = _controllers[rowIndex][colIndex];
      final currentSelection = controller.selection;
      final newOffset =
          currentSelection.baseOffset.clamp(0, cleaned.length);
      controller.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: newOffset),
      );
    }
    _cells[rowIndex][colIndex] = cleaned;
    _triggerSave();
  }

  void _triggerSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final cleanCells = _cells
          .map((r) => r.map((c) => _cleanText(c)).toList())
          .toList();
      final jsonStr = jsonEncode(cleanCells);
      final offset = widget.node.offset;
      widget.controller.replaceText(
        offset,
        1,
        TableBlockEmbed(jsonStr),
        null,
      );
    });
  }

  void _addRow() {
    setState(() {
      final colCount = _cells[0].length;
      _cells.add(List.generate(colCount, (_) => 'Cell'));
      _initControllers();
    });
    _triggerSave();
  }

  void _removeRow() {
    if (_cells.length <= 1) return;
    setState(() {
      _cells.removeLast();
      _initControllers();
    });
    _triggerSave();
  }

  void _addColumn() {
    setState(() {
      for (int i = 0; i < _cells.length; i++) {
        _cells[i].add(i == 0 ? 'Header ${_cells[i].length + 1}' : 'Cell');
      }
      _initControllers();
    });
    _triggerSave();
  }

  void _removeColumn() {
    if (_cells[0].length <= 1) return;
    setState(() {
      for (int i = 0; i < _cells.length; i++) {
        _cells[i].removeLast();
      }
      _initControllers();
    });
    _triggerSave();
  }

  Widget _buildTableStructureActionIcon({
    required IconData structureIcon,
    required IconData actionIcon,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(structureIcon, size: 20),
        Positioned(
          right: -5,
          bottom: -5,
          child: Icon(actionIcon, size: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);

    return TapRegion(
      onTapOutside: (event) {
        debugPrint("TABLE_CELL: onTapOutside triggered");
        for (final row in _focusNodes) {
          for (final node in row) {
            if (node.hasFocus) {
              debugPrint("TABLE_CELL: unfocusing node");
              node.unfocus();
            }
          }
        }
      },
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
                border: Border.all(color: borderColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: Table(
                border: TableBorder.symmetric(
                  inside: BorderSide(color: borderColor),
                ),
                children: List.generate(_cells.length, (rIndex) {
                  final isHeader = rIndex == 0;
                  return TableRow(
                    decoration: BoxDecoration(
                      color: isHeader
                          ? theme.colorScheme.surfaceContainerHigh
                          : (rIndex % 2 == 1
                              ? theme.colorScheme.surface
                              : theme.colorScheme.surfaceContainerLowest),
                    ),
                    children: List.generate(_cells[rIndex].length, (cIndex) {
                      return TableCell(
                        verticalAlignment: TableCellVerticalAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          child: TextField(
                            controller: _controllers[rIndex][cIndex],
                            focusNode: _focusNodes[rIndex][cIndex],
                            readOnly: widget.readOnly,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 13,
                              fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              fillColor: Colors.transparent,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            ),
                            onChanged: (text) => _onCellChanged(rIndex, cIndex, text),
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
            if (!widget.readOnly)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppLayout.radiusL),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: _buildTableStructureActionIcon(
                              structureIcon: Icons.table_rows_outlined,
                              actionIcon: Icons.add_rounded,
                            ),
                            tooltip: 'Add Row',
                            onPressed: _cells.length < 20 ? _addRow : null,
                          ),
                          IconButton(
                            icon: _buildTableStructureActionIcon(
                              structureIcon: Icons.table_rows_outlined,
                              actionIcon: Icons.remove_rounded,
                            ),
                            tooltip: 'Remove Row',
                            onPressed: _cells.length > 1 ? _removeRow : null,
                          ),
                          const SizedBox(width: AppLayout.spaceS),
                          IconButton(
                            icon: _buildTableStructureActionIcon(
                              structureIcon: Icons.view_column_outlined,
                              actionIcon: Icons.add_rounded,
                            ),
                            tooltip: 'Add Column',
                            onPressed: _cells[0].length < 10 ? _addColumn : null,
                          ),
                          IconButton(
                            icon: _buildTableStructureActionIcon(
                              structureIcon: Icons.view_column_outlined,
                              actionIcon: Icons.remove_rounded,
                            ),
                            tooltip: 'Remove Column',
                            onPressed: _cells[0].length > 1 ? _removeColumn : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
