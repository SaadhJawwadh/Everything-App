import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../../../core/theme/app_layout.dart';

/// Standard typography and block formatting styles for FlutterQuill in NoteEditorScreen.
class NoteEditorStyles {
  static DefaultStyles build({
    required ThemeData theme,
    required ColorScheme noteScheme,
  }) {
    return DefaultStyles(
      inlineCode: InlineCodeStyle(
        style: TextStyle(
          color: noteScheme.onSurface,
          backgroundColor: noteScheme.onSurface.withValues(alpha: 0.15),
          fontFamily: 'monospace',
        ),
      ),
      h1: DefaultTextBlockStyle(
        theme.textTheme.displaySmall!.copyWith(
          color: noteScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(16, 0),
        const VerticalSpacing(0, 0),
        null,
      ),
      h2: DefaultTextBlockStyle(
        theme.textTheme.headlineMedium!.copyWith(
          color: noteScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(14, 0),
        const VerticalSpacing(0, 0),
        null,
      ),
      h3: DefaultTextBlockStyle(
        theme.textTheme.headlineSmall!.copyWith(
          color: noteScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(12, 0),
        const VerticalSpacing(0, 0),
        null,
      ),
      quote: DefaultTextBlockStyle(
        TextStyle(
          color: noteScheme.onSurface.withValues(alpha: 0.7),
          fontStyle: FontStyle.italic,
          fontSize: 16,
        ),
        const HorizontalSpacing(16, 0),
        const VerticalSpacing(8, 8),
        const VerticalSpacing(0, 0),
        BoxDecoration(
          border: Border(
            left: BorderSide(
              width: 4,
              color: noteScheme.primary,
            ),
          ),
        ),
      ),
      code: DefaultTextBlockStyle(
        TextStyle(
          color: noteScheme.onSurface,
          fontFamily: 'monospace',
          fontSize: 13.5,
          height: 1.4,
        ),
        const HorizontalSpacing(12, 12),
        const VerticalSpacing(8, 8),
        const VerticalSpacing(0, 0),
        BoxDecoration(
          color: noteScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppLayout.radiusM),
          border: Border.all(
            color: noteScheme.outlineVariant.withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
      ),
    );
  }
}
