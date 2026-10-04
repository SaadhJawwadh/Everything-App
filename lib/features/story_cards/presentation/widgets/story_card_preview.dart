import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/story_card_aspect_ratio.dart';
import '../../models/story_card_config.dart';
import '../../models/story_card_layout_mode.dart';
import '../../models/story_card_theme.dart';

/// Presentation widget rendering a publication-grade social media card.
///
/// Implements a strict 3-Zone structured layout:
/// 1. Top Header Zone: Category badge + Date (top line) and Note Title (second line).
/// 2. Center Body Zone: Adaptive typography quote with theme accents.
/// 3. Bottom Footer Zone: Centered watermark micro-pill with monochrome app emblem.
class StoryCardPreview extends StatelessWidget {
  final StoryCardConfig config;

  const StoryCardPreview({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = StoryCardThemeStyle.resolve(
      preset: config.themePreset,
      appTheme: theme,
      noteColorValue: config.noteColorValue,
    );

    final ratio = config.aspectRatio;
    final isStory = ratio == StoryCardAspectRatio.story;
    final isPortrait = ratio == StoryCardAspectRatio.portrait;
    final text = config.resolvedText;
    final isTamil = StoryCardConfig.containsTamil(text);
    final dateStr = DateFormat('MMM d, y').format(config.date);

    // Resolve font family
    String resolvedFontFamily;
    switch (config.fontStyle) {
      case StoryCardFontStyle.serif:
        resolvedFontFamily = isTamil ? AppTheme.fontNotoSerifTamil : 'serif';
        break;
      case StoryCardFontStyle.sans:
        resolvedFontFamily = isTamil ? AppTheme.fontNotoSansTamil : AppTheme.fontGoogleSansFlex;
        break;
      case StoryCardFontStyle.auto:
        if (style.isEditorial) {
          resolvedFontFamily = isTamil ? AppTheme.fontNotoSerifTamil : 'serif';
        } else if (style.isTerminal) {
          resolvedFontFamily = 'monospace';
        } else {
          resolvedFontFamily = isTamil ? AppTheme.fontNotoSansTamil : AppTheme.fontGoogleSansFlex;
        }
        break;
    }

    const fontFallback = [
      AppTheme.fontNotoSansTamil,
      AppTheme.fontNotoSerifTamil,
      AppTheme.fontGoogleSansFlex,
      AppTheme.fontInter,
      'sans-serif',
    ];

    // Adaptive typography sizing optimized for canvas dimensions
    final charCount = text.length;
    double fontSize;
    double lineHeight;
    FontWeight fontWeight;

    if (charCount < 60) {
      fontSize = isStory ? 24.0 : (isPortrait ? 21.0 : 19.0);
      lineHeight = isTamil ? 1.55 : 1.38;
      fontWeight = FontWeight.bold;
    } else if (charCount < 140) {
      fontSize = isStory ? 18.5 : (isPortrait ? 16.0 : 15.0);
      lineHeight = isTamil ? 1.55 : 1.42;
      fontWeight = FontWeight.w600;
    } else if (charCount < 300) {
      fontSize = isStory ? 15.0 : (isPortrait ? 13.5 : 12.5);
      lineHeight = isTamil ? 1.55 : 1.45;
      fontWeight = FontWeight.w500;
    } else if (charCount < 500) {
      fontSize = isStory ? 13.0 : (isPortrait ? 11.5 : 11.0);
      lineHeight = isTamil ? 1.5 : 1.4;
      fontWeight = FontWeight.normal;
    } else {
      fontSize = isStory ? 11.5 : (isPortrait ? 10.5 : 10.0);
      lineHeight = isTamil ? 1.45 : 1.35;
      fontWeight = FontWeight.normal;
    }

    return AspectRatio(
      aspectRatio: ratio.ratio,
      child: Container(
        width: ratio.baseLogicalWidth,
        height: ratio.baseLogicalHeight,
        decoration: BoxDecoration(
          color: style.background,
          border: Border.all(color: style.border, width: 1.0),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background ambient aura or luminous spheres
            if (style.hasAuraGlow && style.auraColors != null)
              _buildAmbientBackground(style.auraColors!, style.isFrostedGlass),

            // Card content container
            Padding(
              padding: EdgeInsets.fromLTRB(
                isStory ? 24.0 : 20.0,
                isStory ? 34.0 : 22.0, // Top safe margin for social status bar/chrome
                isStory ? 24.0 : 20.0,
                isStory ? 28.0 : 20.0, // Bottom safe margin for reply/chat bar
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ==========================================
                  // 1. TOP HEADER ZONE (Strictly on top)
                  // ==========================================
                  _buildHeaderZone(
                    context: context,
                    style: style,
                    dateStr: dateStr,
                    fontFamily: resolvedFontFamily,
                    fontFallback: fontFallback,
                  ),

                  // ==========================================
                  // 2. CENTER BODY ZONE
                  // ==========================================
                  if (config.layoutMode == StoryCardLayoutMode.article)
                    Expanded(
                      child: _buildArticleBodyZone(
                        text: text,
                        style: style,
                        isStory: isStory,
                        isPortrait: isPortrait,
                        isTamil: isTamil,
                        resolvedFontFamily: resolvedFontFamily,
                        fontFallback: fontFallback,
                      ),
                    )
                  else
                    Expanded(
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Decorative quotation mark in Editorial theme
                            if (style.isEditorial)
                              Positioned(
                                top: 0,
                                left: 0,
                                child: Text(
                                  '“',
                                  style: TextStyle(
                                    fontSize: 48,
                                    height: 0.7,
                                    fontFamily: 'serif',
                                    fontWeight: FontWeight.bold,
                                    color: style.accent.withValues(alpha: 0.22),
                                  ),
                                ),
                              ),

                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isStory ? 14.0 : 10.0,
                                vertical: 8.0,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: style.isEditorial
                                    ? Alignment.centerLeft
                                    : Alignment.center,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: isStory ? 310.0 : (isPortrait ? 280.0 : 260.0),
                                  ),
                                  child: Text(
                                    text.isEmpty ? 'No text selected.' : text,
                                    textAlign: style.isEditorial
                                        ? TextAlign.left
                                        : TextAlign.center,
                                    style: TextStyle(
                                      fontSize: fontSize,
                                      height: lineHeight,
                                      fontWeight: fontWeight,
                                      color: style.text,
                                      fontFamily: resolvedFontFamily,
                                      fontFamilyFallback: fontFallback,
                                      letterSpacing: style.isTerminal
                                          ? 0.0
                                          : (isTamil ? 0.3 : -0.2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ==========================================
                  // 3. BOTTOM FOOTER ZONE (Watermark only)
                  // ==========================================
                  _buildFooterZone(style),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the top header zone with category pill, date, and note title.
  Widget _buildHeaderZone({
    required BuildContext context,
    required StoryCardThemeStyle style,
    required String dateStr,
    required String fontFamily,
    required List<String> fontFallback,
  }) {
    if (style.isTerminal) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            _buildTerminalDot(const Color(0xFFFF5F56)),
            const SizedBox(width: 6),
            _buildTerminalDot(const Color(0xFFFFBD2E)),
            const SizedBox(width: 6),
            _buildTerminalDot(const Color(0xFF27C93F)),
            const Spacer(),
            if (config.showDate)
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 10,
                  color: style.subtext,
                  fontFamily: 'monospace',
                  fontFamilyFallback: fontFallback,
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Line 1: Category Tag Pill on Left + Formatted Date on Right
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Category Badge Pill
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: style.categoryBg,
                  borderRadius: BorderRadius.circular(AppLayout.radiusS),
                ),
                child: Text(
                  config.category.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: style.categoryText,
                    fontFamily: AppTheme.fontInter,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Formatted Date (always placed in the top header line)
            if (config.showDate)
              Text(
                dateStr.toUpperCase(),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: style.subtext,
                  fontFamily: fontFamily,
                  fontFamilyFallback: fontFallback,
                ),
              ),
          ],
        ),

        // Line 2: Note Title (if enabled)
        if (config.showTitle) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 3,
                height: 13,
                decoration: BoxDecoration(
                  color: style.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  config.resolvedTitle.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: style.accent,
                    fontFamily: fontFamily,
                    fontFamilyFallback: fontFallback,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (config.layoutMode == StoryCardLayoutMode.article) ...[
          const SizedBox(height: 8),
          Container(
            height: 1.0,
            color: style.accent.withValues(alpha: 0.22),
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }

  /// Builds the structured reading layout for text-heavy article notes.
  Widget _buildArticleBodyZone({
    required String text,
    required StoryCardThemeStyle style,
    required bool isStory,
    required bool isPortrait,
    required bool isTamil,
    required String resolvedFontFamily,
    required List<String> fontFallback,
  }) {
    if (text.isEmpty) {
      return Center(
        child: Text(
          'No text selected.',
          style: TextStyle(
            fontSize: 14,
            color: style.subtext,
            fontFamily: resolvedFontFamily,
            fontFamilyFallback: fontFallback,
          ),
        ),
      );
    }

    final double bodyFontSize = isStory ? 13.5 : (isPortrait ? 12.0 : 11.0);
    final double bodyLineHeight = isTamil ? 1.55 : 1.48;

    final rawLines = text.split('\n');
    final List<Widget> blocks = [];

    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        blocks.add(const SizedBox(height: 6));
        continue;
      }

      // Heading detection: # Heading or ## Heading
      if (trimmed.startsWith('# ') || trimmed.startsWith('## ') || trimmed.startsWith('### ')) {
        final headingText = trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 6.0, bottom: 3.0),
            child: Text(
              headingText,
              style: TextStyle(
                fontSize: bodyFontSize + 2.5,
                fontWeight: FontWeight.bold,
                color: style.accent,
                fontFamily: resolvedFontFamily,
                fontFamilyFallback: fontFallback,
              ),
            ),
          ),
        );
        continue;
      }

      // Checklist item detection: [x], [X], ☑, [ ], ☐
      final isChecked = trimmed.startsWith('[x] ') || trimmed.startsWith('[X] ') || trimmed.startsWith('☑ ');
      final isUnchecked = trimmed.startsWith('[ ] ') || trimmed.startsWith('☐ ');

      if (isChecked || isUnchecked) {
        final itemText = trimmed.replaceFirst(RegExp(r'^(\[[ xX]\]|☑|☐)\s*'), '');
        blocks.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Icon(
                    isChecked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: bodyFontSize + 1,
                    color: isChecked ? (style.isEditorial ? style.accent : Colors.green) : style.subtext,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    itemText,
                    style: TextStyle(
                      fontSize: bodyFontSize,
                      height: bodyLineHeight,
                      fontWeight: FontWeight.normal,
                      color: isChecked ? style.subtext : style.text,
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                      fontFamily: resolvedFontFamily,
                      fontFamilyFallback: fontFallback,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Bullet item detection: •, -, *
      final isBullet = trimmed.startsWith('• ') || trimmed.startsWith('- ') || trimmed.startsWith('* ');
      if (isBullet) {
        final itemText = trimmed.replaceFirst(RegExp(r'^[•\-\*]\s*'), '');
        blocks.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(top: bodyFontSize * 0.45, right: 8),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: style.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    itemText,
                    style: TextStyle(
                      fontSize: bodyFontSize,
                      height: bodyLineHeight,
                      fontWeight: FontWeight.normal,
                      color: style.text,
                      fontFamily: resolvedFontFamily,
                      fontFamilyFallback: fontFallback,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Standard body paragraph
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 3.5),
          child: Text(
            trimmed,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: bodyFontSize,
              height: bodyLineHeight,
              fontWeight: FontWeight.normal,
              color: style.text,
              fontFamily: resolvedFontFamily,
              fontFamilyFallback: fontFallback,
              letterSpacing: style.isTerminal ? 0.0 : (isTamil ? 0.2 : -0.1),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth,
                minWidth: constraints.maxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: blocks,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the bottom footer zone with the centered watermark badge.
  Widget _buildFooterZone(StoryCardThemeStyle style) {
    if (!config.showWatermark) {
      return const SizedBox(height: 8);
    }

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
          decoration: BoxDecoration(
            color: style.text.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: style.text.withValues(alpha: 0.12),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Image.asset(
                  'assets/app_icon_monochrome.png',
                  width: 12,
                  height: 12,
                  cacheWidth: 36,
                  color: style.accent,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Everything App',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: style.subtext,
                  fontFamily: AppTheme.fontInter,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds ambient background aura gradient or glowing spheres.
  Widget _buildAmbientBackground(List<Color> colors, bool isFrosted) {
    if (isFrosted) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Luminous orb 1 (top right)
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.first,
                    colors.first.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Luminous orb 2 (bottom left)
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.length > 1 ? colors[1] : colors.first,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Specular glass rim overlay
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.0,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Default radial aura glow centered behind quote
    return Center(
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: colors,
            radius: 0.75,
          ),
        ),
      ),
    );
  }

  Widget _buildTerminalDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
