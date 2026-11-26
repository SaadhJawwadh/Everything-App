import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/app_bottom_sheet.dart';
import '../../core/ui/app_card.dart';

/// A Material 3 bottom sheet showing statistics (words, chars, read time)
/// and metadata (folder, created date, modified date) for a note.
class EditorNoteDetailsSheet extends StatelessWidget {
  final String plainText;
  final String folder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EditorNoteDetailsSheet({
    super.key,
    required this.plainText,
    required this.folder,
    this.createdAt,
    this.updatedAt,
  });

  /// Static helper to launch the bottom sheet.
  static void show(
    BuildContext context, {
    required String plainText,
    required String folder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    AppBottomSheet.show(
      context: context,
      title: 'Note Details & Stats',
      child: EditorNoteDetailsSheet(
        plainText: plainText,
        folder: folder,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trimmedText = plainText.trim();
    final words = trimmedText.isEmpty
        ? 0
        : trimmedText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final chars = trimmedText.length;
    final readingTimeMin = (words / 200).ceil();
    final readingTimeStr = words == 0
        ? '0 min read'
        : readingTimeMin <= 1
            ? '1 min read'
            : '$readingTimeMin min read';

    final dateFormat = DateFormat('MMM d, yyyy · h:mm a');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            groupPosition: AppCardGroupPosition.first,
            backgroundColor: colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _StatItem(
                    icon: Icons.notes,
                    value: '$words',
                    label: 'Words',
                  ),
                  VerticalDivider(
                    width: 16,
                    thickness: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  _StatItem(
                    icon: Icons.text_fields,
                    value: '$chars',
                    label: 'Characters',
                  ),
                  VerticalDivider(
                    width: 16,
                    thickness: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  _StatItem(
                    icon: Icons.timer_outlined,
                    value: readingTimeStr,
                    label: 'Read Time',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          AppCard(
            groupPosition: AppCardGroupPosition.last,
            backgroundColor: colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Folder',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      folder,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFamily: AppTheme.fontGoogleSansFlex,
                        fontFamilyFallback: AppTheme.fontFallbacks,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (createdAt != null) ...[
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Created',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        dateFormat.format(createdAt!),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13.0,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
                if (updatedAt != null) ...[
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Last Modified',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        dateFormat.format(updatedAt!),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13.0,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: AppTheme.fontGoogleSansFlex,
              fontFamilyFallback: AppTheme.fontFallbacks,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontVariations: AppTheme.buildFontVariations(
                size: 16.0,
                brightness: theme.brightness,
                weight: 700,
              ),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13.0,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
