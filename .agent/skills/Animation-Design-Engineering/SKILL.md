---
name: Animation-Design-Engineering
description: Distills the UI animation engineering principles and repositories from Enrico Tartarotti's "The Ridiculous Engineering Of Animations" and Emil Kowalski (Linear, animations.dev, emilkowalski/skills) tailored to Everything App. Use PROACTIVELY when building, reviewing, auditing, or refactoring animations, transitions, spring physics, gestures, or perceived performance across Everything App.
---

# Animation Design Engineering (Tartarotti x Emil Kowalski)

Distilled from **Enrico Tartarotti's** *The Ridiculous Engineering Of Animations* (`https://www.youtube.com/watch?v=z3Lo5QT7nME`) and **Emil Kowalski's** design engineering repositories (`emilkowalski/skills`, `animations.dev`, `emilkowal.ski/ui/great-animations`, `pret/pokered`, `rileycx/strafe`), adapted specifically for **Everything App** (`AppLayout`, `AppTheme`, M3 Expressive tokens).

---

## 1. Core Reference Repositories & Case Studies Observed

1. **[`emilkowalski/skills`](https://github.com/emilkowalski/skills)** (`emil-design-eng`, `animate`, `animate-expo`, `review-animations`, `improve-animations`):
   - Encodes the **Animation Decision Framework** (Frequency Gate -> Purpose Gate -> Tool/Property Selection -> Custom Easing/Spring -> Interruptibility -> Reduced Motion).
   - Enforces the `| Before | After | Why |` audit table format and self-contained implementation plans.
2. **[`animations.dev`](https://animations.dev/) & [Great Animations](https://emilkowal.ski/ui/great-animations)** (Emil Kowalski, Design Engineer at Linear):
   - Strong custom cubic-bezier curves (`cubic-bezier(0.23, 1, 0.32, 1)` for `ease-out`, `cubic-bezier(0.77, 0, 0.175, 1)` for `ease-in-out`, `cubic-bezier(0.32, 0.72, 0, 1)` for drawers/sheets).
   - Never animate from `scale(0)` (always start from `scale(0.92..0.97) + opacity: 0`).
   - Never animate keyboard-initiated or 100+/day actions (Raycast vs. Spotlight).
3. **[`pret/pokered`](https://github.com/pret/pokered)** (`engine/battle/animations.asm` - Pokémon Red & Blue Disassembly):
   - Even when the user sets Battle Animations to **OFF** for high-frequency battles, the assembly code intentionally retains a **30-frame (~500ms) pause, screen shake on damage, and Pokéball throw**.
   - **Principle**: Stripping decorative animation must never strip **essential state comprehension** (the user must still perceive that an action occurred).
4. **[`rileycx/strafe`](https://github.com/rileycx/strafe) & [`jurplel/InstantSpaceSwitcher`](https://github.com/lwouis/alt-tab-macos/issues/5555)** (macOS Space Switch Velocity Hack):
   - Synthesizes a fake high-velocity trackpad swipe (`CGEvent`) to trick macOS into skipping the slow desktop-switching slide animation.
   - **Principle**: Peer-to-peer workspace switching (`HomeScreen` root tabs: `Notes`, `Finances`, `Period Tracker`) is a high-frequency navigation loop and must execute in **0ms without sliding**.
5. **Flask (`flask.do` by Enrico Tartarotti)**:
   - Sidebar items, folder opening, and tab switching are **0ms instantaneous** because they are used hundreds of times a day.
   - Auto-hiding panels animate **only** for spatial consistency so the user knows where the hidden panel went and how to summon it back.
   - File drops open **instantly (0ms optimistic UI)** while background uploads use rich animated progress bars (`ExpressiveWavyProgress`).
6. **Wise Instant Transfer vs. Robinhood Confetti Settlement**:
   - **Wise (Benevolent Friction)**: When money transfers became instant, users distrusted whether the transfer actually worked. Adding a short ~450ms verification animation closed the *"delta between what is done and what is perceived to be done."*
   - **Robinhood ($7.5M Settlement Warning)**: Playful confetti after financial trades gamified high-stakes financial decisions. Everything App must keep financial ledger and debt-settlement feedback crisp, calm, and trustworthy—never using slot-machine or confetti dark patterns.

---

## 2. The 6-Step Animation Decision Framework for Everything App

Before writing or modifying any animation in `lib/`, evaluate these 6 steps in strict sequence:

### Step 1: The Frequency Gate (Should This Animate at All?)

| Frequency Tier | Everything App Interactions | Rule |
| :--- | :--- | :--- |
| **100+ times/day** | Top-bar Search activation (`_isSearching`), keyboard shortcuts (`Esc`, `Cmd/Ctrl+F`), root tab switching (`IndexedStack`), ledger account filters (`All` / `Daily` / `Savings`), folder switching | **0ms Instant.** Never add slide or slow entrance animations. |
| **Tens of times/day** | Card/button press (`BouncingWidget`), checklist item toggle, tag/category chip toggle, multi-select row tap | **100–180ms max.** Subtle tactile press (`scale: 0.97`) + instant state update. |
| **Occasional** | `AppBottomSheet`, `AppDialog`, `OpenContainer` note/transaction editor launch, floating selection toolbar (`ExpressiveFloatingToolbar`), collapsible symptoms/completed items | **180–280ms** with strong `ease-out` or `AppLayout.springSpatial`. |
| **Rare / First-Time** | `OnboardingScreen`, `WhatsNewSheet`, all-tasks-completed state, savings goal target reached (`SavingsGoalDepositSheet`), P2P QR pairing success | **Delight tier.** Spring physics (`AppLayout.springBouncy`) and celebratory morphs allowed. |

### Step 2: The Purpose Gate (Name the Purpose in One Phrase)

Every animation in Everything App must serve one of five engineering purposes:
1. **Spatial Consistency**: Establishing a mental map of where UI elements live (`OpenContainer` expanding a `NoteCard` from its exact grid coordinates; `ExpressiveFloatingToolbar` entering and exiting along the same bottom vertical vector).
2. **Tactile Feedback**: Confirming touch registration within 16ms (`BouncingWidget` + `AppHaptics`).
3. **State Indication**: Communicating a non-trivial state transition (morphing a category icon into a selection checkmark; pulsing active P2P sync).
4. **Preventing Jarring Reflow**: Smoothing height changes on user-triggered accordions (`AnimatedSize` on Period Symptoms or Completed Checklists).
5. **Perceived Performance & Benevolent Friction**:
   - *Buying Time*: `SkeletonCard` masonry placeholders during initial SQLCipher decryption.
   - *Closing the Trust Delta*: A 400–450ms verified checkmark transition in `SettleUpSheet` and `SavingsGoalDepositSheet` so users trust that multi-table ledger/split mutations succeeded.

### Step 3: Easing & Spring Selection (`AppLayout` Tokens)

Never use `Curves.easeIn` on UI entrances or exits (`easeIn` starts slow, delaying movement at the exact moment the user watches for feedback). Built-in standard curves are too weak; always reference `AppLayout` tokens:

* **Entering or Exiting UI (`AppLayout.curveStrongEaseOut`)**: `Cubic(0.23, 1.0, 0.32, 1.0)` or `AppLayout.curveEmphasizedDecelerate` (`Cubic(0.05, 0.7, 0.1, 1.0)`). Most visual progress occurs in the first 30% of the duration, making 200ms feel instant.
* **Moving / Morphing On-Screen (`AppLayout.curveStrongEaseInOut`)**: `Cubic(0.77, 0.0, 0.175, 1.0)`. Use when an element *already visible on screen* moves to a new position or changes dimensions (e.g. `MinimalChartDeck` page indicator dot morphing width from `6dp` to `16dp`, or `PageView` slide transitions).
* **Sheets & Drawers (`AppLayout.curveSheet`)**: `Cubic(0.32, 0.72, 0.0, 1.0)` on entrance, `AppLayout.curveEmphasizedAccelerate` (`Cubic(0.3, 0.0, 0.8, 0.15)`) on exit.
* **Gesture-Driven & Interruptible Elements (`AppLayout.springFast` / `AppLayout.springSpatial`)**: Use `ExpressiveSpringCurve` / `SpringSimulation` so velocity is preserved if interrupted mid-flight.

### Step 4: Sub-300ms UI Duration Budgets

* **Micro Press Feedback (`AppLayout.animMicro`)**: `140ms` (press-in `100–120ms`, release `150–160ms`).
* **Fast UI State Changes (`AppLayout.animFast`)**: `180ms` (checkbox morphs, chip selection, search mode header swap).
* **Standard UI & Staggered Lists (`AppLayout.animShort`)**: `200ms` (staggered list items with `16dp` vertical offset, capped at `index.clamp(0, 8)`).
* **Modals, Sheets & Container Morphs (`AppLayout.animModal` / `animDefault`)**: `250ms`–`300ms` max. Never use `375ms` or `400ms+` for list entrances or standard UI toggles.

### Step 5: Physicality, Origin Awareness & Interruptibility

* **No `scale(0)` Entrances**: Never use bare `ScaleTransition(scale: animation)` from `0.0` to `1.0`. Always combine `FadeTransition(opacity: animation)` with a `Tween<double>(begin: 0.92, end: 1.0)` scale so elements never materialize from a single point.
* **Asymmetric Press & Release (`BouncingWidget`)**: Press-in should scale to `0.97` (not `0.95`, which distorts large cards) using `curveStrongEaseOut` (`100ms`), and release should settle smoothly over `160ms` without overshoot on press-down.
* **Eliminate Transparent Container Flashes**: In `OpenContainer`, always set `closedColor` to match the card's actual surface token (`colorScheme.surfaceContainerHigh` or `surfaceContainer`) rather than `Colors.transparent` so the card expands seamlessly without flashing the scaffold backdrop.
* **Warm Tooltip Skip-Delay**: Configure `TooltipThemeData` with `waitDuration: Duration(milliseconds: 500)` so casual touches don't flash tooltips, paired with instant feedback on intentional long-press.

### Step 6: GPU Performance, Same-Frame Haptics & Reduced Motion

* **GPU Compositing Discipline**: Prefer animating transform (`Transform.scale`, `SlideTransition`) and opacity (`FadeTransition`) over layout-triggering properties. Wrap complex `CustomPainter` and `fl_chart` widgets in `RepaintBoundary`.
* **Three Laws of Mobile Haptics (`AppHaptics`)**:
  1. *Same frame as the visual*: Trigger haptics on tap-down or state commit, never after an animation finishes.
  2. *One per user action*: Never trigger haptics per scroll frame or on automatic entrance animations.
  3. *Never the only feedback*: Pair every haptic with a clear visual state change.
* **Accessibility & Reduced Motion (`AppLayout.shouldReduceMotion(context)`)**:
  - Query `MediaQuery.disableAnimationsOf(context)`.
  - When true, preserve gentle opacity/color crossfades (`120ms`) for state comprehension, but bypass spatial translations (`SlideAnimation`), scale bounces (`BouncingWidget`), and continuous decorative loops (`MinimalChartDeck` auto-cycle timer).

---

## 3. Mandatory Audit & Review Format

When auditing or reviewing UI motion in Everything App, output a single Markdown table with `| Before | After | Why |` columns before listing implementation steps:

| Before | After | Why |
| :--- | :--- | :--- |
| `ScaleTransition(scale: anim)` (`0.0 -> 1.0`) | `FadeTransition` + `ScaleTransition(0.92 -> 1.0)` | Nothing in the physical world appears from `scale(0)` |
| `duration: Duration(milliseconds: 375), verticalOffset: 50.0` | `duration: AppLayout.animShort (200ms), verticalOffset: 16.0` | UI animations >300ms with 50px travel feel sluggish |
| `BouncingWidget` `0.95` scale with `easeOutBack` on press-down | Asymmetric `0.97` press (`100ms` ease-out) / `160ms` release | Overshooting on press-down feels unnatural; `0.97` preserves card legibility |
| Unconditional `SlideAnimation` & auto-scroll timers | Gate on `!AppLayout.shouldReduceMotion(context)` | Respects OS `disableAnimations` accessibility setting without losing fade comprehension |
