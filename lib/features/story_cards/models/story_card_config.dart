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
  final int currentSlideIndex;
  final int totalSlides;

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
    this.currentSlideIndex = 0,
    this.totalSlides = 1,
  });

  /// Cleans raw markdown/checklist syntax into card-ready typography.
  static String cleanMarkdownForCard(String raw) {
    var cleaned = raw;
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'^(\s*)[-*]\s+\[[xX]\]\s+', multiLine: true),
      (m) => '${m.group(1)}☑ ',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'^(\s*)[-*]\s+\[ \]\s+', multiLine: true),
      (m) => '${m.group(1)}☐ ',
    );
    cleaned = cleaned.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (m) => m.group(1)!,
    );
    return cleaned;
  }

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

  /// Splits [cleanMarkdownForCard(resolvedText)] into readable carousel slides
  /// along paragraph, sentence, and word boundaries.
  List<String> get slides {
    final cleaned = cleanMarkdownForCard(resolvedText).trim();
    if (cleaned.isEmpty) return const [''];

    final maxWords = layoutMode == StoryCardLayoutMode.quote ? 60 : 110;
    if (wordLimit != StoryCardWordLimit.all || countWords(cleaned) <= maxWords) {
      return [cleaned];
    }

    final result = <String>[];
    final buffer = StringBuffer();

    void flushBuffer() {
      final text = buffer.toString().trim();
      if (text.isNotEmpty) {
        result.add(text);
      }
      buffer.clear();
    }

    void appendUnit(String unit, String separator) {
      final trimmedUnit = unit.trim();
      if (trimmedUnit.isEmpty) return;

      final current = buffer.toString().trim();
      if (current.isEmpty) {
        if (countWords(trimmedUnit) <= maxWords) {
          buffer.write(trimmedUnit);
        } else {
          // Split oversized unit by words
          final words = trimmedUnit.split(RegExp(r'\s+'));
          for (final word in words) {
            final cur = buffer.toString().trim();
            final candidate = cur.isEmpty ? word : '$cur $word';
            if (cur.isNotEmpty && countWords(candidate) > maxWords) {
              flushBuffer();
              buffer.write(word);
            } else {
              if (cur.isNotEmpty) buffer.write(' ');
              buffer.write(word);
            }
          }
        }
        return;
      }

      final candidate = '$current$separator$trimmedUnit';
      if (countWords(candidate) <= maxWords) {
        buffer.write(separator);
        buffer.write(trimmedUnit);
      } else {
        flushBuffer();
        appendUnit(trimmedUnit, separator);
      }
    }

    final paragraphs = cleaned.split(RegExp(r'\n\s*\n'));
    for (final paragraph in paragraphs) {
      final trimmedPara = paragraph.trim();
      if (trimmedPara.isEmpty) continue;

      if (countWords(trimmedPara) <= maxWords) {
        appendUnit(trimmedPara, '\n\n');
      } else {
        final lines = trimmedPara.split('\n');
        for (final line in lines) {
          final trimmedLine = line.trim();
          if (trimmedLine.isEmpty) continue;

          if (countWords(trimmedLine) <= maxWords) {
            appendUnit(trimmedLine, '\n');
          } else {
            final sentences = trimmedLine.split(RegExp(r'(?<=[.!?])\s+'));
            for (final sentence in sentences) {
              appendUnit(sentence, ' ');
            }
          }
        }
      }
    }

    flushBuffer();
    return result.isEmpty ? const [''] : result;
  }

  /// Returns the text for the active [currentSlideIndex].
  String get currentSlideText {
    final allSlides = slides;
    return allSlides[currentSlideIndex.clamp(0, allSlides.length - 1)];
  }

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
    int? currentSlideIndex,
    int? totalSlides,
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
      currentSlideIndex: currentSlideIndex ?? this.currentSlideIndex,
      totalSlides: totalSlides ?? this.totalSlides,
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
          showWatermark == other.showWatermark &&
          currentSlideIndex == other.currentSlideIndex &&
          totalSlides == other.totalSlides;

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
        currentSlideIndex,
        totalSlides,
      );
}
