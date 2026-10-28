import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../core/ui/app_chip.dart';
import '../../data/note_repository.dart';
import '../../../../l10n/app_localizations.dart';

/// Modal bottom sheet allowing users to add existing tags, create new tags with custom colors,
/// and toggle tags associated with a note.
class NoteTagPickerSheet extends StatefulWidget {
  final List<String> currentTags;
  final List<String> allTags;
  final Map<String, int> tagColors;
  final void Function(String tag, bool isSelected) onTagToggled;
  final void Function(String tag, int color) onTagCreated;

  const NoteTagPickerSheet({
    super.key,
    required this.currentTags,
    required this.allTags,
    required this.tagColors,
    required this.onTagToggled,
    required this.onTagCreated,
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> currentTags,
    required List<String> allTags,
    required Map<String, int> tagColors,
    required void Function(String tag, bool isSelected) onTagToggled,
    required void Function(String tag, int color) onTagCreated,
  }) {
    final l10n = AppLocalizations.of(context);
    return AppBottomSheet.show(
      context: context,
      title: l10n?.manageTags ?? 'Manage Tags',
      child: NoteTagPickerSheet(
        currentTags: currentTags,
        allTags: allTags,
        tagColors: tagColors,
        onTagToggled: onTagToggled,
        onTagCreated: onTagCreated,
      ),
    );
  }

  @override
  State<NoteTagPickerSheet> createState() => _NoteTagPickerSheetState();
}

class _NoteTagPickerSheetState extends State<NoteTagPickerSheet> {
  final TextEditingController _tagTextController = TextEditingController();
  int _newTagColor = 0;

  @override
  void dispose() {
    _tagTextController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateTag() async {
    final enteredTag = _tagTextController.text.trim();
    if (enteredTag.isNotEmpty) {
      if (_newTagColor != 0) {
        await NoteRepository.instance.setTagColor(enteredTag, _newTagColor);
      }
      widget.onTagCreated(enteredTag, _newTagColor);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _tagTextController,
            decoration: InputDecoration(
              hintText: 'Create new tag',
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                onPressed: _handleCreateTag,
              ),
            ),
            onSubmitted: (_) => _handleCreateTag(),
          ),
            const SizedBox(height: 16),
            Text(
              'TAG COLOR',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ...AppTheme.noteColors.map((c) {
                  final bool isSystem = c.toARGB32() == 0;
                  final bool isSelected = !isSystem && _newTagColor == c.toARGB32();
                  return Semantics(
                    label: isSystem ? 'Random Color' : 'Color option',
                    selected: isSelected,
                    button: true,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSystem) {
                            final nonZeroColors = AppTheme.noteColors
                                .where((color) => color.toARGB32() != 0)
                                .toList();
                            final randomColor = (nonZeroColors..shuffle()).first;
                            _newTagColor = randomColor.toARGB32();
                          } else {
                            _newTagColor = c.toARGB32();
                          }
                        });
                      },
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Container(
                            width: isSelected ? 34 : 30,
                            height: isSelected ? 34 : 30,
                            decoration: BoxDecoration(
                              color: isSystem ? colorScheme.surfaceContainerHigh : c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.outlineVariant,
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: c.withValues(alpha: 0.4),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
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
                }),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.allTags.isNotEmpty) ...[
              Text(
                'SELECT TAGS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.allTags.map((t) {
                      final isSelected = widget.currentTags.contains(t);
                      final tagColorVal = widget.tagColors[t];
                      final colors = AppChip.getTagColors(context, tagColorVal,
                          isSelected: isSelected);

                      return AppChip(
                        label: t,
                        icon: isSelected ? Icons.check : null,
                        isSelected: isSelected,
                        backgroundColor: colors.bg,
                        selectedBackgroundColor: colors.bg,
                        textColor: colors.fg,
                        border: colors.border,
                        onTap: () {
                          widget.onTagToggled(t, !isSelected);
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
  }
}
