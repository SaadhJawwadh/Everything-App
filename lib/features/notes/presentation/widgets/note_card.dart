import 'dart:collection';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../../../data/note_model.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../widgets/home/universal_search_overlay.dart';
import '../../../../utils/quill_checklist_helper.dart';
import '../../../../utils/rich_text_utils.dart';
import '../../providers/note_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

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

  static final RegExp _checkedFallbackRegex = RegExp(r'"list"\s*:\s*"checked"');
  static final RegExp _uncheckedFallbackRegex = RegExp(r'"list"\s*:\s*"unchecked"');

  static final LinkedHashMap<String, ({List<ChecklistItemData> items, int checked, int unchecked})>
      _checklistCache = LinkedHashMap();

  /// Resolves the exact card background color so [OpenContainer.closedColor]
  /// matches [NoteCard] without surface flashes during expansion.
  static Color resolveCardBackground(Note note, ThemeData theme) {
    if (note.color == 0) return theme.colorScheme.surface;
    return AppTheme.cachedSeedScheme(note.color, theme.brightness).surfaceContainerLow;
  }

  static ({List<ChecklistItemData> items, int checked, int unchecked}) _getCachedChecklist(Note note) {
    final key = '${note.id}_${note.dateModified.microsecondsSinceEpoch}_${note.content.length}_${note.content.hashCode}';
    final cached = _checklistCache.remove(key);
    if (cached != null) {
      _checklistCache[key] = cached; // refresh LRU order
      return cached;
    }

    List<ChecklistItemData> checklistItems = const [];
    int checkedCount = 0;
    int uncheckedCount = 0;
    try {
      final delta = RichTextUtils.contentToDelta(note.content);
      final doc = Document.fromDelta(delta);
      checklistItems = QuillChecklistHelper.extractChecklistData(doc);
      checkedCount = checklistItems.where((i) => i.isDone).length;
      uncheckedCount = checklistItems.where((i) => !i.isDone).length;
    } catch (_) {
      checkedCount = _checkedFallbackRegex.allMatches(note.content).length;
      uncheckedCount = _uncheckedFallbackRegex.allMatches(note.content).length;
    }

    final entry = (items: checklistItems, checked: checkedCount, unchecked: uncheckedCount);
    if (_checklistCache.length >= 200) {
      _checklistCache.remove(_checklistCache.keys.first);
    }
    _checklistCache[key] = entry;
    return entry;
  }

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
      final scheme = AppTheme.cachedSeedScheme(note.color, theme.brightness);
      backgroundColor = scheme.surfaceContainerLow;
      borderColor = scheme.outline.withValues(alpha: 0.2);
    }

    final searchQuery = context.select<NoteProvider, String>((p) => p.searchQuery);

    List<ChecklistItemData> checklistItems = const [];
    int checkedCount = 0;
    int uncheckedCount = 0;
    if (!note.isLocked &&
        (note.content.contains('"checked"') || note.content.contains('"unchecked"'))) {
      final parsed = _getCachedChecklist(note);
      checklistItems = parsed.items;
      checkedCount = parsed.checked;
      uncheckedCount = parsed.unchecked;
    }
    final totalChecklistItems = checkedCount + uncheckedCount;

    return Material(
      color: isSelected ? theme.colorScheme.primaryContainer : backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.radiusL),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : borderColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        splashFactory: InkSparkle.splashFactory,
        onTap: () {
          AppHaptics.lightImpact();
          onTap();
        },
        onLongPress: onLongPress != null
            ? () {
                AppHaptics.mediumImpact();
                onLongPress!();
              }
            : null,
        child: Padding(
          padding: AppLayout.paddingAllL,
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppLayout.spaceXS),
                      Flexible(
                        child: Text(
                          'Locked note',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: AppTheme.fontGoogleSansFlex,
                            fontFamilyFallback: AppTheme.fontFallbacks,
                            fontSize: 13.0,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontVariations: AppTheme.buildFontVariations(
                              size: 13.0,
                              brightness: theme.brightness,
                              weight: 500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (!note.isLocked && note.imagePath != null) ...[
                  const SizedBox(height: AppLayout.spaceM),
                  ClipRRect(borderRadius: BorderRadius.circular(AppLayout.radiusL), child: Image.file(File(note.imagePath!), cacheWidth: 400, height: 120, width: double.infinity, fit: BoxFit.cover, alignment: Alignment.topCenter, errorBuilder: (c, e, s) => const SizedBox.shrink())),
                ],
                if (!note.isLocked && totalChecklistItems > 0) ...[
                  const SizedBox(height: AppLayout.spaceS),
                  Builder(builder: (context) {
                    final successColor = theme.extension<AppSemanticColors>()?.success ??
                        (theme.brightness == Brightness.dark ? const Color(0xFF4CAF50) : const Color(0xFF1B873F));
                    final allDone = checkedCount == totalChecklistItems;
                    final statusColor = allDone ? successColor : theme.colorScheme.onSurfaceVariant;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          allDone
                              ? Icons.check_circle_outline_rounded
                              : Icons.checklist_rounded,
                          size: 16,
                          color: statusColor,
                        ),
                        const SizedBox(width: AppLayout.spaceXS),
                        Flexible(
                          child: Text(
                            '$checkedCount/$totalChecklistItems Done',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontFamily: AppTheme.fontGoogleSansFlex,
                              fontFamilyFallback: AppTheme.fontFallbacks,
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                              fontFeatures: const [FontFeature.tabularFigures()],
                              fontVariations: AppTheme.buildFontVariations(
                                size: 13.0,
                                brightness: theme.brightness,
                                weight: 600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: AppLayout.spaceS),
                  ..._buildChecklistPreview(context, theme, searchQuery, checklistItems),
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
                          final scheme = AppTheme.cachedSeedScheme(colorVal, theme.brightness);
                          bg = scheme.primaryContainer;
                          fg = scheme.onPrimaryContainer;
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppLayout.spaceS, vertical: AppLayout.spaceXS),
                          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppLayout.radiusStadium)),
                          child: Text(
                            tag,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontFamily: AppTheme.fontGoogleSansFlex,
                              fontFamilyFallback: AppTheme.fontFallbacks,
                              fontSize: 13.0,
                              color: fg,
                              fontWeight: FontWeight.w600,
                              fontVariations: AppTheme.buildFontVariations(
                                size: 13.0,
                                brightness: theme.brightness,
                                weight: 600,
                              ),
                            ),
                          ),
                        );
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
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontFamily: AppTheme.fontGoogleSansFlex,
                              fontFamilyFallback: AppTheme.fontFallbacks,
                              fontSize: 13.0,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [FontFeature.tabularFigures()],
                              fontVariations: AppTheme.buildFontVariations(
                                size: 13.0,
                                brightness: theme.brightness,
                                weight: 600,
                              ),
                            ),
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
    ),
  );
}

  List<Widget> _buildChecklistPreview(BuildContext context, ThemeData theme, String searchQuery, List<ChecklistItemData> items) {
    try {
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

      // Exclude completed items from the card preview to keep focus on actionable tasks
      final pendingItems = items.where((i) => !i.isDone).toList();
      final completedItems = items.where((i) => i.isDone).toList();

      if (pendingItems.isEmpty) {
        if (completedItems.isNotEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppLayout.spaceXS),
                  Flexible(
                    child: Text(
                      AppLocalizations.of(context)?.allTasksCompleted(completedItems.length) ??
                          'All ${completedItems.length} tasks completed',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: AppTheme.fontGoogleSansFlex,
                        fontFamilyFallback: AppTheme.fontFallbacks,
                        fontSize: 13.0,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontVariations: AppTheme.buildFontVariations(
                          size: 13.0,
                          brightness: theme.brightness,
                          weight: 600,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ];
        }
        return const [];
      }

      final previewItems = pendingItems.take(3).toList();
      final remainingCount = pendingItems.length - previewItems.length;

      return [
        ...previewItems.map((item) {
          return Semantics(
            button: true,
            label: 'Toggle checklist item: ${item.text}',
            child: InkWell(
              onTap: () {
                if (onChecklistTap != null) {
                  onChecklistTap!(item.lineIndex, item.text);
                } else {
                  onTap();
                }
              },
              borderRadius: BorderRadius.circular(AppLayout.radiusS),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      item.isDone ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 20,
                      color: item.isDone ? theme.colorScheme.primary : theme.colorScheme.outline,
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
        if (remainingCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 28.0),
            child: Text(
              AppLocalizations.of(context)?.moreItems(remainingCount) ??
                  '+$remainingCount more items',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: AppTheme.fontGoogleSansFlex,
                fontFamilyFallback: AppTheme.fontFallbacks,
                fontSize: 13.0,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
                fontVariations: AppTheme.buildFontVariations(
                  size: 13.0,
                  brightness: theme.brightness,
                  weight: 500,
                ),
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
