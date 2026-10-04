# Everything App — Master Agent Kernel & Single Source of Truth

You are Antigravity, the AI pair programmer working on **Everything App** (offline-first note-taking, financial manager, health tracker, and local P2P sync with on-device AI).
This document is the canonical, authoritative Single Source of Truth (SSOT) for all architectural standards, engineering invariants, and developer workflows.

---

## 1. Core Architecture & Tech Stack

* **Framework & Language**: Flutter (>=3.27.0) with Dart (>=3.6.0).
* **State Management**: Reactive state management with `package:provider` (`ChangeNotifier`). Decoupled domain providers registered globally in `main.dart`'s root `MultiProvider`.
* **Local Storage & Security**: Fully local, offline-first SQLCipher encrypted SQLite (`sqflite_sqlcipher` with WAL mode enabled) protected by Android KeyStore / iOS Keychain (`flutter_secure_storage`). AES-256 encrypted JSON backups via `BackupService`.
* **Design System**: Strict Material 3 Expressive theming (`AppTheme` / `AppLayout`) with dynamic Material You wallpaper color extraction (`dynamic_color`), OLED pitch-black dark mode, Google Sans Flex variable typography, 5-tier solid surface containers, and spring-physics micro-interactions.
* **On-Device Intelligence**: Hardware-aware on-device AI (`gemini_nano_android` / AICore) strictly gated by `settings.isAiActive`.
* **Peer-to-Peer Device Sync**: Zero-cloud, bi-directional LWW Wi-Fi sync engine using direct REST HTTP server (Port 8765) and UDP radio beacon (Port 8766).

---

## 2. Directory Structure & Module Map

