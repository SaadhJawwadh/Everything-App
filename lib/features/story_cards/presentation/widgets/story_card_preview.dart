import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/theme/app_theme.dart';
import '../../models/story_card_aspect_ratio.dart';
import '../../models/story_card_config.dart';
import '../../models/story_card_layout_mode.dart';
import '../../models/story_card_theme.dart';

/// Presentation widget rendering a poster-grade social media card.
///
/// Uses clean typographic hierarchy across three zones:
/// 1. Header zone: sentence-case category + tabular date, plus article title when in Reader mode.
/// 2. Body zone: monumental poster display scaling for short quotes or readable structured article prose.
/// 3. Footer zone: plain typographic attribution / slide count without pill chrome.
class StoryCardPreview extends StatelessWidget {
  final StoryCardConfig config;

  const StoryCardPreview({
    super.key,
    required this.config,
  });

  static const double _minQuoteFontSize = 14.0;
  static const double _minArticleFontSize = 13.0;

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
    final text = config.currentSlideText;
    final isTamil = StoryCardConfig.containsTamil(text);
    final dateStr = DateFormat('MMM d, y').format(config.date);

    final String resolvedFontFamily = _resolveFontFamily(style, isTamil);
    const fontFallback = [
      AppTheme.fontNotoSansTamil,
      AppTheme.fontNotoSerifTamil,
      AppTheme.fontGoogleSansFlex,
      AppTheme.fontInter,
      'sans-serif',
    ];

