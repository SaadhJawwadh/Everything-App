import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Horizontal wrapping chips displaying note metadata: reminder, lock, folder, and custom tags.
class NoteMetadataChipsBar extends StatelessWidget {
  final DateTime? reminderAt;
  final bool isNoteLocked;
  final bool isCustomFolder;
  final String folder;
  final List<String> tags;
  final Map<String, int> tagColors;
  final Color textColor;
  final VoidCallback onPickReminder;
  final VoidCallback onClearReminder;
  final VoidCallback onPickFolder;
  final ValueChanged<String> onDeleteTag;

  const NoteMetadataChipsBar({
    super.key,
    required this.reminderAt,
    required this.isNoteLocked,
    required this.isCustomFolder,
    required this.folder,
    required this.tags,
    required this.tagColors,
    required this.textColor,
    required this.onPickReminder,
    required this.onClearReminder,
    required this.onPickFolder,
    required this.onDeleteTag,
  });

  @override
  Widget build(BuildContext context) {
    if (reminderAt == null && !isNoteLocked && !isCustomFolder && tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          if (reminderAt != null)
            InputChip(
              avatar: Icon(Icons.alarm, size: 16, color: textColor),
              label: Text(
                DateFormat('EEE, d MMM • h:mm a').format(reminderAt!),
                style: TextStyle(color: textColor, fontSize: 12),
              ),
              onPressed: onPickReminder,
              onDeleted: onClearReminder,
              deleteIconColor: textColor,
            ),
          if (isNoteLocked)
            Chip(
              avatar: Icon(Icons.lock, size: 16, color: textColor),
              label: Text(
                'Locked',
                style: TextStyle(color: textColor, fontSize: 12),
              ),
            ),
          if (isCustomFolder)
            InputChip(
              avatar: Icon(Icons.folder_outlined, size: 16, color: textColor),
              label: Text(
                folder,
                style: TextStyle(color: textColor, fontSize: 12),
              ),
              onPressed: onPickFolder,
            ),
          ...tags.map((tag) {
            final tagColorValue = tagColors[tag];
            final tagColor = tagColorValue != null && tagColorValue != 0
                ? Color(tagColorValue)
                : null;
            Color? chipBgColor;
            Color? chipLabelColor;
            if (tagColor != null) {
              final scheme = ColorScheme.fromSeed(
                seedColor: tagColor,
                brightness: Theme.of(context).brightness,
              );
              chipBgColor = scheme.primaryContainer;
              chipLabelColor = scheme.onPrimaryContainer;
            }
            return Chip(
              label: Text(tag, style: TextStyle(color: chipLabelColor)),
              backgroundColor: chipBgColor,
              shape: const StadiumBorder(),
              side: BorderSide.none,
              onDeleted: () => onDeleteTag(tag),
              deleteIconColor: chipLabelColor,
            );
          }),
        ],
      ),
    );
  }
}
