---
name: UI-UX-Specialist
description: Dedicated to crafting premium, tactile, and highly responsive user interfaces. Focuses on unified layout systems, micro-interactions, gesture-driven actions, dynamic Material You theming, and M3 Expressive design tokens. Use PROACTIVELY when implementing screens or user-facing interactions.
---

# UI-UX Specialist

Refer to [design.md](file:///Users/saadhjawwadh/Documents/Code/Note%20taking/.agent/skills/UI-UX-Specialist/design.md) for full design system tokens, surface elevation hierarchy, spring motion physics, and Material 3 Expressive component specs.

## 1. Master Design System Rules
* **Single Source of Truth**: All layout spacing, border radii, animation curves, and component tokens MUST be referenced from `AppLayout` and `AppTheme` (`lib/core/theme/`).
* **Core Shared UI Components**: Always use standard UI primitives from `lib/core/ui/`:
  - `AppCard`: Standardized surface card container (supports standard, tonal, and squircle).
  - `AppBottomSheet`: Standardized drag-handled modal sheet with responsive width bounds.
  - `AppChip`: Standardized 8–12dp squircle pill for tags, categories, and phase badges.
  - `AppDialog`: Standardized M3 responsive dialog with 28dp squircle corners.
  - `ExpressiveSliverAppBar`: Standardized borderless solid surface header (zero blur).
  - `ExpressiveSplitButton`: Standardized dual-action split CTA (action button + dropdown trigger).
  - `ExpressiveWavySlider`: Tactile sinusoidal wavy slider for values, scales, and audio.
  - `ExpressiveWavyProgress`: Animated wavy progress indicator for budgets and ongoing tasks.
  - `ExpressiveShapeMorphIndicator`: Shape-morphing loading indicator across 35+ M3 shapes.
* **Component Standards**: Use M3 **FAB Menu**, **Split Buttons**, **Floating Toolbars**, **SegmentedButton**, `SearchBar`, and `Badge.count`.
* **Zero Hardcoded Colors**: Always use `Theme.of(context).colorScheme.<token>` — never hardcode static `Color(...)` values in UI components.
* **A11y Touch Targets**: All clickable icons must meet the minimum $48 \times 48\text{ dp}$ tap target.
* **Unambiguous Master Overwrite Warning Modal**: Before executing actions that replace local state 100% (such as Secondary P2P master sync), display an explicit M3 Warning Modal (`_showOverwriteWarningDialog`) outlining role mechanics and requiring tapping **"I Understand & Overwrite"**.
* **Tactile Haptic Feedback**: Wrap action controls and segment tiles in `BouncingWidget` with `HapticFeedback.lightImpact()` / `mediumImpact()`.
* **Velocity-Aware Spring Physics**: Micro-interactions and press states must use `AppLayout.springFast` / `AppLayout.springSpatial` tokens and `AppLayout.curveEmphasizedDecelerate`, reacting naturally to gesture momentum.
* **TextField Container Transparency**: When embedding `TextField` inside custom-styled containers, set `filled: false`, `fillColor: Colors.transparent`, and borderless `InputBorder` properties on `InputDecoration` to prevent global theme fill artifacts.
* **Symmetric Solid Surface Navigation**: Pair solid `surfaceContainerLow` top app bars with matching `surfaceContainerLow` bottom navigation bars and `extendBody: true` on `Scaffold` for edge-to-edge content depth with ZERO GPU backdrop blur lag.
* **Seamless Borderless Surface Bars**: Top app bars (`ExpressiveSliverAppBar`) and bottom navigation bars MUST be 100% borderless (`border: null`), relying on pure solid `surfaceContainerLow` / `surfaceContainer` fill with subtle tonal elevation so content scrolls underneath cleanly.
* **App Lock Privacy Shield Overlay**: Use solid theme-aware surface container cards (`surfaceContainerHigh`) with M3 stadium action buttons (`StadiumBorder()`), excluding sensitive child widgets from the active tree when locked.
* **Global InkSparkle & Ripple Shape Bounds**: Configure `splashFactory: InkSparkle.splashFactory` globally in `AppTheme`, and enforce matching `borderRadius` across `ListTileThemeData` (`AppLayout.radiusL`) and `IconButtonThemeData` (`CircleBorder`) so ripples conform to rounded surface bounds.
* **Shortcut Search Integration**: Route external search shortcuts (`com.saadhjawwadh.notebook.SEARCH`) through `HomeAppBar.searchRequestedNotifier` to launch the inline stadium search pill and `UniversalSearchOverlay`.
* **Google Material Icons & Symbols Standard**: Icon references must align with official [Google Material Icons / Symbols](https://fonts.google.com/icons). Prefer outlined/rounded variants (`Icons.<icon_name>_outlined` or `Icons.<icon_name>_rounded`) over filled variants for secondary controls and list tiles to maintain clean visual weights across light and dark themes.
* **M3 Expressive Floating Toolbar Architecture**: Ground page navigation with a structural M3 Top App Bar flush against the status area, paired with a single bottom M3 Expressive Floating Toolbar pill ($56\text{dp}$ height, $28\text{dp}$ stadium corners, 1px `outlineVariant` border with `0.35` opacity, $6\text{dp}$ floating elevation, $16\text{dp}$ side margins). Separate action clusters using $1\text{px}$ `VerticalDivider` lines. Keep block insertions (`Table`, `Image`, `Checklist`, `Drawing Canvas`, `Voice Mic`) on the Primary Creation Toolbar, and reserve secondary toolbars strictly for text typography formatting (`Headers`, `Bold`, `Italic`, `Underline`, `Strikethrough`, `Lists`). Consolidate AI into ONE prominent tonal container button (`IconButton.filledTonal`).
* **Material ListTile Ink Splash Safety**: Custom `ListTile` widgets inside custom containers or `AppBottomSheet` panels MUST be wrapped in `Material(color: Colors.transparent)` to guarantee ink ripple animations and eliminate `ListTile background color or ink splashes may be invisible` debug warnings.
* **ListTile Row Title Overflow Protection**: Any `Row` embedded inside the `title` parameter of `SwitchListTile` or `ListTile` MUST wrap text labels in `Flexible(child: Text(..., overflow: TextOverflow.ellipsis))` to prevent horizontal layout overflow errors on narrow device viewports.
* **SegmentedButton Responsive Column Layout**: Position multi-segment `SegmentedButton` controls in a vertical `Column` with full-width bounds (`SizedBox(width: double.infinity, child: SegmentedButton(...))`) below their heading label rather than side-by-side in horizontal `Row` containers to eliminate `RenderFlex` horizontal overflow on narrow viewports.
* **Global Typography Text Scaling**: Inject `MediaQuery(data: mediaQueryData.copyWith(textScaler: TextScaler.linear(mediaQueryData.textScaler.scale(1.0) * (settings.textSize / 16.0))))` in `MaterialApp.builder` so Medium font size (`textSize == 16.0`) natively defaults to the OS device font scale while supporting app-relative scaling.
* **BouncingWidget Spring Normalization**: Evaluate press states using spring physics tokens (`AppLayout.springFast`), scaling by `0.96` on touch down and releasing with fluid overshoot.
* **Solid M3 Surface Fills Over Gradients**: Enforce clean solid surface container fills (`surfaceContainerLow` / `surfaceContainerHigh`) and semantic color tokens (`tertiary`, `error`, `primary`) instead of `LinearGradient` decorations on surface cards, chart rods, lock screens, or icon containers to preserve tactile M3 design consistency.
* **Flexible Badge Scaling & Micro-Button Constraints**: Monospace text badges (e.g. 6-digit pair codes, IP addresses) embedded inside multi-column flex rows must use `Flexible` + `FittedBox(fit: BoxFit.scaleDown)` and explicit icon button constraints (`constraints: BoxConstraints(minWidth: 32, minHeight: 32)`) to eliminate `RenderFlex` horizontal overflow errors on narrow device viewports.
* **M3 Expressive Tonal Container Fills & Squircle Elevation**: To demarcate distinct card segments (Settings Dashboard hero cards, App Lock Screen shield, Financial summary cards, P2P control hub, Cycle phase cards) from background surface noise without returning to gradient fills, use `AppCard.tonal` (12%–25% alpha opacity of semantic container colors with matching 1px border) or `AppCard` with `16–24dp` squircle radius.
* **Optical High-Contrast QR Code Standard**: QR code matrix modules MUST be rendered in solid pure black (`Colors.black`) on a solid white container (`Colors.white`) with minimum 16dp quiet-zone padding. Never use `colorScheme.onSurface` or `colorScheme.primary` for QR modules, as off-white hues in Dark Mode cause camera optical scanning failures.
* **Strict Text Emoji Prohibition in UI Controls**: Never insert raw text emoji glyphs (e.g., `🔄`, `🟢`, `🔴`, `📋`) into button labels, dialog actions, or SnackBar alerts. Replace text emojis with official Material Symbols (`Icons.sync_rounded`, `Icons.check_circle_rounded`) and official M3 button APIs (`FilledButton.icon`, `FilledButton.tonalIcon`).
* **Single Hero Container Dynamic Tint & Border Accent Pattern**: Maintain a single, unified surface container context (`colorScheme.surfaceContainerHigh`) for body cards. Apply dynamic container fills and 1.2px accent borders ONLY to top Hero Cards (`SettingsHeroCard`, Net Balance, P2P Sync Status, Cycle Phase Moon, AI Result Sheet, Trash Auto-Purge Banner):
  - Light Mode (`Brightness.light`): Use 50%–55% alpha opacity of semantic container colors (`primaryContainer`, `tertiaryContainer`, `errorContainer`) with 45% border opacity for vibrant, non-muddy card fills.
  - Dark Mode (`Brightness.dark`): Use 20%–22% alpha opacity with 35% border opacity for deep translucent depth against OLED backdrops.
* **Settings Tile Text Overflow Guardrails**: Enforce `maxLines: 1` and `TextOverflow.ellipsis` on `SettingsTile` titles, and constrain trailing `valueBadge` chips (`maxWidth: 120dp`) to guarantee single-line title alignment across all device widths.
* **RepaintBoundary & Scroll Isolation Standards**: Wrap complex canvas rendering widgets (`fl_chart` charts, custom painters, period calendar views) inside `RepaintBoundary` to prevent unnecessary raster repaint passes during parent list scrolling. Apply `cacheExtent: 250` to primary `CustomScrollView` and `ListView` containers for smooth 60–120 FPS fling-scrolling.
* **BouncingWidget Dual-Gesture Wrapper Rule**: NEVER wrap `IconButton` directly inside `BouncingWidget` when handling `onLongPress` events. Standard `IconButton` internal `InkWell` widgets swallow tap/press events and prevent `onLongPress` from reaching `BouncingWidget`. Use `Tooltip` wrapped around `BouncingWidget(onTap: ..., onLongPress: ..., child: Padding(padding: const EdgeInsets.all(8), child: Icon(...)))` to guarantee 100% responsive tap and hold gesture detection.
* **Top Header Canonical Order & 16dp Edge Margin Symmetry**:
  - In custom top app bars and sliver headers (`HomeAppBar`, `FinancialManagerScreen`, `PeriodTrackerScreen`), maintain strict horizontal outer padding (`left: 16, right: 16`) with zero inner edge spacers.
  - Enforce canonical action sequence: Contextual Primary Action (`Search`, `Sync`, `Today`) $\rightarrow$ Penultimate Overflow Menu (`[ ⋮ Tools ]`) $\rightarrow$ Terminal Rightmost Anchor (`[ ⚙️ Settings ]`).
  - Constrain all top action icons to `BoxConstraints(minWidth: 40, minHeight: 40)` and `VisualDensity.compact` with `padding: EdgeInsets.zero` for uniform inter-button gaps.
  - Tapping Search transforms the header into full-width search mode (`_isSearching`) and eliminates redundant inline search textfields from scroll views.
  - Scope pills use M3 Tonal Container styling (`colorScheme.primaryContainer.withValues(alpha: isDark ? 0.35 : 0.45)`) with a `1.0px` primary outline border (`colorScheme.primary.withValues(alpha: 0.28)`) for 100% dynamic wallpaper contrast.
* **Authentic Currency Badges & Pickers**: Currency selection dialogs and settings tiles MUST render authentic tonal circular avatars displaying the genuine currency symbol (e.g. `Rs.`, `₹`, `$`, `€`, `£`, `¥`, `د.إ`, `﷼`, `C$`, `A$`, `S$`, `RM`, `NZ$`, `CHF`), bold code, and full name rather than generic dollar icons.
* **Hardware-Aware AI UI Gating**: Never render AI sparkle icons, refine menu items, or assist floating buttons unless `settings.isAiActive` is true. This prevents dead interactive elements on emulators and non-NPU devices.
* **AI Selection Action Pill vs Dropdown Redundancy**: When text selection floating toolbars provide context-aware AI refine pills, avoid repeating "Refine with AI" inside general dropdown menus. AI actions must remain strictly gated on `settings.isAiActive`.
* **Contextual Menu Discipline**: Never place global feature configuration switches or module settings inside contextual app bar dropdown menus (`PopupMenuButton`). Reserve 3-dot overflow menus strictly for actions acting directly on the current item (e.g. details, folder assignment, sharing, locking, deletion). Keep all feature preference toggles in `SettingsScreen`.
* **Connected Account Transfer Flow**: Inter-vault/account fund movements must use a unified connected vertical flow card with explicit "FROM ACCOUNT" and "TO ACCOUNT" sections, a tactile rotating swap button `⇅`, dynamic balance projection subtitles (`Balance after transfer: ...`), quick preset chips (`+100`, `+500`, `+1,000`, `+5,000`, `Max`), and a full-width stadium CTA button.
* **Disambiguated Dual-State Keyboard & Formatting Controls**: In rich editor floating docks, never duplicate the soft keyboard dismiss icon. When a secondary tool deck (e.g., text formatting) is expanded, its toggle action must dynamically switch to `Icons.keyboard_arrow_down_rounded` to collapse that specific deck, leaving `Icons.keyboard_hide_rounded` exclusively mapped to dismissing the soft input keyboard.
* **Embedded Sub-Navigation Card Nesting & Spacing**: When embedding complex domain cards inside parent tabs or scroll containers (e.g. `SavingsGoalsCard` within `FinancialAnalyticsTab`), supply an embedding flag (`isEmbeddedInCard: true`) to return content directly without wrapping in another `AppCard`, completely eliminating double padding and whitespace bugs.
* **AI Action Iconography & Phrasing Standards**:
  - Always use canonical Material 3 `Icons.auto_fix_high_rounded` (for AI title/text refinement and formatting actions) or `Icons.auto_awesome_rounded` (for generative creation).
* **Contextual Morphing Action Buttons in Sub-Tab Views**:
  - In screens featuring nested `SegmentedButton` tabs or view modes (`FinancialManagerScreen`), expose a `ValueNotifier<String>` indicating the active sub-tab.
  - The hosting screen's floating action button (`AppMorphingFab`) must reactively listen to this notifier via `ValueListenableBuilder` to dynamically adapt its icon, label, and `onPressed` route destination (e.g. morphing from "New Transaction" to "New Split Bill" when switching to Split Bills).
* **Bounded Modal Sheets & Dynamic Chip Cloud Scroll Guardrails**: Never render unbounded `Column(mainAxisSize: MainAxisSize.min)` containing `Wrap` chip clouds inside `showModalBottomSheet` or `AppBottomSheet`. To eliminate `RenderFlex` overflows on small devices or when software keyboards appear:
  - Constrain modal height using `ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75))`.
  - Wrap content in `SingleChildScrollView` with `viewInsets.bottom` keyboard padding (`EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom + AppLayout.spaceM)`).
  - Constrain inner multi-chip clouds (`Wrap`) to a fixed max viewport (e.g. `maxHeight: 180–220dp`) wrapped in a secondary `SingleChildScrollView`.

## 2. Material 3 Official Components Catalog ([m3.material.io](https://m3.material.io/components))
When implementing UI components, strictly follow the M3 guidelines codified in [design.md Section 9](file:///Users/saadhjawwadh/Documents/Code/Note%20taking/.agent/skills/UI-UX-Specialist/design.md#9-comprehensive-material-3-component-specifications--guidance-catalog-m3materialio):
1. **Action Components:** Use `FilledButton` for single primary CTA, `FilledButton.tonal` for secondary actions, `SegmentedButton` for 2–5 view toggles, and `FloatingActionButton` ($56\text{ dp}$ / $28\text{ dp}$ radius) for constructive canvas actions.
2. **Communication Components:** Use `Badge.count` for unread/filter indicators, `LinearProgressIndicator` with rounded caps for task progress, and floating `SnackBar` for non-blocking confirmations.
3. **Containment Components:** Wrap cards in `AppCard` / `Material` to ensure ink splash visibility, use `AppBottomSheet` with $28\text{ dp}$ top corners for modal panels, and use `AppDialog` for alert confirmations.
4. **Navigation Components:** Use borderless `ExpressiveSliverAppBar` with pure solid `surfaceContainerLow` fill for headers, `NavigationBar` ($80\text{ dp}$ height with active pill container) for mobile, and `NavigationRail` for tablets (>600dp).
5. **Selection Components:** Use `PopupMenuButton` / `MenuAnchor` with Level 3 elevation (`3`), $28\text{ dp}$ shape radius, and $48\text{ dp}$ item height; `FilterChip` / `ChoiceChip` / `AppChip` with `showCheckmark: false` to keep avatar icons unobstructed; `Switch` with active thumb icon for toggles.
6. **Text Input Components:** Use `TextField` with $56\text{ dp}$ height and $12\text{ dp}$ radius. When embedding inside custom stadium pill containers, set `filled: false` and borderless `InputDecoration`.

## 3. Material 3 Official Styles Catalog ([m3.material.io/styles](https://m3.material.io/styles))
When styling UI screens and custom widgets, strictly enforce the M3 Style systems codified in [design.md Section 10](file:///Users/saadhjawwadh/Documents/Code/Note%20taking/.agent/skills/UI-UX-Specialist/design.md#10-comprehensive-material-3-styles-specifications--guidance-catalog-m3materialiostyles):
1. **Color System:** Implement dynamic seed generation (`ColorScheme.fromSeed`), 5-Tier Surface Containers (`lowest` $\rightarrow$ `highest`), OLED pitch black `#000000` dark mode, and minimum $4.5:1$ WCAG AA contrast ratios.
2. **Typography Scale:** Pair `Google Sans Text` / `Plus Jakarta Sans` for controls and `Inter` with tabular figures (`[FontFeature.tabularFigures()]`) for monetary ledgers. Use exact 15-role typography tokens.
3. **Shape System:** Follow the official M3 Expressive shape scale (Tactile Stadium Pills $1000\text{dp}$ / `StadiumBorder` for chips, tags, filter pills, search bars, and primary CTAs; Squircles $12\text{dp}$–$16\text{dp}$ for cards, $28\text{dp}$ for dialogs/sheets; Connected Corner Morphing for grouped lists).
4. **Motion Architecture:** Enforce velocity-aware spring physics (`SpringDescription` tokens: `springFast`, `springSpatial`, `springBouncy`) and standard transition patterns (`SharedAxis`, `FadeThrough`, `OpenContainer`).
5. **Elevation & Depth:** Use tonal surface container elevation (0–5 tiers) with subtle 1px `outlineVariant` borders instead of heavy drop shadows or Apple-style Gaussian frosted blurs.
6. **Material Symbols:** Use official Google Material Symbols (`Icons.<name>_outlined` / `Icons.<name>_rounded`) with minimum $48 \times 48\text{ dp}$ touch target sizes.

## 4. Frozen Flank & Split-Axis Floating Toolbars
* **Dual-Axis Pinning**: When designing dense floating toolbars with directional steppers, freeze primary navigation axes on the left ($64\text{dp}$) and right ($64\text{dp}$) and place scrollable tools in `Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, ...))`.
* **Multi-Tier Gestures**:
  - `onTap`: Single character/item nudge with `HapticFeedback.selectionClick()`.
  - `onDoubleTap` & `onLongPress`: Smart boundary snap (e.g. word boundary jumping).
* **Entrance Transitions**: Wrap contextual floating pills in `AnimatedSwitcher` using `SlideTransition(Offset(0, 0.35) -> Offset.zero)` and `FadeTransition` with `Curves.easeOutCubic` over `AppLayout.animShort`.

## 5. Balanced Metric Cards & Bi-Directional Visual Invariants
* **No-Whitespace Dual-Column Layout**: Never leave wide horizontal empty space on status cards. Split metrics into balanced columns separated by a subtle 1px translucent vertical divider (`colorScheme.outlineVariant.withValues(alpha: 0.35)`).
* **Badge Width Guardrail**: Keep floating header badges under 15 characters (e.g. `Est ~395.8k`) so deck titles never truncate into ellipsis (`TextOverflow.ellipsis`) on narrow mobile screens.
* **Chart Tooltip 1px Outline & Depth**: Floating Canvas chart tooltips (`LineTouchTooltipData`) must specify a 1px primary accent border (`BorderSide(color: colorScheme.primary.withValues(alpha: 0.3), width: 1.0)`) and rounded radius (`AppLayout.radiusM`) to prevent light-mode blending against surface cards.
* **$48dp Custom Hit Target Wrappers**: Micro-elements (pagination dots, header dropdowns, "Details >" links) must enforce minimum $48 \times 48\text{dp}$ hit bounds (`BoxConstraints(minWidth: 48, minHeight: 48)` or padded gesture wrappers) and supply `Semantics(button: true)`.

## 6. 0ms Optimistic UI & Zero-Flicker State Transitions
* **Zero Jitter on User Actions**: Interactive operations (Delete, Undo, Pin, Archive, Symptom/Flow toggling) MUST update in-memory UI models immediately in 0ms. Never unmount active lists or display modal loading spinners while writing local SQLite updates in the background.
* **Preserve Mounted State**: When deleting or restoring items, mutate local data structures synchronously (`removeWhere`, `add`, `sort`) and trigger targeted re-renders without triggering full-screen or list-level loading indicators.

## 7. Top App Bar Rhythm, Action Order & High-Frequency Action Rule
* **High-Frequency vs Administrative Action Rule**: High-frequency layout and view manipulations (such as note sorting) must NOT be buried inside the 3-dot overflow menu (`⋮`). Provide a dedicated top-bar action button with an instant popup menu. Reserve the 3-dot tools menu strictly for secondary administrative utilities.
* **3-Module Scope Hierarchy**:
  - **Notes**: `Notes` title + `[ 📁 Folder • Count ▾ ]` tonal pill (triggers `_showFolderPicker`).
  - **Finances**: `Finances` title + `[ 📅 Date Range ▾ ]` tonal pill (triggers `_selectDateRange`).
  - **Health Tracker**: `Period Tracker` title + `[ 🌸 Day X • Phase ]` tonal badge (shows active cycle phase).
* **Right Action Bar (Symmetric Action Flow)**:
  - **Notes**: `[ 🔍 Search ]` $\rightarrow$ `[ 🔃 Sort ]` $\rightarrow$ `[ 🔄 P2P Sync (when paired) ]` $\rightarrow$ `[ ⋮ Notes Tools ]` $\rightarrow$ `[ ⚙️ Settings ]`.
  - **Finances**: `[ 🔍 Search ]` $\rightarrow$ `[ 🔄 SMS Quick Sync ]` $\rightarrow$ `[ ⋮ Finances Tools ]` $\rightarrow$ `[ ⚙️ Settings ]`.
  - **Health Tracker**: `[ 📅 Today ]` $\rightarrow$ `[ ⋮ Health Tools ]` $\rightarrow$ `[ ⚙️ Settings ]`.
* **Compact Hit Constraints**: Action bar icon buttons MUST use `constraints: const BoxConstraints(minWidth: 40, minHeight: 40)` and `visualDensity: VisualDensity.compact` to eliminate overlapping hitboxes and prevent misdirected touch gestures.
* **Sub-Pixel Headroom Invariant**: Top bars hosting title + scope pill stacks MUST specify `toolbarHeight: MediaQuery.of(context).padding.top + 72.0` and child container `height: 60.0` (with `top: padding.top + 6.0, bottom: 6.0`) to avoid sub-pixel layout clipping across high-density mobile screens.
* **M3 Chevron Token**: Always use `Icons.keyboard_arrow_down_rounded` across all dropdown chips, form fields, and selector pills (deprecating legacy `Icons.arrow_drop_down`).
* **Selection Control Modernization (`showSelectedIcon: false`)**: All `SegmentedButton<T>` instances displaying contextual icons or custom labels MUST set `showSelectedIcon: false` to prevent Flutter from swapping genuine button icons with default checkmark glyphs upon selection. Active states must rely on tonal container fills and primary icon/label tints.
* **Tactile Canvas Haptics**: Interactive charts (`LineChart`, `PieChart`) and calendar widgets (`TableCalendar`) must provide tactile micro-feedback via `HapticFeedback.selectionClick()` whenever the user scrubs through data points, donut slices, or flips dates/pages.
* **Social Story Card Studio Standard**: When exporting note text or quotes to social media formats (9:16 Story, 1:1 Square, 4:5 Portrait), cards must support local font switching (e.g. Noto Sans & Serif Tamil), Instagram/WhatsApp safe-margin heatmaps, word-limit constraints, and a centered micro-pill watermark featuring the monochrome app emblem.


