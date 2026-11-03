import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../widgets/bouncing_widget.dart';

/// Top bar for NoteEditorScreen, encapsulating both search mode and the primary navigation/action bar.
class NoteEditorTopBar extends StatelessWidget {
  final bool isSearching;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool isCaseSensitive;
  final List<int> searchOffsets;
  final int currentSearchIndex;
  final VoidCallback onCloseSearch;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onToggleCaseSensitive;
  final VoidCallback onPreviousSearchMatch;
  final VoidCallback onNextSearchMatch;
  final VoidCallback onBackPressed;
  final Color textColor;
  final QuillController quillController;
  final VoidCallback onTagPicker;
  final DateTime? reminderAt;
  final bool isNoteLocked;
  final bool isNoteInTrash;
  final bool minimalEditorMode;
  final ValueChanged<String> onMenuSelected;

  const NoteEditorTopBar({
    super.key,
    required this.isSearching,
    required this.searchController,
    required this.searchFocusNode,
    required this.isCaseSensitive,
    required this.searchOffsets,
    required this.currentSearchIndex,
    required this.onCloseSearch,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onToggleCaseSensitive,
    required this.onPreviousSearchMatch,
    required this.onNextSearchMatch,
    required this.onBackPressed,
    required this.textColor,
    required this.quillController,
    required this.onTagPicker,
    required this.reminderAt,
    required this.isNoteLocked,
    required this.isNoteInTrash,
    required this.minimalEditorMode,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: isSearching
            ? CallbackShortcuts(
                bindings: <ShortcutActivator, VoidCallback>{
                  const SingleActivator(LogicalKeyboardKey.escape): onCloseSearch,
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        color: theme.colorScheme.onSurfaceVariant,
                        tooltip: 'Close search',
                        onPressed: onCloseSearch,
                      ),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          focusNode: searchFocusNode,
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
                          onChanged: onSearchChanged,
                          onSubmitted: onSearchSubmitted,
                        ),
                      ),
                      Tooltip(
                        message: 'Match case',
                        child: InkWell(
                          onTap: onToggleCaseSensitive,
                          borderRadius: BorderRadius.circular(AppLayout.radiusS),
                          child: AnimatedContainer(
                            duration: AppLayout.animMicro,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCaseSensitive
                                  ? theme.colorScheme.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppLayout.radiusS),
                              border: Border.all(
                                color: isCaseSensitive
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              'Aa',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isCaseSensitive ? FontWeight.bold : FontWeight.normal,
                                color: isCaseSensitive
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (searchController.text.isNotEmpty)
                        AnimatedContainer(
                          duration: AppLayout.animMicro,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: searchOffsets.isNotEmpty
                                ? theme.colorScheme.secondaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppLayout.radiusM),
                          ),
                          child: Text(
                            searchOffsets.isNotEmpty
                                ? '${currentSearchIndex + 1}/${searchOffsets.length}'
                                : '0/0',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: searchOffsets.isNotEmpty
                                  ? theme.colorScheme.onSecondaryContainer
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (searchOffsets.isNotEmpty) ...[
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                          color: theme.colorScheme.onSurfaceVariant,
                          tooltip: 'Previous match',
                          onPressed: onPreviousSearchMatch,
                        ),
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                          color: theme.colorScheme.onSurfaceVariant,
                          tooltip: 'Next match',
                          onPressed: onNextSearchMatch,
                        ),
                      ],
                      if (searchController.text.isNotEmpty)
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: theme.colorScheme.onSurfaceVariant,
                          tooltip: 'Clear search text',
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                        ),
                    ],
                  ),
                ),
              )
            : Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                    color: textColor,
                    onPressed: onBackPressed,
                  ),
                  const SizedBox(width: AppLayout.spaceS),
                  QuillToolbarHistoryButton(
                    isUndo: true,
                    controller: quillController,
                    options: QuillToolbarHistoryButtonOptions(
                      iconTheme: QuillIconTheme(
                        iconButtonUnselectedData: IconButtonData(
                          style: IconButton.styleFrom(
                            foregroundColor: textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  QuillToolbarHistoryButton(
                    isUndo: false,
                    controller: quillController,
                    options: QuillToolbarHistoryButtonOptions(
                      iconTheme: QuillIconTheme(
                        iconButtonUnselectedData: IconButtonData(
                          style: IconButton.styleFrom(
                            foregroundColor: textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  BouncingWidget(
                    onTap: onTagPicker,
                    child: IconButton(
                      icon: const Icon(Icons.label_outline),
                      tooltip: 'Tags',
                      color: textColor,
                      onPressed: onTagPicker,
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
                    onSelected: onMenuSelected,
                    itemBuilder: (context) {
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
                        if (minimalEditorMode)
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
                              Icon(reminderAt != null ? Icons.alarm_on_rounded : Icons.alarm_add_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                              const SizedBox(width: 12),
                              Text(reminderAt != null ? 'Change reminder' : 'Set reminder', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        if (reminderAt != null)
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
                              Icon(isNoteLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                              const SizedBox(width: 12),
                              Text(isNoteLocked ? 'Unlock note' : 'Lock note', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
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
                              Text(isNoteInTrash ? 'Delete Permanently' : 'Move to Trash', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.error, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                ],
              ),
      ),
    );
  }
}
