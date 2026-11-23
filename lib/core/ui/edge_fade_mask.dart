import 'package:flutter/material.dart';

/// Direction along which [EdgeFadeMask] feathers overflowing scroll content.
enum EdgeFadeAxis {
  /// Feathers the bottom edge of a vertical scroll container.
  verticalBottom,

  /// Feathers the trailing right edge of a horizontal scroll container.
  horizontalRight,
}

/// Applies a subtle trailing edge fade to scrollable content so clipped cards
/// or chips signal scrollability cleanly.
///
/// When [fadeColor] is provided (matching the solid surface behind the scroll
/// view), renders a zero-`saveLayer` gradient overlay instead of [ShaderMask].
class EdgeFadeMask extends StatelessWidget {
  final Widget child;
  final EdgeFadeAxis axis;
  final double fadeStop;
  final Color? fadeColor;
  final double fadeExtent;

  const EdgeFadeMask({
    super.key,
    required this.child,
    this.axis = EdgeFadeAxis.horizontalRight,
    this.fadeStop = 0.94,
    this.fadeColor,
    this.fadeExtent = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    final isVertical = axis == EdgeFadeAxis.verticalBottom;
    if (fadeColor != null) {
      final gradient = LinearGradient(
        begin: isVertical ? Alignment.topCenter : Alignment.centerLeft,
        end: isVertical ? Alignment.bottomCenter : Alignment.centerRight,
        colors: [fadeColor!.withValues(alpha: 0.0), fadeColor!],
      );
      return Stack(
        children: [
          child,
          Positioned(
            left: isVertical ? 0 : null,
            right: 0,
            top: isVertical ? null : 0,
            bottom: 0,
            width: isVertical ? null : fadeExtent,
            height: isVertical ? fadeExtent : null,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: gradient),
              ),
            ),
          ),
        ],
      );
    }

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: isVertical ? Alignment.topCenter : Alignment.centerLeft,
          end: isVertical ? Alignment.bottomCenter : Alignment.centerRight,
          colors: const [Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, fadeStop, 1.0],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}
