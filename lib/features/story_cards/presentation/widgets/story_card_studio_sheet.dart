import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
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
  final StoryCardRenderService renderService;
  final StoryCardMediaService mediaService;
  final Future<Directory> Function()? tempDirProvider;

  const StoryCardStudioSheet({
    super.key,
    required this.initialText,
    required this.noteTitle,
    this.category = 'Note',
    this.noteColorValue = 0,
    required this.noteDate,
    this.renderService = const StoryCardRenderService(),
    this.mediaService = const StoryCardMediaService(),
    this.tempDirProvider,
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
      padding: EdgeInsets.zero,
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

  late TextEditingController _textController;
  late TextEditingController _titleController;

  late StoryCardConfig _config;
  bool _isExporting = false;
  bool _isEditingText = false;
  bool _isSummarizing = false;
  String? _feedbackMessage;
  bool _feedbackIsError = false;
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

  bool _isGenAiActive(BuildContext context) {
    try {
      return context.watch<SettingsProvider>().isGenAiActive;
    } catch (_) {
      return false;
    }
  }

  Future<void> _applyAiHighlight() async {
    if (_isSummarizing) return;
    bool genAiActive = false;
    try {
      genAiActive = context.read<SettingsProvider>().isGenAiActive;
    } catch (_) {}
    if (!genAiActive) return;
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
        _setFeedback('Could not generate AI highlight', isError: true);
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

  void _setFeedback(String message, {bool isError = false}) {
    _feedbackTimer?.cancel();
    if (mounted) {
      setState(() {
        _feedbackMessage = message;
        _feedbackIsError = isError;
      });
      _feedbackTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _feedbackMessage = null;
            _feedbackIsError = false;
          });
        }
      });
    }
  }

  Future<Uint8List?> _captureCard({double pixelRatio = 3.5}) async {
    return await widget.renderService.capturePng(_repaintKey, pixelRatio: pixelRatio);
  }

  /// Captures every slide sequentially by switching [currentSlideIndex],
  /// waiting two rendered frames so layout and paint settle in all build modes,
  /// writing each PNG to a temp file to avoid holding all buffers in RAM, and
  /// restoring the original slide index in `finally`.
  Future<List<File>> _captureAllSlideFiles() async {
    final total = _config.slides.length;
    final originalIndex = _config.currentSlideIndex;
    final tempDir = await (widget.tempDirProvider?.call() ?? getTemporaryDirectory());
    final ts = DateTime.now().millisecondsSinceEpoch;
    final files = <File>[];

    try {
      for (int i = 0; i < total; i++) {
        if (!mounted) break;
        setState(() => _config = _config.copyWith(currentSlideIndex: i));
        WidgetsBinding.instance.ensureVisualUpdate();
        await WidgetsBinding.instance.endOfFrame;
        WidgetsBinding.instance.scheduleFrame();
        await WidgetsBinding.instance.endOfFrame;
        final bytes = await _captureCard(pixelRatio: 2.5);
        if (bytes != null) {
          final file = File('${tempDir.path}/story_share_${ts}_s${i + 1}.png');
          await file.writeAsBytes(bytes, flush: true);
          files.add(file);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _config = _config.copyWith(currentSlideIndex: originalIndex));
      }
    }
    return files;
  }

  Future<void> _shareAllSlides() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    AppHaptics.mediumImpact();
    try {
      final files = await _captureAllSlideFiles();
      if (files.isEmpty || !mounted) {
        if (mounted) {
          _setFeedback('Could not generate story slides', isError: true);
          AppSnackBar.showError(context, message: 'Could not generate story slides');
        }
        return;
      }
      await widget.mediaService.shareMultipleImageFiles(
        files,
        title: _config.resolvedTitle,
      );
    } catch (e) {
      if (mounted) {
        _setFeedback('Sharing slides failed: $e', isError: true);
        AppSnackBar.showError(context, message: 'Sharing slides failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _saveAllSlidesToGallery() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    AppHaptics.mediumImpact();
    List<File> files = const [];
    try {
      files = await _captureAllSlideFiles();
      if (files.isEmpty || !mounted) {
        if (mounted) {
          _setFeedback('Could not generate story slides', isError: true);
          AppSnackBar.showError(context, message: 'Could not generate story slides');
        }
        return;
      }
      final saved = await widget.mediaService.saveMultipleImageFilesToGallery(files);
      if (mounted) {
        if (saved > 0) {
          _setFeedback('Saved $saved slides to Gallery');
          AppSnackBar.showSuccess(
            context,
            message: 'Saved $saved of ${files.length} slides to Pictures/EverythingApp',
          );
        } else {
          _setFeedback('Failed to save slides to gallery', isError: true);
          AppSnackBar.showError(context, message: 'Failed to save slides to gallery');
        }
      }
    } catch (e) {
      if (mounted) {
        _setFeedback('Saving slides failed: $e', isError: true);
        AppSnackBar.showError(context, message: 'Saving slides failed: $e');
      }
    } finally {
      for (final file in files) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _shareCard() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    AppHaptics.mediumImpact();

    try {
      final bytes = await _captureCard();
      if (bytes == null || !mounted) {
        if (mounted) {
          _setFeedback('Could not generate story image', isError: true);
          AppSnackBar.showError(context, message: 'Could not generate story image');
        }
        return;
      }

      await widget.mediaService.shareImage(
        bytes,
        title: _config.resolvedTitle,
      );
    } catch (e) {
      if (mounted) {
        _setFeedback('Sharing failed: $e', isError: true);
        AppSnackBar.showError(context, message: 'Sharing failed: $e');
      }
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
        if (mounted) {
          _setFeedback('Could not generate story image', isError: true);
          AppSnackBar.showError(context, message: 'Could not generate story image');
        }
        return;
      }

      final savedPath = await widget.mediaService.saveImageToGallery(bytes);
      if (mounted) {
        if (savedPath != null) {
          _setFeedback('Saved to Gallery in Pictures/EverythingApp');
          AppSnackBar.showSuccess(
            context,
            message: 'Saved to Gallery in $savedPath',
          );
        } else {
          _setFeedback('Failed to save image to gallery', isError: true);
          AppSnackBar.showError(context, message: 'Failed to save image to gallery');
        }
      }
    } catch (e) {
      if (mounted) {
        _setFeedback('Failed to save image: $e', isError: true);
        AppSnackBar.showError(context, message: 'Failed to save image: $e');
      }
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
        if (mounted) {
          _setFeedback('Could not render image for clipboard', isError: true);
          AppSnackBar.showError(context, message: 'Could not render image for clipboard');
        }
        return;
      }

      final success = await widget.mediaService.copyImageToClipboard(
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
      if (mounted) {
        _setFeedback('Clipboard copy failed: $e', isError: true);
        AppSnackBar.showError(context, message: 'Clipboard copy failed: $e');
      }
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
    final availableHeight = mediaQuery.size.height;
    final maxHeight = availableHeight * 0.88;

    // Responsive card preview viewport sizing so 9:16, 4:5, and 1:1 fit without clipping.
    final targetPreviewHeight = _config.aspectRatio == StoryCardAspectRatio.story
        ? (availableHeight * 0.34).clamp(220.0, 310.0)
        : (_config.aspectRatio == StoryCardAspectRatio.portrait
            ? (availableHeight * 0.30).clamp(200.0, 275.0)
            : (availableHeight * 0.26).clamp(185.0, 245.0));
    final maxPreviewWidth =
        (mediaQuery.size.width - AppLayout.spaceL * 2).clamp(160.0, 420.0);
    final rawPreviewWidth = targetPreviewHeight * _config.aspectRatio.ratio;
    final previewWidth =
        rawPreviewWidth > maxPreviewWidth ? maxPreviewWidth : rawPreviewWidth;
    final previewHeight = previewWidth / _config.aspectRatio.ratio;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Pinned Sheet Header: Title & Edit Note Text Toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppLayout.spaceL,
              0,
              AppLayout.spaceL,
              AppLayout.spaceXS,
            ),
            child: Row(
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
                    size: 18,
                  ),
                  label: Text(_isEditingText ? 'Preview' : 'Edit Text'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    tapTargetSize: MaterialTapTargetSize.padded,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ],
            ),
          ),

          // 2. Scrollable Middle: AI Highlight, Editor, Preview, Slide Switcher & Controls
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppLayout.spaceL,
                AppLayout.spaceXS,
                AppLayout.spaceL,
                AppLayout.spaceS,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_config.totalWordCount > 30 && _isGenAiActive(context)) ...[
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
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onPressed: _isSummarizing ? null : _applyAiHighlight,
                      ),
                    ),
                    const SizedBox(height: AppLayout.spaceS),
                  ],

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
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
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
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
                    label: Text(mode.label, style: const TextStyle(fontSize: 12)),
                    icon: Icon(mode.icon, size: 15),
                  );
                }).toList(),
                selected: {_config.layoutMode},
                showSelectedIcon: false,
                style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.padded,
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
                    label: Text(ratio.label, style: const TextStyle(fontSize: 12)),
                    icon: Icon(ratio.icon, size: 15),
                  );
                }).toList(),
                selected: {_config.aspectRatio},
                showSelectedIcon: false,
                style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.padded,
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
              'Typography style',
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
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
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      selected: isSelected,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
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
              'Visual theme',
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: StoryCardThemePreset.values.map((preset) {
                  final isSelected = _config.themePreset == preset;
                  final swatchStyle = StoryCardThemeStyle.resolve(
                    preset: preset,
                    appTheme: theme,
                    noteColorValue: _config.noteColorValue,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      showCheckmark: false,
                      avatar: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: swatchStyle.background,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: swatchStyle.accent,
                            width: 2.0,
                          ),
                        ),
                      ),
                      label: Text(
                        preset.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      selected: isSelected,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
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
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                FilterChip(
                  showCheckmark: false,
                  label: Text(
                    'Title',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _config.showTitle ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  avatar: Icon(
                    Icons.title_rounded,
                    size: 16,
                    color: _config.showTitle ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                  selected: _config.showTitle,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (val) {
                    AppHaptics.selectionClick();
                    setState(() => _config = _config.copyWith(showTitle: val));
                  },
                ),
                FilterChip(
                  showCheckmark: false,
                  label: Text(
                    'Date',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _config.showDate ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  avatar: Icon(
                    Icons.event_outlined,
                    size: 16,
                    color: _config.showDate ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                  selected: _config.showDate,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (val) {
                    AppHaptics.selectionClick();
                    setState(() => _config = _config.copyWith(showDate: val));
                  },
                ),
                FilterChip(
                  showCheckmark: false,
                  label: Text(
                    'Watermark',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _config.showWatermark ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  avatar: Icon(
                    Icons.verified_outlined,
                    size: 16,
                    color: _config.showWatermark ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                  selected: _config.showWatermark,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (val) {
                    AppHaptics.selectionClick();
                    setState(() => _config = _config.copyWith(showWatermark: val));
                    _savePreference(showWatermark: val);
                  },
                ),
              ],
            ),
                ],
              ),
            ),
          ),

          // 3. Pinned Bottom Footer: Subtle Divider + Feedback Banner + Action Bar
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppLayout.spaceL,
              AppLayout.spaceS,
              AppLayout.spaceL,
              mediaQuery.viewInsets.bottom + AppLayout.spaceM,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // In-Sheet Live Feedback Banner
                AnimatedSwitcher(
                  duration: AppLayout.shouldReduceMotion(context)
                      ? Duration.zero
                      : AppLayout.animModal,
                  switchInCurve: AppLayout.curveStrongEaseOut,
                  switchOutCurve: AppLayout.curveEmphasizedAccelerate,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(sizeFactor: animation, child: child),
                  ),
                  child: _feedbackMessage != null
                      ? Container(
                          key: ValueKey<String>('${_feedbackIsError ? 'err' : 'ok'}_$_feedbackMessage'),
                          margin: const EdgeInsets.only(bottom: AppLayout.spaceS),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppLayout.spaceM,
                            vertical: AppLayout.spaceS,
                          ),
                          decoration: BoxDecoration(
                            color: _feedbackIsError
                                ? colorScheme.errorContainer.withValues(alpha: 0.75)
                                : colorScheme.primaryContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(AppLayout.radiusM),
                            border: Border.all(
                              color: (_feedbackIsError ? colorScheme.error : colorScheme.primary)
                                  .withValues(alpha: 0.4),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _feedbackIsError
                                    ? Icons.error_outline_rounded
                                    : Icons.check_circle_rounded,
                                size: 16,
                                color: _feedbackIsError
                                    ? colorScheme.error
                                    : colorScheme.primary,
                              ),
                              const SizedBox(width: AppLayout.spaceS),
                              Flexible(
                                child: Text(
                                  _feedbackMessage!,
                                  style: textTheme.labelMedium?.copyWith(
                                    color: _feedbackIsError
                                        ? colorScheme.onErrorContainer
                                        : colorScheme.onPrimaryContainer,
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

                // Action Bar: 1 Primary CTA (Share / Share All) + Compact Secondary Icon Actions (Save, Copy)
                Builder(
                  builder: (context) {
                    final slideCount = _config.slides.length;
                    final isMultiSlide = slideCount > 1;
                    return Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: _isExporting
                                  ? null
                                  : (isMultiSlide ? _shareAllSlides : _shareCard),
                              icon: _isExporting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(
                                      isMultiSlide
                                          ? Icons.collections_outlined
                                          : Icons.share_rounded,
                                      size: 20,
                                    ),
                              label: Text(
                                _isExporting
                                    ? 'Exporting...'
                                    : (isMultiSlide ? 'Share All ($slideCount)' : 'Share'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppLayout.spaceS),
                        Semantics(
                          button: true,
                          label: isMultiSlide
                              ? 'Save all slides to gallery'
                              : 'Save image to gallery',
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: IconButton.filledTonal(
                              onPressed: _isExporting
                                  ? null
                                  : (isMultiSlide
                                      ? _saveAllSlidesToGallery
                                      : _saveCardToGallery),
                              tooltip: isMultiSlide
                                  ? 'Save all $slideCount slides to gallery'
                                  : 'Save to Gallery (Pictures/EverythingApp)',
                              icon: Icon(
                                isMultiSlide
                                    ? Icons.download_for_offline_outlined
                                    : Icons.download_rounded,
                                size: 22,
                              ),
                              style: IconButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                backgroundColor: colorScheme.surfaceContainerHighest,
                                foregroundColor: colorScheme.onSurface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppLayout.radiusM),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                                  ),
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
                            width: 48,
                            height: 48,
                            child: IconButton.filledTonal(
                              onPressed: _isExporting ? null : _copyImageToClipboard,
                              tooltip: 'Copy Image to Clipboard',
                              icon: const Icon(Icons.copy_rounded, size: 20),
                              style: IconButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                backgroundColor: colorScheme.surfaceContainerHighest,
                                foregroundColor: colorScheme.onSurface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppLayout.radiusM),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
