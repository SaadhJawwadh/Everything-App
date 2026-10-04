import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';
import '../core/services/app_haptics.dart';
import '../core/ui/app_chip.dart';

class TagFilterBar extends StatelessWidget {
  final Function(String) onTagLongPress;

  const TagFilterBar({super.key, required this.onTagLongPress});

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        final allTags = noteProvider.allTags;
        final selectedTag = noteProvider.selectedTag;
        final tagColors = noteProvider.tagColors;
        final checklistCount = noteProvider.checklistNotesCount;
        final isChecklistFiltered = noteProvider.filterChecklistsOnly;
        final showChecklistChip = checklistCount > 0;
        final itemCount = allTags.length + (showChecklistChip ? 1 : 0);

        return Container(
          height: 40,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (showChecklistChip && index == 1) {
                final todoColors = AppChip.getTagColors(context, null, isSelected: isChecklistFiltered);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: AppChip(
                    icon: Icons.checklist_rtl_rounded,
                    label: 'Checklists · $checklistCount',
                    isSelected: isChecklistFiltered,
                    isCompact: true,
                    backgroundColor: todoColors.bg,
                    selectedBackgroundColor: todoColors.bg,
                    textColor: todoColors.fg,
                    border: todoColors.border,
                    onTap: () {
                      AppHaptics.selectionClick();
                      noteProvider.setFilterChecklistsOnly(!isChecklistFiltered);
                    },
                  ),
                );
              }

              final tagIndex = (showChecklistChip && index > 1) ? index - 1 : index;
              final tag = allTags[tagIndex];
              final isSelected = tag == selectedTag;
              final tagColorValue = tagColors[tag];
              final chipColors = AppChip.getTagColors(context, tagColorValue, isSelected: isSelected);

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onLongPress: () {
                    AppHaptics.mediumImpact();
                    onTagLongPress(tag);
                  },
                  child: AppChip(
                    label: (noteProvider.tagCounts[tag] ?? 0) > 0
                        ? '$tag · ${noteProvider.tagCounts[tag]}'
                        : tag,
                    isSelected: isSelected,
                    isCompact: true,
                    backgroundColor: chipColors.bg,
                    selectedBackgroundColor: chipColors.bg,
                    textColor: chipColors.fg,
                    border: chipColors.border,
                    onTap: () {
                      AppHaptics.selectionClick();
                      noteProvider.setTag(tag);
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
