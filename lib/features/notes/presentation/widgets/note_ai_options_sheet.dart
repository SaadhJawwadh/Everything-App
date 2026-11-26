import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/app_card.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../../services/local_ai_service.dart';

/// Modal bottom sheet providing on-device Gemini AI assistance options
/// (refine tone, fix grammar, expand, summarize, suggest titles & tags)
/// and the result preview sheet.
class NoteAiOptionsSheet {
  static Future<void> showOptions({
    required BuildContext context,
    required QuillController quillController,
    required LocalAiService aiService,
    required SettingsProvider settings,
    required void Function(String newTitle) onTitleSuggested,
    required void Function(List<String> newTags) onTagsSuggested,
    required void Function(String summary) onSummaryGenerated,
    required VoidCallback onContentModified,
  }) async {
    if (!settings.isAiActive) return;

    final sel = quillController.selection;
    final bool isSelection = sel.isValid && !sel.isCollapsed;
    final String targetText = isSelection
        ? quillController.document.getPlainText(sel.start, sel.end - sel.start).trim()
        : quillController.document.toPlainText().trim();

    bool isLoading = false;
    String? statusText;

    final reduceMotion = AppLayout.shouldReduceMotion(context);
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      sheetAnimationStyle: reduceMotion
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: AppLayout.animModal,
              reverseDuration: AppLayout.animFast,
              curve: AppLayout.curveSheet,
              reverseCurve: AppLayout.curveEmphasizedAccelerate,
            ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppLayout.radiusXXL)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final theme = Theme.of(sheetContext);
            final colorScheme = theme.colorScheme;

