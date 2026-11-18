import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/app_haptics.dart';

import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../core/ui/app_snack_bar.dart';
import '../../../../services/hybrid_local_ai_service.dart';
import '../../models/story_card_aspect_ratio.dart';
import '../../models/story_card_config.dart';
import '../../models/story_card_layout_mode.dart';
import '../../models/story_card_theme.dart';
import '../../services/story_card_media_service.dart';
import '../../services/story_card_render_service.dart';
import 'story_card_preview.dart';

/// Full-featured interactive studio modal to preview, customize, and export
/// note excerpts into publication-grade social media cards.
class StoryCardStudioSheet extends StatefulWidget {
  final String initialText;
  final String noteTitle;
  final String category;
  final int noteColorValue;
  final DateTime noteDate;

  const StoryCardStudioSheet({
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
    return AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      child: StoryCardStudioSheet(
        initialText: initialText,
        noteTitle: noteTitle,
        category: category,
        noteColorValue: noteColorValue,
        noteDate: noteDate,
      ),
    );
  }

  @override
  State<StoryCardStudioSheet> createState() => _StoryCardStudioSheetState();
}

class _StoryCardStudioSheetState extends State<StoryCardStudioSheet> {
  static const String _prefAspectKey = 'story_pref_aspect';
  static const String _prefThemeKey = 'story_pref_theme';
  static const String _prefFontKey = 'story_pref_font';
  static const String _prefWatermarkKey = 'story_pref_watermark';

  final GlobalKey _repaintKey = GlobalKey();
  final StoryCardRenderService _renderService = const StoryCardRenderService();
  final StoryCardMediaService _mediaService = const StoryCardMediaService();

  late TextEditingController _textController;
  late TextEditingController _titleController;

  late StoryCardConfig _config;
  bool _isExporting = false;
  bool _isEditingText = false;
  bool _isSummarizing = false;
  String? _feedbackMessage;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    final trimmedText = widget.initialText.trim();
    _textController = TextEditingController(text: trimmedText);
    _titleController = TextEditingController(text: widget.noteTitle.trim());

    final autoLayoutMode = StoryCardLayoutMode.autoDetect(trimmedText);

    final initialConfig = StoryCardConfig(
      title: widget.noteTitle.trim(),
      text: trimmedText,
      category: widget.category.isNotEmpty ? widget.category : 'Note',
      date: widget.noteDate,
      noteColorValue: widget.noteColorValue,
      aspectRatio: StoryCardAspectRatio.story,
      themePreset: StoryCardThemePreset.editorial,
      wordLimit: StoryCardWordLimit.all,
      fontStyle: StoryCardFontStyle.auto,
      layoutMode: autoLayoutMode,
      showTitle: true,
      showDate: true,
      showWatermark: false,
    );
    _config = initialConfig.copyWith(totalSlides: initialConfig.slides.length);
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final savedAspect = prefs.getString(_prefAspectKey);
      final savedTheme = prefs.getString(_prefThemeKey);
      final savedFont = prefs.getString(_prefFontKey);
      final savedWatermark = prefs.getBool(_prefWatermarkKey);

      final aspect = savedAspect != null
          ? StoryCardAspectRatio.values.where((e) => e.name == savedAspect).firstOrNull
          : null;
      final theme = savedTheme != null
          ? StoryCardThemePreset.values.where((e) => e.name == savedTheme).firstOrNull
          : null;
      final font = savedFont != null
          ? StoryCardFontStyle.values.where((e) => e.name == savedFont).firstOrNull
          : null;

