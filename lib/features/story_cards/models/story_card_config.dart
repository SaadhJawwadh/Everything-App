import 'story_card_aspect_ratio.dart';
import 'story_card_layout_mode.dart';
import 'story_card_theme.dart';

/// Immutable configuration representing all customization options for a Story Card.
class StoryCardConfig {
  final String title;
  final String text;
  final String category;
  final DateTime date;
  final int noteColorValue;
  final StoryCardAspectRatio aspectRatio;
  final StoryCardThemePreset themePreset;
  final StoryCardWordLimit wordLimit;
  final StoryCardFontStyle fontStyle;
  final StoryCardLayoutMode layoutMode;
  final bool showTitle;
  final bool showDate;
  final bool showWatermark;

  const StoryCardConfig({
    required this.title,
    required this.text,
    this.category = 'Note',
    required this.date,
    this.noteColorValue = 0,
    this.aspectRatio = StoryCardAspectRatio.story,
    this.themePreset = StoryCardThemePreset.editorial,
    this.wordLimit = StoryCardWordLimit.all,
    this.fontStyle = StoryCardFontStyle.auto,
    this.layoutMode = StoryCardLayoutMode.quote,
    this.showTitle = true,
    this.showDate = true,
    this.showWatermark = false,
  });

  /// Detects if text contains Tamil characters for language-aware font selection.
  static bool containsTamil(String input) {
    return RegExp(r'[\u0B80-\u0BFF]').hasMatch(input);
  }

  /// Counts the total number of whitespace-delimited words.
  static int countWords(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  /// Resolves the display quote text applying the selected [wordLimit].
  String get resolvedText {
    final trimmed = text.trim();
    final maxWords = wordLimit.maxWords;
    if (maxWords == null || trimmed.isEmpty) return trimmed;
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length <= maxWords) return trimmed;
    return '${words.take(maxWords).join(' ')}...';
  }

  /// Resolves an authentic display title, guaranteeing a non-empty header title.
  String get resolvedTitle {
    final trimmed = title.trim();
    if (trimmed.isNotEmpty) return trimmed;

    // Fallback to first line of text or 'Reflection'
    final lines = text.trim().split('\n');
    for (final line in lines) {
      final clean = line.replaceAll(RegExp(r'^[#*>\-\s]+'), '').trim();
      if (clean.isNotEmpty) {
        final words = clean.split(RegExp(r'\s+'));
        if (words.length > 5) {
          return '${words.take(5).join(' ')}...';
        }
        return clean;
      }
    }
    return 'Reflection';
  }

  /// Total word count of the original raw text.
  int get totalWordCount => countWords(text);

  /// Word count of the currently resolved/truncated text.
  int get displayedWordCount => countWords(resolvedText);

  /// Creates a copy with modified fields.
  StoryCardConfig copyWith({
    String? title,
    String? text,
    String? category,
    DateTime? date,
    int? noteColorValue,
    StoryCardAspectRatio? aspectRatio,
    StoryCardThemePreset? themePreset,
    StoryCardWordLimit? wordLimit,
    StoryCardFontStyle? fontStyle,
    StoryCardLayoutMode? layoutMode,
    bool? showTitle,
    bool? showDate,
    bool? showWatermark,
  }) {
    return StoryCardConfig(
      title: title ?? this.title,
      text: text ?? this.text,
      category: category ?? this.category,
      date: date ?? this.date,
      noteColorValue: noteColorValue ?? this.noteColorValue,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      themePreset: themePreset ?? this.themePreset,
      wordLimit: wordLimit ?? this.wordLimit,
      fontStyle: fontStyle ?? this.fontStyle,
      layoutMode: layoutMode ?? this.layoutMode,
      showTitle: showTitle ?? this.showTitle,
      showDate: showDate ?? this.showDate,
      showWatermark: showWatermark ?? this.showWatermark,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryCardConfig &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          text == other.text &&
          category == other.category &&
          date == other.date &&
          noteColorValue == other.noteColorValue &&
          aspectRatio == other.aspectRatio &&
          themePreset == other.themePreset &&
          wordLimit == other.wordLimit &&
          fontStyle == other.fontStyle &&
          layoutMode == other.layoutMode &&
          showTitle == other.showTitle &&
          showDate == other.showDate &&
          showWatermark == other.showWatermark;

  @override
  int get hashCode => Object.hash(
        title,
        text,
        category,
        date,
        noteColorValue,
        aspectRatio,
        themePreset,
        wordLimit,
        fontStyle,
        layoutMode,
        showTitle,
        showDate,
        showWatermark,
      );
}
