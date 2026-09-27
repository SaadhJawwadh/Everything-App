import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/app_haptics.dart';
import '../../core/theme/app_layout.dart';
import '../../features/notes/data/note_repository.dart';
import '../../providers/note_provider.dart';
import '../../utils/widget_helper.dart';

/// Modal bottom sheet to quickly append a checklist item to an active or default note
/// directly from the Android Home Screen AppWidget or in-app triggers.
class QuickAddTodoSheet extends StatefulWidget {
  final String activeNoteId;

  const QuickAddTodoSheet({super.key, required this.activeNoteId});

  static Future<void> show(BuildContext context, String activeNoteId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickAddTodoSheet(activeNoteId: activeNoteId),
    );
  }

  @override
  State<QuickAddTodoSheet> createState() => _QuickAddTodoSheetState();
}

class _QuickAddTodoSheetState extends State<QuickAddTodoSheet> {
  final TextEditingController _textController = TextEditingController();
  String _targetTitle = 'Quick Add Task';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadNoteTitle();
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
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);

    AppHaptics.mediumImpact();
    Navigator.of(context).pop();

    await WidgetHelper.quickAddTask(
      noteId: widget.activeNoteId == 'ALL_NOTES' ? null : widget.activeNoteId,
      taskText: text,
    );

    unawaited(noteProvider.refreshNotes());
    messenger.showSnackBar(
      SnackBar(
        content: Text('Task added: $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: AppLayout.spaceL,
        right: AppLayout.spaceL,
        top: AppLayout.spaceL,
        bottom: bottomInset + AppLayout.spaceL,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppLayout.radiusXXL),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(AppLayout.radiusS),
              ),
            ),
          ),
          const SizedBox(height: AppLayout.spaceM),
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
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'What needs to be done?',
              filled: true,
              fillColor: colorScheme.surfaceContainerLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppLayout.spaceM,
                vertical: AppLayout.spaceM,
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppLayout.spaceM),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AppLayout.spaceS),
              FilledButton.icon(
                onPressed: _submit,
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
