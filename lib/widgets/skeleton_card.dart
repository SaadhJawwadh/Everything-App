import 'package:flutter/material.dart';
import '../core/theme/app_layout.dart';

/// A softly pulsing placeholder card shown while content loads.
class SkeletonCard extends StatefulWidget {
  final double height;
  const SkeletonCard({super.key, required this.height});

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
    upperBound: 1.0,
  );
  late final CurvedAnimation _curvedOpacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutSine,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppLayout.shouldReduceMotion(context)) {
      _controller.stop();
      _controller.value = 0.72;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _curvedOpacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _curvedOpacity,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppLayout.radiusL),
          ),
        ),
      ),
    );
  }
}
