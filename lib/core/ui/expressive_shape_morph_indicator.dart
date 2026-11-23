import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_layout.dart';

/// Material 3 Expressive Shape-Morphing Loading Indicator.
/// Continuously interpolates between expressive geometric polygons (circle, rounded squircle, starburst, clover).
class ExpressiveShapeMorphIndicator extends StatefulWidget {
  final double size;
  final Color? color;

  const ExpressiveShapeMorphIndicator({
    super.key,
    this.size = 40.0,
    this.color,
  });

  @override
  State<ExpressiveShapeMorphIndicator> createState() =>
      _ExpressiveShapeMorphIndicatorState();
}

class _ExpressiveShapeMorphIndicatorState
    extends State<ExpressiveShapeMorphIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppLayout.shouldReduceMotion(context)) {
      _controller.stop();
      _controller.value = 0.25;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = widget.color ?? theme.colorScheme.primary;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _ShapeMorphPainter(
            animation: _controller,
            color: indicatorColor,
          ),
        ),
      ),
    );
  }
}

class _ShapeMorphPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _ShapeMorphPainter({
    required this.animation,
    required this.color,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final double progress = animation.value;
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double baseRadius = size.width / 2 * 0.85;

    // Harmonic frequency morphing across stages (4-lobe clover -> squircle -> 8-point starburst -> smooth circle)
    final double stage = progress * 4.0;
    final int currentPhase = stage.floor() % 4;
    final double t = stage - stage.floor();

    final Path path = Path();
    const int numPoints = 120;

    for (int i = 0; i <= numPoints; i++) {
      final double theta = (i / numPoints) * 2 * math.pi;
      double r = baseRadius;

      // Calculate radial harmonic modulation based on phase
      switch (currentPhase) {
        case 0: // Circle to 4-corner squircle
          final double harmonic = math.cos(4 * theta);
          r += (harmonic * (baseRadius * 0.22)) * t;
          break;
        case 1: // Squircle to 8-point starburst
          final double h1 = math.cos(4 * theta) * (baseRadius * 0.22);
          final double h2 = math.cos(8 * theta) * (baseRadius * 0.25);
          r += h1 * (1 - t) + h2 * t;
          break;
        case 2: // Starburst to 3-petal clover
          final double h2 = math.cos(8 * theta) * (baseRadius * 0.25);
          final double h3 = math.cos(3 * theta) * (baseRadius * 0.25);
          r += h2 * (1 - t) + h3 * t;
          break;
        case 3: // Clover back to smooth circle
          final double h3 = math.cos(3 * theta) * (baseRadius * 0.25);
          r += h3 * (1 - t);
          break;
      }

      final double x = center.dx + r * math.cos(theta + progress * 2 * math.pi);
      final double y = center.dy + r * math.sin(theta + progress * 2 * math.pi);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ShapeMorphPainter oldDelegate) {
    return oldDelegate.animation != animation || oldDelegate.color != color;
  }
}