Consult the detailed [Developer Map (.agent/map.md)](file:///Users/saadhjawwadh/Documents/Code/Note%20taking/.agent/map.md) before searching or modifying code:

```
lib/
├── core/                               # Shared design system, UI primitives, and router
│   ├── routes/app_router.dart          # Centralized route strings and M3 shared-axis transitions
│   ├── theme/                          # Single Source of Truth Design Tokens
│   │   ├── app_layout.dart             # Spacings (spaceXS–XXL), squircle radii, SpringDescription tokens
│   │   └── app_theme.dart              # M3 ColorSchemes, 15-role typography, InkSparkle
│   └── ui/                             # Standard Atomic UI Component Library
│       ├── app_card.dart               # Surface container card (standard, tonal, squircle, connected)
│       ├── app_bottom_sheet.dart       # Drag-handled modal sheet with responsive width bounds
│       ├── app_chip.dart               # Standardized 8–12dp squircle chip & tag pill
│       ├── app_dialog.dart             # Responsive confirmation and prompt dialogs
│       ├── expressive_sliver_app_bar.dart # Seamless borderless M3 surface header (zero blur)
│       ├── expressive_split_button.dart   # M3 Expressive Split Button (action + dropdown anchor)
│       ├── expressive_wavy_slider.dart    # Tactile sinusoidal wavy slider
│       ├── expressive_wavy_progress.dart  # Animated wavy linear & circular progress indicators
│       ├── expressive_shape_morph_indicator.dart # Shape-morphing loading indicator (35+ shapes)
│       └── app_morphing_fab.dart       # Dynamic squircle-to-stadium morphing FAB
├── features/                           # Feature-Driven Domain Bundles
│   ├── notes/                          # Lossless Quill Delta notes, tags, auto-purge trash
│   ├── finances/                       # SMS auto-import ledger, categories, recurring rules, AI refine
│   ├── health/                         # Menstrual cycle predictions, ovulation, discreet alerts
│   ├── settings/                       # App preferences, full-screen onboarding wizard, backups, lock
│   └── sync/                           # Master P2P device sync engine, pairing wizard, QR scanner
├── data/                               # Database helpers, models, and migrations
└── services/                           # Background sync, Workmanager isolates, notifications, AI
```

---

## 3. Non-Negotiable System Invariants

### 🎨 Invariant 1: Single Source of Truth Theme & Core UI Primitives
* **No Magic Values**: Never hardcode padding, margins, border radii, motion curves, or static colors inside screen widgets.
* **Tokens**: Reference layout tokens from `AppLayout` and semantic colors from `Theme.of(context).colorScheme` or `AppSemanticColors`.
* **Shared UI Library**: Always use `AppCard`, `AppBottomSheet`, `AppChip`, `AppDialog`, and `ExpressiveSliverAppBar` from `lib/core/ui/`.
* **Seamless Borderless Surface Bars**: Top app bars (`ExpressiveSliverAppBar`) and bottom navigation bars MUST be 100% borderless (`border: null`), relying on pure solid `surfaceContainerLow` / `surfaceContainer` fill with subtle tonal elevation—ZERO `BackdropFilter` or frosted glass blurs.
* **M3 Expressive Shape Hierarchy**: Use the official M3 Expressive shape scale:
  - Tactile Stadium Pills ($1000\text{dp}$ / `StadiumBorder`): Standard for chips, tags, filter pills, search bars, and primary CTAs, creating soft, touch-friendly capsules (matching Google's M3 Expressive research).
  - Squircles ($12\text{dp}$–$16\text{dp}$ for cards, $28\text{dp}$ for dialogs/sheets).
  - Connected Corner Morphing for grouped lists (first item rounded top, middle items flat, last item rounded bottom).
* **Velocity-Aware Spring Physics**: Micro-interactions and press states must use `SpringDescription` tokens (`AppLayout.springFast` / `AppLayout.springSpatial`) and `AppLayout.curveEmphasizedDecelerate`, reacting naturally to gesture momentum.
* **Dynamic Hero Card Opacities**: Hero cards (`SettingsHeroCard`, Net Balance, P2P Sync Status, Cycle Moon Phase, Trash Auto-Purge Banner) must dynamically adjust container opacity (50%–55% alpha in Light Mode; 20%–22% alpha in Dark Mode) with subtle 1.2px accent borders.

### 🏗️ Invariant 2: Feature-Driven Domain Architecture & Root Provider Registration
* **Domain Modularization**: Place domain models, repositories, providers, and presentation screens inside `lib/features/<module>/`.
* **Decoupled Providers**: Encapsulate queries, calculations, and auto-save timers in `ChangeNotifier` providers.
* **Root Provider Registration**: Always register domain providers (`FinancialManagerProvider`, `NoteProvider`, `P2pSyncProvider`, `SettingsProvider`) in `main.dart`'s root `MultiProvider` list so state is globally accessible across routes and modal sheets.
* **No Stubs / Direct Imports**: Import screens and repositories directly from feature directories. Do NOT create 1-line re-export stub files.

### 🤖 Invariant 3: Hardware-Aware AI Capability Gating (`isAiActive`)
* Never gate AI UI triggers on `useOnDeviceAi` alone.
* AI sparkle icons, toolbar assist buttons, and refine menu actions MUST query `settings.isAiActive` (`_useOnDeviceAi && _isDeviceAiSupported`) so emulators and devices lacking on-device Gemini Nano/AICore hardware cleanly hide non-functional controls.

### 💳 Invariant 4: Authentic Currencies, SMS Deduplication, Tombstone Safety, Dual Accounts & Recurring Sync
* **Authentic Symbol Badges**: Render authentic tonal circular avatars displaying the genuine currency symbol (e.g. `Rs.`, `₹`, `$`, `€`, `£`, `¥`, `د.إ`, `﷼`, `C$`, `A$`, `S$`, `RM`, `NZ$`, `CHF`), bold code, and full name instead of generic dollar icons.
* **Two-Bank Account Model**: All financial records and transactions support explicit account tagging (`AccountType.daily` = `'daily'`, `AccountType.savings` = `'savings'`). The Financial Manager Hero Card displays dual interactive balance metrics (`_dailyCashFlow` vs `_savingsVaultCashFlow`), and the ledger supports 0ms account filtering. Bank deposits and savings keywords are auto-routed to `AccountType.savings`.
* **Recurring Rule Propagation**: Editing recurring transaction details (amount, category, description, frequency) in `TransactionEditorScreen` MUST propagate changes to the master `RecurringRule` definition via `RecurringRuleRepository.findMatchingRule()`, keeping all future auto-generated cycles in sync.
* **PII Lookahead Assertions**: Reference number stripping regexes MUST require digit lookaheads (`\b(?=[A-Za-z0-9]*\d)[A-Za-z0-9]{10,}\b`) to avoid truncating legitimate 10+ character English words.
* **SMS Sandbox Whitelisting**: SMS parsing engines must recognize simulated test senders (`'BANK_SMS'`, `'CARD'`, `'ALERTS'`, `'BANK'`) as verified financial senders.
* **SMS Permission Manifest Parity**: Permission services must strictly query declared permissions (`Permission.sms`). Never query undeclared permissions (e.g. `Permission.phone`), as `permission_handler` permanently returns `denied` for undeclared permissions.
* **Tombstone Ingestion Guardrail**: `TransactionRepository.createSmsTransaction` must query `smsExists(smsId)` against active `transactions` and `deleted_transaction_sms_ids` by default, rejecting re-imports unless `bypassTombstones: true` is explicitly requested.
* **SMS Timestamp Normalization & Streamlined Ingestion**: All SMS ingestion engines must pass message dates through `SmsParser.resolveMessageDate(messageDate)` to normalize 10-digit second and 13-digit millisecond epoch timestamps. App strictly adheres to Scheduled Daily Auto-Sync + Manual On-Demand (`[ 🔄 Sync ]`) + Real-time Live Listener (`telephony.listenIncomingSms`), eliminating unsolicited launch/resume polling loops to preserve battery and CPU.
* **Soft-Delete Undo Parity**: All deletion undo handlers must invoke `restoreTransaction(id)` (`UPDATE transactions SET deletedAt = NULL WHERE id = ?`) or `restoreNote(id)` rather than attempting record re-insertion (`createTransaction`/`insertNote`), preventing primary key collisions and tombstone re-import blocks.
* **Non-Blocking Chunked Sync & Cancellation**: SMS inbox syncing must process messages in non-blocking chunks (yielding every 25 messages), check `_cancelRequested`, and display an instant `Cancel` button on sync progress banners.
* **SMS 24-Hour Default Lookback & Real-Time Sync Banner**: Quick sync and daily scheduled sync MUST default to scanning the **last 24 hours** (`DateTime.now().subtract(const Duration(hours: 24))`) rather than incremental cutoffs, eliminating skipped-message bugs from "fetch only new". A persistent frosted progress banner is rendered directly below the top app bar across all financial tabs (`Ledger`, `Budgets`, `Split Bills`) during sync with a 1-tap `[ Cancel ]` button, followed by exact-count floating SnackBar feedback upon completion.

### 🔒 Invariant 5: Local-First Security, SQLite WAL Mode & Resilient Backups
* **SQLCipher Password Contract**: Pass explicit encryption keys to `openDatabase()`. In `DatabaseHelper.onOpen`, execute `PRAGMA journal_mode = WAL;` via `db.rawQuery(...)` for non-blocking concurrent writes.
* **Resilient Auto-Backup Storage Priority**: Scheduled background backups (`BackupService.performAutoBackup()`) MUST default to sandboxed protected app documents (`getApplicationDocumentsDirectory()`), preventing Android Storage Access Framework (SAF) URI permission revocations across OS updates and device reboots.
* **Local Auth / Dialog Resume**: Screens invoking native file pickers or share sheets must call `AppLockScreen.ignoreNextResumeLock()` to prevent unintentional app locking on resume.

### 🔄 Invariant 6: Zero-Cloud P2P Sync & Bi-Directional Merge
* **LWW 2-Way Delta Merges**: Execute non-destructive merges over local Wi-Fi. Soft-deletes check `deletedAt` with 5-second clock skew tolerance.
* **Stable Identity & Multi-Network Endpoints**: Each peer retains an immutable `deviceId` UUID with multiple saved `DeviceEndpoint`s (e.g., home and office Wi-Fi). Never deduplicate peers by IP or pair code.

### 🛡️ Invariant 7: Absolute Permission Rule & Major/Minor Release Gates
* **No Unprompted Git Actions**: NEVER run `git commit`, `git tag`, or `git push` without explicit, real-time user confirmation.
* **Mandatory Analysis & Testing**: Run `flutter analyze` (0 errors/warnings) and `flutter test` (all tests passing) before committing or building.
* **Major vs. Minor Documentation Strategy**:
  - **Major Releases (`X.0.0`)**: Review `OnboardingScreen` slides; optionally bump onboarding key (`hasSeenOnboarding_v2`) if core workflows changed.
  - **Minor/Patch Releases (`X.Y.Z`)**: Existing users bypass onboarding. `PLAY_STORE_NOTES.md` and `WhatsNewSheet` present the **cumulative headline features from the current minor cycle (`X.Y.x`)** alongside the latest patch fixes.
* **5-Point Release Parity & Test Guardrail**: Atomically update `PLAY_STORE_NOTES.md` (`<en-US>` and `<ta-IN>`, < 450 characters each), `lib/screens/changelog_screen.dart`, `lib/widgets/whats_new_sheet.dart`, `CHANGELOG.md`, and the version assertion in `test/upgrade_backward_compatibility_test.dart` before compiling release APKs or running `./deploy.sh`.
* **Play Store VersionCode Immutability**: Google Play Developer Console strictly disallows re-uploading an existing `versionCode` (even if an earlier run failed at a later step or only partially completed). Never attempt to re-deploy or re-tag with an existing version code. If a release fails at or after upload, the patch version MUST be incremented (`X.Y.Z+W` where $W = X \times 10000 + Y \times 100 + Z$).
* **Emulator Clean Shutdown Protocol**: When verifying on an Android virtual device, always cleanly terminate the emulator (`adb -s <device> emu kill`) and kill any background daemon process once testing and release tasks conclude, preventing orphaned QEMU processes from draining system CPU and memory.

### 🔘 Invariant 8: Standard FAB Bottom Clearance & Universal Morphing Protocol
* **No Obscured Content**: Bottom scrollable content must never be clipped or obscured by floating buttons or bottom navigation chrome. Always apply `AppLayout.fabBottomPadding = 96.0` to sliver lists or bottom padding containers.
* **Universal Morphing FAB**: All floating action buttons must use `AppMorphingFab` (`lib/core/ui/app_morphing_fab.dart`), reacting to `UserScrollNotification` to dynamically collapse into a $56 \times 56\text{dp}$ circular button on downward scroll and expand back to the stadium button on upward scroll.
* **Donut Chart Precision**: Donut chart center hole labels must be explicitly bounded inside a `SizedBox` with `FittedBox(fit: BoxFit.scaleDown)` to prevent text from touching chart rings, and slices must enforce a minimum 1.5% angle floor so micro-slivers remain visible.

### 🖼️ Invariant 9: R8 Full-Mode Optimization & Bitmap Memory Downsampling
* **R8 Full-Mode Hygiene**: Maintain `android.enableR8.fullMode=true` in `android/gradle.properties`. Avoid broad wildcards like `-keep class io.flutter.** { *; }` in `proguard-rules.pro` that disable dead code elimination and method inlining passes.
* **Native & ML Plugin ProGuard Rules**: When introducing native plugins with optional sub-modules or dynamic model loaders (e.g. `mobile_scanner`, `speech_to_text`, `gemini_nano_android`, `in_app_update`, `in_app_review`), always declare explicit `-keep class <plugin>.** { *; }` and `-dontwarn <plugin>.**` rules in `android/app/proguard-rules.pro` to prevent R8 class-stripping aborts during release compilation.
* **Bitmap Downsampling Bounds**: Never decode raw 12–48MP images without bounding parameters. All `Image.file`, `Image.network`, and `Image.asset` preview widgets MUST supply `cacheWidth` (e.g. `cacheWidth: 1080` for note embeds, `cacheWidth: 400` for grid/list cards, `cacheWidth: 300` for receipt previews) and provide `errorBuilder` fallbacks to prevent OOM memory pressure.
* **Global Image Cache Bounds**: `main.dart` must maintain `imageCache.maximumSizeBytes = 100 * 1024 * 1024` (100MB) and `maximumSize = 100`.

### 🎯 Invariant 10: Touch Target Bounds, Chart Outlines & Semantic Labels
* **$\ge 48\times 48\text{dp}$ Touch Targets**: All interactive micro-elements (sync buttons, date filter pills, "Details >" links, pagination indicator dots) must enforce minimum $48 \times 48\text{dp}$ hit bounds (`BoxConstraints(minWidth: 48, minHeight: 48)` or padded gesture wrappers) and supply `Semantics(button: true)`.
* **Chart Tooltip 1px Accent Outline**: Floating Canvas chart tooltips (`LineTouchTooltipData`) must specify a 1px primary accent border (`BorderSide(color: colorScheme.primary.withValues(alpha: 0.3), width: 1.0)`) and rounded radius (`AppLayout.radiusM`) to prevent light-mode blending against surface cards.
* **Prohibition of Raw Text Emojis (Rule 41)**: Strictly replace raw Unicode emoji glyphs (`🔮`, `🔴`, `🟢`) in UI labels and badges with authentic Material Symbols (`Icons.auto_awesome_rounded`) and plain-language semantic labels.

### 🤝 Invariant 12: Split Bills & Shared Debts Domain Integration
* **Modular Integration**: Split Bills is an optional financial sub-feature gated by `settings.showSplitBills`. When enabled, it appears as the third tab in `FinancialManagerScreen` (`Ledger`, `Budgets`, `Split Bills`).
* **Ledger Cash Flow Contract**: 
  - When the user pays for a group bill, the master expense reflects the full receipt total (matching bank SMS debits).
  - Debt repayments from participants settled in `SettleUpSheet` MUST record as `Income` in the Daily Operating account.
  - When a friend pays for a bill, the user's ledger records personal liability *only* upon the user settling their own share with that friend (recorded as `Expense`). Other participants settling with the payer are purely informational in the Split Tab and MUST NEVER create ledger entries in the user's personal accounts. Once the user pays their share, the split is completed (`Settled for You`) from the user's perspective.
  - Reversing a settlement (`unsettleAllForContact`) MUST delete the matching ledger transaction in `transactions` (`TransactionRepository.deleteTransaction`), ensuring cash flow balances remain identical to settled states.
* **Offline OCR & Sharing**: Receipt scanning (`ReceiptScannerService`) operates 100% locally on-device via ML Kit. WhatsApp payment reminder templates (`SplitShareService.formatPersonPendingStatement`) format genuine multi-bill itemized breakdown summaries with running totals and user-configured default payment info without third-party cloud SDKs.
* **Full Backup & P2P Sync Invariant**: Split bills tables (`split_bills`, `split_participants`, `split_contacts`) MUST be serialized in `BackupService.generateBackupJson()`, restored in `BackupService.restoreFromBackupData()`, and merged via `SyncMergeService.mergeRemoteData()`.
* **Resume Lock Bypass**: Any screen invoking external file pickers or system share sheets (JSON backups, CSV imports, Receipt Camera/Gallery, WhatsApp sharing) MUST call `AppLockScreen.ignoreNextResumeLock()` immediately before launch.

### 🎨 Invariant 13: Selection Controls Modernization & Legacy Dropdown Prohibition
* **No Legacy M2 Dropdowns**: Never use `DropdownButton` or `DropdownButtonFormField`.
* **Short Option Sets (2–4 choices)**: Use `SegmentedButton<T>` with compact visual density and haptic feedback.
* **Large Datasets (Categories)**: Use dynamic `FilterChip` clouds sourced strictly from `TransactionCategory.allNames` with authentic icons (`TransactionCategory.iconFor(c)`) and color backgrounds (`TransactionCategory.colorFor(c)`).
* **Unblocked Chip Avatars**: All selection chips (`FilterChip`, `ChoiceChip`) with leading avatars or icons MUST set `showCheckmark: false`. Never allow Flutter's default checkmark to overlay, squash, or conceal category, account, or studio icons. Highlight active selections cleanly with dynamic theme container fills, prominent borders, and `colorScheme.primary` icon tints.
* **Chevron Modernization**: Standardize all dropdown indicators across forms, date selectors, and scope pills on `Icons.keyboard_arrow_down_rounded`.

### 🏛️ Invariant 14: Top App Bar Symmetry, Tonal Scope Pills, Search Integration & Action Order
* **Left Header Structure**: Module Title (`titleLarge` 18pt bold) paired with an interactive Tonal Scope Pill directly below:
  - **Notes**: `Notes` + `[ 📁 Folder • Count ▾ ]` (opens folder picker modal).
  - **Finances**: `Finances` + `[ 📅 Date Range ▾ ]` (opens preset date range sheet).
  - **Health Tracker**: `Period Tracker` + `[ 🌸 Day X • Phase ]` (indicates active cycle status).
* **Tonal Scope Pill Contrast Standard**: Scope pills MUST use M3 Tonal Container styling (`colorScheme.primaryContainer.withValues(alpha: isDark ? 0.35 : 0.45)`) with a subtle `1.0px` primary accent border (`colorScheme.primary.withValues(alpha: 0.28)`), `colorScheme.onSurface` label, and `colorScheme.primary` leading icon & dropdown chevron, guaranteeing 100% legibility across dynamic Material You wallpaper palettes.
* **High-Frequency vs Administrative Action Rule**: High-frequency layout and view manipulations (such as note sorting) must NOT be buried inside the 3-dot overflow menu (`⋮`). Provide a dedicated top-bar action button (`Icons.sort_rounded`) with an instant popup menu. Reserve the 3-dot tools menu strictly for secondary administrative utilities (view toggle, folders, tags, archive, trash).
* **Top Action Bar Canonical Order (Muscle Memory)**:
  - **Notes**: `[ 🔍 Search ]` $\rightarrow$ `[ 🔃 Sort ]` $\rightarrow$ `[ 🔄 Sync (when paired) ]` $\rightarrow$ `[ ⋮ Notes Tools ]` $\rightarrow$ `[ ⚙️ Settings ]`.
  - **Finances**: `[ 🔍 Search ]` $\rightarrow$ `[ 🔄 SMS Sync ]` $\rightarrow$ `[ ⋮ Finances Tools ]` $\rightarrow$ `[ ⚙️ Settings ]`.
  - **Health Tracker**: `[ 📅 Today ]` $\rightarrow$ `[ ⋮ Health Tools ]` $\rightarrow$ `[ ⚙️ Settings ]`.
* **Top Bar Transaction Search Integration**: Tapping `[ 🔍 Search ]` in Finances transforms the top app bar into full-width search mode (`_isSearching`) with back button, real-time debounced query input, and clear button (matching Notes), auto-switches to the `Ledger` tab, and completely eliminates redundant inline `TextField` search boxes from scroll views.
* **Edge Margin Symmetry & Compact Hit Constraints**:
  - Outer horizontal padding MUST be strictly `16dp` left and `16dp` right with ZERO inner edge spacers.
  - All top bar action icons MUST enforce `constraints: const BoxConstraints(minWidth: 40, minHeight: 40)`, `visualDensity: VisualDensity.compact`, and `padding: EdgeInsets.zero` to maintain uniform inter-button gaps without overlapping hitboxes.
* **Top Bar Sub-Pixel Headroom**: SliverAppBar headers hosting title + scope pill columns MUST enforce `toolbarHeight: MediaQuery.of(context).padding.top + 72.0` and inner container `height: 60.0` (with vertical padding `top: padding.top + 6.0, bottom: 6.0`) to eliminate sub-pixel layout overflows.

### 📥 Invariant 15: Google Takeout & Note Migration Standards
* **ZIP Directory Path Invariant**: Never filter ZIP entries on broad substrings like `!name.contains('takeout')`, as Google Takeout stores all Keep notes under `Takeout/Keep/<note>.json`. Only exclude the top-level index file (`baseName != 'takeout.json'`).
* **Keep Bookmark Annotations Invariant**: In Google Keep, web bookmarks shared from browsers set `textContent: ""` and place the URL, title, and description inside `data['annotations']`. Importers MUST extract `annotations` into formatted markdown links, preventing notes from importing as blank bodies with only labels.
* **Companion Image Resolution**: When importing from extracted folders or ZIPs, companion image attachments (e.g. `1961dd5...jpg`) must be resolved relative to the note's source directory (`file.parent` or ZIP entry path) and copied to protected sandboxed storage (`getApplicationDocumentsDirectory()`).
* **Archived Notes Parity & Discoverability**: Google Keep notes with `"isArchived": true` MUST be saved with `isArchived = 1` and remain immediately discoverable via the top Folder Scope Pill (`[ 📁 Notes ▾ ] -> Archived Notes`) and Tools menu (`⋮ -> Archived Notes`).

### 📱 Invariant 16: Android App Shortcuts & Deep Intent Routing Protocol
* **Static App Shortcuts (`app_shortcuts.xml`)**: Support high-priority launcher shortcuts: `NEW_NOTE` (`app://open/new_note`), `ADD_TRANSACTION` (`app://open/new_transaction`), `SCAN_RECEIPT` (`app://open/scan_receipt`), and `SYNC_DEVICES` (`app://open/sync_devices`).
* **Dual-Phase Intent Ingestion**: `MainActivity.kt` handles intents across cold launches (`onCreate`) and warm resume (`onNewIntent`), passing the URI via Flutter method channel `pendingWidgetAction`. `HomeScreen._checkAndProcessPendingIntents()` dispatches the action immediately to the target view.

### 📝 Invariant 17: Interactive Home Screen Widget & Native Bridge Contract
* **Native RemoteViews Architecture**: The interactive checklist widget (`TodoWidgetProvider`, `TodoWidgetService`, `TodoWidgetActionReceiver`) renders directly on the Android home screen launcher. Interactive checkbox clicks execute in the background via standalone `BroadcastReceiver` without launching the Flutter engine, immediately updating `RemoteViews` and recording pending state in `FlutterSharedPreferences` (`flutter.todo_widget_data`, `flutter.pending_todo_action_...`).
* **Zero-Drift Synchronization**: Whenever the app returns to foreground (`HomeScreen._checkAndProcessPendingIntents()` / `NoteProvider.refreshNotes()`), `WidgetHelper.processPendingWidgetActions()` MUST execute immediately, reconciling launcher actions with the persistent SQLCipher database and Quill Delta documents.
* **Calm Habit Gamification**: Habit and mindfulness features (`ClarityMosaicStrip`) MUST adhere to Calm Technology principles: rolling 14-day consistency mosaics celebrating intentionality without stressful streak countdowns, broken-chain guilt, or dopamine traps.

---

## 4. Token & Command Economy (LLM OS Principles)

1. **Consult Developer Map First**: Read [.agent/map.md](file:///Users/saadhjawwadh/Documents/Code/Note%20taking/.agent/map.md) to locate exact files, providers, and schemas before querying or editing.
2. **Targeted Reading**: Use `grep_search` and bounded line slices (`view_file` with `StartLine`/`EndLine`). Never mass-scan the workspace, `build/`, `.dart_tool/`, or lockfiles.
3. **Reactive Wakeup**: Do not poll or loop while waiting for asynchronous commands or background tasks. The system will automatically wake up upon task completion.

---

## 5. Specialized Workspace Skills

Activate deep procedural skills in [.agent/skills/](file:///Users/saadhjawwadh/Documents/Code/Note%20taking/.agent/skills/) for complex workflows:

* **[App-Feature-Expert](file:///.agent/skills/App-Feature-Expert/SKILL.md)**: Domain architecture specialist for Notes (Quill Delta scope guardrails, auto-save), Financial Manager (SMS regex parsing, AI refine, recurring rules), Health Tracker (cycle prediction algorithms), and Settings.
* **[UI-UX-Specialist](file:///.agent/skills/UI-UX-Specialist/SKILL.md)**: M3 Expressive design tokens, spring physics, seamless borderless bars, dynamic hero container alpha tints, and touch accessibility ($48 \times 48\text{dp}$).
* **[Onboarding-Expert](file:///.agent/skills/Onboarding-Expert/SKILL.md)**: Full-screen onboarding wizard (`OnboardingScreen`), live theme previews, modular feature setup, NPU AICore detection, and Settings replayability.
* **[release-management](file:///.agent/skills/release-management/SKILL.md)**: End-to-end release procedures, R8/ProGuard verification, local APK smoke testing, bilingual `PLAY_STORE_NOTES.md` sync, and `./deploy.sh` automation.
* **[Tester](file:///.agent/skills/Tester/SKILL.md)**: Comprehensive QA verification, viewport setups for full-screen widget tests, path provider mocks, SQLCipher & Workmanager isolate validation.
* **[skill-trainer](file:///.agent/skills/skill-trainer/SKILL.md)**: Protocol for extracting session learnings, updating skills, and maintaining the developer map.
* **[Loop-Engineer](file:///.agent/skills/Loop-Engineer/SKILL.md)**: Universal 4-tier autonomous loop engineering harness grounded in Flow Engineering, TDD self-healing, monotonic zero-regression verifiers, live UI/UX research with interactive grilling, and Small-to-Mighty roadmaps.
* **[Product-Design-Engineering](file:///.agent/skills/Product-Design-Engineering/SKILL.md)**: Interaction psychology and design engineering heuristics distilled from Enrico Tartarotti: 7 Levels of Tech Design, 100ms touch disambiguation, kinetic latency masking, intentional friction, direct manipulation, and high-trust choice architecture.