            Widget buildSectionHeader(String title, IconData icon) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFamily: AppTheme.fontGoogleSansFlex,
                        fontFamilyFallback: AppTheme.fontFallbacks,
                        fontSize: 13.0,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontVariations: AppTheme.buildFontVariations(
                          size: 13.0,
                          brightness: theme.brightness,
                          weight: 600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final engineSummary = settings.isDeviceAiSupported
                ? 'Android AI Core · 100% offline'
                : 'Offline NLP engine · 100% private';
            final scopeSummary = isSelection
                ? 'Selected text (${targetText.length} chars)'
                : 'Entire note (${targetText.length} chars)';

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              size: 22,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'On-Device Gemini AI',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: AppTheme.fontGoogleSansFlex,
                            fontFamilyFallback: AppTheme.fontFallbacks,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$engineSummary · $scopeSummary',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13.0,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        if (isLoading) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(AppLayout.radiusM),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    statusText ?? 'Processing on-device...',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          buildSectionHeader('Writing & Style', Icons.edit_note_rounded),
                          _buildAiTile(
                            context: sheetContext,
                            icon: Icons.spellcheck_rounded,
                            title: 'Proofread & Fix Grammar',
                            subtitle: 'Fix spelling, grammar, and punctuation cleanly',
                            groupPosition: AppCardGroupPosition.first,
                            onTap: () async {
                              final nav = Navigator.of(sheetContext);
                              if (targetText.isEmpty) {
                                setModalState(() => statusText = 'No text to proofread.');
                                return;
                              }
                              setModalState(() {
                                isLoading = true;
                                statusText = 'Proofreading text...';
                              });
                              final res = await aiService.refineText(targetText, 'proofread');
                              if (!sheetContext.mounted) return;
                              if (res != null && res.trim().isNotEmpty) {
                                nav.pop();
                                if (context.mounted) {
                                  await showResult(
                                    context: context,
                                    title: 'Proofread Result',
                                    resultText: res.trim(),
                                    isSelection: isSelection,
                                    selection: isSelection ? sel : null,
                                    quillController: quillController,
                                    onContentModified: onContentModified,
                                  );
                                }
                              } else {
                                setModalState(() {
                                  isLoading = false;
                                  statusText = 'Failed to proofread text.';
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 2),
                          _buildAiTile(
                            context: sheetContext,
                            icon: Icons.auto_fix_high_rounded,
                            title: 'Improve Fluency',
                            subtitle: 'Enhance vocabulary, flow, and sentence variety',
                            groupPosition: AppCardGroupPosition.middle,
                            onTap: () async {
                              final nav = Navigator.of(sheetContext);
                              if (targetText.isEmpty) {
                                setModalState(() => statusText = 'No text to enhance.');
                                return;
                              }
                              setModalState(() {
                                isLoading = true;
                                statusText = 'Improving fluency...';
                              });
                              final res = await aiService.refineText(targetText, 'improve');
                              if (!sheetContext.mounted) return;
                              if (res != null && res.trim().isNotEmpty) {
                                nav.pop();
                                if (context.mounted) {
                                  await showResult(
                                    context: context,
                                    title: 'Improved Fluency',
                                    resultText: res.trim(),
                                    isSelection: isSelection,
                                    selection: isSelection ? sel : null,
                                    quillController: quillController,
                                    onContentModified: onContentModified,
                                  );
                                }
                              } else {
                                setModalState(() {
                                  isLoading = false;
                                  statusText = 'Failed to improve text.';
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 2),
                          _buildAiTile(
                            context: sheetContext,
                            icon: Icons.work_outline_rounded,
                            title: 'Make Professional',
                            subtitle: 'Polite, clear, and business-ready tone',
                            groupPosition: AppCardGroupPosition.middle,
                            onTap: () async {
                              final nav = Navigator.of(sheetContext);
                              if (targetText.isEmpty) {
                                setModalState(() => statusText = 'No text to refine.');
                                return;
                              }
                              setModalState(() {
                                isLoading = true;
                                statusText = 'Adjusting tone...';
                              });
                              final res = await aiService.refineText(targetText, 'professional');
                              if (!sheetContext.mounted) return;
                              if (res != null && res.trim().isNotEmpty) {
                                nav.pop();
                                if (context.mounted) {
                                  await showResult(
                                    context: context,
                                    title: 'Professional Tone',
                                    resultText: res.trim(),
                                    isSelection: isSelection,
                                    selection: isSelection ? sel : null,
                                    quillController: quillController,
                                    onContentModified: onContentModified,
                                  );
                                }
                              } else {
                                setModalState(() {
                                  isLoading = false;
                                  statusText = 'Failed to adjust tone.';
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 2),
                          _buildAiTile(
                            context: sheetContext,
                            icon: Icons.compress_rounded,
                            title: 'Summarize & Shorten',
                            subtitle: 'Condense into concise, punchy bullet points',
                            groupPosition: AppCardGroupPosition.middle,
                            onTap: () async {
                              final nav = Navigator.of(sheetContext);
                              if (targetText.isEmpty) {
                                setModalState(() => statusText = 'No text to shorten.');
                                return;
                              }
                              setModalState(() {
                                isLoading = true;
                                statusText = 'Shortening text...';
                              });
                              final res = await aiService.refineText(targetText, 'shorten');
                              if (!sheetContext.mounted) return;
                              if (res != null && res.trim().isNotEmpty) {
                                nav.pop();
                                if (context.mounted) {
                                  await showResult(
                                    context: context,
                                    title: 'Shortened Text',
                                    resultText: res.trim(),
                                    isSelection: isSelection,
                                    selection: isSelection ? sel : null,
                                    quillController: quillController,
                                    onContentModified: onContentModified,
                                  );
                                }
                              } else {
                                setModalState(() {
                                  isLoading = false;
                                  statusText = 'Failed to shorten text.';
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 2),
                          _buildAiTile(
                            context: sheetContext,
                            icon: Icons.unfold_more_rounded,
                            title: 'Elaborate & Expand',
                            subtitle: 'Flesh out quick notes into structured paragraphs',
                            groupPosition: AppCardGroupPosition.last,
                            onTap: () async {
                              final nav = Navigator.of(sheetContext);
                              if (targetText.isEmpty) {
                                setModalState(() => statusText = 'No text to expand.');
                                return;
                              }
                              setModalState(() {
                                isLoading = true;
                                statusText = 'Expanding text...';
                              });
                              final res = await aiService.refineText(targetText, 'expand');
                              if (!sheetContext.mounted) return;
                              if (res != null && res.trim().isNotEmpty) {
                                nav.pop();
                                if (context.mounted) {
                                  await showResult(
                                    context: context,
                                    title: 'Expanded Text',
                                    resultText: res.trim(),
                                    isSelection: isSelection,
                                    selection: isSelection ? sel : null,
                                    quillController: quillController,
                                    onContentModified: onContentModified,
                                  );
                                }
                              } else {
                                setModalState(() {
                                  isLoading = false;
                                  statusText = 'Failed to expand text.';
                                });
                              }
                            },
                          ),

                          // Section 2: Smart Metadata & Organization
                          if (!isSelection) ...[
                            buildSectionHeader('Smart Metadata & Organization', Icons.auto_awesome_mosaic_rounded),
                            _buildAiTile(
                              context: sheetContext,
                              icon: Icons.title_rounded,
                              title: 'Suggest Title',
                              subtitle: 'Generate a clean title from note content',
                              groupPosition: AppCardGroupPosition.first,
                              onTap: () async {
                                final nav = Navigator.of(sheetContext);
                                if (targetText.isEmpty) {
                                  setModalState(() => statusText = 'Note is empty.');
                                  return;
                                }
                                setModalState(() {
                                  isLoading = true;
                                  statusText = 'Analyzing content...';
                                });
                                final prompt =
                                    "Generate a short, concise title (maximum 4-5 words) for the following text. Respond ONLY with the title:\n\n$targetText";
                                String? suggested = await aiService.generateText(prompt);
                                if (!sheetContext.mounted) return;
                                if (suggested == null || suggested.trim().isEmpty) {
                                  final lines = targetText.split(RegExp(r'\r?\n|\.'));
                                  final firstLine = lines.firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
                                  if (firstLine.trim().isNotEmpty) {
                                    final clean = firstLine.trim().replaceAll(RegExp(r'^[•\-\*\d+\.\s]+'), '');
                                    suggested = clean.length > 35 ? '${clean.substring(0, 35)}…' : clean;
                                  }
                                }
                                if (suggested != null && suggested.trim().isNotEmpty) {
                                  onTitleSuggested(suggested.trim().replaceAll('"', ''));
                                  nav.pop();
                                } else {
                                  setModalState(() {
                                    isLoading = false;
                                    statusText = 'Failed to generate title.';
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 2),
                            _buildAiTile(
                              context: sheetContext,
                              icon: Icons.label_outline_rounded,
                              title: 'Suggest Tags',
                              subtitle: 'Auto-detect topics and apply tags',
                              groupPosition: AppCardGroupPosition.middle,
                              onTap: () async {
                                final nav = Navigator.of(sheetContext);
                                if (targetText.isEmpty) {
                                  setModalState(() => statusText = 'Note is empty.');
                                  return;
                                }
                                setModalState(() {
                                  isLoading = true;
                                  statusText = 'Detecting tags...';
                                });
                                final prompt =
                                    "Suggest 2 to 4 short comma-separated topic tags for this note:\n\n$targetText";
                                final res = await aiService.generateText(prompt);
                                if (!sheetContext.mounted) return;
                                if (res != null && res.trim().isNotEmpty) {
                                  final split = res
                                      .split(RegExp(r'[,;\n]'))
                                      .map((t) => t.trim().replaceAll(RegExp(r'^[#•\-\*\s]+'), ''))
                                      .where((t) => t.isNotEmpty && t.length < 25)
                                      .take(4)
                                      .toList();
                                  if (split.isNotEmpty) {
                                    onTagsSuggested(split);
                                    nav.pop();
                                    return;
                                  }
                                }
                                setModalState(() {
                                  isLoading = false;
                                  statusText = 'No tags detected.';
                                });
                              },
                            ),
                            const SizedBox(height: 2),
                            _buildAiTile(
                              context: sheetContext,
                              icon: Icons.summarize_outlined,
                              title: 'Generate Summary Card',
                              subtitle: 'Create a permanent summary header on this note',
                              groupPosition: AppCardGroupPosition.last,
                              onTap: () async {
                                final nav = Navigator.of(sheetContext);
                                if (targetText.isEmpty) {
                                  setModalState(() => statusText = 'Note is empty.');
                                  return;
                                }
                                setModalState(() {
                                  isLoading = true;
                                  statusText = 'Generating summary...';
                                });
                                final summary = await aiService.summarize(targetText);
                                if (!sheetContext.mounted) return;
                                if (summary != null && summary.trim().isNotEmpty) {
                                  onSummaryGenerated(summary.trim());
                                  nav.pop();
                                } else {
                                  setModalState(() {
                                    isLoading = false;
                                    statusText = 'Failed to generate summary.';
                                  });
                                }
                              },
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> showResult({
    required BuildContext context,
    required String title,
    required String resultText,
    required bool isSelection,
    required TextSelection? selection,
    required QuillController quillController,
    required VoidCallback onContentModified,
  }) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final reduceMotion = AppLayout.shouldReduceMotion(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colorScheme.surfaceContainerHigh,
      sheetAnimationStyle: reduceMotion
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: AppLayout.animModal,
              reverseDuration: AppLayout.animFast,
              curve: AppLayout.curveSheet,
              reverseCurve: AppLayout.curveEmphasizedAccelerate,
            ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppLayout.radiusXXL)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: colorScheme.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppLayout.radiusM),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      resultText,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.post_add_outlined, size: 18),
                      label: const Text('Insert Below'),
                      onPressed: () {
                        final docLen = quillController.document.length;
                        final safeLen = docLen > 0 ? docLen - 1 : 0;
                        final insertPos = isSelection && selection != null
                            ? selection.end.clamp(0, safeLen)
                            : safeLen;
                        quillController.replaceText(
                          insertPos,
                          0,
                          '\n$resultText',
                          null,
                        );
                        onContentModified();
                        Navigator.of(ctx).pop();
                      },
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(isSelection ? 'Replace Selection' : 'Replace All'),
                      onPressed: () {
                        final docLen = quillController.document.length;
                        final safeLen = docLen > 0 ? docLen - 1 : 0;
                        if (isSelection && selection != null) {
                          final start = selection.start.clamp(0, safeLen);
                          final end = selection.end.clamp(start, safeLen);
                          quillController.replaceText(
                            start,
                            end - start,
                            resultText,
                            null,
                          );
                        } else {
                          quillController.replaceText(
                            0,
                            safeLen,
                            resultText,
                            null,
                          );
                        }
                        onContentModified();
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildAiTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    AppCardGroupPosition groupPosition = AppCardGroupPosition.none,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      groupPosition: groupPosition,
      backgroundColor: colorScheme.surfaceContainerLow,
      padding: EdgeInsets.zero,
      child: ListTile(
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: colorScheme.primary),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontFamily: AppTheme.fontGoogleSansFlex,
            fontFamilyFallback: AppTheme.fontFallbacks,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
            fontSize: 14.0,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 13.0,
            height: 1.25,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        onTap: onTap,
      ),
    );
  }
}
