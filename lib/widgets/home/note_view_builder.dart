import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import '../../data/note_model.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import '../../providers/note_provider.dart';
import 'package:note_taking_app/features/notes/presentation/screens/note_editor_screen.dart';
import '../../screens/home_screen.dart'; // For NoteCard for now, maybe move it too
import '../../features/notes/data/note_repository.dart';
import '../../core/theme/app_layout.dart';
import '../skeleton_card.dart';

class NoteViewBuilder extends StatelessWidget {
  final VoidCallback onRefresh;
  final Function(Note, VoidCallback) onNoteTap;
  final Function(Note) onNoteLongPress;

  const NoteViewBuilder({
    super.key,
    required this.onRefresh,
    required this.onNoteTap,
    required this.onNoteLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final noteProvider = context.watch<NoteProvider>();
    final settings = context.watch<SettingsProvider>();

    if (noteProvider.isLoading) {
      // Skeleton cards instead of a bare spinner — mirrors the grid the
      // content will land in.
      final skeletonColumns =
          (MediaQuery.sizeOf(context).width / 220).floor().clamp(2, 4);
      const skeletonHeights = [150.0, 190.0, 120.0, 170.0, 140.0, 200.0];
      return SliverMasonryGrid.count(
        crossAxisCount: skeletonColumns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childCount: skeletonHeights.length,
        itemBuilder: (context, index) =>
            SkeletonCard(height: skeletonHeights[index]),
      );
    }

    if (noteProvider.filteredNotes.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          key: const ValueKey('empty'),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.note_alt_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outlineVariant),
              const SizedBox(height: 16),
              Text(
                'No notes here yet',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap + to create one',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteEditorScreen(
                        initialFolder: noteProvider.selectedFolder,
                      ),
                    ),
                  ).then((_) => onRefresh());
                },
                icon: const Icon(Icons.add),
                label: const Text('Create My First Note'),
              ),
              ],
              ),
              ),
              );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, AppLayout.fabBottomPadding),
      sliver: _buildSliverLayout(context, settings, noteProvider),
    );
  }

  Widget _buildSliverLayout(BuildContext context, SettingsProvider settings, NoteProvider noteProvider) {
    if (settings.noteViewMode == NoteViewMode.list) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final note = noteProvider.filteredNotes[index];
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 220),
              child: SlideAnimation(
                verticalOffset: 24.0,
                child: FadeInAnimation(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildDismissibleNoteCard(context, note, onRefresh, noteProvider),
                  ),
                ),
              ),
            );
          },
          childCount: noteProvider.filteredNotes.length,
        ),
      );
    } else {
      // Grid (Masonry Grid) — column count adapts to width so tablets and
      // foldables get 3-4 columns instead of two stretched ones.
      final width = MediaQuery.sizeOf(context).width;
      final columnCount = (width / 220).floor().clamp(2, 4);
      return SliverMasonryGrid.count(
        crossAxisCount: columnCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childCount: noteProvider.filteredNotes.length,
        itemBuilder: (context, index) {
          final note = noteProvider.filteredNotes[index];
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 220),
            columnCount: columnCount,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: _buildOpenContainer(context, note, onRefresh, noteProvider),
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildDismissibleNoteCard(BuildContext context, Note note, VoidCallback refresh, NoteProvider noteProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.horizontal,
      background: Container(
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppLayout.radiusL),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.archive, color: colorScheme.onPrimaryContainer),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppLayout.radiusL),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete, color: colorScheme.onErrorContainer),
      ),
      onDismissed: (direction) async {
        if (direction == DismissDirection.endToStart) {
          await NoteRepository.instance.softDeleteNote(note.id);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              content: const Text('Note moved to trash'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  await NoteRepository.instance.restoreNote(note.id);
                  refresh();
                },
              ),
            ),
          );
        } else {
          final updated = note.copyWith(
            isArchived: true,
            dateModified: DateTime.now(),
          );
          await NoteRepository.instance.updateNote(updated);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              content: const Text('Note archived'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  final reverted = note.copyWith(
                    isArchived: false,
                    dateModified: DateTime.now(),
                  );
                  await NoteRepository.instance.updateNote(reverted);
                  refresh();
                },
              ),
            ),
          );
        }
        refresh();
      },
      child: _buildOpenContainer(context, note, refresh, noteProvider),
    );
  }

  Widget _buildOpenContainer(BuildContext context, Note note, VoidCallback refresh, NoteProvider noteProvider) {
    return OpenContainer<bool>(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 300),
      openBuilder: (context, _) => NoteEditorScreen(note: note),
      closedElevation: 0,
      openElevation: 0,
      closedColor: Colors.transparent,
      openColor: Theme.of(context).colorScheme.surface,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppLayout.radiusL)),
      onClosed: (returned) async {
        refresh();
      },
      closedBuilder: (context, openContainer) {
        return NoteCard(
          note: note,
          onTap: () => onNoteTap(note, openContainer),
          isSelected: noteProvider.selectedNoteIds.contains(note.id),
          tagColors: noteProvider.tagColors,
          onLongPress: () => onNoteLongPress(note),
        );
      },
    );
  }
}
