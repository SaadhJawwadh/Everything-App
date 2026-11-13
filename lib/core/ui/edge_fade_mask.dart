import 'package:flutter/material.dart';

/// Direction along which [EdgeFadeMask] feathers overflowing scroll content.
enum EdgeFadeAxis {
  /// Feathers the bottom edge of a vertical scroll container.
  verticalBottom,

  /// Feathers the trailing right edge of a horizontal scroll container.
  horizontalRight,
}

/// Applies a subtle [ShaderMask] alpha feather to the trailing edge of
/// scrollable content so clipped cards or chips signal scrollability cleanly.
class EdgeFadeMask extends StatelessWidget {
  final Widget child;
  final EdgeFadeAxis axis;
  final double fadeStop;

  const EdgeFadeMask({
    super.key,
    required this.child,
    this.axis = EdgeFadeAxis.horizontalRight,
    this.fadeStop = 0.94,
  });

  @override
  Widget build(BuildContext context) {
    final isVertical = axis == EdgeFadeAxis.verticalBottom;
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
