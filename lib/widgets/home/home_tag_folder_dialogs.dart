import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/app_bottom_sheet.dart';
import '../../core/ui/app_dialog.dart';
import '../../data/note_templates.dart';
import '../../features/notes/data/note_repository.dart';
import '../../features/notes/presentation/screens/note_editor_screen.dart';
import '../../features/notes/providers/note_provider.dart';
import '../../l10n/app_localizations.dart';

class HomeTagFolderDialogs {
  HomeTagFolderDialogs._();

  static Future<void> bulkMoveToFolder({
    required BuildContext context,
    required Future<void> Function() onRefreshNotes,
  }) async {
    final noteProvider = context.read<NoteProvider>();
    if (noteProvider.selectedNoteIds.isEmpty) return;

    final allFolders = await NoteRepository.instance.getAllFolders();
    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        title: l10n?.filterByFolder ?? 'Move to folder',
        confirmLabel: l10n?.save ?? 'Create & Move',
        onConfirm: () {
          final v = controller.text.trim();
          if (v.isNotEmpty) Navigator.pop(ctx, v);
        },
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: const Icon(Icons.notes_outlined),
                        title: Text(l10n?.allNotes ?? 'All Notes'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppLayout.radiusM),
                        ),
                        onTap: () {
                          Navigator.pop(ctx, 'All Notes');
                        },
                      ),
                    ),
                    ...allFolders.map((f) => Material(
                          color: Colors.transparent,
                          child: ListTile(
                            leading: const Icon(Icons.folder_outlined),
                            title: Text(f),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppLayout.radiusM),
                            ),
                            onTap: () {
                              Navigator.pop(ctx, f);
                            },
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: AppLayout.spaceS),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'New folder name',
                  prefixIcon: const Icon(Icons.create_new_folder_outlined),
                  filled: false,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppLayout.radiusM),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppLayout.radiusM),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppLayout.radiusM),
                    borderSide: BorderSide(
                      color: Theme.of(ctx).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (chosen == null || !context.mounted) return;
    final ids = noteProvider.selectedNoteIds.toList();
    await NoteRepository.instance.bulkMoveNotesToFolder(ids, chosen);
    noteProvider.clearSelection();
    await onRefreshNotes();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(chosen == 'All Notes'
            ? '${ids.length} note${ids.length == 1 ? '' : 's'} removed from folder'
            : '${ids.length} note${ids.length == 1 ? '' : 's'} moved to "$chosen"'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  static Future<void> bulkTag(BuildContext context) async {
    final noteProvider = context.read<NoteProvider>();
    final availableTags = noteProvider.allTags
        .where((t) => t != 'All' && t != 'Archived' && t != 'Trash')
        .toList();
    if (availableTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tags available. Create a tag first.')),
      );
      return;
    }

    final selectedNewTag = await showDialog<String>(
      context: context,
      builder: (context) => AppDialog(
        title: 'Add Tag to Selected',
        showConfirmButton: false,
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableTags.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(availableTags[index]),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
              ),
              onTap: () => Navigator.pop(context, availableTags[index]),
            ),
          ),
        ),
      ),
    );

    if (selectedNewTag != null) await noteProvider.bulkTag([selectedNewTag]);
  }

  static Future<void> editTag(BuildContext context, String tag) async {
    final controller = TextEditingController(text: tag);
    int selectedColor = context.read<NoteProvider>().tagColors[tag] ?? 0;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AppDialog(
          title: 'Edit Tag',
          confirmLabel: 'Save',
          onConfirm: () async {
            final newName = controller.text.trim();
            final noteProvider = context.read<NoteProvider>();
            if (newName.isNotEmpty) {
              if (newName != tag) await NoteRepository.instance.renameTag(tag, newName);
              if (selectedColor != (noteProvider.tagColors[tag] ?? 0)) {
                await NoteRepository.instance.setTagColor(newName, selectedColor);
              }
              if (!context.mounted) return;
              Navigator.pop(context);
              await noteProvider.refreshNotes();
              if (noteProvider.selectedTag == tag) noteProvider.setTag(newName);
            }
          },
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
                  return Semantics(
                    button: true,
                    label: isSystem ? 'Random color' : 'Color swatch',
                    selected: isSelected,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                      onTap: () {
                        if (isSystem) {
                          final nonZeroColors = AppTheme.noteColors
                              .where((color) => color.toARGB32() != 0)
                              .toList();
                          final randomColor = (nonZeroColors..shuffle()).first;
                          setDialogState(() => selectedColor = randomColor.toARGB32());
                        } else {
                          setDialogState(() => selectedColor = c.toARGB32());
                        }
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        child: Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSystem ? Theme.of(context).colorScheme.surface : c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outlineVariant,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: isSystem
                                ? const Icon(Icons.shuffle, size: 16)
                                : (isSelected
                                    ? Icon(
                                        Icons.check,
                                        size: 16,
                                        color: c.computeLuminance() > 0.5
                                            ? Colors.black
                                            : Colors.white,
                                      )
                                    : null),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }),
    );
  }

  static Future<void> deleteTag(BuildContext context, String tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: 'Delete Tag?',
        content: Text(
          'Are you sure you want to delete "$tag"? This will remove the tag from all notes.',
        ),
        cancelLabel: 'Cancel',
        confirmLabel: 'Delete',
        isDestructive: true,
        onCancel: () => Navigator.pop(context, false),
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (confirmed == true) {
      await NoteRepository.instance.deleteTag(tag);
      if (!context.mounted) return;
      final noteProvider = context.read<NoteProvider>();
      if (noteProvider.selectedTag == tag) noteProvider.setTag('All');
      await noteProvider.refreshNotes();
    }
  }

  static void showTagOptions(BuildContext context, String tag) {
    if (tag == 'All' || tag == 'Archived' || tag == 'Trash') return;
    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit Tag'),
            onTap: () {
              Navigator.pop(context);
              editTag(context, tag);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Delete Tag',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () {
              Navigator.pop(context);
              deleteTag(context, tag);
            },
          ),
        ],
      ),
    );
  }

  static void showTemplateSheet({
    required BuildContext context,
    required Future<void> Function({bool scrollOnModified}) onRefreshNotes,
  }) {
    final l10n = AppLocalizations.of(context);
    AppBottomSheet.show(
      context: context,
      title: l10n?.startFromTemplate ?? 'Start from a template',
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...NoteTemplate.all(l10n).map(
              (t) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    t.icon,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(t.name),
                subtitle: Text(t.description),
                onTap: () async {
                  Navigator.pop(context);
                  final noteProvider = Provider.of<NoteProvider>(context, listen: false);
                  final returned = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteEditorScreen(
                        templateTitle: t.title,
                        templateContent: t.contentDeltaJson,
                        initialFolder: noteProvider.selectedFolder,
                      ),
                    ),
                  );
                  if (returned == true) await onRefreshNotes(scrollOnModified: true);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
