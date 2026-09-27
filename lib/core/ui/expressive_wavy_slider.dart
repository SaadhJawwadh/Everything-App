import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/app_haptics.dart';

/// Material 3 Expressive Tactile Sinusoidal Wavy Slider.
/// Renders an oscillating sinusoidal wave along the active track that reacts to value changes.
class ExpressiveWavySlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final Color? activeColor;
  final Color? inactiveColor;

  const ExpressiveWavySlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.onChangeEnd,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<ExpressiveWavySlider> createState() => _ExpressiveWavySliderState();
}

class _ExpressiveWavySliderState extends State<ExpressiveWavySlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  int? _lastStepIndex;
  double? _lastBoundHit;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    if (widget.divisions != null && widget.divisions! > 0) {
      _lastStepIndex = _computeStep(widget.value);
    }
  }

  int _computeStep(double val) {
    if (widget.divisions == null || widget.divisions! <= 0) return 0;
    final range = widget.max - widget.min;
    if (range <= 0) return 0;
    return ((val - widget.min) / range * widget.divisions!).round();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final active = widget.activeColor ?? colorScheme.primary;
    final inactive = widget.inactiveColor ?? colorScheme.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackShape: _WavySliderTrackShape(
              waveAnimation: _waveController.value,
              activeColor: active,
              inactiveColor: inactive,
            ),
            thumbColor: active,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
            overlayColor: active.withValues(alpha: 0.16),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 22.0),
          ),
          child: Slider(
            value: widget.value.clamp(widget.min, widget.max),
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            onChanged: (val) {
              if (widget.divisions != null && widget.divisions! > 0) {
                // Discrete slider: tick once cleanly per discrete step crossing
                final currentStep = _computeStep(val);
                if (_lastStepIndex != null && currentStep != _lastStepIndex) {
                  AppHaptics.selectionClick();
                }
                _lastStepIndex = currentStep;
              } else {
                // Continuous slider: silent during drag, subtle bump on reaching min or max bounds
                const double threshold = 1e-4;
                final bool atMin = (val - widget.min).abs() <= threshold;
                final bool atMax = (val - widget.max).abs() <= threshold;

                if (atMin && _lastBoundHit != widget.min) {
                  AppHaptics.selectionClick();
                  _lastBoundHit = widget.min;
                } else if (atMax && _lastBoundHit != widget.max) {
                  AppHaptics.selectionClick();
                  _lastBoundHit = widget.max;
                } else if (!atMin && !atMax) {
                  _lastBoundHit = null;
                }
              }
              widget.onChanged(val);
            },
            onChangeEnd: (val) {
              _lastStepIndex = widget.divisions != null && widget.divisions! > 0
                  ? _computeStep(val)
                  : null;
              _lastBoundHit = null;
              widget.onChangeEnd?.call(val);
            },
          ),
        );
      },
    );
  }
}

class _WavySliderTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  final double waveAnimation;
  final Color activeColor;
  final Color inactiveColor;

  _WavySliderTrackShape({
    required this.waveAnimation,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Paint inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final Paint activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    // Draw inactive flat track
    context.canvas.drawLine(
      Offset(thumbCenter.dx, trackRect.center.dy),
      Offset(trackRect.right, trackRect.center.dy),
      inactivePaint,
    );

    // Draw active sinusoidal wavy track
    final Path wavePath = Path();
    final double startX = trackRect.left;
    final double endX = thumbCenter.dx;

    if (endX <= startX) return;

    wavePath.moveTo(startX, trackRect.center.dy);
    const double wavelength = 18.0;
    const double amplitude = 3.5;
    final double phase = waveAnimation * 2 * math.pi;

    for (double x = startX; x <= endX; x += 2.0) {
      final double relativeX = x - startX;
      final double y = trackRect.center.dy +
          amplitude * math.sin((relativeX / wavelength) * 2 * math.pi - phase);
      wavePath.lineTo(x, y);
    }

    context.canvas.drawPath(wavePath, activePaint);
  }
}
