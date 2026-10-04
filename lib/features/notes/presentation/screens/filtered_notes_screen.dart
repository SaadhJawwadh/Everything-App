import 'package:flutter/material.dart';
import 'package:note_taking_app/core/services/app_haptics.dart';
import 'package:provider/provider.dart';
import 'package:note_taking_app/features/notes/data/note_repository.dart';
import 'package:note_taking_app/data/note_model.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:animations/animations.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:note_taking_app/screens/home_screen.dart';
import 'package:note_taking_app/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:note_taking_app/core/theme/app_layout.dart';
import 'package:note_taking_app/core/ui/expressive_sliver_app_bar.dart';
import 'package:note_taking_app/core/ui/expressive_floating_toolbar.dart';
import 'package:note_taking_app/core/ui/app_card.dart';
import 'package:note_taking_app/core/ui/expressive_shape_morph_indicator.dart';

enum FilterType { archived, trash }

class FilteredNotesScreen extends StatefulWidget {
  final FilterType filterType;

  const FilteredNotesScreen({super.key, required this.filterType});

  @override
  State<FilteredNotesScreen> createState() => _FilteredNotesScreenState();
}

class _FilteredNotesScreenState extends State<FilteredNotesScreen> {
  List<Note> displayedNotes = [];
  bool isLoading = true;
  Map<String, int> _tagColors = {};
  final Set<String> _selectedNoteIds = {};