      if (aspect != null || theme != null || font != null || savedWatermark != null) {
        setState(() {
          _updateConfig(_config.copyWith(
            aspectRatio: aspect ?? _config.aspectRatio,
            themePreset: theme ?? _config.themePreset,
            fontStyle: font ?? _config.fontStyle,
            showWatermark: savedWatermark ?? _config.showWatermark,
          ));
        });
      }
    } catch (_) {}
  }

  Future<void> _savePreference({
    StoryCardAspectRatio? aspectRatio,
    StoryCardThemePreset? themePreset,
    StoryCardFontStyle? fontStyle,
    bool? showWatermark,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (aspectRatio != null) {
        await prefs.setString(_prefAspectKey, aspectRatio.name);
      }
      if (themePreset != null) {
        await prefs.setString(_prefThemeKey, themePreset.name);
      }
      if (fontStyle != null) {
        await prefs.setString(_prefFontKey, fontStyle.name);
      }
      if (showWatermark != null) {
        await prefs.setBool(_prefWatermarkKey, showWatermark);
      }
    } catch (_) {}
  }

  void _updateConfig(StoryCardConfig next) {
    final slides = next.slides;
    final clampedIndex = next.currentSlideIndex.clamp(0, slides.length - 1);
    _config = next.copyWith(
      currentSlideIndex: clampedIndex,
      totalSlides: slides.length,
    );
  }

  Future<void> _applyAiHighlight() async {
    if (_isSummarizing) return;
    AppHaptics.selectionClick();
    setState(() => _isSummarizing = true);
    try {
      final summary = await HybridLocalAiService().summarize(_config.text);
      if (!mounted) return;
      if (summary != null && summary.trim().isNotEmpty) {
        final cleaned = summary
            .split('\n')
            .map((line) => line.replaceFirst(RegExp(r'^\s*[-*•]\s+'), '').trim())
            .where((line) => line.isNotEmpty)
            .join(' ');
        if (cleaned.isNotEmpty) {
          setState(() {
            _textController.text = cleaned;
            _updateConfig(_config.copyWith(text: cleaned, currentSlideIndex: 0));
          });
          _setFeedback('AI Highlight applied');
        }
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(context, message: 'Could not generate AI highlight');
      }
    } finally {
      if (mounted) setState(() => _isSummarizing = false);
    }
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _setFeedback(String message) {
    _feedbackTimer?.cancel();
    if (mounted) {
      setState(() => _feedbackMessage = message);
      _feedbackTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _feedbackMessage = null);
        }
      });
    }
  }

  Future<Uint8List?> _captureCard() async {
    return await _renderService.capturePng(_repaintKey, pixelRatio: 3.5);
  }

  Future<void> _shareCard() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    AppHaptics.mediumImpact();

    try {
      final bytes = await _captureCard();
      if (bytes == null || !mounted) {
        if (mounted) AppSnackBar.showError(context, message: 'Could not generate story image');
        return;
      }

      await _mediaService.shareImage(
        bytes,
        title: _config.resolvedTitle,
      );
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: 'Sharing failed: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _saveCardToGallery() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    AppHaptics.mediumImpact();

    try {
      final bytes = await _captureCard();
      if (bytes == null || !mounted) {
        if (mounted) AppSnackBar.showError(context, message: 'Could not generate story image');
        return;
      }

      final savedPath = await _mediaService.saveImageToGallery(bytes);
      if (mounted) {
        if (savedPath != null) {
          _setFeedback('Saved to Gallery in Pictures/EverythingApp');
          AppSnackBar.showSuccess(
            context,
            message: 'Saved to Gallery in $savedPath',
          );
        } else {
          AppSnackBar.showError(context, message: 'Failed to save image to gallery');
        }
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: 'Failed to save image: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _copyImageToClipboard() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    AppHaptics.selectionClick();

    try {
      final bytes = await _captureCard();
      if (bytes == null || !mounted) {
        if (mounted) AppSnackBar.showError(context, message: 'Could not render image for clipboard');
        return;
      }

      final success = await _mediaService.copyImageToClipboard(
        bytes,
        fallbackText: _config.resolvedText,
      );

      if (mounted) {
        if (success) {
          _setFeedback('Story image copied to clipboard!');
          AppSnackBar.showSuccess(
            context,
            message: 'Story image copied to clipboard! Ready to paste.',
          );
        } else {
          _setFeedback('Quote text copied to clipboard');
          AppSnackBar.show(
            context,
            message: 'Quote text copied to clipboard',
            icon: Icons.copy_rounded,
          );
        }
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: 'Clipboard copy failed: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.88;

    // Card preview viewport sizing
    final previewHeight = _config.aspectRatio == StoryCardAspectRatio.story
        ? 340.0
        : (_config.aspectRatio == StoryCardAspectRatio.portrait ? 300.0 : 260.0);
    final previewWidth = previewHeight * _config.aspectRatio.ratio;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppLayout.spaceL,
          AppLayout.spaceXS,
          AppLayout.spaceL,
          mediaQuery.viewInsets.bottom + AppLayout.spaceL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sheet Header: Title & Edit Note Text Toggle
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 20, color: colorScheme.primary),
                const SizedBox(width: AppLayout.spaceS),
                Expanded(
                  child: Text(
                    'Story Card Studio',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    AppHaptics.selectionClick();
                    setState(() => _isEditingText = !_isEditingText);
                  },
                  icon: Icon(
                    _isEditingText ? Icons.visibility_rounded : Icons.edit_note_rounded,
                    size: 17,
                  ),
                  label: Text(_isEditingText ? 'Preview' : 'Edit Text'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            if (_config.totalWordCount > 30) ...[
              const SizedBox(height: AppLayout.spaceXS),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: _isSummarizing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.auto_awesome_rounded,
                          size: 15,
                          color: colorScheme.primary,
                        ),
                  label: Text(
                    _isSummarizing ? 'Distilling...' : 'AI Highlight',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onPressed: _isSummarizing ? null : _applyAiHighlight,
                ),
              ),
            ],
            const SizedBox(height: AppLayout.spaceS),

            // Optional Text & Title Editor Box
            if (_isEditingText) ...[
              Container(
                padding: const EdgeInsets.all(AppLayout.spaceM),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppLayout.radiusM),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _titleController,
                      style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Card Title',
                        hintText: 'Enter title...',
                        isDense: true,
                        border: UnderlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _config = _config.copyWith(title: val.trim());
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _textController,
                      maxLines: 4,
                      style: textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        labelText: 'Quote Text',
                        isDense: true,
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _updateConfig(_config.copyWith(text: val));
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppLayout.spaceM),
            ],

            // Centered Live Card Preview (Rendered at canonical master resolution, scaled down for preview)
            Center(
              child: SizedBox(
                width: previewWidth,
                height: previewHeight,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _config.aspectRatio.baseLogicalWidth,
                    height: _config.aspectRatio.baseLogicalHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppLayout.radiusM),
                      child: RepaintBoundary(
                        key: _repaintKey,
                        child: StoryCardPreview(config: _config),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_config.slides.length > 1) ...[
              const SizedBox(height: AppLayout.spaceS),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _config.currentSlideIndex > 0
                          ? () {
                              AppHaptics.selectionClick();
                              setState(() {
                                _updateConfig(_config.copyWith(
                                  currentSlideIndex: _config.currentSlideIndex - 1,
                                ));
                              });
                            }
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                      tooltip: 'Previous slide',
                      visualDensity: VisualDensity.compact,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppLayout.radiusM),
                      ),
                      child: Text(
                        'Slide ${_config.currentSlideIndex + 1} of ${_config.slides.length}',
                        style: textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _config.currentSlideIndex < _config.slides.length - 1
                          ? () {
                              AppHaptics.selectionClick();
                              setState(() {
                                _updateConfig(_config.copyWith(
                                  currentSlideIndex: _config.currentSlideIndex + 1,
                                ));
                              });
                            }
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                      tooltip: 'Next slide',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppLayout.spaceM),

            // Controls 0: Layout Mode Switcher (Quote vs Reader)
            Center(
              child: SegmentedButton<StoryCardLayoutMode>(
                segments: StoryCardLayoutMode.values.map((mode) {
                  return ButtonSegment(
                    value: mode,
                    label: Text(mode.label, style: const TextStyle(fontSize: 11)),
                    icon: Icon(mode.icon, size: 14),
                  );
                }).toList(),
                selected: {_config.layoutMode},
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onSelectionChanged: (set) {
                  AppHaptics.selectionClick();
                  setState(() {
                    _updateConfig(_config.copyWith(
                      layoutMode: set.first,
                    ));
                  });
                },
              ),
            ),
            const SizedBox(height: AppLayout.spaceS),

            // Controls 1: Aspect Ratio Selector
            Center(
              child: SegmentedButton<StoryCardAspectRatio>(
                segments: StoryCardAspectRatio.values.map((ratio) {
                  return ButtonSegment(
                    value: ratio,
                    label: Text(ratio.label, style: const TextStyle(fontSize: 11)),
                    icon: Icon(ratio.icon, size: 14),
                  );
                }).toList(),
                selected: {_config.aspectRatio},
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onSelectionChanged: (set) {
                  AppHaptics.selectionClick();
                  final nextRatio = set.first;
                  setState(() => _config = _config.copyWith(aspectRatio: nextRatio));
                  _savePreference(aspectRatio: nextRatio);
                },
              ),
            ),
            const SizedBox(height: AppLayout.spaceM),

            // Controls 2: Typography Font Style Switcher
            Text(
              'TYPOGRAPHY STYLE',
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: StoryCardFontStyle.values.map((style) {
                  final isSelected = _config.fontStyle == style;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: FilterChip(
                      showCheckmark: false,
                      label: Text(
                        style.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (_) {
                        AppHaptics.selectionClick();
                        setState(() => _config = _config.copyWith(fontStyle: style));
                        _savePreference(fontStyle: style);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppLayout.spaceM),

            // Controls 4: Visual Theme Presets
            Text(
              'VISUAL THEME',
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: StoryCardThemePreset.values.map((preset) {
                  final isSelected = _config.themePreset == preset;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      showCheckmark: false,
                      avatar: Icon(
                        preset.icon,
                        size: 15,
                        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      ),
                      label: Text(
                        preset.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (_) {
                        AppHaptics.selectionClick();
                        setState(() => _config = _config.copyWith(themePreset: preset));
                        _savePreference(themePreset: preset);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppLayout.spaceM),

            // Controls 5: Elements & Toggles (Title, Date, Watermark)
            Row(
              children: [
                FilterChip(
                  showCheckmark: false,
                  label: Text(
                    'Title',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: _config.showTitle ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  avatar: Icon(
                    Icons.title_rounded,
                    size: 15,
                    color: _config.showTitle ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                  selected: _config.showTitle,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (val) {
                    AppHaptics.selectionClick();
                    setState(() => _config = _config.copyWith(showTitle: val));
                  },
                ),
                const SizedBox(width: 6),
                FilterChip(
                  showCheckmark: false,
                  label: Text(
                    'Date',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: _config.showDate ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  avatar: Icon(
                    Icons.event_outlined,
                    size: 15,
                    color: _config.showDate ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                  selected: _config.showDate,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (val) {
                    AppHaptics.selectionClick();
                    setState(() => _config = _config.copyWith(showDate: val));
                  },
                ),
                const SizedBox(width: 6),
                FilterChip(
                  showCheckmark: false,
                  label: Text(
                    'Watermark',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: _config.showWatermark ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  avatar: Icon(
                    Icons.verified_outlined,
                    size: 15,
                    color: _config.showWatermark ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                  selected: _config.showWatermark,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (val) {
                    AppHaptics.selectionClick();
                    setState(() => _config = _config.copyWith(showWatermark: val));
                    _savePreference(showWatermark: val);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppLayout.spaceM),

            // In-Sheet Live Feedback Banner
            AnimatedSwitcher(
              duration: AppLayout.animModal,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(sizeFactor: animation, child: child),
              ),
              child: _feedbackMessage != null
                  ? Container(
                      key: ValueKey<String>(_feedbackMessage!),
                      margin: const EdgeInsets.only(bottom: AppLayout.spaceM),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppLayout.spaceM,
                        vertical: AppLayout.spaceS,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppLayout.radiusM),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.4),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: AppLayout.spaceS),
                          Flexible(
                            child: Text(
                              _feedbackMessage!,
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('empty_feedback')),
            ),

            // Action Buttons: Primary Share + Save to Gallery + Copy Image
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _isExporting ? null : _shareCard,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.share_rounded, size: 20),
                      label: Text(
                        _isExporting ? 'Exporting...' : 'Share Image',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppLayout.spaceS),
                Semantics(
                  button: true,
                  label: 'Save image to gallery',
                  child: SizedBox(
                    width: 52,
                    height: 48,
                    child: IconButton.filledTonal(
                      onPressed: _isExporting ? null : _saveCardToGallery,
                      tooltip: 'Save to Gallery (Pictures/EverythingApp)',
                      icon: const Icon(Icons.download_rounded, size: 22),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        foregroundColor: colorScheme.onSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppLayout.radiusM),
                          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.7)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppLayout.spaceS),
                Semantics(
                  button: true,
                  label: 'Copy image to clipboard',
                  child: SizedBox(
                    width: 52,
                    height: 48,
                    child: IconButton.filledTonal(
                      onPressed: _isExporting ? null : _copyImageToClipboard,
                      tooltip: 'Copy Image to Clipboard',
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        foregroundColor: colorScheme.onSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppLayout.radiusM),
                          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.7)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
