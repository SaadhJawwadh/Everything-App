import 'package:flutter/material.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';

/// Predefined note color palette seed presets
class NoteColorPresets {
  static const List<({String label, int colorValue})> presets = [
    (label: 'Default', colorValue: 0),
    (label: 'Coral Red', colorValue: 0xFFF28B82),
    (label: 'Peach Orange', colorValue: 0xFFFBBC04),
    (label: 'Warm Amber', colorValue: 0xFFFFF475),
    (label: 'Mint Green', colorValue: 0xFFCCFF90),
    (label: 'Sage Teal', colorValue: 0xFFA7FFEB),
    (label: 'Sky Blue', colorValue: 0xFFCBF0F8),
    (label: 'Ocean Indigo', colorValue: 0xFFAECBFA),
    (label: 'Soft Purple', colorValue: 0xFFD7AEFB),
    (label: 'Blush Pink', colorValue: 0xFFFDCFE8),
    (label: 'Warm Sand', colorValue: 0xFFE6C9A8),
    (label: 'Charcoal Grey', colorValue: 0xFFE8EAED),
  ];
}

/// Standardized modal bottom sheet for picking note colors.
class NoteColorPickerSheet extends StatelessWidget {
  final int selectedColor;
  final ValueChanged<int> onColorSelected;

  const NoteColorPickerSheet({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required int selectedColor,
    required ValueChanged<int> onColorSelected,
  }) {
    return AppBottomSheet.show(
      context: context,
      title: 'Note Color',
      child: NoteColorPickerSheet(
        selectedColor: selectedColor,
        onColorSelected: onColorSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: NoteColorPresets.presets.map((preset) {
          final isSelected = selectedColor == preset.colorValue;
          final isDefault = preset.colorValue == 0;

          final displayColor = isDefault
              ? colorScheme.surfaceContainerHighest
              : Color(preset.colorValue);

          return Tooltip(
            message: preset.label,
            child: InkWell(
              onTap: () {
                AppHaptics.selectionClick();
                onColorSelected(preset.colorValue);
                Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(AppLayout.radiusMAX),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: displayColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: isSelected ? 2.5 : 1.0,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        color: isDefault
                            ? colorScheme.onSurfaceVariant
                            : (ThemeData.estimateBrightnessForColor(displayColor) ==
                                    Brightness.dark
                                ? Colors.white
                                : Colors.black87),
                        size: 22,
                      )
                    : isDefault
                        ? Icon(
                            Icons.format_color_reset_outlined,
                            color: colorScheme.onSurfaceVariant,
                            size: 20,
                          )
                        : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
