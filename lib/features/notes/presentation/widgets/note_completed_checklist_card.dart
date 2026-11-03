import 'package:flutter/material.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/services/app_haptics.dart';

/// Collapsible card displaying completed checklist tasks with uncheck/delete bulk and single actions.
class NoteCompletedChecklistCard extends StatelessWidget {
  final List<String> completedItems;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final VoidCallback onUncheckAll;
  final VoidCallback onDeleteAll;
  final ValueChanged<String> onRestoreItem;
  final ValueChanged<String> onDeleteItem;
  final ColorScheme noteScheme;
  final Color textColor;

  const NoteCompletedChecklistCard({
    super.key,
    required this.completedItems,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.onUncheckAll,
    required this.onDeleteAll,
    required this.onRestoreItem,
    required this.onDeleteItem,
    required this.noteScheme,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (completedItems.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: AnimatedContainer(
        duration: AppLayout.animDefault,
        curve: AppLayout.curveExpressiveSpatial,
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
              onTap: onToggleCollapse,
              borderRadius: BorderRadius.circular(AppLayout.radiusXL),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      isCollapsed
                          ? Icons.keyboard_arrow_right_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: noteScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${completedItems.length} completed ${completedItems.length == 1 ? 'item' : 'items'}',
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
                        onPressed: () {
                          AppHaptics.mediumImpact();
                          onUncheckAll();
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
                        onPressed: () {
                          AppHaptics.mediumImpact();
                          onDeleteAll();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: AppLayout.animDefault,
              curve: AppLayout.curveExpressiveSpatial,
              child: !isCollapsed
                  ? Column(
                      children: [
                        const SizedBox(height: 6.0),
                        ...completedItems.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: true,
                                  onChanged: (val) {
                                    AppHaptics.selectionClick();
                                    onRestoreItem(item);
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
                                  tooltip: 'Remove item',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                  onPressed: () {
                                    AppHaptics.selectionClick();
                                    onDeleteItem(item);
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
