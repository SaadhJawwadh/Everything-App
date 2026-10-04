import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/expressive_floating_toolbar.dart';

class NoteEditorBottomBar extends StatelessWidget {
  final QuillController quillController;
  final bool showFormattingBar;
  final bool isImageSelected;
  final bool isSystemDefault;
  final int color;
  final Color textColor;
  final ColorScheme noteScheme;
  final bool isKeyboardOpen;
  final bool isAiActive;
  final bool minimalEditorMode;
  final VoidCallback onToggleFormattingBar;
  final void Function({required bool byWord}) onNudgeLeft;
  final void Function({required bool byWord}) onNudgeRight;
  final VoidCallback onNudgeUp;
  final VoidCallback onNudgeDown;
  final VoidCallback onShowAiOptions;
  final VoidCallback onInsertTable;
  final VoidCallback onShowImageOptions;
  final VoidCallback onHideKeyboard;

  const NoteEditorBottomBar({
    super.key,
    required this.quillController,
    required this.showFormattingBar,
    required this.isImageSelected,
    required this.isSystemDefault,
    required this.color,
    required this.textColor,
    required this.noteScheme,
    required this.isKeyboardOpen,
    required this.isAiActive,
    required this.minimalEditorMode,
    required this.onToggleFormattingBar,
    required this.onNudgeLeft,
    required this.onNudgeRight,
    required this.onNudgeUp,
    required this.onNudgeDown,
    required this.onShowAiOptions,
    required this.onInsertTable,
    required this.onShowImageOptions,
    required this.onHideKeyboard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Floating Formatting Bar Sub-tier ──
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.4),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: (showFormattingBar && !isImageSelected)
              ? SafeArea(
                  key: const ValueKey('floating_formatting_bar'),
                  top: false,
                  bottom: false,
                  child: ExpressiveFloatingToolbar(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    backgroundColor: (isSystemDefault
                            ? theme.colorScheme.surfaceContainerHigh
                            : ColorScheme.fromSeed(
                                    seedColor: Color(color),
                                    brightness: theme.brightness)
                                .surfaceContainerHigh)
                        .withValues(alpha: 0.95),
                    children: [
                      // ── FIXED LEFT: Horizontal Stepper [ ‹ ] [ › ] ──
                      Tooltip(
                        message: 'Nudge left (Double-tap / long-press for word)',
                        child: InkResponse(
                          radius: 16,
                          onTap: () => onNudgeLeft(byWord: false),
                          onDoubleTap: () => onNudgeLeft(byWord: true),
                          onLongPress: () => onNudgeLeft(byWord: true),
                          child: SizedBox(
                            width: 32,
                            height: 36,
                            child: Icon(
                              Icons.chevron_left_rounded,
                              color: textColor,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      Tooltip(
                        message: 'Nudge right (Double-tap / long-press for word)',
                        child: InkResponse(
                          radius: 16,
                          onTap: () => onNudgeRight(byWord: false),
                          onDoubleTap: () => onNudgeRight(byWord: true),
                          onLongPress: () => onNudgeRight(byWord: true),
                          child: SizedBox(
                            width: 32,
                            height: 36,
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: textColor,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),

                      // ── SCROLLABLE CENTER: Formatting Tools ──
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            children: [
                              // Cluster 1: Header Hierarchy Switcher
                              ListenableBuilder(
                                listenable: quillController,
                                builder: (context, _) {
                                  final style = quillController.getSelectionStyle();
                                  final headerAttr = style.attributes[Attribute.header.key];
                                  final int currentLevel;
                                  final String currentLabel;
                                  final IconData currentIcon;
                                  if (headerAttr == Attribute.h1) {
                                    currentLevel = 1;
                                    currentLabel = 'H1';
                                    currentIcon = Icons.title;
                                  } else if (headerAttr == Attribute.h2) {
                                    currentLevel = 2;
                                    currentLabel = 'H2';
                                    currentIcon = Icons.title;
                                  } else if (headerAttr == Attribute.h3) {
                                    currentLevel = 3;
                                    currentLabel = 'H3';
                                    currentIcon = Icons.title;
                                  } else {
                                    currentLevel = 0;
                                    currentLabel = 'Body';
                                    currentIcon = Icons.short_text;
                                  }

                                  return MenuAnchor(
                                    builder: (context, menu, child) {
                                      return TextButton.icon(
                                        onPressed: () {
                                          if (menu.isOpen) {
                                            menu.close();
                                          } else {
                                            menu.open();
                                          }
                                        },
                                        icon: Icon(
                                          currentIcon,
                                          size: 18,
                                          color: currentLevel > 0
                                              ? theme.colorScheme.primary
                                              : textColor,
                                        ),
                                        label: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              currentLabel,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: currentLevel > 0
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: currentLevel > 0
                                                    ? theme.colorScheme.primary
                                                    : textColor,
                                              ),
                                            ),
                                            Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              size: 16,
                                              color: textColor,
                                            ),
                                          ],
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      );
                                    },
                                    menuChildren: [
                                      MenuItemButton(
                                        leadingIcon: Icon(
                                          Icons.short_text,
                                          size: 18,
                                          color: currentLevel == 0
                                              ? theme.colorScheme.primary
                                              : null,
                                        ),
                                        child: Text(
                                          'Body Text',
                                          style: TextStyle(
                                            fontWeight: currentLevel == 0
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        onPressed: () {
                                          quillController.formatSelection(
                                            Attribute.header,
                                          );
                                        },
                                      ),
                                      MenuItemButton(
                                        leadingIcon: Icon(
                                          Icons.title,
                                          size: 18,
                                          color: currentLevel == 1
                                              ? theme.colorScheme.primary
                                              : null,
                                        ),
                                        child: Text(
                                          'Heading 1',
                                          style: TextStyle(
                                            fontWeight: currentLevel == 1
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        onPressed: () {
                                          quillController.formatSelection(
                                            Attribute.h1,
                                          );
                                        },
                                      ),
                                      MenuItemButton(
                                        leadingIcon: Icon(
                                          Icons.title,
                                          size: 16,
                                          color: currentLevel == 2
                                              ? theme.colorScheme.primary
                                              : null,
                                        ),
                                        child: Text(
                                          'Heading 2',
                                          style: TextStyle(
                                            fontWeight: currentLevel == 2
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        onPressed: () {
                                          quillController.formatSelection(
                                            Attribute.h2,
                                          );
                                        },
                                      ),
                                      MenuItemButton(
                                        leadingIcon: Icon(
                                          Icons.title,
                                          size: 14,
                                          color: currentLevel == 3
                                              ? theme.colorScheme.primary
                                              : null,
                                        ),
                                        child: Text(
                                          'Heading 3',
                                          style: TextStyle(
                                            fontWeight: currentLevel == 3
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        onPressed: () {
                                          quillController.formatSelection(
                                            Attribute.h3,
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(width: AppLayout.spaceS),
                              // Cluster 2: Inline Styles
                              QuillToolbarToggleStyleButton(
                                attribute: Attribute.bold,
                                controller: quillController,
                                options: QuillToolbarToggleStyleButtonOptions(
                                    iconData: Icons.format_bold,
                                    iconTheme: QuillIconTheme(
                                        iconButtonUnselectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: textColor)),
                                        iconButtonSelectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: theme
                                                        .colorScheme
                                                        .onPrimary)))),
                              ),
                              QuillToolbarToggleStyleButton(
                                attribute: Attribute.italic,
                                controller: quillController,
                                options: QuillToolbarToggleStyleButtonOptions(
                                    iconData: Icons.format_italic,
                                    iconTheme: QuillIconTheme(
                                        iconButtonUnselectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: textColor)),
                                        iconButtonSelectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: theme
                                                        .colorScheme
                                                        .onPrimary)))),
                              ),
                              QuillToolbarToggleStyleButton(
                                attribute: Attribute.underline,
                                controller: quillController,
                                options: QuillToolbarToggleStyleButtonOptions(
                                    iconData: Icons.format_underlined,
                                    iconTheme: QuillIconTheme(
                                        iconButtonUnselectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: textColor)),
                                        iconButtonSelectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: theme
                                                        .colorScheme
                                                        .onPrimary)))),
                              ),
                              QuillToolbarToggleStyleButton(
                                attribute: Attribute.strikeThrough,
                                controller: quillController,
                                options: QuillToolbarToggleStyleButtonOptions(
                                    iconData: Icons.format_strikethrough,
                                    iconTheme: QuillIconTheme(
                                        iconButtonUnselectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: textColor)),
                                        iconButtonSelectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: theme
                                                        .colorScheme
                                                        .onPrimary)))),
                              ),

                              const SizedBox(width: AppLayout.spaceS),
                              // Cluster 3: Paragraph & Alignment
                              QuillToolbarToggleStyleButton(
                                attribute: Attribute.ol,
                                controller: quillController,
                                options: QuillToolbarToggleStyleButtonOptions(
                                    iconData: Icons.format_list_numbered,
                                    iconTheme: QuillIconTheme(
                                        iconButtonUnselectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: textColor)),
                                        iconButtonSelectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: theme
                                                        .colorScheme
                                                        .onPrimary)))),
                              ),
                              QuillToolbarToggleStyleButton(
                                attribute: Attribute.ul,
                                controller: quillController,
                                options: QuillToolbarToggleStyleButtonOptions(
                                    iconData: Icons.format_list_bulleted,
                                    iconTheme: QuillIconTheme(
                                        iconButtonUnselectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: textColor)),
                                        iconButtonSelectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: theme
                                                        .colorScheme
                                                        .onPrimary)))),
                              ),
                              QuillToolbarIndentButton(
                                controller: quillController,
                                isIncrease: false,
                                options: QuillToolbarIndentButtonOptions(
                                    iconData: Icons.format_indent_decrease,
                                    iconTheme: QuillIconTheme(
                                        iconButtonUnselectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: textColor)))),
                              ),
                              QuillToolbarIndentButton(
                                controller: quillController,
                                isIncrease: true,
                                options: QuillToolbarIndentButtonOptions(
                                    iconData: Icons.format_indent_increase,
                                    iconTheme: QuillIconTheme(
                                        iconButtonUnselectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: textColor)))),
                              ),
                              QuillToolbarToggleStyleButton(
                                attribute: Attribute.leftAlignment,
                                controller: quillController,
                                options: QuillToolbarToggleStyleButtonOptions(
                                    iconData: Icons.format_align_left,
                                    iconTheme: QuillIconTheme(
                                        iconButtonUnselectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: textColor)),
                                        iconButtonSelectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: theme
                                                        .colorScheme
                                                        .onPrimary)))),
                              ),
                              QuillToolbarToggleStyleButton(
                                attribute: Attribute.centerAlignment,
                                controller: quillController,
                                options: QuillToolbarToggleStyleButtonOptions(
                                    iconData: Icons.format_align_center,
                                    iconTheme: QuillIconTheme(
                                        iconButtonUnselectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: textColor)),
                                        iconButtonSelectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: theme
                                                        .colorScheme
                                                        .onPrimary)))),
                              ),
                              QuillToolbarToggleStyleButton(
                                attribute: Attribute.rightAlignment,
                                controller: quillController,
                                options: QuillToolbarToggleStyleButtonOptions(
                                    iconData: Icons.format_align_right,
                                    iconTheme: QuillIconTheme(
                                        iconButtonUnselectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: textColor)),
                                        iconButtonSelectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: theme
                                                        .colorScheme
                                                        .onPrimary)))),
                              ),
                              QuillToolbarToggleStyleButton(
                                attribute: Attribute.justifyAlignment,
                                controller: quillController,
                                options: QuillToolbarToggleStyleButtonOptions(
                                    iconData: Icons.format_align_justify,
                                    iconTheme: QuillIconTheme(
                                        iconButtonUnselectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: textColor)),
                                        iconButtonSelectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: theme
                                                        .colorScheme
                                                        .onPrimary)))),
                              ),
                              QuillToolbarToggleStyleButton(
                                attribute: Attribute.blockQuote,
                                controller: quillController,
                                options: QuillToolbarToggleStyleButtonOptions(
                                    iconData: Icons.format_quote,
                                    iconTheme: QuillIconTheme(
                                        iconButtonUnselectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: textColor)),
                                        iconButtonSelectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: theme
                                                        .colorScheme
                                                        .onPrimary)))),
                              ),
                              QuillToolbarToggleStyleButton(
                                attribute: Attribute.codeBlock,
                                controller: quillController,
                                options: QuillToolbarToggleStyleButtonOptions(
                                    iconData: Icons.code,
                                    iconTheme: QuillIconTheme(
                                        iconButtonUnselectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: textColor)),
                                        iconButtonSelectedData:
                                            IconButtonData(
                                                style: IconButton.styleFrom(
                                                    foregroundColor: theme
                                                        .colorScheme
                                                        .onPrimary)))),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── FIXED RIGHT: Vertical Stepper [ ▲ ] [ ▼ ] ──
                      const SizedBox(width: 8.0),
                      Tooltip(
                        message: 'Expand selection line up',
                        child: InkResponse(
                          radius: 16,
                          onTap: onNudgeUp,
                          child: SizedBox(
                            width: 32,
                            height: 36,
                            child: Icon(
                              Icons.keyboard_arrow_up_rounded,
                              color: textColor,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      Tooltip(
                        message: 'Expand selection line down',
                        child: InkResponse(
                          radius: 16,
                          onTap: onNudgeDown,
                          child: SizedBox(
                            width: 32,
                            height: 36,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: textColor,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('empty_formatting_bar')),
        ),

        // ── Main Bottom Toolbar (Pill) ──
        Visibility(
          visible: !isImageSelected,
          child: SafeArea(
            top: false,
            child: ExpressiveFloatingToolbar(
              backgroundColor: isSystemDefault
                  ? theme.colorScheme.surfaceContainerHighest
                  : ColorScheme.fromSeed(
                          seedColor: Color(color),
                          brightness: theme.brightness)
                      .surfaceContainerHighest,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              isScrollable: true,
              children: [
                IconButton(
                  icon: Icon(showFormattingBar
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.text_format_rounded),
                  tooltip: showFormattingBar ? 'Hide formatting' : 'Formatting',
                  onPressed: onToggleFormattingBar,
                  style: IconButton.styleFrom(
                    foregroundColor: showFormattingBar
                        ? theme.colorScheme.primary
                        : textColor,
                  ),
                ),
                if (isAiActive && !minimalEditorMode) ...[
                  IconButton.filledTonal(
                    icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                    tooltip: 'Gemini AI Assist',
                    onPressed: onShowAiOptions,
                    style: IconButton.styleFrom(
                      backgroundColor: noteScheme.primaryContainer,
                      foregroundColor: noteScheme.onPrimaryContainer,
                    ),
                  ),
                  ExpressiveFloatingToolbar.spacer(),
                ],
                if (!minimalEditorMode)
                  IconButton(
                    icon: const Icon(Icons.table_chart_outlined),
                    tooltip: 'Insert Table',
                    onPressed: onInsertTable,
                    style: IconButton.styleFrom(
                      foregroundColor: textColor,
                    ),
                  ),
                QuillToolbarToggleCheckListButton(
                  controller: quillController,
                  options: QuillToolbarToggleCheckListButtonOptions(
                      iconData: Icons.check_box_outlined,
                      iconTheme: QuillIconTheme(
                          iconButtonUnselectedData:
                              IconButtonData(
                                  style: IconButton.styleFrom(
                                      foregroundColor: textColor)),
                          iconButtonSelectedData:
                              IconButtonData(
                                  style: IconButton.styleFrom(
                                      foregroundColor:
                                          theme.colorScheme.onPrimary)))),
                ),
                IconButton(
                  icon: const Icon(Icons.image_outlined),
                  tooltip: 'Attach Image',
                  onPressed: onShowImageOptions,
                  style: IconButton.styleFrom(
                    foregroundColor: textColor,
                  ),
                ),
                if (isKeyboardOpen)
                  IconButton(
                    icon: const Icon(Icons.keyboard_hide_rounded),
                    tooltip: 'Hide Keyboard',
                    onPressed: onHideKeyboard,
                    style: IconButton.styleFrom(
                      foregroundColor: textColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
