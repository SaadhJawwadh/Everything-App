# Antigravity Master Execution Plan: Animation Design Engineering Overhaul

> **Target Repository**: `/Users/saadhjawwadh/Documents/Code/Everything App`
> **Companion Skill**: [`.agent/skills/Animation-Design-Engineering/SKILL.md`](file:///Users/saadhjawwadh/Documents/Code/Everything%20App/.agent/skills/Animation-Design-Engineering/SKILL.md)
> **Source Authority**: Enrico Tartarotti's [*The Ridiculous Engineering Of Animations*](https://www.youtube.com/watch?v=z3Lo5QT7nME) & Emil Kowalski's [`emilkowalski/skills`](https://github.com/emilkowalski/skills) ([`emil-design-eng`](https://github.com/emilkowalski/skills/blob/main/skills/emil-design-eng/SKILL.md), [`animate`](https://www.ui-skills.com/skills/emilkowalski/animate), [`animate-expo`](https://github.com/emilkowalski/skills/blob/main/skills/animate-expo/SKILL.md), [`review-animations`](https://github.com/emilkowalski/skills/blob/main/skills/review-animations/SKILL.md), [`improve-animations`](https://github.com/emilkowalski/skills/blob/main/skills/improve-animations/SKILL.md)), [`animations.dev`](https://animations.dev/), [`pret/pokered`](https://github.com/pret/pokered), and [`rileycx/strafe`](https://github.com/rileycx/strafe).

---

## 1. Executive Audit Table (`Before` / `After` / `Why`)

Every finding below was verified directly against the current `Everything App` codebase (`v2.47.0+24700`). Execute all 10 milestones in order.

| # | Severity | Location (`file:line`) | Before | After | Why (Video & Repo Principle) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | **HIGH** | `lib/core/theme/app_layout.dart:50-87` | Only defines `animShort (200ms)`, `animDefault (300ms)`, `animLong (500ms)`, `Curves.easeOutCubic`, and `Curves.easeOutBack`; **0** `disableAnimations` checks across the entire repo | Add `animMicro (140ms)`, `animFast (180ms)`, `animModal (250ms)`, Emil's strong curves (`curveStrongEaseOut = Cubic(0.23, 1, 0.32, 1)`, `curveStrongEaseInOut = Cubic(0.77, 0, 0.175, 1)`, `curveSheet = Cubic(0.32, 0.72, 0, 1)`), and `shouldReduceMotion(context)` | Built-in curves are too weak; UI animations must stay `<300ms`; OS Reduced Motion (`MediaQuery.disableAnimationsOf`) must drop spatial movement while keeping gentle opacity fades (`emilkowalski/skills`). |
| **2** | **HIGH** | `lib/features/finances/presentation/widgets/financial_ledger_tab.dart:152-155` | `AnimatedSwitcher(duration: 180ms, transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child))` | `FadeTransition(opacity: anim)` + `ScaleTransition` from `0.92 -> 1.0` with `AppLayout.curveStrongEaseOut` | **Cardinal Rule (`review-animations`)**: Never animate from `scale(0)`. Nothing in nature materializes from zero volume. |
| **3** | **HIGH** | `lib/widgets/bouncing_widget.dart:23-68` | Symmetric `100ms` press/release shrinking by `5%` (`0.95`) using `Curves.easeOutBack` on press-down | Asymmetric timing: `100ms` press-in to `scale: 0.97` with `AppLayout.curveStrongEaseOut`; `160ms` release with `AppLayout.curveExpressiveEffects` + reduced-motion guard | Overshooting (`easeOutBack`) on press-down feels unnatural; `0.97` scales icons/labels physically without distorting large cards; press-in and release must be asymmetric (`animate-expo`). |
| **4** | **HIGH** | `lib/features/notes/presentation/screens/manage_tags_screen.dart:222`, `filtered_notes_screen.dart:367`, `sms_contacts_screen.dart:197`, `category_management_screen.dart:189`, `sms_rules_screen.dart:812` | `AnimationConfiguration.staggeredList(position: index, duration: Duration(milliseconds: 375))` + `SlideAnimation(verticalOffset: 50.0)` | `position: index.clamp(0, 8)`, `duration: AppLayout.animShort (200ms)`, `verticalOffset: 16.0`, gated by `AppLayout.shouldReduceMotion(context)` | **Sub-300ms UI Rule**: `375ms` duration with a `50px` slide offset makes management screens feel sluggish and heavy. Capping stagger at 8 items prevents cascading lag on long lists. |
| **5** | **HIGH** | `lib/widgets/home/home_app_bar.dart:54-60, 111-145` | Shortcut-triggered search (`searchRequestedNotifier`) and manual search run a `180ms` `Curves.fastOutSlowIn` `AnimatedSwitcher` | **0ms instant** transition when triggered via keyboard/launcher shortcut (`_isShortcutTriggered`), and `AppLayout.animFast (150ms)` `curveStrongEaseOut` on manual tap | **Raycast vs. Spotlight Law (`[00:07:32]`)**: Never animate keyboard/shortcut-initiated search launchers; the cursor must be ready on frame 1. |
| **6** | **MEDIUM** | `lib/widgets/home/note_view_builder.dart:295-310` & `lib/features/notes/presentation/screens/filtered_notes_screen.dart:375-385` | `OpenContainer` uses `300ms` duration, `closedColor: Colors.transparent`, and mixes `ContainerTransitionType.fade` with `fadeThrough` | Standardize on `AppLayout.animModal (250ms)`, `ContainerTransitionType.fadeThrough`, and `closedColor: Colors.transparent` replaced by clean card-matched surface color where appropriate | **Spatial Consistency (`[00:00:37]`)**: Cards must expand smoothly out of their exact grid/list slot in `<280ms` with consistent container semantics across Home, Archive, Trash, and Ledger. |
| **7** | **MEDIUM** | `lib/features/health/presentation/widgets/period_log_dashboard_card.dart:332-336` | `AnimatedSize(duration: Duration(milliseconds: 220), curve: Curves.easeInOut)` on Symptoms accordion | `duration: AppLayout.animShort (200ms)`, `curve: AppLayout.curveStrongEaseOut` | Weak built-in `Curves.easeInOut` starts slow on a user tap, making the symptoms drawer feel delayed during the first 60ms. |
| **8** | **MEDIUM** | `lib/features/finances/presentation/widgets/minimal_chart_deck.dart:64-77, 233-245` | `PageView` auto-cycles every 6s with `400ms Curves.easeInOutCubic` even when Reduced Motion is active; dot indicator uses `250ms` | Pause auto-cycle when `AppLayout.shouldReduceMotion(context)` is true; use `280ms AppLayout.curveStrongEaseInOut` for on-screen slide and `180ms` for dot morph | On-screen morphing elements use strong `ease-in-out` under 300ms; decorative auto-cycling must respect OS reduced-motion preferences. |
| **9** | **MEDIUM** | `lib/core/theme/app_theme.dart` (Global `TooltipThemeData`) | Default Flutter tooltip timing (0ms wait on long-press, inconsistent fade) | Configure global `TooltipThemeData` with `waitDuration: Duration(milliseconds: 500)`, `showDuration: Duration(milliseconds: 1500)`, and compact M3 styling | **Desktop/Toolbar Tooltip Rule (`[00:09:35]`)**: Prevents accidental tooltip flashes while keeping intentional toolbar inspection crisp. |
| **10** | **LOW / GUARD** | `lib/features/finances/presentation/widgets/settle_up_sheet.dart:210-226, 294-301` & `savings_goal_deposit_sheet.dart:118-123, 355-375` | Static icon swap during `Future.delayed(450ms / 500ms)` confirmation beat | Wrap button icon/label in `AnimatedSwitcher` (`180ms`, `curveStrongEaseOut`, `scale: 0.92 -> 1.0` + `FadeTransition`) during the `420ms` benevolent-friction trust window; codify **Zero-Confetti Financial Guardrail** | **Wise Instant-Transfer & `pret/pokered` 30-Frame Rule (`[00:11:19]`, `[00:15:32]`)**: Preserves the deliberate ~420ms trust verification beat while making the visual state morph smooth and banning Robinhood-style confetti. |

---

## 2. Step-by-Step Implementation Instructions for Antigravity

### Milestone 1: Upgrade `AppLayout` Motion Tokens & Reduced-Motion Helper

**File**: `lib/core/theme/app_layout.dart`

1. Read `lib/core/theme/app_layout.dart` (lines 45–95).
2. Replace the animation constants block (lines 49–87) so it preserves 100% backward compatibility with existing tokens (`animShort`, `animDefault`, `animLong`, `curveExpressive`, `curveFast`, `curveEmphasizedDecelerate`, `curveEmphasizedAccelerate`, `springFast`, `springSpatial`, `springBouncy`) while adding the new precision tokens from Emil Kowalski's `emil-design-eng` and `animate-expo` specifications:

```dart
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
```

---

### Milestone 2: Eliminate `scale(0)` in `FinancialLedgerTab` Selection Checkboxes

**File**: `lib/features/finances/presentation/widgets/financial_ledger_tab.dart`

1. Read lines 105–195 of `lib/features/finances/presentation/widgets/financial_ledger_tab.dart`.
2. Locate the `AnimatedSwitcher` on lines 152–155:
   ```dart
   // CURRENT CODE (lines 152-155):
   leading: AnimatedSwitcher(
     duration: const Duration(milliseconds: 180),
     transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
     child: isSelected
   ```
3. Replace with `AppLayout.animFast` and `AppLayout.scaleFadeTransitionBuilder` (which starts from `scale: 0.92` + `opacity: 0.0` instead of `scale: 0.0`):
   ```dart
   // TARGET CODE:
   leading: AnimatedSwitcher(
     duration: AppLayout.animFast,
     transitionBuilder: AppLayout.scaleFadeTransitionBuilder,
     child: isSelected
   ```
4. Also update the `OpenContainer` `transitionDuration` on line 119 from `const Duration(milliseconds: 300)` to `AppLayout.animModal` (`250ms`), and cap the `AnimationConfiguration.staggeredList` position on lines 90 and 112 to `position: index.clamp(0, 8)` with `duration: AppLayout.animShort`.

---

### Milestone 3: Asymmetric Press/Release & `scale(0.97)` Physicality in `BouncingWidget`

**File**: `lib/widgets/bouncing_widget.dart`

1. Read `lib/widgets/bouncing_widget.dart` (lines 1–75).
2. **Problem**:
   - Currently `upperBound: 0.05` shrinks elements by 5% (`0.95`), which is too aggressive on wide cards.
   - Uses symmetric `100ms` duration for both press and release.
   - Applies `Curves.easeOutBack.transform(normalized)` on press-down, causing an unnatural overshoot *while pressing in*.
   - Does not check `AppLayout.shouldReduceMotion(context)`.
3. Replace `lib/widgets/bouncing_widget.dart` with an asymmetric, reduced-motion-aware implementation using `0.97` scale (`upperBound: 0.03`), `100ms` press-in (`AppLayout.curveStrongEaseOut`), and `160ms` release (`AppLayout.curveExpressiveEffects`):

```dart
import 'package:flutter/material.dart';
import '../core/theme/app_layout.dart';

class BouncingWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;

  const BouncingWidget({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.97,
  });

  @override
  State<BouncingWidget> createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<BouncingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 160),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AppLayout.shouldReduceMotion(context);
    final shrinkDelta = (1.0 - widget.scaleFactor).clamp(0.01, 0.08);

    return GestureDetector(
      onTapDown: reduceMotion ? null : _onTapDown,
      onTapUp: reduceMotion ? null : _onTapUp,
      onTapCancel: reduceMotion ? null : _onTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          if (reduceMotion || _controller.value == 0.0) {
            return child!;
          }
          final curved = _controller.status == AnimationStatus.reverse
              ? AppLayout.curveExpressiveEffects.transform(_controller.value)
              : AppLayout.curveStrongEaseOut.transform(_controller.value);
          final scale = 1.0 - (curved * shrinkDelta);
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
```

---

### Milestone 4: Standardize Staggered Lists Under 300ms (`200ms`, `16dp` Offset, Capped at 8)

**Files**:
- `lib/features/notes/presentation/screens/manage_tags_screen.dart` (lines 220–232)
- `lib/features/notes/presentation/screens/filtered_notes_screen.dart` (lines 365–385)
- `lib/features/finances/presentation/screens/sms_contacts_screen.dart` (lines 195–208)
- `lib/features/finances/presentation/screens/category_management_screen.dart` (lines 187–200)
- `lib/features/finances/presentation/screens/sms_rules_screen.dart` (lines 810–822)
- `lib/widgets/home/note_view_builder.dart` (lines 172–215)

1. In each of the 5 screens currently using `duration: const Duration(milliseconds: 375)` (or `300ms` in `sms_rules_screen.dart`) and `verticalOffset: 50.0`:
   - Change `position: index` (or `i`) to `position: index.clamp(0, 8)` so items below the fold do not accumulate long stagger delays.
   - Change `duration: const Duration(milliseconds: 375)` to `duration: AppLayout.animShort` (`200ms`).
   - Change `verticalOffset: 50.0` to `verticalOffset: AppLayout.shouldReduceMotion(context) ? 0.0 : 16.0`.
2. In `lib/widgets/home/note_view_builder.dart`:
   - On line 174 (`SliverList`): update `position: index.clamp(0, 8)`, `duration: AppLayout.animShort`, and `verticalOffset: AppLayout.shouldReduceMotion(context) ? 0.0 : 16.0`.
   - On line 203 (`SliverMasonryGrid`): update `position: index.clamp(0, 8)`, `duration: AppLayout.animShort`, and pass `scale: AppLayout.shouldReduceMotion(context) ? 1.0 : 0.95` to `ScaleAnimation` so grid cards never scale from `0.0`! (By default, `flutter_staggered_animations`'s `ScaleAnimation()` starts at `scale: 0.0` unless `scale: 0.95` is explicitly passed!).

```dart
// CRITICAL FIX in lib/widgets/home/note_view_builder.dart (lines 203-212):
return AnimationConfiguration.staggeredGrid(
  position: index.clamp(0, 8),
  duration: AppLayout.animShort,
  columnCount: columnCount,
  child: ScaleAnimation(
    scale: AppLayout.shouldReduceMotion(context) ? 1.0 : 0.95,
    curve: AppLayout.curveStrongEaseOut,
    child: FadeInAnimation(
      curve: AppLayout.curveStrongEaseOut,
      child: _buildOpenContainer(context, note, onRefresh, noteProvider),
    ),
  ),
);
```

---

### Milestone 5: 0ms Shortcut-Initiated Search & Fast Header Swap (`HomeAppBar`)

**File**: `lib/widgets/home/home_app_bar.dart`

1. Read `lib/widgets/home/home_app_bar.dart` (lines 45–155).
2. **Principle (Raycast vs. Spotlight at `[00:07:32]`)**: When search is triggered via external shortcut (`HomeAppBar.searchRequestedNotifier`), the transition must be **0ms (`Duration.zero`)** so the user can type immediately without waiting for an entrance animation. When tapped manually, use `AppLayout.animFast` (`180ms`) with `AppLayout.curveStrongEaseOut` instead of `Curves.fastOutSlowIn`.
3. Add a boolean `_skipNextSearchAnimation = false;` to `_HomeAppBarState`:
   ```dart
   void _handleSearchRequest() {
     if (HomeAppBar.searchRequestedNotifier.value && mounted) {
       setState(() {
         _skipNextSearchAnimation = true;
         _isSearching = true;
       });
       HomeAppBar.searchRequestedNotifier.value = false;
     }
   }
   ```
4. In `HomeAppBar.build` (line 111), update `AnimatedSwitcher`:
   ```dart
   child: AnimatedSwitcher(
     duration: (_skipNextSearchAnimation || AppLayout.shouldReduceMotion(context))
         ? Duration.zero
         : AppLayout.animFast,
     switchInCurve: AppLayout.curveStrongEaseOut,
     switchOutCurve: AppLayout.curveEmphasizedAccelerate,
   ```
   And reset `_skipNextSearchAnimation = false;` when closing search.

---

### Milestone 6: Spatial Consistency on `OpenContainer` Card-to-Editor Transitions

**Files**:
- `lib/widgets/home/note_view_builder.dart` (lines 291–330)
- `lib/features/notes/presentation/screens/filtered_notes_screen.dart` (lines 374–405)

1. In `lib/widgets/home/note_view_builder.dart`:
   - Change `transitionDuration: const Duration(milliseconds: 300)` to `transitionDuration: AppLayout.shouldReduceMotion(context) ? Duration.zero : AppLayout.animModal` (`250ms`).
2. In `lib/features/notes/presentation/screens/filtered_notes_screen.dart`:
   - Align `OpenContainer<bool>` (line 375) with `NoteViewBuilder` by setting `transitionType: ContainerTransitionType.fadeThrough`, `transitionDuration: AppLayout.shouldReduceMotion(context) ? Duration.zero : AppLayout.animModal`, and `openElevation: 0`, `openColor: colorScheme.surface`.

---

### Milestone 7: Fix Accordion Easing in `PeriodLogDashboardCard` & `NoteEditorBottomBar`

**Files**:
- `lib/features/health/presentation/widgets/period_log_dashboard_card.dart` (lines 240–365)
- `lib/features/notes/presentation/widgets/note_editor_bottom_bar.dart` (lines 55–75)

1. In `lib/features/health/presentation/widgets/period_log_dashboard_card.dart`:
   - On lines 241 and 358 (`AnimatedContainer` for Flow Intensity and Symptoms chips): replace `duration: const Duration(milliseconds: 180)` with `duration: AppLayout.animFast` and add `curve: AppLayout.curveStrongEaseOut`.
   - On lines 332–335 (`AnimatedSize` for the collapsible Symptoms drawer): replace `curve: Curves.easeInOut` with `curve: AppLayout.curveStrongEaseOut` and `duration: AppLayout.animShort` (`200ms`) so tapping "Symptoms" starts expanding on frame 1 without an `easeIn` delay.
2. In `lib/features/notes/presentation/widgets/note_editor_bottom_bar.dart`:
   - On line 58 (`AnimatedSwitcher` for the floating formatting bar): change `duration: AppLayout.animDefault` (`300ms`) to `duration: AppLayout.animModal` (`250ms`), and gate the `SlideTransition` offset on `AppLayout.shouldReduceMotion(context) ? Offset.zero : const Offset(0.0, 0.25)` so reduced-motion users get a clean opacity fade.

---

### Milestone 8: On-Screen Easing & Reduced-Motion Guard in `MinimalChartDeck`

**File**: `lib/features/finances/presentation/widgets/minimal_chart_deck.dart`

1. Read `lib/features/finances/presentation/widgets/minimal_chart_deck.dart` (lines 55–85 and 225–255).
2. In `_startAutoCycleTimer()` (line 60):
   - Inside the periodic timer callback, check `if (AppLayout.shouldReduceMotion(context)) return;` so users with Reduced Motion enabled are never subjected to unsolicited auto-scrolling charts.
   - Change the `animateToPage` duration on line 73 from `const Duration(milliseconds: 400)` with `Curves.easeInOutCubic` to `AppLayout.animDefault` (`300ms`) with `AppLayout.curveStrongEaseInOut` (`Cubic(0.77, 0.0, 0.175, 1.0)` — Emil Kowalski's curve for elements already on screen moving to a new position).
3. On line 234 (manual dot tap `animateToPage`) and line 242 (`AnimatedContainer` dot width morph):
   - Use `duration: AppLayout.animModal` (`250ms`) with `curve: AppLayout.curveStrongEaseOut` for `animateToPage`, and `duration: AppLayout.animFast` (`180ms`) with `curve: AppLayout.curveStrongEaseInOut` for the dot indicator width morph.

---

### Milestone 9: Global Tooltip Hygiene (`AppTheme`) & Sheet Curve Polish (`AppBottomSheet`)

**Files**:
- `lib/core/theme/app_theme.dart`
- `lib/core/ui/app_bottom_sheet.dart`

1. In `lib/core/ui/app_bottom_sheet.dart` (lines 33–38):
   - Update `sheetAnimationStyle` to use `duration: AppLayout.animModal` (`250ms`), `reverseDuration: AppLayout.animFast` (`180ms`), `curve: AppLayout.curveSheet` (`Cubic(0.32, 0.72, 0.0, 1.0)`), and `reverseCurve: AppLayout.curveEmphasizedAccelerate`.
2. In `lib/core/theme/app_theme.dart`:
   - Add a standardized `tooltipTheme` to both Light and Dark `ThemeData` with `waitDuration: const Duration(milliseconds: 500)` and `showDuration: const Duration(milliseconds: 1500)` so casual pointer/finger passes never trigger jarring tooltip flashes.

---

### Milestone 10: Benevolent Friction & Anti-Gamification Guardrail in Financial Sheets

**Files**:
- `lib/features/finances/presentation/widgets/settle_up_sheet.dart` (lines 210–230, 290–305)
- `lib/features/finances/presentation/widgets/savings_goal_deposit_sheet.dart` (lines 115–125, 355–380)

1. **Principle (Wise Instant Transfer & `pret/pokered` 30-Frame Rule vs. Robinhood Confetti Settlement)**:
   - Keep the deliberate confirmation beat (`AppLayout.animTrustBeat = 420ms`) when `showDelight` is enabled so users visually register that their settlement or savings milestone succeeded before the sheet dismisses.
   - Replace the abrupt un-animated icon/text swap on the `FilledButton.icon` in both `SettleUpSheet` and `SavingsGoalDepositSheet` with an `AnimatedSwitcher` (`duration: AppLayout.animFast`, `transitionBuilder: AppLayout.scaleFadeTransitionBuilder`) so the transition from `"Confirm Settle Up"` -> `"All Settled Up!"` morphs smoothly with `scale(0.92 -> 1.0)` + opacity.
   - Replace `Future.delayed(const Duration(milliseconds: 450))` (and `500` in `SavingsGoalDepositSheet`) with `Future.delayed(AppLayout.animTrustBeat)`.
   - Never add particle confetti overlays to financial debits, credits, or settlements.

---

## 3. Automated Verification & Device Feel-Check Protocol

After completing Milestones 1–10:

1. **Static Analysis**:
   ```bash
   flutter analyze
   ```
   Must report **0 errors and 0 warnings**.

2. **Unit & Widget Test Suite**:
   Create `test/animation_engineering_invariants_test.dart` to verify:
   - `AppLayout.animMicro`, `AppLayout.animFast`, `AppLayout.animShort`, `AppLayout.animModal`, and `AppLayout.animDefault` are all `<= 300ms`.
   - `AppLayout.curveStrongEaseOut` (`Cubic(0.23, 1.0, 0.32, 1.0)`), `AppLayout.curveStrongEaseInOut` (`Cubic(0.77, 0.0, 0.175, 1.0)`), and `AppLayout.curveSheet` (`Cubic(0.32, 0.72, 0.0, 1.0)`) evaluate front-loaded progress (`curveStrongEaseOut.transform(0.3) > 0.65`).
   - `AppLayout.scaleFadeTransitionBuilder` starts at `scale: 0.92` (never `0.0`) when `animation.value == 0.0`.
   - `BouncingWidget` bypasses scale transforms when `MediaQueryData(disableAnimations: true)` is injected.
   - Run:
     ```bash
     flutter test
     ```

3. **Slow-Motion & Real-Device Feel Check (`emilkowalski/skills` Protocol)**:
   - Inspect `NoteCard` grid entrance in 3x slow motion (`timeDilation = 3.0` in Flutter DevTools) to confirm cards start at `scale: 0.95` + `opacity: 0.0` (never growing from a tiny pinprick at `scale: 0.0`).
   - Toggle multi-select checkboxes rapidly in `FinancialLedgerTab` to confirm smooth interruptible retargeting and `0.92 -> 1.0` scale-fade morphing.
   - Trigger `HomeAppBar.searchRequestedNotifier` to confirm 0ms instant search bar activation with immediate keyboard focus.
