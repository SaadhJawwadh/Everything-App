import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_layout.dart';

/// Standardized Search Bar widget for NoteEditorScreen.
class NoteSearchReplaceBar extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool isCaseSensitive;
  final List<int> searchOffsets;
  final int currentSearchIndex;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onNextMatch;
  final VoidCallback onPreviousMatch;
  final VoidCallback onToggleCaseSensitive;
  final VoidCallback onCloseSearch;

  const NoteSearchReplaceBar({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.isCaseSensitive,
    required this.searchOffsets,
    required this.currentSearchIndex,
    required this.onSearchChanged,
    required this.onNextMatch,
    required this.onPreviousMatch,
    required this.onToggleCaseSensitive,
    required this.onCloseSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): onCloseSearch,
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              color: colorScheme.onSurfaceVariant,
              tooltip: 'Close search',
              onPressed: onCloseSearch,
            ),
            Expanded(
              child: TextField(
                controller: searchController,
                focusNode: searchFocusNode,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search in note...',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
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
                onSubmitted: (_) => onNextMatch(),
              ),
            ),
            Tooltip(
              message: 'Match case',
              child: InkWell(
                onTap: onToggleCaseSensitive,
                borderRadius: BorderRadius.circular(AppLayout.radiusS),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCaseSensitive
                        ? colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppLayout.radiusS),
                    border: Border.all(
                      color: isCaseSensitive
                          ? colorScheme.primary
                          : colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'Aa',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCaseSensitive ? FontWeight.bold : FontWeight.normal,
                      color: isCaseSensitive
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            if (searchController.text.isNotEmpty)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: searchOffsets.isNotEmpty
                      ? colorScheme.secondaryContainer
                      : colorScheme.surfaceContainerHighest,
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
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (searchOffsets.isNotEmpty) ...[
              IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                color: colorScheme.onSurfaceVariant,
                tooltip: 'Previous match',
                onPressed: onPreviousMatch,
              ),
              IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                color: colorScheme.onSurfaceVariant,
                tooltip: 'Next match',
                onPressed: onNextMatch,
              ),
            ],
            if (searchController.text.isNotEmpty)
              IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close_rounded, size: 20),
                color: colorScheme.onSurfaceVariant,
                tooltip: 'Clear search text',
                onPressed: () {
                  searchController.clear();
                  onSearchChanged('');
                },
              ),
          ],
        ),
      ),
    );
  }
}
