import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:note_taking_app/core/services/app_haptics.dart';
import 'package:note_taking_app/features/notes/data/note_repository.dart';
import 'package:note_taking_app/features/notes/providers/note_provider.dart';
import 'package:note_taking_app/core/theme/app_theme.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:note_taking_app/core/theme/app_layout.dart';
import 'package:note_taking_app/core/ui/app_dialog.dart';
import 'package:note_taking_app/core/ui/expressive_sliver_app_bar.dart';
import 'package:note_taking_app/core/ui/expressive_shape_morph_indicator.dart';

class ManageTagsScreen extends StatefulWidget {
  const ManageTagsScreen({super.key});

  @override
  State<ManageTagsScreen> createState() => _ManageTagsScreenState();
}

class _ManageTagsScreenState extends State<ManageTagsScreen> {
  List<String> _tags = [];
  Map<String, int> _tagColors = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    setState(() => _isLoading = true);
    final tags = await NoteRepository.instance.getAllTags();
    final col = await NoteRepository.instance.getAllTagColors();
    setState(() {
      _tags = tags;
      _tagColors = col;
      _isLoading = false;
    });
  }

  Future<void> _editTag(String tag) async {
    final controller = TextEditingController(text: tag);
    int selectedColor = _tagColors[tag] ?? 0;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) {
        return AppDialog(
          title: 'Edit Tag',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Tag Name'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text('Tag Color'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: AppTheme.noteColors.map((c) {
                  final bool isSystem = c.toARGB32() == 0;
                  final bool isSelected = !isSystem && selectedColor == c.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      AppHaptics.selectionClick();
                      if (isSystem) {
                        final nonZeroColors = AppTheme.noteColors.where((color) => color.toARGB32() != 0).toList();
                        final randomColor = (nonZeroColors..shuffle()).first;
                        setDialogState(() => selectedColor = randomColor.toARGB32());
                      } else {
                        setDialogState(() => selectedColor = c.toARGB32());
                      }
                    },
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: AnimatedContainer(
                          duration: AppLayout.animShort,
                          width: isSelected ? 36 : 32,
                          height: isSelected ? 36 : 32,
                          decoration: BoxDecoration(
                            color: isSystem
                                ? Theme.of(dialogContext).colorScheme.surfaceContainerHigh
                                : c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(dialogContext).colorScheme.primary
                                  : Theme.of(dialogContext).colorScheme.outlineVariant,
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
                                      size: 18,
                                      color: c.computeLuminance() > 0.5
                                          ? Colors.black
                                          : Colors.white)
                                  : null),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          cancelLabel: 'Cancel',
          confirmLabel: 'Save',
          onCancel: () => Navigator.pop(dialogContext),
          onConfirm: () async {
            final newName = controller.text.trim();
            if (newName.isNotEmpty) {
              if (newName != tag) {
                await NoteRepository.instance.renameTag(tag, newName);
              }
              if (selectedColor != (_tagColors[tag] ?? 0)) {
                await NoteRepository.instance.setTagColor(newName, selectedColor);
              }
              AppHaptics.mediumImpact();
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              await _loadTags();
              if (mounted) {
                await context.read<NoteProvider>().handleTagRenamed(tag, newName);
              }
            }
          },
        );
      }),
    );
  }

  Future<void> _deleteTag(String tag) async {
    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: 'Delete Tag?',
      message: 'Are you sure you want to delete "$tag"? This will remove the tag from all notes.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true) {
      AppHaptics.mediumImpact();
      await NoteRepository.instance.deleteTag(tag);
      await _loadTags();
      if (mounted) {
        await context.read<NoteProvider>().refreshNotes();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: AnimationLimiter(
        child: CustomScrollView(
          slivers: [
            const ExpressiveSliverAppBar(
              titleText: 'Manage Tags',
              showBackButton: true,
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: ExpressiveShapeMorphIndicator(size: 44)),
              )
            else if (_tags.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No tags found',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tag = _tags[index];
                      final tagColorValue = _tagColors[tag];
                      final tagColor =
                          tagColorValue != null && tagColorValue != 0
                              ? Color(tagColorValue)
                              : null;

                      return AnimationConfiguration.staggeredList(
                        position: index.clamp(0, 8),
                        duration: AppLayout.animShort,
                        child: SlideAnimation(
                          verticalOffset: AppLayout.shouldReduceMotion(context) ? 0.0 : 16.0,
                          child: FadeInAnimation(
                            child: Semantics(
                              label: 'Tag: $tag',
                              child: Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 8),
                                color: colorScheme.surfaceContainerLow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppLayout.radiusL),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                                    width: 1.0,
                                  ),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: tagColor ?? colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  title: Text(tag),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: 'Edit',
                                        onPressed: () => _editTag(tag),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        tooltip: 'Delete',
                                        onPressed: () => _deleteTag(tag),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: _tags.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