  bool get _isSelectionMode => _selectedNoteIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    });
    refreshNotes();
  }

  void _toggleSelection(String id) {
    AppHaptics.selectionClick();
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() {
      if (_selectedNoteIds.contains(id)) {
        _selectedNoteIds.remove(id);
      } else {
        _selectedNoteIds.add(id);
      }
    });
  }

  void _clearSelection() {
    AppHaptics.selectionClick();
    setState(() {
      _selectedNoteIds.clear();
    });
  }

  void _selectAll() {
    AppHaptics.selectionClick();
    setState(() {
      _selectedNoteIds.clear();
      for (final n in displayedNotes) {
        _selectedNoteIds.add(n.id);
      }
    });
  }

  Future<void> _bulkRestore() async {
    AppHaptics.mediumImpact();
    final count = _selectedNoteIds.length;
    final idsToRestore = List<String>.from(_selectedNoteIds);
    for (final id in idsToRestore) {
      await NoteRepository.instance.restoreNote(id);
    }
    setState(() => _selectedNoteIds.clear());
    await refreshNotes();
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored $count note${count == 1 ? "" : "s"}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _bulkDeletePermanently() async {
    AppHaptics.mediumImpact();
    final count = _selectedNoteIds.length;
    final idsToDelete = List<String>.from(_selectedNoteIds);

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count Note${count == 1 ? "" : "s"} Permanently?'),
        content: const Text('These notes will be removed forever and cannot be recovered.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final id in idsToDelete) {
        await NoteRepository.instance.deleteNote(id);
      }
      setState(() => _selectedNoteIds.clear());
      await refreshNotes();
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permanently deleted $count note${count == 1 ? "" : "s"}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _bulkUnarchive() async {
    AppHaptics.mediumImpact();
    final count = _selectedNoteIds.length;
    final idsToUnarchive = List<String>.from(_selectedNoteIds);
    for (final id in idsToUnarchive) {
      await NoteRepository.instance.archiveNote(id, false);
    }
    setState(() => _selectedNoteIds.clear());
    await refreshNotes();
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unarchived $count note${count == 1 ? "" : "s"}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _bulkMoveToTrash() async {
    AppHaptics.mediumImpact();
    final count = _selectedNoteIds.length;
    final idsToTrash = List<String>.from(_selectedNoteIds);
    for (final id in idsToTrash) {
      await NoteRepository.instance.softDeleteNote(id);
    }
    setState(() => _selectedNoteIds.clear());
    await refreshNotes();
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moved $count note${count == 1 ? "" : "s"} to Trash'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future refreshNotes() async {
    setState(() => isLoading = true);
    final colors = await NoteRepository.instance.getAllTagColors();
    _tagColors = colors;

    if (widget.filterType == FilterType.archived) {
      displayedNotes = await NoteRepository.instance.readAllNotes(isArchived: true);
    } else {
      displayedNotes = await NoteRepository.instance.readTrashedNotes();
    }

    displayedNotes.sort((a, b) => b.dateModified.compareTo(a.dateModified));

    setState(() => isLoading = false);
  }

  Widget _buildSelectionToolbar(BuildContext context, ColorScheme colorScheme) {
    return SafeArea(
      top: false,
      child: Center(
        child: ExpressiveFloatingToolbar(
          key: const ValueKey('filtered_notes_selection_toolbar'),
          isVibrant: true,
          mainAxisSize: MainAxisSize.min,
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          children: widget.filterType == FilterType.trash
              ? [
                  ExpressiveFloatingToolbar.labeledActionButton(
                    icon: Icons.restore_from_trash_outlined,
                    label: 'Restore',
                    color: colorScheme.primary,
                    onPressed: _bulkRestore,
                  ),
                  ExpressiveFloatingToolbar.spacer(),
                  ExpressiveFloatingToolbar.labeledActionButton(
                    icon: Icons.delete_forever_outlined,
                    label: 'Delete Forever',
                    color: colorScheme.error,
                    onPressed: _bulkDeletePermanently,
                  ),
                ]
              : [
                  ExpressiveFloatingToolbar.labeledActionButton(
                    icon: Icons.unarchive_outlined,
                    label: 'Unarchive',
                    color: colorScheme.primary,
                    onPressed: _bulkUnarchive,
                  ),
                  ExpressiveFloatingToolbar.spacer(),
                  ExpressiveFloatingToolbar.labeledActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: 'Move to Trash',
                    color: colorScheme.error,
                    onPressed: _bulkMoveToTrash,
                  ),
                ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.filterType == FilterType.archived ? 'Archived' : 'Trash';
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final allSelected = displayedNotes.isNotEmpty &&
        _selectedNoteIds.length == displayedNotes.length;

    return Consumer<SettingsProvider>(builder: (context, settings, child) {
      return PopScope(
        canPop: !_isSelectionMode,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _clearSelection();
        },
        child: Scaffold(
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  ExpressiveSliverAppBar(
                    leading: _isSelectionMode
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Clear selection',
                            onPressed: _clearSelection,
                          )
                        : null,
                    showBackButton: !_isSelectionMode,
                    titleText: _isSelectionMode ? '${_selectedNoteIds.length} selected' : title,
                    actions: _isSelectionMode
                        ? [
                            IconButton(
                              icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded),
                              tooltip: allSelected ? 'Deselect all' : 'Select all',
                              onPressed: allSelected ? _clearSelection : _selectAll,
                            ),
                          ]
                        : null,
                  ),
                  if (widget.filterType == FilterType.trash && !isLoading && !_isSelectionMode)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Builder(builder: (ctx) {
                          final isDark = Theme.of(ctx).brightness == Brightness.dark;
                          return AppCard.tonal(
                            color: colorScheme.errorContainer
                                .withValues(alpha: isDark ? 0.20 : 0.52),
                            borderColor: colorScheme.error
                                .withValues(alpha: isDark ? 0.35 : 0.45),
                            borderRadius: AppLayout.radiusL,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.auto_delete_outlined,
                                    size: 20,
                                    color: colorScheme.error,
                                  ),
                                ),
                                const SizedBox(width: AppLayout.spaceM),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Trash Auto-Purge Active',
                                        style: textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.error,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        settings.trashAutoPurgeDays > 0
                                            ? 'Notes in trash are automatically purged after ${settings.trashAutoPurgeDays} days.'
                                            : 'Notes in trash can be restored anytime before permanent deletion.',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  if (isLoading)
                    const SliverFillRemaining(
                      child: Center(child: ExpressiveShapeMorphIndicator(size: 44)),
                    )
                  else if (displayedNotes.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.filterType == FilterType.trash
                                  ? Icons.delete_outline
                                  : Icons.archive_outlined,
                              size: 64,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No notes in $title',
                              style: textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, AppLayout.fabBottomPadding),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final note = displayedNotes[index];
                            final isSelected = _selectedNoteIds.contains(note.id);

                            return AnimationConfiguration.staggeredList(
                              position: index,
                              duration: const Duration(milliseconds: 375),
                              child: SlideAnimation(
                                verticalOffset: 50.0,
                                child: FadeInAnimation(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: OpenContainer<bool>(
                                      transitionType: ContainerTransitionType.fade,
                                      openBuilder: (context, _) => NoteEditorScreen(note: note),
                                      closedElevation: 0,
                                      closedColor: Colors.transparent,
                                      closedShape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppLayout.radiusL),
                                      ),
                                      onClosed: (returned) async {
                                        await refreshNotes();
                                      },
                                      closedBuilder: (context, openContainer) {
                                        return NoteCard(
                                          note: note,
                                          onTap: () {
                                            if (_isSelectionMode) {
                                              _toggleSelection(note.id);
                                            } else {
                                              openContainer();
                                            }
                                          },
                                          tagColors: _tagColors,
                                          isSelected: isSelected,
                                          onLongPress: () {
                                            _toggleSelection(note.id);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: displayedNotes.length,
                        ),
                      ),
                    ),
                ],
              ),
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                left: 0,
                right: 0,
                child: AnimatedSwitcher(
                  duration: AppLayout.animDefault,
                  switchInCurve: AppLayout.curveEmphasizedDecelerate,
                  switchOutCurve: AppLayout.curveEmphasizedAccelerate,
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 1.0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    );
                  },
                  child: _isSelectionMode
                      ? _buildSelectionToolbar(context, colorScheme)
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
