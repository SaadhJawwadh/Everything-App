import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../../../core/services/app_haptics.dart';

import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../core/ui/app_snack_bar.dart';
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
  final GlobalKey _repaintKey = GlobalKey();
  final StoryCardRenderService _renderService = const StoryCardRenderService();
  final StoryCardMediaService _mediaService = const StoryCardMediaService();

  late TextEditingController _textController;
  late TextEditingController _titleController;

  late StoryCardConfig _config;
  bool _isExporting = false;
  bool _isEditingText = false;
  String? _feedbackMessage;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    final trimmedText = widget.initialText.trim();
    _textController = TextEditingController(text: trimmedText);
    _titleController = TextEditingController(text: widget.noteTitle.trim());

    final totalWords = StoryCardConfig.countWords(trimmedText);
    final autoLayoutMode = StoryCardLayoutMode.autoDetect(trimmedText);
    final initialWordLimit = autoLayoutMode == StoryCardLayoutMode.article
        ? StoryCardWordLimit.all
        : (totalWords > 60 ? StoryCardWordLimit.w50 : StoryCardWordLimit.all);

    _config = StoryCardConfig(
      title: widget.noteTitle.trim(),
      text: trimmedText,
      category: widget.category.isNotEmpty ? widget.category : 'Note',
      date: widget.noteDate,
      noteColorValue: widget.noteColorValue,
      aspectRatio: StoryCardAspectRatio.story,
      themePreset: StoryCardThemePreset.editorial,
      wordLimit: initialWordLimit,
      fontStyle: StoryCardFontStyle.auto,
      layoutMode: autoLayoutMode,
      showTitle: true,
      showDate: true,
      showWatermark: false,
    );
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
                          _config = _config.copyWith(text: val);
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
                    final newMode = set.first;
                    _config = _config.copyWith(
                      layoutMode: newMode,
                      wordLimit: newMode == StoryCardLayoutMode.article && _config.wordLimit != StoryCardWordLimit.all
                          ? StoryCardWordLimit.all
                          : _config.wordLimit,
                    );
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
                  setState(() => _config = _config.copyWith(aspectRatio: set.first));
                },
              ),
            ),
            const SizedBox(height: AppLayout.spaceM),

            // Controls 2: Word Limit Selector with Live Stats Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'QUOTE LENGTH',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppLayout.radiusS),
                  ),
                  child: Text(
                    '📝 ${_config.displayedWordCount} / ${_config.totalWordCount} words',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSecondaryContainer,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: StoryCardWordLimit.values.map((limit) {
                  final isSelected = _config.wordLimit == limit;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: FilterChip(
                      showCheckmark: false,
                      label: Text(
                        limit.label,
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
                        setState(() => _config = _config.copyWith(wordLimit: limit));
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppLayout.spaceM),

            // Controls 3: Typography Font Style Switcher
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
                  },
                ),
              ],
            ),
            const SizedBox(height: AppLayout.spaceM),

            // In-Sheet Live Feedback Banner
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
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
