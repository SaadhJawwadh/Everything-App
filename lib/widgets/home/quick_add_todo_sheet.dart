import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/app_haptics.dart';
import '../../core/theme/app_layout.dart';
import '../../core/ui/app_bottom_sheet.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../features/notes/data/note_repository.dart';
import 'package:note_taking_app/features/notes/providers/note_provider.dart';
import '../../utils/widget_helper.dart';

/// Modal bottom sheet to quickly append a checklist item to an active or default note
/// directly from the Android Home Screen AppWidget or in-app triggers.
class QuickAddTodoSheet extends StatefulWidget {
  final String activeNoteId;
  final String? initialNoteTitle;

  const QuickAddTodoSheet({
    super.key,
    required this.activeNoteId,
    this.initialNoteTitle,
  });

  static Future<void> show(
    BuildContext context,
    String activeNoteId, {
    String? initialNoteTitle,
  }) {
    return AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      padding: EdgeInsets.zero,
      child: QuickAddTodoSheet(
        activeNoteId: activeNoteId,
        initialNoteTitle: initialNoteTitle,
      ),
    );
  }

  @override
  State<QuickAddTodoSheet> createState() => _QuickAddTodoSheetState();
}

class _QuickAddTodoSheetState extends State<QuickAddTodoSheet> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late String _targetTitle;
  bool _isSubmitting = false;
  bool _hasText = false;
  String? _addedConfirmation;

  @override
  void initState() {
    super.initState();
    final initialTitle = widget.initialNoteTitle?.trim() ?? '';
    _targetTitle =
        initialTitle.isNotEmpty ? 'Add Task: $initialTitle' : 'Quick Add Task';
    _textController.addListener(_onTextChanged);
    if (initialTitle.isEmpty) {
      _loadNoteTitle();
    }
  }

  void _onTextChanged() {
    final nextHasText = _textController.text.trim().isNotEmpty;
    if (nextHasText != _hasText && mounted) {
      setState(() => _hasText = nextHasText);
    }
  }

  Future<void> _loadNoteTitle() async {
    if (widget.activeNoteId != 'ALL_NOTES' && widget.activeNoteId.isNotEmpty) {
      final note = await NoteRepository.instance.readNote(widget.activeNoteId);
      if (note != null && note.title.trim().isNotEmpty && mounted) {
        setState(() {
          _targetTitle = 'Add Task: ${note.title.trim()}';
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit({bool keepOpen = false}) async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final successBar = AppSnackBar.build(
      context,
      message: 'Task added: $text',
      type: SnackBarType.success,
      duration: const Duration(seconds: 2),
    );

    AppHaptics.mediumImpact();

    if (!keepOpen) {
      Navigator.of(context).pop();
    }

    await WidgetHelper.quickAddTask(
      noteId: widget.activeNoteId == 'ALL_NOTES' ? null : widget.activeNoteId,
      taskText: text,
    );

    unawaited(noteProvider.refreshNotes());

    if (keepOpen) {
      if (mounted) {
        _textController.clear();
        setState(() {
          _isSubmitting = false;
          _hasText = false;
          _addedConfirmation = 'Added: $text';
        });
        _focusNode.requestFocus();
      }
      return;
    }

    messenger
      ..clearSnackBars()
      ..showSnackBar(successBar);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final canSubmit = _hasText && !_isSubmitting;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppLayout.spaceL,
        AppLayout.spaceS,
        AppLayout.spaceL,
        bottomInset + AppLayout.spaceL,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.task_alt_rounded,
                color: colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: AppLayout.spaceS),
              Expanded(
                child: Text(
                  _targetTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppLayout.spaceM),
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'What needs to be done?',
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
                borderSide: BorderSide(
                  color: colorScheme.primary,
                  width: 1.5,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppLayout.spaceM,
                vertical: AppLayout.spaceM,
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_addedConfirmation != null) ...[
            const SizedBox(height: AppLayout.spaceS),
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: AppLayout.spaceXS),
                Expanded(
                  child: Text(
                    _addedConfirmation!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppLayout.spaceM),
          Row(
            children: [
              TextButton(
                onPressed: canSubmit ? () => _submit(keepOpen: true) : null,
                child: const Text('+ Add another'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AppLayout.spaceS),
              FilledButton.icon(
                onPressed: canSubmit ? () => _submit() : null,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Task'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
