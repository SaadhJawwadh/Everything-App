import 'package:flutter/material.dart';
import '../theme/app_layout.dart';

/// Reusable Modal Bottom Sheet helper providing standardized layout, drag handles, and width constraints.
class AppBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;
  final bool showDragHandle;

  const AppBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.padding,
    this.showDragHandle = true,
  });

  /// Displays [child] in a standardized Modal Bottom Sheet.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    List<Widget>? actions,
    bool isScrollControlled = true,
    bool showDragHandle = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: const AnimationStyle(
        duration: AppLayout.animDefault,
        reverseDuration: AppLayout.animShort,
        curve: AppLayout.curveEmphasizedDecelerate,
        reverseCurve: AppLayout.curveEmphasizedAccelerate,
      ),
      builder: (context) => AppBottomSheet(
        title: title,
        actions: actions,
        showDragHandle: showDragHandle,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppLayout.maxContentWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.90,
        ),
        child: Material(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppLayout.radiusXXL),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            if (showDragHandle)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: AppLayout.spaceM, bottom: AppLayout.spaceS),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppLayout.radiusS),
                  ),
                ),
              ),
            if (title != null || actions != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppLayout.spaceL, AppLayout.spaceS, AppLayout.spaceL, AppLayout.spaceS),
                child: Row(
                  children: [
                    if (title != null)
                      Expanded(
                        child: Text(
                          title!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (actions != null) ...actions!,
                  ],
                ),
              ),
            Flexible(
              child: Padding(
                padding: padding ?? const EdgeInsets.all(AppLayout.spaceL),
                child: child,
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
