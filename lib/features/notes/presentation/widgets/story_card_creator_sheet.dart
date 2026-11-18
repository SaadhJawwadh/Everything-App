import 'package:flutter/material.dart';
import '../../../story_cards/story_cards.dart';

export '../../../story_cards/models/story_card_aspect_ratio.dart';
export '../../../story_cards/models/story_card_theme.dart';
export '../../../story_cards/presentation/widgets/story_card_studio_sheet.dart';

/// Backward-compatible adapter for [StoryCardStudioSheet].
class StoryCardCreatorSheet extends StatelessWidget {
  final String initialText;
  final String noteTitle;
  final String category;
  final int noteColorValue;
  final DateTime noteDate;

  const StoryCardCreatorSheet({
    super.key,
    required this.initialText,
    required this.noteTitle,
    this.category = 'Note',
    this.noteColorValue = 0,
    required this.noteDate,
  });

  /// Displays the [StoryCardStudioSheet] modal bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required String initialText,
    required String noteTitle,
    String category = 'Note',
    int noteColorValue = 0,
    required DateTime noteDate,
  }) {
    return StoryCardStudioSheet.show(
      context: context,
      initialText: initialText,
      noteTitle: noteTitle,
      category: category,
      noteColorValue: noteColorValue,
      noteDate: noteDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoryCardStudioSheet(
      initialText: initialText,
      noteTitle: noteTitle,
      category: category,
      noteColorValue: noteColorValue,
      noteDate: noteDate,
    );
  }
}
