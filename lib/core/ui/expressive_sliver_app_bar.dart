import 'package:flutter/material.dart';
import '../theme/app_layout.dart';

/// Material 3 Expressive borderless surface top app bar.
/// Uses 100% solid surfaceContainerLow fill with subtle tonal elevation and zero blur.
class ExpressiveSliverAppBar extends StatelessWidget {
  final Widget? title;
  final String? titleText;
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final double height;

  const ExpressiveSliverAppBar({
    super.key,
    this.title,
    this.titleText,
    this.leading,
    this.showBackButton = false,
    this.onBackPressed,
    this.actions,
    this.height = 56.0,
  });

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final totalHeight = statusBarHeight + height + 12.0;

    Widget? leadingWidget = leading;
    if (leadingWidget == null && showBackButton) {
      leadingWidget = IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Back',
        onPressed: onBackPressed ??
            () {
              Navigator.pop(context);
            },
      );
    }

    Widget headerContent;
    if (title != null) {
      headerContent = title!;
    } else {
      headerContent = Text(
        titleText ?? '',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
        overflow: TextOverflow.ellipsis,
      );
    }

    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      primary: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: totalHeight,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        padding: EdgeInsets.only(
          top: statusBarHeight + 6,
          left: AppLayout.spaceL,
          right: AppLayout.spaceL,
          bottom: 6,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          border: null,
        ),
        child: Align(
          alignment: Alignment.center,
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                if (leadingWidget != null) ...[
                  leadingWidget,
                  const SizedBox(width: AppLayout.spaceXS),
                ],
                Expanded(child: headerContent),
                if (actions != null) ...actions!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Backward compatibility alias for migration continuity.
typedef FrostedGlassSliverAppBar = ExpressiveSliverAppBar;
