import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// M3 Expressive physics-based spring curve driven by [SpringSimulation].
class ExpressiveSpringCurve extends Curve {
  final SpringDescription spring;
  final double startVelocity;

  const ExpressiveSpringCurve({
    this.spring = AppLayout.springSpatial,
    this.startVelocity = 0.0,
  });

  @override
  double transformInternal(double t) {
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    final sim = SpringSimulation(spring, 0.0, 1.0, startVelocity);
    return sim.x(t);
  }
}

class AppLayout {
  // Spacing Single Source of Truth
  static const double spaceXS = 4.0;
  static const double spaceS = 8.0;
  static const double spaceM = 12.0;
  static const double spaceL = 16.0;
  static const double spaceXL = 24.0;
  static const double spaceXXL = 32.0;

  // Border Radii Single Source of Truth
  static const double radiusXS = 4.0;
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 28.0;
  static const double radiusMAX = 32.0;
  static const double radiusStadium = 1000.0;

  // Icons
  static const double iconS = 16.0;
  static const double iconM = 24.0;
  static const double iconL = 32.0;
  static const double iconXL = 48.0;
  static const double icon20 = 20.0;

  // ── Animation Durations (Sub-300ms UI Discipline) ─────────────────────────
  /// 140ms: Button press-in/release feedback and micro-toggles (100–160ms budget).
  static const Duration animMicro = Duration(milliseconds: 140);

  /// 180ms: Fast UI state changes, checkboxes, chips, and popovers (150–200ms budget).
  static const Duration animFast = Duration(milliseconds: 180);

  /// 200ms: Standard snappy UI transitions and staggered list items.
  static const Duration animShort = Duration(milliseconds: 200);

  /// 250ms: Modal bottom sheets, dialogs, and OpenContainer card morphs (<300ms budget).
  static const Duration animModal = Duration(milliseconds: 250);

  /// 300ms: Maximum ceiling for standard spatial transitions.
  static const Duration animDefault = Duration(milliseconds: 300);

  /// 420ms: Benevolent friction trust window (Wise / Pokered 30-frame verification beat).
  static const Duration animTrustBeat = Duration(milliseconds: 420);

  /// 500ms: Reserved strictly for rare/first-time onboarding or celebratory morphs.
  static const Duration animLong = Duration(milliseconds: 500);

  // ── Easing Curves (Emil Kowalski & M3 Expressive) ─────────────────────────
  /// Strong ease-out for entering/exiting UI elements — starts fast on frame 1.
  static const Curve curveStrongEaseOut = Cubic(0.23, 1.0, 0.32, 1.0);

  /// Strong ease-in-out for elements already on screen moving/morphing.
  static const Curve curveStrongEaseInOut = Cubic(0.77, 0.0, 0.175, 1.0);

  /// Fluid iOS/Ionic drawer and sheet curve.
  static const Curve curveSheet = Cubic(0.32, 0.72, 0.0, 1.0);

  static const Curve curveExpressive = Curves.easeOutBack;
  static const Curve curveSpring = Curves.elasticOut;
  static const Curve curveFast = Curves.easeOutCubic;
  static const Curve curveEmphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve curveEmphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  // M3 Expressive Velocity-Aware Spring Physics Tokens
  /// Fast snappy spring for button presses, icon snaps, and toggle micro-interactions.
  static const SpringDescription springFast = SpringDescription(
    mass: 1.0,
    stiffness: 380.0,
    damping: 24.0,
  );

  /// Spatial natural spring for bottom sheets, dialog entrances, and folder expansions.
  static const SpringDescription springSpatial = SpringDescription(
    mass: 1.0,
    stiffness: 300.0,
    damping: 22.0,
  );

  /// Playful bouncy spring for FAB morphs, badges, and success celebrations.
  static const SpringDescription springBouncy = SpringDescription(
    mass: 1.0,
    stiffness: 240.0,
    damping: 14.0,
  );

  /// M3 Expressive Spatial Spring Curve (smooth settling for cards, sheets, dialogs).
  static const Curve curveExpressiveSpatial = ExpressiveSpringCurve(spring: springSpatial);

  /// M3 Expressive Snappy Effects Spring Curve (for toolbars, pills, toggles, chips).
  static const Curve curveExpressiveEffects = ExpressiveSpringCurve(spring: springFast);

  /// M3 Expressive Bouncy Spring Curve (for badges, celebrations, FAB morphs).
  static const Curve curveExpressiveBouncy = ExpressiveSpringCurve(spring: springBouncy);

  /// Returns true when the OS accessibility "Reduce Motion" / "Remove Animations" setting is active.
  /// Per Emil Kowalski's accessibility rule: reduced motion means gentler motion (keep opacity/color,
  /// drop spatial translation, scale bounces, and looping timers), not broken UI.
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  /// Standard origin-safe scale + fade transition builder that never animates from scale(0).
  /// Starts at scale 0.92 with 0.0 opacity and settles at 1.0 using [curveStrongEaseOut].
  static Widget scaleFadeTransitionBuilder(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: curveStrongEaseOut,
      reverseCurve: curveEmphasizedAccelerate,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
        child: child,
      ),
    );
  }

  // Layout Constraints & Breakpoints
  static const double maxContentWidth = 600.0;
  static const double breakpointCompact = 600.0;
  static const double breakpointMedium = 840.0;
  static const double breakpointExpanded = 1200.0;
  static const double cardElevation = 0.0;
  static const double floatingElevation = 6.0;

  /// Returns true if the screen is wide enough for dual-pane presentation (foldables & tablets).
  static bool isDualPane(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= breakpointCompact;
  }

  /// Returns true if the device has a physical hinge or display feature dividing the screen.
  static bool hasHinge(BuildContext context) {
    return MediaQuery.displayFeaturesOf(context).isNotEmpty;
  }

  // Shared Padding
  static const double fabBottomPadding = 96.0;
  static const EdgeInsets paddingAllM = EdgeInsets.all(spaceM);
  static const EdgeInsets paddingAllL = EdgeInsets.all(spaceL);
  static const EdgeInsets paddingHome = EdgeInsets.fromLTRB(spaceL, 0, spaceL, fabBottomPadding);

  /// Theme-driven soft shadow that adapts between light & dark themes.
  static List<BoxShadow> softShadow(BuildContext context, {double blurRadius = 10, Offset offset = const Offset(0, 4)}) {
    return [
      BoxShadow(
        color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
        blurRadius: blurRadius,
        offset: offset,
      ),
    ];
  }
}
