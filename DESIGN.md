# Everything App Design System

## Overview
Everything App follows **Material 3 Expressive** combined with a **Calm Technology** editorial discipline. The interface relies on solid tonal surface hierarchy, dynamic Material You color extraction (`dynamic_color`), `Google Sans Flex` variable UI typography paired with `Inter` Regular body prose, `FontFeature.tabularFigures()` for numeric stability, and sub-300ms spring physics.

**Zero glassmorphism**: Top bars, bottom navigation, cards, and modal sheets are 100% solid tonal surfaces with zero `BackdropFilter` or frosted-glass blurs.

---

## 1. Color & Surface Architecture

### Dynamic Material You & Fallbacks (`lib/core/theme/app_theme.dart`)
- **Primary Palette Source**: Wallpaper-derived `ColorScheme` via `DynamicColorBuilder`.
- **Fallback Seed**: `#6750A4` (M3 Violet Dusk).
- **Dark Mode Surface Ladder** (Soft Charcoal Dark Slate, 5-tier solid elevation):
  - `surface`: `#141318`
  - `surfaceContainerLow`: `#1C1A22` (borderless `ExpressiveSliverAppBar`, grouped result items)
  - `surfaceContainer`: `#211F28`
  - `surfaceContainerHigh`: `#2B2834` (standard `AppCard`, `AppBottomSheet`, `AppDialog`, menus)
  - `surfaceContainerHighest`: `#363442` (filled inputs, inactive chip tracks)
  - `onSurface`: `#E6E1E5`, `onSurfaceVariant`: `#CAC4D0`
- **Per-Note & Tag Palettes**: Derived deterministically via `AppTheme.cachedSeedScheme(seedColor, brightness)` from `AppTheme.noteColors`.
- **Semantic Roles (`AppSemanticColors`)**:
  - `success`: `#1B873F` (Light) / `#4CAF50` (Dark)
  - Cycle phases (`phaseMenstrual`, `phaseFollicular`, `phaseOvulatory`, `phaseLuteal`)
  - Destructive actions map to `colorScheme.error`.

### Hero Containers
- Top hero cards (`SettingsHeroCard`, `FinanceHeroSummaryCard`, `CyclePhaseHeroCard`, Trash Auto-Purge Banner) use dynamic container opacity (`50%–55%` alpha in Light Mode; `20%–22%` alpha in Dark Mode) with a subtle `1.0–1.2px` accent border.
- Secondary body cards stay in unified solid surface containers (`AppCard` / `surfaceContainerHigh` / `surfaceContainerLow`).

---

## 2. Typography & Reading Measure

### Variable Font Pairing (`pubspec.yaml` & `app_theme.dart`)
- **UI Chrome & Headings (`Google Sans Flex`)**: Full bundled variable font (`wght`, `opsz`, `GRAD`, `ROND`, `slnt`, `wdth`) across `display*`, `headline*`, `title*`, and `label*` roles.
  - Optical size (`opsz`) is aligned with rendered point size (e.g. `opsz: 18` when `titleLarge` renders at `18pt` in app bars, `opsz: 22` at default `22pt`).
  - Dark mode applies subtle positive grade (`GRAD: 15`) for crisp stroke legibility on dark surfaces.
  - Display & headline roles (`displayLarge`–`headlineSmall`) apply `-0.02em` negative tracking.
- **Body Prose (`Inter` Regular)**: Bundled `Inter-Regular.ttf` is reserved for body prose (`bodyLarge`, `bodyMedium`, `bodySmall`) to preserve clean readability and eliminate faux-bold font synthesis.
- **Locale Fallbacks**: `Noto Sans Tamil`, `Inter`, `Roboto`, `sans-serif`.
- **Code Blocks**: System `monospace` inside `NoteEditorStyles`.

### Typographic Hygiene Rules
- **Tabular Numerals**: All counters, financial amounts, timestamps, search match indices (`1/12`), word/character stats, and checklist counts enforce `fontFeatures: const [FontFeature.tabularFigures()]`.
- **Sentence Case**: All UI labels, section headers, kickers, and `SnackBarAction` labels use sentence case (`Pro tip`, `Tag color`, `Undo`) rather than tracked-out `ALL CAPS`.
- **Above-the-Fold Legibility Floor**: UI text in opening viewports (`HomeAppBar`, `TagFilterBar`, `AppChip`, `NoteCard`, `UniversalSearchOverlay`) stays `>= 13sp`.
- **Editor Measure**: Rich-text note prose (`NoteEditorCanvas`) is centered inside `ConstrainedBox(maxWidth: 680)` (~65ch) on tablets and foldables. Rich-text `NoteEditorStyles` headings (`H1`–`H3`) preserve full document hierarchy.

