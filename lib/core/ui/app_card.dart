import 'package:flutter/material.dart';
import '../theme/app_layout.dart';

/// Group position for connected corner morphing in lists and cards.
enum AppCardGroupPosition {
  none,   // Isolated card: uniform outer radius
  first,  // Top item: rounded top corners, connected inner bottom corners (6dp)
  middle, // Middle item: connected inner corners (6dp)
  last,   // Bottom item: connected inner top corners (6dp), rounded bottom corners
  single, // Single item in group: all corners outer radius
}

/// Reusable AppCard widget providing single-source-of-truth styling for card containers.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final BorderSide? border;
  final double? borderRadius;
  final BorderRadiusGeometry? borderRadiusGeometry;
  final ShapeBorder? shape;
  final List<BoxShadow>? boxShadow;
  final bool isFrosted;
  final double blurSigma;
  final AppCardGroupPosition groupPosition;
  final bool isSelected;
  final bool isStadium;
  final bool animate;
  final Duration animationDuration;
  final Curve animationCurve;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.borderRadiusGeometry,
    this.shape,
    this.boxShadow,
    this.groupPosition = AppCardGroupPosition.none,
    this.isSelected = false,
    this.isStadium = false,
    this.animate = false,
    this.animationDuration = AppLayout.animDefault,
    this.animationCurve = AppLayout.curveExpressiveSpatial,
  })  : isFrosted = false,
        blurSigma = 0.0;

  /// Material 3 Tonal Card constructor with subtle container tint & matching border.
  factory AppCard.tonal({
    Key? key,
    required Widget child,
    required Color color,
    Color? borderColor,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    double? borderRadius,
    BorderRadiusGeometry? borderRadiusGeometry,
    ShapeBorder? shape,
    List<BoxShadow>? boxShadow,
    AppCardGroupPosition groupPosition = AppCardGroupPosition.none,
    bool isSelected = false,
    bool isStadium = false,
    bool animate = false,
    Duration animationDuration = AppLayout.animDefault,
    Curve animationCurve = AppLayout.curveExpressiveSpatial,
  }) {
    return AppCard(
      key: key,
      padding: padding,
      margin: margin,
      onTap: onTap,
      onLongPress: onLongPress,
      backgroundColor: color,
      border: BorderSide(
        color: borderColor ?? color.withValues(alpha: 0.35),
        width: 1.0,
      ),
      borderRadius: borderRadius,
      borderRadiusGeometry: borderRadiusGeometry,
      shape: shape,
      boxShadow: boxShadow,
      groupPosition: groupPosition,
      isSelected: isSelected,
      isStadium: isStadium,
      animate: animate,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
      child: child,
    );
  }

  /// Material 3 Surface Card constructor (formerly frosted, now pure solid M3 surface container).
  const AppCard.frosted({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.borderRadiusGeometry,
    this.shape,
    this.boxShadow,
    this.groupPosition = AppCardGroupPosition.none,
    this.isSelected = false,
    this.isStadium = false,
    this.animate = false,
    this.animationDuration = AppLayout.animDefault,
    this.animationCurve = AppLayout.curveExpressiveSpatial,
    this.blurSigma = 0.0,
  }) : isFrosted = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveColor = isSelected
        ? theme.colorScheme.primaryContainer.withValues(alpha: isDark ? 0.35 : 0.50)
        : (backgroundColor ??
            (isFrosted
                ? (isDark
                    ? theme.colorScheme.surfaceContainerHigh
                    : theme.colorScheme.surfaceContainer)
                : theme.colorScheme.surfaceContainerHigh));

    final effectiveBorder = isSelected
        ? BorderSide(
            color: theme.colorScheme.primary,
            width: 1.5,
          )
        : (border ??
            (isFrosted
                ? BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.50),
                    width: 1.0,
                  )
                : null));

    final double outer = borderRadius ?? (isStadium ? AppLayout.radiusStadium : AppLayout.radiusL);
    const double inner = 6.0;

    final BorderRadiusGeometry effectiveBorderRadius = borderRadiusGeometry ??
        () {
          if (shape is RoundedRectangleBorder) {
            return (shape as RoundedRectangleBorder).borderRadius;
          }
          if (isStadium) {
            return BorderRadius.circular(AppLayout.radiusStadium);
          }
          switch (groupPosition) {
            case AppCardGroupPosition.first:
              return BorderRadius.only(
                topLeft: Radius.circular(outer),
                topRight: Radius.circular(outer),
                bottomLeft: const Radius.circular(inner),
                bottomRight: const Radius.circular(inner),
              );
            case AppCardGroupPosition.middle:
              return const BorderRadius.all(Radius.circular(inner));
            case AppCardGroupPosition.last:
              return BorderRadius.only(
                topLeft: const Radius.circular(inner),
                topRight: const Radius.circular(inner),
                bottomLeft: Radius.circular(outer),
                bottomRight: Radius.circular(outer),
              );
            case AppCardGroupPosition.single:
            case AppCardGroupPosition.none:
              return BorderRadius.circular(outer);
          }
        }();

    final bool shouldAnimate = animate ||
        groupPosition != AppCardGroupPosition.none ||
        isSelected ||
        isStadium;

    Widget cardPadding = Padding(
      padding: padding ?? AppLayout.paddingAllL,
      child: child,
    );

    Widget innerInk = (onTap != null || onLongPress != null)
        ? Material(
            color: Colors.transparent,
            borderRadius: effectiveBorderRadius is BorderRadius ? effectiveBorderRadius : null,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              splashColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              highlightColor: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: effectiveBorderRadius is BorderRadius ? effectiveBorderRadius : null,
              child: cardPadding,
            ),
          )
        : Material(
            type: MaterialType.transparency,
            child: cardPadding,
          );

    Widget containerWidget;
    if (shape != null) {
      final decoration = ShapeDecoration(
        color: effectiveColor,
        shape: shape!,
        shadows: boxShadow,
      );
      containerWidget = shouldAnimate
          ? AnimatedContainer(
              duration: animationDuration,
              curve: animationCurve,
              decoration: decoration,
              child: innerInk,
            )
          : Container(
              decoration: decoration,
              child: innerInk,
            );
    } else {
      final decoration = BoxDecoration(
        color: effectiveColor,
        borderRadius: effectiveBorderRadius,
        border: effectiveBorder != null ? Border.fromBorderSide(effectiveBorder) : null,
        boxShadow: boxShadow,
      );
      containerWidget = shouldAnimate
          ? AnimatedContainer(
              duration: animationDuration,
              curve: animationCurve,
              decoration: decoration,
              child: innerInk,
            )
          : Container(
              decoration: decoration,
              child: innerInk,
            );
    }

    if (margin != null) {
      containerWidget = Padding(
        padding: margin!,
        child: containerWidget,
      );
    }

    return containerWidget;
  }
}