    return AspectRatio(
      aspectRatio: ratio.ratio,
      child: Container(
        width: ratio.baseLogicalWidth,
        height: ratio.baseLogicalHeight,
        decoration: BoxDecoration(
          color: style.background,
          border: Border.all(color: style.border, width: 1.0),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isStory ? 26.0 : 22.0,
            isStory ? 34.0 : 22.0,
            isStory ? 26.0 : 22.0,
            isStory ? 28.0 : 20.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderZone(
                style: style,
                dateStr: dateStr,
                isStory: isStory,
                isTamil: isTamil,
                fontFamily: resolvedFontFamily,
                fontFallback: fontFallback,
              ),
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
                  child: _buildQuoteBodyZone(
                    text: text,
                    style: style,
                    isStory: isStory,
                    isPortrait: isPortrait,
                    isTamil: isTamil,
                    resolvedFontFamily: resolvedFontFamily,
                    fontFallback: fontFallback,
                  ),
                ),
              _buildFooterZone(
                style: style,
                fontFamily: resolvedFontFamily,
                fontFallback: fontFallback,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveFontFamily(StoryCardThemeStyle style, bool isTamil) {
    switch (config.fontStyle) {
      case StoryCardFontStyle.serif:
        return isTamil ? AppTheme.fontNotoSerifTamil : 'serif';
      case StoryCardFontStyle.sans:
        return isTamil ? AppTheme.fontNotoSansTamil : AppTheme.fontGoogleSansFlex;
      case StoryCardFontStyle.auto:
        if (style.isEditorial) {
          return isTamil ? AppTheme.fontNotoSerifTamil : 'serif';
        } else if (style.isTerminal) {
          return 'monospace';
        }
        return isTamil ? AppTheme.fontNotoSansTamil : AppTheme.fontGoogleSansFlex;
    }
  }

  /// Builds the top header zone using plain typographic hierarchy (no capsule pills or macOS dots).
  Widget _buildHeaderZone({
    required StoryCardThemeStyle style,
    required String dateStr,
    required bool isStory,
    required bool isTamil,
    required String fontFamily,
    required List<String> fontFallback,
  }) {
    final categoryLabel = config.category.trim();
    final metaFontSize = isStory ? 13.0 : 12.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (categoryLabel.isNotEmpty)
              Expanded(
                child: Text(
                  categoryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: metaFontSize,
                    fontWeight: FontWeight.w600,
                    color: style.accent,
                    fontFamily: style.isTerminal ? 'monospace' : AppTheme.fontGoogleSansFlex,
                    fontFamilyFallback: fontFallback,
                  ),
                ),
              )
            else
              const Spacer(),
            if (config.showDate) ...[
              const SizedBox(width: 12),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: metaFontSize,
                  fontWeight: FontWeight.w500,
                  color: style.subtext,
                  fontFamily: style.isTerminal ? 'monospace' : AppTheme.fontGoogleSansFlex,
                  fontFamilyFallback: fontFallback,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
        if (config.showTitle && config.layoutMode == StoryCardLayoutMode.article) ...[
          const SizedBox(height: 10),
          Text(
            config.resolvedTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isStory ? 22.0 : 19.0,
              height: isTamil ? 1.3 : 1.12,
              fontWeight: FontWeight.w700,
              letterSpacing: style.isTerminal ? 0.0 : -0.02 * (isStory ? 22.0 : 19.0),
              color: style.text,
              fontFamily: fontFamily,
              fontFamilyFallback: fontFallback,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          height: 1.0,
          color: style.text.withValues(alpha: 0.14),
        ),
        SizedBox(height: config.layoutMode == StoryCardLayoutMode.article ? 14 : 12),
      ],
    );
  }

  /// Builds the structured reading layout for text-heavy article notes at readable sizes.
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
            fontSize: 15.0,
            color: style.subtext,
            fontFamily: resolvedFontFamily,
            fontFamilyFallback: fontFallback,
          ),
        ),
      );
    }

    final double bodyFontSize =
        (isStory ? 14.5 : (isPortrait ? 13.5 : 13.0)).clamp(_minArticleFontSize, 18.0);
    final double bodyLineHeight = isTamil ? 1.52 : 1.44;

    final rawLines = text.split('\n');
    final List<Widget> blocks = [];

    for (int i = 0; i < rawLines.length; i++) {
      final trimmed = rawLines[i].trim();

      if (trimmed.isEmpty) {
        blocks.add(const SizedBox(height: 7));
        continue;
      }

      if (trimmed.startsWith('# ') || trimmed.startsWith('## ') || trimmed.startsWith('### ')) {
        final headingText = trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 6.0, bottom: 4.0),
            child: Text(
              headingText,
              style: TextStyle(
                fontSize: bodyFontSize + 3.0,
                height: 1.2,
                fontWeight: FontWeight.w700,
                letterSpacing: style.isTerminal ? 0.0 : -0.02 * (bodyFontSize + 3.0),
                color: style.accent,
                fontFamily: resolvedFontFamily,
                fontFamilyFallback: fontFallback,
              ),
            ),
          ),
        );
        continue;
      }

      final isChecked =
          trimmed.startsWith('[x] ') || trimmed.startsWith('[X] ') || trimmed.startsWith('☑ ');
      final isUnchecked = trimmed.startsWith('[ ] ') || trimmed.startsWith('☐ ');

      if (isChecked || isUnchecked) {
        final itemText = trimmed.replaceFirst(RegExp(r'^(\[[ xX]\]|☑|☐)\s*'), '');
        blocks.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2.5),
                  child: Icon(
                    isChecked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: bodyFontSize + 1.5,
                    color: isChecked ? style.accent : style.subtext,
                  ),
                ),
                const SizedBox(width: 8),
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

      final isBullet = trimmed.startsWith('• ') || trimmed.startsWith('- ') || trimmed.startsWith('* ');
      if (isBullet) {
        final itemText = trimmed.replaceFirst(RegExp(r'^[•\-\*]\s*'), '');
        blocks.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(top: bodyFontSize * 0.48, right: 9),
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

      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4.5),
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

    // Keep text at its readable font size without shrink-to-fit distortion or RenderFlex overflow.
    return ClipRect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: blocks,
        ),
      ),
    );
  }

  /// Builds the bottom footer zone with clean typographic hierarchy (no boxed micro-pills).
  Widget _buildFooterZone({
    required StoryCardThemeStyle style,
    required String fontFamily,
    required List<String> fontFallback,
  }) {
    final slideCount = config.slides.length;
    final hasMultiSlides = slideCount > 1;
    if (!config.showWatermark && !hasMultiSlides) {
      return const SizedBox(height: 6);
    }

    final safeSlideIndex = config.currentSlideIndex.clamp(0, slideCount - 1);
    final footerTextStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      color: style.subtext,
      fontFamily: style.isTerminal ? 'monospace' : AppTheme.fontGoogleSansFlex,
      fontFamilyFallback: fontFallback,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: config.showWatermark && hasMultiSlides
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.center,
        children: [
          if (config.showWatermark)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Image.asset(
                    'assets/app_icon_monochrome.png',
                    width: 14,
                    height: 14,
                    cacheWidth: 42,
                    color: style.accent,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.auto_stories_rounded,
                      size: 14,
                      color: style.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text('Everything App', style: footerTextStyle),
              ],
            ),
          if (hasMultiSlides)
            Text(
              '${safeSlideIndex + 1} / $slideCount',
              style: footerTextStyle.copyWith(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }

  /// Builds the poster quote presentation with monumental display scaling for short
  /// excerpts and a strict readability floor for long text.
  Widget _buildQuoteBodyZone({
    required String text,
    required StoryCardThemeStyle style,
    required bool isStory,
    required bool isPortrait,
    required bool isTamil,
    required String resolvedFontFamily,
    required List<String> fontFallback,
  }) {
    final bool isLeftAligned = style.isEditorial || style.isTerminal;
    final bool hasTitleAttribution = config.showTitle && config.resolvedTitle.isNotEmpty;
    final displayQuote = text.isEmpty ? 'No text selected.' : text;

    final _QuoteTypographySpec spec = _resolveQuoteSpec(
      charCount: displayQuote.length,
      isStory: isStory,
      isPortrait: isPortrait,
      isTamil: isTamil,
      isTerminal: style.isTerminal,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double attributionAllowance = hasTitleAttribution ? (isStory ? 44.0 : 38.0) : 0.0;
        final double availableTextWidth =
            (constraints.maxWidth - (isLeftAligned ? 16.0 : 0.0)).clamp(120.0, 400.0);
        final double availableTextHeight =
            (constraints.maxHeight - attributionAllowance - 16.0).clamp(60.0, 600.0);

        final _FittedQuoteResult fitted = _fitQuoteWithinFloor(
          text: displayQuote,
          initialSpec: spec,
          maxWidth: availableTextWidth,
          maxHeight: availableTextHeight,
          isTamil: isTamil,
          isTerminal: style.isTerminal,
          fontFamily: resolvedFontFamily,
          fontFallback: fontFallback,
        );

        final TextStyle quoteTextStyle = TextStyle(
          fontSize: fitted.fontSize,
          height: fitted.lineHeight,
          fontWeight: fitted.fontWeight,
          color: style.text,
          fontFamily: resolvedFontFamily,
          fontFamilyFallback: fontFallback,
          letterSpacing: fitted.letterSpacing,
        );

        final int? maxLines = fitted.exceedsAtFloor
            ? (availableTextHeight / (fitted.fontSize * fitted.lineHeight)).floor().clamp(2, 30)
            : null;

        return Align(
          alignment: isLeftAligned ? Alignment.centerLeft : Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: isLeftAligned ? Alignment.centerLeft : Alignment.center,
            children: [
              Positioned(
                top: isStory ? -6 : -8,
                left: isLeftAligned ? 0 : null,
                child: Text(
                  '“',
                  style: TextStyle(
                    fontSize: isStory ? 72 : 56,
                    height: 0.85,
                    fontFamily: isTamil ? AppTheme.fontNotoSerifTamil : 'serif',
                    fontWeight: FontWeight.w700,
                    color: style.accent.withValues(alpha: 0.14),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    isLeftAligned ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: isLeftAligned
                        ? const EdgeInsets.only(left: 14.0)
                        : EdgeInsets.zero,
                    decoration: isLeftAligned
                        ? BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: style.accent,
                                width: 3.0,
                              ),
                            ),
                          )
                        : null,
                    child: Text(
                      displayQuote,
                      textAlign: isLeftAligned ? TextAlign.left : TextAlign.center,
                      maxLines: maxLines,
                      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
                      style: quoteTextStyle,
                    ),
                  ),
                  if (hasTitleAttribution) ...[
                    SizedBox(height: isStory ? 18.0 : 12.0),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment:
                          isLeftAligned ? MainAxisAlignment.start : MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 16,
                          height: 2,
                          color: style.accent,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            config.resolvedTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isStory ? 13.5 : 13.0,
                              fontWeight: FontWeight.w600,
                              color: style.accent,
                              fontFamily: resolvedFontFamily,
                              fontFamilyFallback: fontFallback,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  _QuoteTypographySpec _resolveQuoteSpec({
    required int charCount,
    required bool isStory,
    required bool isPortrait,
    required bool isTamil,
    required bool isTerminal,
  }) {
    final double fontSize;
    final double lineHeight;
    final FontWeight fontWeight;
    final double trackingFactor;

    if (charCount <= 48) {
      fontSize = isStory ? 44.0 : (isPortrait ? 40.0 : 36.0);
      lineHeight = isTamil ? 1.25 : 0.98;
      fontWeight = FontWeight.w800;
      trackingFactor = -0.03;
    } else if (charCount <= 90) {
      fontSize = isStory ? 38.0 : (isPortrait ? 36.0 : 36.0);
      lineHeight = isTamil ? 1.28 : 1.04;
      fontWeight = FontWeight.w700;
      trackingFactor = -0.03;
    } else if (charCount <= 165) {
      fontSize = isStory ? 26.0 : (isPortrait ? 23.0 : 21.0);
      lineHeight = isTamil ? 1.38 : 1.18;
      fontWeight = FontWeight.w600;
      trackingFactor = -0.02;
    } else if (charCount <= 280) {
      fontSize = isStory ? 20.0 : (isPortrait ? 18.0 : 16.5);
      lineHeight = isTamil ? 1.45 : 1.30;
      fontWeight = FontWeight.w500;
      trackingFactor = -0.015;
    } else {
      fontSize = isStory ? 16.0 : (isPortrait ? 15.0 : 14.5);
      lineHeight = isTamil ? 1.48 : 1.38;
      fontWeight = FontWeight.normal;
      trackingFactor = -0.01;
    }

    return _QuoteTypographySpec(
      fontSize: fontSize,
      lineHeight: lineHeight,
      fontWeight: fontWeight,
      letterSpacing: isTerminal || isTamil ? 0.0 : fontSize * trackingFactor,
    );
  }

  /// Steps font size down only when needed to fit the card viewport, stopping at
  /// [_minQuoteFontSize] so long quotes never collapse below readable bounds.
  _FittedQuoteResult _fitQuoteWithinFloor({
    required String text,
    required _QuoteTypographySpec initialSpec,
    required double maxWidth,
    required double maxHeight,
    required bool isTamil,
    required bool isTerminal,
    required String fontFamily,
    required List<String> fontFallback,
  }) {
    double candidateSize = initialSpec.fontSize;
    final double trackingFactor =
        initialSpec.fontSize > 0 ? initialSpec.letterSpacing / initialSpec.fontSize : 0.0;

    while (candidateSize >= _minQuoteFontSize) {
      final candidateHeightRatio = candidateSize >= 34.0
          ? initialSpec.lineHeight
          : (isTamil ? 1.45 : (candidateSize >= 24.0 ? 1.16 : 1.34));
      final candidateLetterSpacing =
          isTerminal || isTamil ? 0.0 : candidateSize * trackingFactor;

      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: candidateSize,
            height: candidateHeightRatio,
            fontWeight: initialSpec.fontWeight,
            fontFamily: fontFamily,
            fontFamilyFallback: fontFallback,
            letterSpacing: candidateLetterSpacing,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);

      if (painter.height <= maxHeight) {
        return _FittedQuoteResult(
          fontSize: candidateSize,
          lineHeight: candidateHeightRatio,
          fontWeight: initialSpec.fontWeight,
          letterSpacing: candidateLetterSpacing,
          exceedsAtFloor: false,
        );
      }

      if (candidateSize <= _minQuoteFontSize) {
        return _FittedQuoteResult(
          fontSize: _minQuoteFontSize,
          lineHeight: isTamil ? 1.45 : 1.36,
          fontWeight: FontWeight.normal,
          letterSpacing: isTerminal || isTamil ? 0.0 : _minQuoteFontSize * -0.01,
          exceedsAtFloor: true,
        );
      }

      candidateSize = (candidateSize - 2.0).clamp(_minQuoteFontSize, initialSpec.fontSize);
    }

    return _FittedQuoteResult(
      fontSize: _minQuoteFontSize,
      lineHeight: isTamil ? 1.45 : 1.36,
      fontWeight: FontWeight.normal,
      letterSpacing: isTerminal || isTamil ? 0.0 : _minQuoteFontSize * -0.01,
      exceedsAtFloor: true,
    );
  }
}

class _QuoteTypographySpec {
  final double fontSize;
  final double lineHeight;
  final FontWeight fontWeight;
  final double letterSpacing;

  const _QuoteTypographySpec({
    required this.fontSize,
    required this.lineHeight,
    required this.fontWeight,
    required this.letterSpacing,
  });
}

class _FittedQuoteResult {
  final double fontSize;
  final double lineHeight;
  final FontWeight fontWeight;
  final double letterSpacing;
  final bool exceedsAtFloor;

  const _FittedQuoteResult({
    required this.fontSize,
    required this.lineHeight,
    required this.fontWeight,
    required this.letterSpacing,
    required this.exceedsAtFloor,
  });
}
