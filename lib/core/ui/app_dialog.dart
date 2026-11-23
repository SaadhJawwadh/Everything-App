import 'package:flutter/material.dart';
import '../services/app_haptics.dart';
import '../theme/app_layout.dart';
import '../../l10n/app_localizations.dart';

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

  /// Displays a dialog using standardized scale (0.94 -> 1.0) + fade motion
  /// and reduced-motion awareness.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    bool useRootNavigator = true,
  }) {
    final reduceMotion = AppLayout.shouldReduceMotion(context);
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      useRootNavigator: useRootNavigator,
      transitionDuration: reduceMotion ? Duration.zero : AppLayout.animFast,
      pageBuilder: (dialogContext, _, __) => Builder(builder: builder),
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        if (reduceMotion) {
          return FadeTransition(opacity: animation, child: child);
        }
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppLayout.curveStrongEaseOut,
          reverseCurve: AppLayout.curveEmphasizedAccelerate,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Standardized confirmation dialog prompt.
  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) {
    return show<bool>(
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
    final l10n = AppLocalizations.of(context);
    final resolvedCancel = cancelLabel == 'Cancel' ? (l10n?.cancel ?? cancelLabel) : cancelLabel;
    final resolvedConfirm = confirmLabel == 'Confirm' ? (l10n?.confirm ?? confirmLabel) : confirmLabel;

    return DisplayFeatureSubScreen(
      anchorPoint: Offset.zero,
      child: AlertDialog(
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
              child: Text(resolvedCancel),
            ),
            if (showConfirmButton)
              FilledButton(
                onPressed: () {
                  if (isDestructive) {
                    AppHaptics.mediumImpact();
                  } else {
                    AppHaptics.lightImpact();
                  }
                  if (onConfirm != null) {
                    onConfirm!();
                  } else {
                    Navigator.of(context).pop(true);
                  }
                },
                style: isDestructive
                    ? FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                      )
                    : null,
                child: Text(resolvedConfirm),
              ),
          ],
        ),
      );
  }
}
