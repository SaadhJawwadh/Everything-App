import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/app_haptics.dart';
import 'package:provider/provider.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import '../../providers/note_provider.dart';
import '../../features/sync/providers/p2p_sync_provider.dart';
import 'package:note_taking_app/features/sync/presentation/screens/p2p_sync_screen.dart';
import 'package:note_taking_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:note_taking_app/features/notes/presentation/screens/manage_tags_screen.dart';
import 'package:note_taking_app/features/notes/presentation/screens/filtered_notes_screen.dart';
import 'package:note_taking_app/features/notes/presentation/widgets/note_migration_sheet.dart';
import '../../core/theme/app_layout.dart';
import '../../core/ui/app_chip.dart';
import '../../core/ui/app_dialog.dart';
import '../../utils/app_route.dart';
import '../bouncing_widget.dart';
import 'package:note_taking_app/l10n/app_localizations.dart';

class HomeAppBar extends StatefulWidget implements PreferredSizeWidget {
  final VoidCallback onClearSelection;
  final VoidCallback onBulkArchive;
  final VoidCallback onBulkDelete;
  final VoidCallback onBulkTag;
  final VoidCallback onBulkMoveToFolder;
  final VoidCallback onCycleViewMode;
  final VoidCallback onRefresh;

  static final ValueNotifier<bool> searchRequestedNotifier = ValueNotifier<bool>(false);

  const HomeAppBar({
    super.key,
    required this.onClearSelection,
    required this.onBulkArchive,
    required this.onBulkDelete,
    required this.onBulkTag,
    required this.onBulkMoveToFolder,
    required this.onCycleViewMode,
    required this.onRefresh,
  });

  @override
  State<HomeAppBar> createState() => _HomeAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(84);
}

