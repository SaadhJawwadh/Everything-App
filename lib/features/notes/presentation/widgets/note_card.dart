import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../../../data/note_model.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/ui/app_chip.dart';
import '../../../../widgets/bouncing_widget.dart';
import '../../../../widgets/home/universal_search_overlay.dart';
import '../../../../utils/quill_checklist_helper.dart';
import '../../../../utils/rich_text_utils.dart';
import '../../../../providers/note_provider.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Map<String, int>? tagColors;
  final bool isSelected;
  final void Function(int lineIndex, String text)? onChecklistTap;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.tagColors,
    this.isSelected = false,
    this.onChecklistTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSystemDefault = note.color == 0;
    final theme = Theme.of(context);
    Color backgroundColor;
    Color borderColor;

    if (isSystemDefault) {
      backgroundColor = theme.colorScheme.surface;
      borderColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.3);
    } else {
      final scheme = ColorScheme.fromSeed(seedColor: Color(note.color), brightness: theme.brightness);
      backgroundColor = scheme.surfaceContainerLow;
      borderColor = scheme.outline.withValues(alpha: 0.2);
    }

    final searchQuery = context.watch<NoteProvider>().searchQuery;

    final checkedCount = RegExp(r'"list"\s*:\s*"checked"').allMatches(note.content).length;
    final uncheckedCount = RegExp(r'"list"\s*:\s*"unchecked"').allMatches(note.content).length;
    final totalChecklistItems = checkedCount + uncheckedCount;

    return BouncingWidget(
      onTap: onTap,
      onLongPress: onLongPress != null
          ? () {
              AppHaptics.mediumImpact();
              onLongPress!();
            }
          : null,
      child: Container(
        padding: AppLayout.paddingAllL,
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer : backgroundColor,
          borderRadius: BorderRadius.circular(AppLayout.radiusL),
          border: Border.all(color: isSelected ? theme.colorScheme.primary : borderColor, width: isSelected ? 2 : 1),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (note.title.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: HighlightedText(
                          text: note.title,
                          query: searchQuery,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold) ?? const TextStyle(),
                          highlightStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary) ?? const TextStyle(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (note.isPinned)
                        Padding(
                          padding: EdgeInsets.only(
                            left: AppLayout.spaceS,
                            right: isSelected ? 22.0 : 0.0,
                          ),
                          child: Icon(
                            Icons.push_pin,
                            size: AppLayout.iconS,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      else if (isSelected)
                        const SizedBox(width: 22.0),
                    ],
                  ),
                if (note.isLocked) ...[
                  const SizedBox(height: AppLayout.spaceS),
                  AppChip(
                    label: 'Locked Note',
                    icon: Icons.lock_outline,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    textColor: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
                if (!note.isLocked && note.imagePath != null) ...[
                  const SizedBox(height: AppLayout.spaceM),
                  ClipRRect(borderRadius: BorderRadius.circular(AppLayout.radiusL), child: Image.file(File(note.imagePath!), cacheWidth: 400, height: 120, width: double.infinity, fit: BoxFit.cover, alignment: Alignment.topCenter, errorBuilder: (c, e, s) => const SizedBox.shrink())),
                ],
                if (!note.isLocked && totalChecklistItems > 0) ...[
                  const SizedBox(height: AppLayout.spaceS),
                  Row(
                    children: [
                      AppChip(
                        label: '$checkedCount/$totalChecklistItems Done',
                        icon: checkedCount == totalChecklistItems
                            ? Icons.check_circle_outline_rounded
                            : Icons.checklist_rounded,
                        backgroundColor: checkedCount == totalChecklistItems
                            ? Colors.green.withValues(alpha: 0.15)
                            : theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
                        textColor: checkedCount == totalChecklistItems
                            ? Colors.green
                            : theme.colorScheme.onSecondaryContainer,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppLayout.spaceS),
                  ..._buildChecklistPreview(context, theme, searchQuery),
                ] else if (!note.isLocked && ((note.previewText?.isNotEmpty ?? false) || note.content.isNotEmpty))
                  Flexible(
                    child: HighlightedText(
                      text: note.previewText ?? '...',
                      query: searchQuery,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant) ?? const TextStyle(),
                      highlightStyle: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary) ?? const TextStyle(),
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(height: AppLayout.spaceM),
                  Wrap(
                    spacing: AppLayout.spaceXS, runSpacing: AppLayout.spaceXS,
                    children: [
                      ...note.tags.take(3).map((tag) {
                        final colorVal = tagColors?[tag];
                        Color bg = theme.colorScheme.secondaryContainer.withValues(alpha: 0.5);
                        Color fg = theme.colorScheme.onSecondaryContainer;
                        if (colorVal != null && colorVal != 0) {
                          final scheme = ColorScheme.fromSeed(seedColor: Color(colorVal), brightness: theme.brightness);
                          bg = scheme.primaryContainer;
                          fg = scheme.onPrimaryContainer;
                        }
                        return Container(padding: const EdgeInsets.symmetric(horizontal: AppLayout.spaceS, vertical: AppLayout.spaceXS), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppLayout.radiusStadium)), child: Text(tag, style: TextStyle(fontSize: 11.5, color: fg, fontWeight: FontWeight.w600)));
                      }),
                      if (note.tags.length > 3)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppLayout.spaceS, vertical: AppLayout.spaceXS),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                          ),
                          child: Text(
                            '+${note.tags.length - 3}',
                            style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
            if (isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: AppLayout.softShadow(context),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChecklistPreview(BuildContext context, ThemeData theme, String searchQuery) {
    try {
      final delta = RichTextUtils.contentToDelta(note.content);
      final doc = Document.fromDelta(delta);
      final items = QuillChecklistHelper.extractChecklistData(doc);
      if (items.isEmpty) {
        if ((note.previewText?.isNotEmpty ?? false) || note.content.isNotEmpty) {
          return [
            Flexible(
              child: HighlightedText(
                text: note.previewText ?? '...',
                query: searchQuery,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant) ?? const TextStyle(),
                highlightStyle: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary) ?? const TextStyle(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ];
        }
        return const [];
      }

      final previewItems = items.take(4).toList();
      return [
        ...previewItems.map((item) {
          return InkWell(
            onTap: () {
              if (onChecklistTap != null) {
                onChecklistTap!(item.lineIndex, item.text);
              } else {
                onTap();
              }
            },
            borderRadius: BorderRadius.circular(AppLayout.radiusS),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      item.isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: item.isDone ? Colors.green : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: AppLayout.spaceS),
                    Expanded(
                      child: Text(
                        item.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: item.isDone
                              ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                              : theme.colorScheme.onSurface,
                          decoration: item.isDone ? TextDecoration.lineThrough : null,
                          decorationColor: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        if (items.length > 4)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              '+ ${items.length - 4} more items',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ];
    } catch (_) {
      return [
        if ((note.previewText?.isNotEmpty ?? false) || note.content.isNotEmpty)
          Flexible(
            child: HighlightedText(
              text: note.previewText ?? '...',
              query: searchQuery,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant) ?? const TextStyle(),
              highlightStyle: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary) ?? const TextStyle(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ];
    }
  }
}
