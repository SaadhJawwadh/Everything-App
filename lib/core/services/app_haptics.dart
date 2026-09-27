import 'package:flutter/services.dart';

/// Single source of truth for tactile haptic feedback across the application.
/// Respects the global [isEnabled] preference managed by SettingsProvider.
class AppHaptics {
  AppHaptics._();

  /// Global toggle controlling whether tactile haptics are emitted.
  static bool isEnabled = true;

  /// Subtle click for discrete step transitions (e.g. slider step snapping),
  /// boundary collisions, or direct toggle controls.
  static void selectionClick() {
    if (!isEnabled) return;
    HapticFeedback.selectionClick();
  }

  /// Light tactile impact for confirmed positive actions or goal milestones.
  static void lightImpact() {
    if (!isEnabled) return;
    HapticFeedback.lightImpact();
  }

  /// Medium tactile impact for mode transitions (long-press multi-select)
  /// or high-consequence/destructive actions (trash purge, bulk delete).
  static void mediumImpact() {
    if (!isEnabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Heavy impact for critical error states or security alerts.
  static void heavyImpact() {
    if (!isEnabled) return;
    HapticFeedback.heavyImpact();
  }
}
