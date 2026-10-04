import 'package:flutter/material.dart';

/// Available layout presentation modes for Story Cards.
enum StoryCardLayoutMode {
  /// Quote Spotlight: Centered, decorative quotation marks, large adaptive typography.
  /// Ideal for punchy excerpts, aphorisms, and short quotes (< 50 words).
  quote('Quote', Icons.format_quote_rounded),

  /// Article Reader: Top-aligned, structured paragraphs, bullet points, checklists,
  /// compact header, and high-density readability.
  /// Ideal for text-heavy notes, takeaways, journal reflections, and summaries (50–300+ words).
  article('Reader', Icons.article_rounded);

  final String label;
  final IconData icon;

  const StoryCardLayoutMode(this.label, this.icon);

  /// Auto-detects the recommended layout mode based on text density and structure.
  static StoryCardLayoutMode autoDetect(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return StoryCardLayoutMode.quote;
    final words = trimmed.split(RegExp(r'\s+')).length;
    final lines = trimmed.split('\n').where((l) => l.trim().isNotEmpty).length;
    final hasListItems = RegExp(r'(^|\n)\s*([*•\-]|\d+\.|\[[ xX]\]|☑|☐)\s+').hasMatch(trimmed);

    // If text has multiple paragraphs, list items, or more than 40 words, default to Reader
    if (words > 40 || lines > 3 || hasListItems || trimmed.contains('\n\n')) {
      return StoryCardLayoutMode.article;
    }
    return StoryCardLayoutMode.quote;
  }
}