---

## 3. Shapes, Radii & Layout Tokens (`lib/core/theme/app_layout.dart`)

- **Spacing Scale**: `spaceXS` (`4`), `spaceS` (`8`), `spaceM` (`12`), `spaceL` (`16`), `spaceXL` (`24`), `spaceXXL` (`32`), `fabBottomPadding` (`96`).
- **M3 Expressive Shape Scale**:
  - **Tactile Stadium Pills (`radiusStadium = 1000dp` / `StadiumBorder`)**: Interactive filter chips (`TagFilterBar`, `AppChip`), top-bar Tonal Scope Pills, primary CTAs, `AppMorphingFab`, `ExpressiveFloatingToolbar`, and `ExpressiveSplitButton`.
  - **Squircles (`radiusM = 12dp`, `radiusL = 16dp`, `radiusXL = 20dp`)**: Cards, menus, and list tiles.
  - **Sheets & Dialogs (`radiusXXL = 28dp`)**: `AppBottomSheet` and `AppDialog`, constrained to `maxContentWidth = 600dp`.
  - **Connected Corner Morphing (`AppCardGroupPosition`)**: Grouped lists connect inner corners (`6dp`) while keeping outer top/bottom corners rounded (`16dp`).

---

## 4. Component & Anti-Clutter Standards (`lib/core/ui/`)

- **Seamless Borderless Bars**: `ExpressiveSliverAppBar` and `HomeAppBar` use solid `surfaceContainerLow` fill with zero border and zero blur.
- **No Decorative Static Pills or Card Cages**:
  - Reserve capsule/pill shapes strictly for **interactive** controls (filters, scope pills, removable metadata `InputChip`s, action toolbars).
  - Render static card metadata (`X/Y Done`, `Locked note`, `+N more items`, counts) as crisp typographic hierarchy rather than boxed badges.
  - Avoid nested bordered boxes inside cards or sheets; separate subsections with whitespace, `1px` `Divider`s, or connected `AppCardGroupPosition` rows.
  - Provide at most one primary CTA per section/card without duplicate dismiss or link actions.
- **Checklist Immediacy**: `NoteEditorCanvas` places `NoteCompletedChecklistCard` **below** `QuillEditor` so checklist notes open directly to actionable pending tasks. `NoteCard` previews filter out completed items and show a clean completion state when all tasks are done.
- **Selection Controls**: Use `SegmentedButton` for 2–4 options and `FilterChip` (`showCheckmark: false`) for larger sets; never use legacy `DropdownButton`.
- **Zero Emojis in UI Controls**: Use official Material Symbols (`Icons.*_rounded` / `_outlined`) instead of raw Unicode emoji glyphs.
- **Optical High-Contrast QR Standard**: Pair/sync QR codes render pure black `#000000` modules inside a pure white `#FFFFFF` container with `16dp` quiet-zone padding.

---

## 5. Motion, Physics & Accessibility

- **Sub-300ms Discipline**: `animMicro` (`140ms`), `animFast` (`180ms`), `animShort` (`200ms`), `animModal` (`250ms`), `animDefault` (`300ms`).
- **Easing & Springs**: `curveStrongEaseOut` (`Cubic(0.23, 1.0, 0.32, 1.0)`), `curveStrongEaseInOut`, `curveSheet`, and velocity-aware `SpringDescription` tokens (`springFast`, `springSpatial`, `springBouncy`).
- **Reduced Motion Parity**: All animated routes (`AppRouter.sharedAxis`), staggered lists/grids (`NoteViewBuilder`, `FilteredNotesScreen`, `ManageTagsScreen`), sheets (`AppBottomSheet`), dialogs (`AppDialog`), cards (`AppCard`), and press bounces (`BouncingWidget`) query `AppLayout.shouldReduceMotion(context)` (`MediaQuery.maybeDisableAnimationsOf`) to drop spatial translations, staggers, and scale bounces while keeping immediate state changes.
- **Touch Target Floor**: Interactive controls enforce `>= 48x48dp` hit bounds (`iconButtonTheme`, `filledButtonTheme`, cursor steppers, tag color swatches) with `Semantics` labels.
