import 'package:flutter/material.dart';
import '../../../../core/theme/app_layout.dart';

/// Floating AI summary overlay panel positioned above the bottom toolbar.
class NoteAiSummaryPanel extends StatelessWidget {
  final String summary;
  final ColorScheme noteScheme;
  final VoidCallback onClose;
  final VoidCallback onCopy;
  final VoidCallback onAppend;

  const NoteAiSummaryPanel({
    super.key,
    required this.summary,
    required this.noteScheme,
    required this.onClose,
    required this.onCopy,
    required this.onAppend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      left: 16,
      right: 16,
      bottom: 80, // Elevated above bottom formatting bar
      child: Card(
        color: noteScheme.surfaceContainerHigh,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusL),
          side: BorderSide(
            color: noteScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: noteScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'AI Summary',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClose,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Text(
                    summary,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                      color: noteScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    onPressed: onCopy,
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Append'),
                    onPressed: onAppend,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
