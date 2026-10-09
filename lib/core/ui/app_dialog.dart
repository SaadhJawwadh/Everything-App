import 'package:flutter/material.dart';

/// Reusable Modal Dialog helper providing consistent M3 alert and input dialog styling.
class AppDialog extends StatelessWidget {
  final String title;
  final Widget? content;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final bool showConfirmButton;
  final List<Widget>? actions;

  const AppDialog({
    super.key,
    required this.title,
    this.content,
    this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
    this.showConfirmButton = true,
    this.actions,
  });

  /// Standardized confirmation dialog prompt.
  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: content ??
          (message != null
              ? Text(
                  message!,
                  style: theme.textTheme.bodyMedium,
                )
              : null),
      actions: actions ??
          [
            TextButton(
              onPressed: onCancel ?? () => Navigator.of(context).pop(),
              child: Text(cancelLabel),
            ),
            if (showConfirmButton)
              FilledButton(
                onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
                style: isDestructive
                    ? FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                      )
                    : null,
                child: Text(confirmLabel),
              ),
          ],
    );
  }
}
