import 'package:flutter/material.dart';

/// Visual theme presets for the Story Card.
///
/// Enum identifiers are preserved for backward compatibility with persisted
/// user preferences while providing art-directed poster palettes.
enum StoryCardThemePreset {
  editorial('Gallery', Icons.crop_portrait_rounded),
  obsidianAura('Forest', Icons.park_outlined),
  velvetOled('Cobalt', Icons.palette_outlined),
  frostedGlassLuxe('Silver', Icons.layers_outlined),
  noteTint('Note Tint', Icons.color_lens_outlined),
  terminal('Terminal', Icons.terminal_rounded);

  final String label;
  final IconData icon;
  const StoryCardThemePreset(this.label, this.icon);
}

/// Resolved color and typographic styling properties for a Story Card theme.
class StoryCardThemeStyle {
  final Color background;
  final Color text;
  final Color accent;
  final Color subtext;
  final Color border;
  final bool isEditorial;
  final bool isTerminal;

  const StoryCardThemeStyle({
    required this.background,
    required this.text,
    required this.accent,
    required this.subtext,
    required this.border,
    this.isEditorial = false,
    this.isTerminal = false,
  });

  /// Resolves the concrete [StoryCardThemeStyle] given the preset, app theme,
  /// and optional note color.
  factory StoryCardThemeStyle.resolve({
    required StoryCardThemePreset preset,
    required ThemeData appTheme,
    int noteColorValue = 0,
  }) {
    switch (preset) {
      case StoryCardThemePreset.editorial:
        return const StoryCardThemeStyle(
          background: Color(0xFFF7F8FA),
          text: Color(0xFF0E1116),
          accent: Color(0xFFC82E16),
          subtext: Color(0xFF4B5362),
          border: Color(0xFFD8DDE6),
          isEditorial: true,
        );

      case StoryCardThemePreset.obsidianAura:
        return const StoryCardThemeStyle(
          background: Color(0xFF0A2219),
          text: Color(0xFFF2F6F3),
          accent: Color(0xFFC5EE6B),
          subtext: Color(0xFF9CB5A8),
          border: Color(0xFF1B3D2F),
        );

      case StoryCardThemePreset.velvetOled:
        return const StoryCardThemeStyle(
          background: Color(0xFF1239D6),
          text: Color(0xFFFFFFFF),
          accent: Color(0xFFFFE14D),
          subtext: Color(0xFFD4E0FF),
          border: Color(0xFF2E56EE),
        );

      case StoryCardThemePreset.frostedGlassLuxe:
        return const StoryCardThemeStyle(
          background: Color(0xFFE1E4E9),
          text: Color(0xFF101318),
          accent: Color(0xFF1239D6),
          subtext: Color(0xFF434B58),
          border: Color(0xFFC2C8D2),
        );

      case StoryCardThemePreset.noteTint:
        final seedColor = noteColorValue != 0
            ? Color(noteColorValue)
            : appTheme.colorScheme.primaryContainer;
        final isBright = seedColor.computeLuminance() > 0.42;
        final textColor = isBright
            ? const Color(0xFF0E1116)
            : const Color(0xFFF6F7F9);
        final hsl = HSLColor.fromColor(seedColor);
        final Color accentColor;
        if (hsl.saturation < 0.14) {
          accentColor = isBright
              ? const Color(0xFF1239D6)
              : const Color(0xFFFF5E3A);
        } else {
          accentColor = hsl
              .withLightness(isBright ? 0.24 : 0.82)
              .withSaturation((hsl.saturation + 0.15).clamp(0.45, 0.92))
              .toColor();
        }
        return StoryCardThemeStyle(
          background: seedColor,
          text: textColor,
          accent: accentColor,
          subtext: textColor.withValues(alpha: 0.74),
          border: textColor.withValues(alpha: 0.16),
        );

      case StoryCardThemePreset.terminal:
        return const StoryCardThemeStyle(
          background: Color(0xFF0B0D12),
          text: Color(0xFFF1F3F5),
          accent: Color(0xFFFF5E3A),
          subtext: Color(0xFF9BA3B2),
          border: Color(0xFF222733),
          isTerminal: true,
        );
    }
  }
}