class _HomeAppBarState extends State<HomeAppBar> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    HomeAppBar.searchRequestedNotifier.addListener(_handleSearchRequest);
  }

  void _handleSearchRequest() {
    if (HomeAppBar.searchRequestedNotifier.value && mounted) {
      setState(() {
        _isSearching = true;
      });
      HomeAppBar.searchRequestedNotifier.value = false;
    }
  }

  @override
  void dispose() {
    HomeAppBar.searchRequestedNotifier.removeListener(_handleSearchRequest);
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = context.watch<NoteProvider>();
    final settings = context.watch<SettingsProvider>();
    final statusBarHeight = MediaQuery.of(context).padding.top;

    final totalHeight = statusBarHeight + 72.0;

    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      primary: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: totalHeight,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        padding: EdgeInsets.only(
          top: statusBarHeight + 6,
          left: 16,
          right: 16,
          bottom: 6,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          border: null,
        ),
        child: Align(
          alignment: Alignment.center,
          child: SizedBox(
            height: 60,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.fastOutSlowIn,
              switchOutCurve: Curves.fastOutSlowIn,
              child: noteProvider.isSelectionMode
                  ? KeyedSubtree(
                      key: const ValueKey('selection_mode'),
                      child: _buildSelectionMode(context, noteProvider))
                  : _isSearching
                      ? KeyedSubtree(
                          key: const ValueKey('search_mode'),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh
                                  .withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(AppLayout.radiusMAX),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: _buildSearchMode(context),
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('normal_mode'),
                          child: _buildNormalMode(context, settings)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionMode(BuildContext context, NoteProvider noteProvider) {
    final allSelected = noteProvider.selectedNoteIds.length == noteProvider.notes.length &&
        noteProvider.notes.isNotEmpty;

    return Row(
      children: [
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Clear selection',
          onPressed: () {
            AppHaptics.selectionClick();
            widget.onClearSelection();
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${noteProvider.selectedNoteIds.length} selected',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ),
        IconButton(
          icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded),
          tooltip: allSelected ? 'Deselect all' : 'Select all',
          onPressed: () {
            AppHaptics.selectionClick();
            if (allSelected) {
              noteProvider.clearSelection();
            } else {
              noteProvider.selectAll();
            }
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildSearchMode(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Close search',
          onPressed: () {
            context.read<NoteProvider>().setSearchQuery('');
            setState(() {
              _isSearching = false;
              _searchController.clear();
            });
          },
        ),
        Expanded(
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: theme.textTheme.titleMedium,
            enableInteractiveSelection: true,
            textCapitalization: TextCapitalization.sentences,
            autocorrect: true,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)?.searchNotes ?? 'Search notes, settings, tags...',
              hintStyle: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              filled: false,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            onChanged: (val) {
              _debounceTimer?.cancel();
              _debounceTimer = Timer(const Duration(milliseconds: 150), () {
                if (mounted) {
                  context.read<NoteProvider>().setSearchQuery(val);
                }
              });
              setState(() {});
            },
            onSubmitted: (query) {
              FocusScope.of(context).unfocus();
            },
          ),
        ),
        if (_searchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Clear query',
            onPressed: () {
              _searchController.clear();
              context.read<NoteProvider>().setSearchQuery('');
              setState(() {});
            },
          ),
        IconButton(
          icon: const Icon(Icons.search_rounded),
          tooltip: 'Search',
          onPressed: () {
            FocusScope.of(context).unfocus();
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _showCreateFolderDialog(BuildContext context, NoteProvider noteProvider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Create New Folder',
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Folder name',
            prefixIcon: Icon(Icons.create_new_folder_outlined),
          ),
          onSubmitted: (v) {
            final name = v.trim();
            if (name.isNotEmpty) {
              noteProvider.createFolder(name);
              Navigator.pop(ctx);
            }
          },
        ),
        cancelLabel: 'Cancel',
        confirmLabel: 'Create',
        onCancel: () => Navigator.pop(ctx),
        onConfirm: () {
          final name = controller.text.trim();
          if (name.isNotEmpty) {
            noteProvider.createFolder(name);
            Navigator.pop(ctx);
          }
        },
      ),
    );
  }

  void _showFolderPicker(BuildContext context, NoteProvider noteProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final folders = ['Notes', 'All Notes', ...noteProvider.folders];
        final currentFolder = noteProvider.selectedFolder ?? 'Notes';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter by folder',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                      label: const Text('New Folder'),
                      onPressed: () {
                        Navigator.pop(context); // Close bottom sheet
                        _showCreateFolderDialog(context, noteProvider);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppLayout.spaceS),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ...folders.map((folder) {
                      final isSelected = folder == currentFolder;
                      final count = noteProvider.folderCounts[folder];
                      return ListTile(
                        leading: Icon(
                          folder == 'Notes'
                              ? Icons.folder_open_outlined
                              : folder == 'All Notes'
                                  ? Icons.folder_copy_outlined
                                  : Icons.folder,
                          color: isSelected ? Theme.of(context).colorScheme.primary : null,
                        ),
                        title: Text(
                          folder,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Theme.of(context).colorScheme.primary : null,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (count != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  '$count',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            if (isSelected)
                              Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
                          ],
                        ),
                        onTap: () {
                          noteProvider.setFolder(folder);
                          Navigator.pop(context);
                        },
                      );
                    }),
                    const SizedBox(height: AppLayout.spaceM),
                    ListTile(
                      leading: Icon(
                        Icons.checklist_rtl_rounded,
                        color: noteProvider.filterChecklistsOnly
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        'Checklists & Tasks',
                        style: TextStyle(
                          fontWeight: noteProvider.filterChecklistsOnly ? FontWeight.bold : FontWeight.normal,
                          color: noteProvider.filterChecklistsOnly ? Theme.of(context).colorScheme.primary : null,
                        ),
                      ),
                      trailing: noteProvider.checklistNotesCount > 0
                          ? AppChip(
                              label: '${noteProvider.checklistNotesCount}',
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            )
                          : null,
                      onTap: () {
                        noteProvider.setFilterChecklistsOnly(true);
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.archive_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      title: const Text('Archived Notes'),
                      trailing: noteProvider.archivedCount > 0
                          ? AppChip(
                              label: '${noteProvider.archivedCount}',
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        AppRoute.push(context, const FilteredNotesScreen(filterType: FilterType.archived));
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
                      title: Text('Trash Bin', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      trailing: noteProvider.trashCount > 0
                          ? AppChip(
                              label: '${noteProvider.trashCount}',
                              backgroundColor: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4),
                              textColor: Theme.of(context).colorScheme.error,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        AppRoute.push(context, const FilteredNotesScreen(filterType: FilterType.trash));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNormalMode(BuildContext context, SettingsProvider settings) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final noteProvider = context.watch<NoteProvider>();
    final isChecklistsMode = noteProvider.filterChecklistsOnly;
    final displayFolder = isChecklistsMode
        ? 'Checklists'
        : (noteProvider.selectedFolder ?? 'Notes');
    final count = isChecklistsMode
        ? noteProvider.checklistNotesCount
        : (noteProvider.folderCounts[displayFolder] ?? noteProvider.tagCounts['All'] ?? 0);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)?.navNotes ?? 'Notes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
              ),
              const SizedBox(height: 3),
              Semantics(
                button: true,
                label: 'Folder: $displayFolder, $count notes. Tap to change folder',
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                  onTap: () {
                    _showFolderPicker(context, noteProvider);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: isDark ? 0.35 : 0.45),
                      borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.28),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isChecklistsMode
                              ? Icons.checklist_rtl_rounded
                              : Icons.folder_outlined,
                          color: colorScheme.primary,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$displayFolder • $count',
                          style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: colorScheme.primary,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: AppLocalizations.of(context)?.searchNotes ?? 'Search notes',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            setState(() {
              _isSearching = true;
            });
          },
        ),
        Consumer<P2pSyncProvider>(
          builder: (context, syncProvider, _) {
            // Show when there are paired devices (regardless of auto-sync toggle)
            if (syncProvider.pairedDevices.isEmpty) {
              return const SizedBox.shrink();
            }
            final isSyncing = syncProvider.status == SyncStatus.syncing;
            final isError = syncProvider.status == SyncStatus.error;
            IconData syncIcon;
            Color? iconColor;
            if (isSyncing) {
              syncIcon = Icons.sync_rounded;
              iconColor = null;
            } else if (isError) {
              syncIcon = Icons.sync_problem_rounded;
              iconColor = Theme.of(context).colorScheme.error;
            } else if (syncProvider.status == SyncStatus.completed) {
              syncIcon = Icons.sync_rounded;
              iconColor = Theme.of(context).colorScheme.primary;
            } else {
              syncIcon = Icons.sync_rounded;
              iconColor = null;
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              child: Tooltip(
                message: isSyncing
                    ? 'Syncing...'
                    : isError
                        ? 'Sync failed — long-press for Sync settings'
                        : 'Quick Sync (Tap) | P2P Sync Hub (Hold)',
                child: BouncingWidget(
                  onTap: isSyncing
                      ? null
                      : () async {
                          await syncProvider.syncNow(onCompleted: () {
                            noteProvider.refreshNotes();
                          });
                        },
                  onLongPress: () {
                    AppHaptics.mediumImpact();
                    AppRoute.push(context, const P2pSyncScreen());
                  },
                  child: Center(
                    child: isSyncing
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                            ),
                          )
                        : Icon(syncIcon, color: iconColor),
                  ),
                ),
              ),
            );
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort_rounded),
          tooltip: 'Sort notes',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          elevation: 3,
          shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppLayout.radiusXL),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          onSelected: (sortMode) {
            noteProvider.setSortMode(sortMode);
          },
          itemBuilder: (context) {
            final colorScheme = Theme.of(context).colorScheme;
            final currentSort = noteProvider.sortMode;

            return [
              ('modified', 'Sort by Last Modified', Icons.access_time_rounded),
              ('created', 'Sort by Date Created', Icons.calendar_today_rounded),
              ('title', 'Sort by Title', Icons.sort_by_alpha_rounded),
              ('color', 'Sort by Color', Icons.palette_outlined),
            ].map((item) {
              final isSelected = currentSort == item.$1;
              return PopupMenuItem<String>(
                value: item.$1,
                height: 48,
                child: Row(
                  children: [
                    Icon(
                      item.$3,
                      size: 20,
                      color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.$2,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                            ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                  ],
                ),
              );
            }).toList();
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          tooltip: 'Notes Tools',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          elevation: 3,
          shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppLayout.radiusXL),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          onSelected: (action) {
            if (action == 'view_mode') {
              widget.onCycleViewMode();
            } else if (action == 'manage_folders') {
              _showFolderPicker(context, noteProvider);
            } else if (action == 'manage_tags') {
              AppRoute.push(context, const ManageTagsScreen());
            } else if (action == 'import_notes') {
              NoteMigrationSheet.show(context);
            } else if (action == 'archived') {
              AppRoute.push(context, const FilteredNotesScreen(filterType: FilterType.archived));
            } else if (action == 'trash') {
              AppRoute.push(context, const FilteredNotesScreen(filterType: FilterType.trash));
            }
          },
          itemBuilder: (context) {
            final colorScheme = Theme.of(context).colorScheme;

            return [
              PopupMenuItem<String>(
                value: 'view_mode',
                height: 48,
                child: Row(
                  children: [
                    Icon(
                      _getIconForMode(settings.noteViewMode),
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getTooltipForMode(settings.noteViewMode),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'manage_folders',
                height: 48,
                child: Row(
                  children: [
                    Icon(Icons.create_new_folder_outlined, size: 20, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(
                      'Manage Folders',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'manage_tags',
                height: 48,
                child: Row(
                  children: [
                    Icon(Icons.label_outline_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(
                      'Manage Tags',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'import_notes',
                height: 48,
                child: Row(
                  children: [
                    Icon(Icons.import_contacts_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(
                      'Import Notes',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'archived',
                height: 48,
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined, size: 20, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(
                      'Archived Notes',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'trash',
                height: 48,
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 20, color: colorScheme.error),
                    const SizedBox(width: 12),
                    Text(
                      'Trash Bin',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colorScheme.error,
                          ),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            AppRoute.push(context, const SettingsScreen())
                .then((_) => widget.onRefresh());
          },
        ),
      ],
    );
  }

  IconData _getIconForMode(NoteViewMode mode) {
    switch (mode) {
      case NoteViewMode.list:
        return Icons.grid_view_outlined;
      case NoteViewMode.grid:
        return Icons.view_agenda_outlined;
    }
  }

  String _getTooltipForMode(NoteViewMode mode) {
    switch (mode) {
      case NoteViewMode.list:
        return 'Switch to grid view';
      case NoteViewMode.grid:
        return 'Switch to list view';
    }
  }
}
