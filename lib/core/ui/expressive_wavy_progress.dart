import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_layout.dart';

/// Material 3 Expressive Animated Sinusoidal Wavy Linear Progress Indicator.
class ExpressiveWavyLinearProgress extends StatefulWidget {
  final double? value;
  final Color? color;
  final Color? backgroundColor;
  final double height;

  const ExpressiveWavyLinearProgress({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.height = 6.0,
  });

  @override
  State<ExpressiveWavyLinearProgress> createState() =>
      _ExpressiveWavyLinearProgressState();
}

class _ExpressiveWavyLinearProgressState
    extends State<ExpressiveWavyLinearProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppLayout.shouldReduceMotion(context)) {
      _controller.stop();
      _controller.value = 0.0;
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
    final colorScheme = theme.colorScheme;
    final primary = widget.color ?? colorScheme.primary;
    final bg = widget.backgroundColor ?? colorScheme.surfaceContainerHighest;

    return RepaintBoundary(
      child: CustomPaint(
        size: Size(double.infinity, widget.height + 6.0),
        painter: _WavyProgressPainter(
          progress: widget.value,
          animation: _controller,
          color: primary,
          backgroundColor: bg,
          strokeWidth: widget.height,
        ),
      ),
    );
  }
}

class _WavyProgressPainter extends CustomPainter {
  final double? progress;
  final Animation<double> animation;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _WavyProgressPainter({
    required this.progress,
    required this.animation,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final double midY = size.height / 2;

    // Background track
    final Paint bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(strokeWidth / 2, midY),
      Offset(size.width - strokeWidth / 2, midY),
      bgPaint,
    );

    // Active Wavy track
    final Paint activePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double activeWidth = progress != null
        ? (size.width * progress!.clamp(0.0, 1.0))
        : size.width;

    if (activeWidth <= strokeWidth) return;

    final Path wavePath = Path();
    wavePath.moveTo(strokeWidth / 2, midY);

    const double wavelength = 20.0;
    const double amplitude = 3.0;
    final double phase = animation.value * 2 * math.pi;

    for (double x = strokeWidth / 2; x <= activeWidth; x += 2.0) {
      final double y = midY + amplitude * math.sin((x / wavelength) * 2 * math.pi - phase);
      wavePath.lineTo(x, y);
    }

    canvas.drawPath(wavePath, activePaint);
  }

  @override
  bool shouldRepaint(covariant _WavyProgressPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
