import 'package:flutter/material.dart';
import '../theme/app_layout.dart';

/// A docked Material 3 bottom action bar for full-screen form editors.
///
/// Automatically hides when the soft keyboard is open so form inputs remain
/// unobstructed while typing, and renders a solid `surfaceContainerLow` bar
/// with an optional leading tonal icon button and a primary stadium CTA.
class EditorBottomActionBar extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final Widget? leadingAction;

  const EditorBottomActionBar({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.leadingAction,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppLayout.spaceM,
            AppLayout.spaceS + 4,
            AppLayout.spaceM,
            AppLayout.spaceS + 4,
          ),
          child: Row(
            children: [
              if (leadingAction != null) ...[
                leadingAction!,
                const SizedBox(width: AppLayout.spaceS),
              ],
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onPressed,
                    icon: Icon(icon),
                    label: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
