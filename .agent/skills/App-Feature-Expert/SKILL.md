---
name: App-Feature-Expert
description: Unified specialist for all core app domain modules (Notes & Quill Editor, Financial Manager & SMS Parsing, Health Tracker & Cycle Predictions, Settings & App Lock). Enforces feature-driven architecture, decoupled providers, single-source-of-truth theme tokens, and shared core UI primitives.
---

# Unified App Feature Expert

Specialist skill governing domain modules, feature-driven architecture (`lib/features/`), single-source-of-truth theme tokens (`lib/core/theme/`), reusable core UI primitives (`lib/core/ui/`), and decoupled provider state management.

---

## 1. Modular Architecture & Single Source of Truth

- **Directory Structure**:
  - `lib/features/notes/`: Note model, repository, `NoteEditorProvider`, and editor/list screens.
  - `lib/features/finances/`: Transaction model, `TransactionRepository`, `FinancialManagerProvider`, and financial ledger/analytics screens.
  - `lib/features/health/`: Period log model, `PeriodRepository`, `PeriodTrackerProvider`, and cycle prediction screens.
  - `lib/features/settings/`: `SettingsProvider`, backup services, app lock, and settings screens.
  - `lib/core/theme/`: Single source of truth for design tokens (`AppTheme`, `AppLayout`, `AppSemanticColors`).
  - `lib/core/ui/`: Core shared UI primitives (`AppCard`, `AppBottomSheet`, `AppChip`, `AppDialog`, `ExpressiveSliverAppBar`).
  - `lib/features/`: Feature-driven domains (`notes/`, `finances/`, `health/`, `settings/`, `sync/`).
  - `lib/services/`: Cross-cutting background isolates, Workmanager tasks, notifications, and on-device AI.
- **Strict Invariants**:
  - **Single Source of Truth Theme**: Layout metrics from `AppLayout`, colors from `AppSemanticColors` or `Theme.of(context).colorScheme`. NEVER hardcode padding or colors inside screen widgets.
  - **Shared UI Primitives**: Use `AppCard` for cards, `AppBottomSheet` for modal sheets, `AppChip` for tag/filter pills, `AppDialog` for confirmation prompts, and `ExpressiveSliverAppBar` for borderless M3 surface headers.
  - **Root Provider Registration Invariant**: Always register domain `ChangeNotifierProvider`s (`FinancialManagerProvider`, `NoteProvider`, `P2pSyncProvider`) in `main.dart`'s root `MultiProvider` list so state is globally accessible across screens, push routes, and modal bottom sheets.
  - **Variable Font System**: Always use `GoogleSansFlex` variable font (`GoogleSansFlex-VariableFont_*.ttf`) for font definitions. Avoid adding static font weight binaries (`Bold`, `Medium`, `Regular`) to assets.
  - **Overlay & Modal Provider Safety**: Modal bottom sheets (`AppBottomSheet`) and `PopupMenuButton` items run in separate `OverlayEntry` route contexts. Never wrap `PopupMenuButton.itemBuilder` entries in `Consumer<T>` or rely on route-scoped providers inside popups; use local state variables (e.g., `_trashedCount`) and convert popup sheets to `StatefulWidget`s that read repository singletons (`TransactionRepository.instance`) directly.
  - **Unified Dual-Gesture Sync Pattern**: Sync icons across feature headers (`HomeAppBar` for Notes, `FinancialManagerScreen` for Finances) MUST follow an identical dual-gesture interaction:
    - **Single Tap (`onTap`)**: `HapticFeedback.lightImpact()` + executes fast 24-hour background quick sync.
    - **Long Press (`onLongPress`)**: `HapticFeedback.mediumImpact()` + opens advanced option modal sheet (`P2pSyncScreen` for Notes, `SmsImportSheet` for Finances).
    - **Active State Progress**: Render `CircularProgressIndicator` (strokeWidth: 2) inside `SizedBox(width: 18, height: 18)` while background/foreground sync streams are active.
  - **SQLite WAL Mode & Performance Indexing Invariant**: In `DatabaseHelper.onOpen`, execute `PRAGMA journal_mode = WAL;` and `PRAGMA synchronous = NORMAL;` to allow non-blocking background writes. Create indexes on frequently queried columns (`notes(deletedAt)`, `notes(dateModified)`, `transactions(date)`, `transactions(smsId)`, `transactions(deletedAt)`, `deleted_transaction_sms_ids(smsId)`). PRAGMA queries in `sqflite_sqlcipher` MUST be executed via `db.rawQuery('PRAGMA ...;')` rather than `db.execute('PRAGMA ...;')` to prevent `Queries can be performed using SQLiteDatabase query or rawQuery methods only` runtime exceptions.
  - **SQLite Single-Quote Migration Syntax Invariant**: All `DatabaseHelper._upgradeDB` migration SQL statements MUST use standard single quotes (`''`) for string literals and default values (e.g. `DEFAULT ''`, `NULLIF(col, '')`). Double quotes `""` are parsed by SQLite as column identifiers and will cause `no such column: ""` migration crashes.
  - **WorkManager Periodic Task Registration Invariant**: Periodic background tasks (`BackupService.schedulePeriodicBackup`) MUST default to `ExistingPeriodicWorkPolicy.keep` during app startup and initialization. Do NOT use `ExistingPeriodicWorkPolicy.replace` on startup, as this cancels the active periodic timer and resets the countdown interval on every app launch. Only pass `.replace` when the user actively modifies execution frequency, changes backup destination folders, or triggers an immediate sync.
  - **Mandatory Bitmap Memory Downsampling**: In `main.dart`, set `PaintingBinding.instance.imageCache.maximumSizeBytes = 100MB` and `maximumSize = 100`. All `Image.file`, `Image.network`, and `Image.asset` preview widgets MUST supply `cacheWidth` (e.g. `cacheWidth: 1080` for note body embeds, `cacheWidth: 400` for grid/list cards) and provide an `errorBuilder` fallback container to prevent 12–48MP camera images from allocating 24–48MB RAM buffers per image.
  - **Global Multilingual Architecture & MaterialApp SupportedLocales Invariant**: When expanding language support (e.g., `zh`, `pt`, `es`, `de`, `fr`, `ta`, `en`), `MaterialApp` in `main.dart` MUST register `supportedLocales: AppLocalizations.supportedLocales` rather than a hardcoded list. Hardcoded locale lists cause Flutter's `localeResolutionCallback` to silently drop newly supported languages and fall back to English, breaking reactive in-app language switching.

---

## 2. Notes Engine & Quill Editor (`lib/features/notes/`)

- **Data Schema & Delta JSON**: Notes store lossless Quill Delta JSON. `dateModified` updates ONLY on text content save. Soft-deleted notes auto-purge after 7 days via `clearOldTrash()`.
- **Decoupled State (`NoteEditorProvider`)**: Auto-saving, dirty state tracking, title/content state, tag matching, and category selection are managed by `NoteEditorProvider`.
- **Locked Notes & Reminders**: App lock gate authenticates via `AppLockScreen`. Reminders use `NotificationService.scheduleNoteReminder` (`0x4E000000 | noteId.hashCode`).
- **Share-Into-Notes Pipeline**: Cold-start shares routed via `AppLockScreen.pendingSharedMedia`. Shared images copied to `shared_images/` before embedding.

### ⚠️ Flutter Quill Document & Attribute Scope Guardrails
- **Strict Attribute Scoping**:
  - Apply block attributes (`list: checked`, `list: unchecked`, `header`) strictly to line-ending `\n` characters (length 1).
  - Apply inline attributes (`strikeThrough`, `bold`, `italic`) strictly to text character ranges.
  - NEVER format inline attributes with length `0` or on `\n` line breaks, as this pollutes `Line.style` and causes `Line.retain` / `AttributeScope` crashes during Backspace keypresses.
- **Post-Frame Deferred Mutations**:
  - When extracting or restoring lines inside `document.changes.listen` or UI callbacks, wrap document edits in `WidgetsBinding.instance.addPostFrameCallback((_) { ... })`.
  - Prevents mid-render `RenderEditor` painting exceptions and `Null check operator used on null value` errors.
- **Selection Clamping**:
  - Always clamp `controller.selection` to `(doc.length - 1)` after deleting line nodes so cursor offsets never exceed current document text boundaries (`Range start X is out of text of length Y`).
- **Delta Serialization & Sanitization**:
  - Separate text insertions from newline block insertions when building Deltas for database persistence.
  - Sanitize loaded Deltas before `Document.fromDelta()` with `RichTextUtils.sanitizeDelta(Delta delta)` to split text runs from `\n` boundaries without stripping inline text formatting (`bold`, `italic`, `underline`).
  - Retain block attributes (`'list'`, `'header'`, and `'indent'`) on `\n` line endings while stripping invalid inline formatting from newlines to guarantee multi-level list indents and formatting survive note save and reloads.
- **Normalized Selection Range & Embed Insertions**:
  - Use `_getNormalizedSelectionRange()` (`(min(base, extent), abs(base - extent))`) for embed insertions (tables, images) to prevent negative range exceptions on right-to-left cursor drags.
- **Protected Image Directory**:
  - Images picked in note editor must be copied to `getApplicationDocumentsDirectory() / 'note_images/'` with unique UUID names before embedding to guarantee sandbox isolation and resilience.

### 🖋️ Note Editor & Floating Precision Selection Invariants
* **Symmetrical Split-Axis Flanks**:
  - **Left Flank ($64\text{dp}$ Fixed)**: Horizontal stepper `[ ‹ ] [ › ]` (32dp per icon) with single-tap character nudges, double-tap & long-press word-boundary regex jumps, and `HapticFeedback.selectionClick()`. When `selection.isCollapsed`, update via `TextSelection.collapsed(offset: newOffset)` rather than opening accidental ranges.
  - **Right Flank ($64\text{dp}$ Fixed)**: Vertical stepper `[ ▲ ] [ ▼ ]` (32dp per icon) with line-level vertical navigation.
  - **Scrollable Center**: Center formatting tools (`Headings`, `B`, `I`, `U`, `S`, `Align`, `Indent`, `Quote`, `Code`) wrapped in `Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, ...))`.
  - Bottom toolbar stays permanently clean without mode-swapping glitches: `[Formatting Toggle (Arrow-Down when open)] [AI Assist (gated by isAiActive)] | [Table] [Checklist] [Image] [Hide Keyboard]`.
  - Disambiguate formatting bar dismissal: When the formatting deck is expanded, the toggle button displays `Icons.keyboard_arrow_down_rounded` to collapse formatting, keeping `Icons.keyboard_hide_rounded` strictly dedicated to hiding the soft keyboard.
  - Voice dictation dependencies and permissions are eliminated to keep the app privacy-focused and lightweight.

### 📥 Google Keep & Markdown Migration Standards
* **JSON Structured Schema Handling**:
  - `textContent`: Plain text note body.
  - `annotations`: Bookmark notes with empty `textContent`. Format as rich markdown links (`[Title](url)` and summary description) rather than discarding them as blank notes.
  - `listContent`: Checklist items with `{"text": "...", "isChecked": bool}` converted to Quill Delta checklist block attributes (`list: checked` / `list: unchecked`).
  - `labels`: Extracted as note tags and preserved in `note.tags`.
  - `color`: Mapped to genuine app note color palette (`GREEN`, `BLUE`, `YELLOW`, `RED`, `PURPLE`, etc.).
  - `createdTimestampUsec` / `userEditedTimestampUsec`: 16-digit microsecond timestamps normalized to `DateTime.fromMicrosecondsSinceEpoch()`.
  - `isArchived`: Mapped to `note.isArchived = 1`.
* **Takeout Directory Hierarchy**: Google Takeout ZIP files place note JSON files inside `Takeout/Keep/`. Importers must inspect `baseName != 'takeout.json'` rather than checking `!name.contains('takeout')` to avoid rejecting all Keep notes.
* **Resilient Path Resolution**: Always wrap `getApplicationDocumentsDirectory()` in a try-catch falling back to `Directory.systemTemp` to ensure isolated unit tests and background sync workers run cleanly without plugin channel dependencies.

### 📱 Interactive Android Home Screen Widget Architecture
* **Native Components**:
  - `TodoWidgetProvider` (`android/.../TodoWidgetProvider.kt`): `AppWidgetProvider` subclass managing launcher widget updates, layout inflation (`R.layout.todo_widget_layout`), remote adapter connections, and pending intent dispatch.
  - `TodoWidgetService` (`android/.../TodoWidgetService.kt`): `RemoteViewsService` and `RemoteViewsFactory` providing the collection view adapter for scrollable checklist items (`R.layout.todo_widget_item`) parsed from `flutter.todo_widget_data`.
  - `TodoWidgetActionReceiver` (`android/.../TodoWidgetActionReceiver.kt`): Standalone `BroadcastReceiver` handling `ACTION_TOGGLE_TODO` directly from home screen taps without bringing the app to the foreground. Updates the in-memory JSON payload and issues `appWidgetManager.notifyAppWidgetViewDataChanged`.
* **Flutter-to-Native Bridge (`WidgetHelper`)**:
  - Located at `lib/utils/widget_helper.dart`.
  - Serializes active checklist items from pinned notes to `FlutterSharedPreferences` under key `flutter.todo_widget_data`.
  - Triggers native broadcast intent `android.appwidget.action.APPWIDGET_UPDATE` via `widget_helper.dart` platform channel or Android intent broadcast.
  - On app launch and resume, `NoteProvider.refreshNotes()` calls `WidgetHelper.processPendingWidgetActions()` to synchronously reconcile any toggles made directly from the launcher with persistent note storage.
* **Direct Deep Intent Routing**:
  - Tapping the `+` button in the widget header fires a `PendingIntent` with `ACTION_QUICK_ADD_TODO`.
  - `MainActivity.kt` routes this intent to `AppLockScreen.pendingQuickAddTodo` and pops up `QuickAddTodoSheet`, seamlessly adding tasks with auto-capitalization and saving back to the widget.

### 🧘 Calm Habit Gamification & Restrained Tactility
* **Days of Clarity Strip (`ClarityMosaicStrip`)**:
  - Located at `lib/widgets/clarity_mosaic_strip.dart`.
  - Implements a rolling 14-day activity mosaic directly below the Notes top app bar.
  - Contextual toggle `settings.showClarityMosaic` in Settings and Onboarding Slide 3.
  - **Calm Technology Invariant**: Celebrates daily consistency without streak countdowns, broken-chain guilt, or dopamine-trap gamification. If a user misses a day, the mosaic simply reflects rest without shaming badges.
* **Auto-Collapse / Reorder Completed Checklists**:
  - Located in `lib/utils/quill_checklist_helper.dart`.
  - When `settings.moveCompletedChecklistsToBottom` is enabled, checking an item smoothly animates it to the bottom completed partition.
* **Restrained Tactile Haptics (`AppHaptics`)**:
  - Centralized in `lib/core/services/app_haptics.dart`.
  - Gated globally by `settings.enableHaptics`. Provides `lightImpact()`, `mediumImpact()`, `heavyImpact()`, and `selectionClick()`.

---

## 3. Financial Manager & SMS Ledger (`lib/features/finances/`)

- **Two-Bank Account Architecture (`AccountType.daily` vs `AccountType.savings`)**:
  - `TransactionModel` and database schema (version 20+) support explicit account bucket tagging: `account: AccountType.daily` (`'daily'`, default) and `account: AccountType.savings` (`'savings'`).
  - **Dynamic Hero Card Split**: The top hero card computes `_dailyCashFlow` and `_savingsVaultCashFlow`, rendering dedicated interactive balance badges. Tapping either badge filters the ledger to that account.
  - **Account Filter Row**: Segmented button/filter chips (`[ All Accounts | 💳 Daily Operating | 🏦 Savings Vault ]`) provide instant 0ms ledger filtering.
  - **Auto-Deposit Routing**: `SmsParser` detects fixed deposits, vault deposits, and savings keywords (`'savings'`, `'fixed deposit'`, `'vault'`, `'transferred to savings'`), automatically assigning `account: AccountType.savings`.
- **Recurring Payment Rule Propagation**:
  - `RecurringRuleRepository.findMatchingRule(description, category, isExpense)` links individual transaction records back to their master `RecurringRule`.
  - When editing a recurring transaction in `TransactionEditorScreen`, updates to amount, description, category, and frequency propagate to the parent rule definition to keep all future materialized occurrences accurate.
  - Canceling a recurring payment sets the rule status to canceled without destroying historical transaction records.
- **AI Spending Analysis & CSV Export Protocol**:
  - `FinancialExportService.buildAiAnalysisPrompt()` formats ledger summaries, burn rate metrics, 50/30/20 budget allocations, and merchant drains into a structured LLM prompt tailored for Claude, ChatGPT, Gemini, and NotebookLM.
  - `FinancialExportService.showExportSheet()` presents an M3 bottom sheet offering:
    1. CSV export with pre-loaded AI prompt.
    2. 1-tap clipboard copying of the AI prompt text.
    3. Clean RFC 4180 CSV export with the `Account` column.
- **Streamlined SMS Ingestion Model (Scheduled Daily + Manual + Live Listener)**:
  - Eliminates unsolicited launch and resume polling loops. Ingestion strictly relies on:
    1. Real-time Android broadcast listener (`telephony.listenIncomingSms`) when an SMS arrives.
    2. Scheduled Daily Auto-Sync via WorkManager at user-configured time (e.g. 20:00).
    3. Manual 1-tap quick sync (`[ 🔄 Sync ]`) in Finances header and custom historical imports in `SmsImportSheet`.
- **SMS Auto-Import & Sandbox Pipeline**: Decoupled regex parsing (`SmsParser` + `sms_constants.dart`) and `SmsService`. 5-minute transaction deduplication window. Reversals purge target transaction within 7 days. `SmsParser` allows long merchant descriptions up to 60 characters and recognizes sandbox test identifiers (`'BANK_SMS'`, `'CARD'`, `'ALERTS'`, `'BANK'`) alongside major banks. PII reference cleaners MUST use digit lookaheads (`\b(?=[A-Za-z0-9]*\d)[A-Za-z0-9]{10,}\b`) to avoid truncating legitimate 10+ character English words.
- **Currencies & Multi-Currency Extraction**: Curated currency metadata (`CurrencyInfo` in `AppConstants`) provides authentic symbols and supports custom currency codes. `SmsConstants.buildPreferredAmountRegex(currency)` prioritizes matching against the user's active preferred currency before general currency fallbacks.
- **One-Tap Category Learning**: When editing transactions, wrap category suggestions in a scoped `ListenableBuilder` tied to `_descriptionController` with stopword protection (`_stopwords`) to let users persist clean merchant keywords directly into `CategoryDefinition`.
- **Hardware-Aware AI Gating (`isAiActive`)**: All AI feature triggers across domain screens (`FinancialManagerScreen` overflow menu, `TransactionEditorScreen` description suffix icon, `NoteEditorScreen` floating toolbar) MUST be guarded by `settings.isAiActive` (`_useOnDeviceAi && _isDeviceAiSupported`) rather than `useOnDeviceAi` alone, preventing dead AI buttons on emulators and non-NPU devices.
- **SMS Permission Manifest Parity**: Only request and check permissions declared in `AndroidManifest.xml` (`Permission.sms`). Never query undeclared companion permissions (e.g. `Permission.phone`), as `permission_handler` permanently returns `denied` for undeclared permissions and silently blocks SMS sync.
- **Non-Blocking Chunked Sync & Instant Cancellation**: Background SMS inbox sync processes messages in non-blocking batches of 25-50 messages (yielding to the event loop), checks `_cancelRequested`, and exposes a responsive "Cancel" button on sync progress banners.
- **Financial Trash Bin & Permanent Tombstones**: Soft-deleted transactions (`deletedAt != null`) are excluded from active ledger queries but retained for 30-day auto-purge retention. Permanently purged transactions write their `smsId` to `deleted_transaction_sms_ids`. `TransactionRepository.createSmsTransaction` MUST query `smsExists(smsId)` by default to permanently prevent deleted SMS transactions from being re-imported during bulk scans unless `bypassTombstones: true` is explicitly provided.
- **SMS Bank Parser & Self-Transfer (CEFTS) Ingestion**:
  - Automatically recognizes CEFTS / IB CEFTS transfers (`trf`, `cefts`, `ib cefts`) and personal account matches (`to:\s*saadh`, `saadh com`, `saadh tab`), categorizing them as `TransactionCategory.transfer` with zero expense burn impact.
  - Automatically filters non-financial fuel quota and broadcast notifications (e.g. `Quota used: ... Balance: ...`).
  - Cleans extracted merchant titles by stripping telephone numbers (`\b011\d{7}\b`) and geographic suffixes (`COLOMBO \d+`, `LK`, `SRI LANKA`).
- **Sender Blocklist & Soft-Delete Protocol**: When deleting an SMS-derived transaction, the delete dialog provides a non-intrusive checkbox `[ ] Block future SMS imports for this source` to instantly update `sms_contacts.is_blocked` and clear active filter caches.
- **Smart Recurring Subscriptions & Live Category Auto-Detection**:
  - When typing a description (*"Netflix"*, *"Spotify"*, *"Starlink"*, *"Rent"*), the recurring rule form automatically pre-selects the appropriate category in real-time.
  - Default category selection defaults to `Subscriptions` (for expenses) and `Deposit` (for income).
  - Built-in deduplication prevents creating duplicate rules for the same merchant and frequency.
- **Native Telephony Channel Safety Guardrail**: Wrap `_startTelephonyListening()` and `listenIncomingSms` in safe try-catch blocks and verify `await hasPermission()` BEFORE invoking `telephony.listenIncomingSms()`. Prevents `IllegalStateException: Reply already submitted` crashes on Android when SMS permissions are revoked or denied.
- **AI Title Refinement Pipeline**: `refineSingleTransactionWithAi()` and `performBulkAiRefine()` clean up cryptic bank codes (e.g. `POS/12345/KEELLS`) into clean merchant titles. Reads original SMS body safely via `getOriginalSmsBody()` from native telephony logs.
- **Background Isolate & Workmanager Safety**: `backgroundMessageHandler` and `performDailyTransactionSync` MUST invoke `WidgetsFlutterBinding.ensureInitialized()` at entry to prevent isolate crashes when accessing `SharedPreferences`, `DatabaseHelper`, or platform channels. Task re-scheduling in `performDailyTransactionSync` MUST be wrapped in a `finally` block so daily sync chains never break on execution errors.
- **Service Initialization & Permission Grants**: `SmsService.init()` initializes telephony listening on launch if permission is granted and syncs Workmanager schedules. `requestPermissions()` automatically triggers listening and schedule sync upon grant.
- **Recurring Transactions Materialization**: `RecurringRuleRepository.instance.materializeDueRules()` MUST be invoked at app launch in `main.dart` and inside `FinancialManagerProvider.loadTransactions()`.
- **Tabular Figures & Typography**: All balance strings and financial figures use `Inter` with tabular figures (`fontFeatures: [FontFeature.tabularFigures()]`).
- **Trend Forecasting & Active Month-End Run-Rate**: `SpendingForecastService.calculateMonthlyForecast()` is the canonical source of truth for ongoing projections. On days 1–3, smoothly blend current daily burn with prior 3-month historical daily average to prevent rent/utility bill spikes.
- **Dynamic 3-Slide Visual Intelligence Deck (`MinimalChartDeck`)**:
  - **Dynamic Gating**: Gated on `totalBudget > 0` for 3 slides (Trajectory $\to$ Donut $\to$ Budget Pacing) or 2 slides (Trajectory $\to$ Donut).
  - **Slide Header Density**: Use compact title `'Spending Trend'` (instead of `'Spending Trajectory'`) and keep badges under 15 characters (e.g. `Est ~395.8k`) so deck titles never truncate into ellipsis on narrow screens.
  - **Context-Aware Deep Linking**: Tapping "Details >" inspects active page index and deep-links to sub-tabs (Slide 0/1 $\to$ Breakdown, Slide 2 $\to$ Budgets).
  - **Chart Tooltip 1px Accent Outline**: Floating Canvas chart tooltips (`LineTouchTooltipData`) must specify a 1px primary accent border (`BorderSide(color: colorScheme.primary.withValues(alpha: 0.3), width: 1.0)`) and rounded radius (`AppLayout.radiusM`) to prevent light-mode blending against surface cards.
- **Android App Widget Dynamic Canvas Sparkline**: Render anti-aliased canvas sparklines in `FinanceWidgetProvider.kt` with gradient underfill and glowing forecast dots, fed by `WidgetHelper.dart` via `widget_sparkline_data`.
- **Budgets 3-Way Sub-Navigation & Savings Goals Vault**:
  The Budgets tab hosts a 3-way segmented pill navigation (`[Breakdown] ⇄ [Budgets] ⇄ [Savings]`). To prevent whitespace padding anomalies, `SavingsGoalsCard(isEmbeddedInCard: true)` returns inner content directly without nesting another `AppCard`. The goal creation sheet supplies an expanded 24-color M3 palette (`_colorPalette`) covering all primary color spectrums.
- **Ledger Floating Toolbar & SQLite ID Lookup Invariant**:
  Bulk operations (e.g. `bulkAiRefineSelected()`, `bulkDeleteSelected()`) triggered from `LedgerFloatingToolbar` must resolve transactions by ID directly from storage (`_repository.readTransaction(id)`) rather than assuming in-memory collections are populated, and must notify `FinancialManagerScreen.refreshNotifier` to immediately trigger a UI re-render.

---

## 4. Split Bills & Shared Debts (`lib/features/finances/`)

- **Domain Architecture & Provider**:
  - `SplitBillModel`, `SplitParticipantModel`, and `SplitReceiptDraft` in `lib/features/finances/data/models/split_bill_model.dart`.
  - `SplitBillRepository` manages SQLite persistence across `split_bills`, `split_participants`, and `split_receipt_drafts`.
  - `SplitBillProvider` manages reactive in-memory state, search queries, participant filtering (`all`, `unsettled`, `settled`, `i_owe`, `i_am_owed`), bill mutations, and settlements.
- **Split Mathematics & Payer Attribution**:
  - Supports `SplitType.equal` (auto-distributes among selected participants + user) and `SplitType.customExact` (exact individual amount tracking with discrepancy validation).
  - Handles `PayerType.userPaid` (User paid for all, participants owe user) and `PayerType.friendPaid` (Friend paid for group, user and other friends owe that friend).
- **Ledger Interop & Settle-Up Protocol (`SettleUpSheet`)**:
  - Settling a debt where a friend owes the user creates an `Income` transaction (`AccountType.daily`, category: `Income`, tag: `[Split Settlement]`).
  - Settling a debt where the user owes a friend creates an `Expense` transaction (`AccountType.daily`, category: `Split Settlement`).
  - When a friend paid for a bill, other participants settling with that friend are strictly informational inside the Split tab (toggling `hasPaid` in the split record only) and NEVER create ledger transactions in the user's personal accounts.
  - From the user's perspective, once the user pays their own share, the split is marked as `Settled for You`.
  - All settlements execute with 0ms optimistic UI feedback.
- **Contextual Dynamic FAB & Active Tab Routing**:
  - `FinancialManagerScreen.activeTabNotifier` broadcasts the active tab segment (`'Ledger'`, `'Budgets'`, `'Split Bills'`).
  - The root floating action button in `home_screen.dart` listens to this notifier and dynamically morphs into "New Split Bill" (`Icons.pie_chart_outline_rounded`), routing directly to `SplitBillEditorScreen`.
- **Dual-Mode Ledger Cash Flow Contract**:
  - **User Paid (`PayerType.userPaid`)**: Master expense is recorded in `AccountType.daily` reflecting the full receipt total (matching bank SMS debits).
  - **Friend Paid (`PayerType.friendPaid`)**: Initial bill creation produces NO ledger entry in personal accounts. Personal liability is recorded as an `Expense` ONLY when the user settles their share with the friend via `SettleUpSheet`.
- **Swipe-to-Delete with Undo**:
  - Split bills support swipe-to-delete with `AppDialog.showConfirm` guard and instant floating SnackBar `UNDO`.
- **Multi-Bill Itemized Statements (`SplitShareService.formatPersonPendingStatement`)**:
  - When sharing debt summaries for a contact, generate a comprehensive itemized breakdown detailing each unpaid bill title, date, individual participant share, and cumulative outstanding total.
  - Never truncate statements to just the most recent single bill. Include user payment instructions (e.g. Bank details or UPI) cleanly at the bottom.
- **Settlement Undo Ledger Parity (`unsettleAllForContact`)**:
  - Reversing a settlement must delete the matching ledger transaction in `transactions` (`TransactionRepository.deleteTransaction`) that was created during the initial settle-up.
  - Guarantees that personal operating account balances and ledger entries stay perfectly synchronized with split bill settlement states.
- **100% Offline Receipt OCR (`ReceiptScannerService`)**:
  - On-device text recognition using Google ML Kit.
  - Regex parser extracts grand total (`TOTAL`, `GRAND TOTAL`, `AMOUNT PAID`), subtotal, taxes, and merchant name.
  - Generates pre-filled `SplitReceiptDraft` for 1-tap bill creation without manual typing.
- **WhatsApp Breakdown Sharing (`SplitShareService`)**:
  - Generates formatted personal settlement messages including participant breakdown, total, and user-configured payment details (`Account Number`, `Bank`, `Payee Name`).
  - Launches native WhatsApp deep links (`https://wa.me/?text=...`) or copies to clipboard with haptic feedback.

---

## 5. Health & Period Tracker (`lib/features/health/`)

- **Cycle Predictions & Ovulation**: Rolling average from last 3 to 7 cycles (excluding outliers $<15$ or $>60$ days). Ovulation window estimated 14 days prior to expected start.
- **Notification Rescheduling**: `NotificationService.schedulePeriodNotifications()` MUST be invoked in `PeriodRepository` when period logs are created, updated, or deleted, and in `SettingsProvider.loadSettings()` on app launch if enabled.
- **Semantic Phase Colors**: Resolved at build time via `AppSemanticColors` (`ThemeExtension`).
- **Privacy & Alerts**: Local data only (excluded from unencrypted backup). Discreet notification strings (`"Check the app"`). Privacy mask active until biometric authentication passes.

---

## 5. Settings & App Configuration (`lib/features/settings/`)

- **Settings State (`SettingsProvider`)**: Manages theme mode, dynamic color schemes, currency selection, custom transaction rules, app lock timeouts, and category budgets.
- **Resilient Auto-Backup Storage Contract**: `BackupService.performAutoBackup()` defaults to protected app storage (`getApplicationDocumentsDirectory()`), which Android guarantees is immune to Storage Access Framework (SAF) URI permission revocations across app updates and phone reboots. If custom external folders fail permission verification, the service gracefully falls back to app storage.
- **Hardware-Aware AI Support State**: `checkAiCoreSupport(LocalAiService)` checks Android AICore on launch, setting `_isDeviceAiSupported`. `isAiActive` provides a single source of truth for both hardware capability and user preference.
- **Schedule Sync On Preference Changes**: Setter methods (`setAutoBackupEnabled`, `setAutoBackupFrequency`, `setAutoBackupPath`, `setDailySyncEnabled`) MUST invoke their respective schedule sync helpers (`syncAutoBackupSchedule`, `syncDailySyncSchedule`) to guarantee Workmanager tasks stay in sync with stored preferences.
- **Backup & Restore**: Encryption-guarded backup JSON via `BackupService`. Excludes sensitive biometric settings to prevent override via untrusted files.
- **Real-Time Backup Restore Event Broadcaster**:
  - `BackupService.restoreFromBackupData()` triggers real-time refresh notifications across all domain providers (`NoteProvider`, `FinancialManagerProvider`, `SplitBillProvider`, `PeriodTrackerProvider`), immediately updating the UI without requiring an app restart.

---

## 6. Master P2P Device Sync Engine (`lib/features/sync/`)

- **Bi-Directional Delta Merge Architecture**: Devices execute non-destructive 2-way LWW delta merges (`SyncMergeService.mergeRemoteData()`), merging notes, financial ledgers, period logs, and settings over Wi-Fi without losing local edits.
- **Tombstones vs. Soft-Deletes**:
  - **Permanent Purges**: Handled via `deleted_notes` tombstone table; purged IDs delete matching local notes.
  - **Soft-Deletes (`notes.deletedAt != null`)**: Merged by checking `deletedAt` date with a 5-second clock skew tolerance. Local soft-deleted notes are preserved in Trash and cannot be resurrected unless the remote edit timestamp is strictly *after* the local deletion timestamp.
- **Reactive UI Auto-Refresh Pattern**: Passive HTTP host servers merge payloads in background threads. Domain providers (`NoteProvider`, `FinancialManagerProvider`) MUST subscribe to `P2pSyncService.instance.syncEvents` to automatically re-query SQLite (`refreshNotes()`, `loadTransactions()`) whenever incoming or outgoing sync payloads are merged.
- **Direct REST HTTP Server (Port 8765) + UDP Radio Beacon (Port 8766)**: Direct socket connections bypass cloud servers and BLE daemons entirely, discovering peers and executing transfers in < 10 ms across dynamic DHCP IPs and VPN split-tunneling.
- **Deduplicated Device Cards**: Devices are strictly deduplicated by unique `deviceId`.
- **Stable Identity & Multi-Network Endpoints**: Persist each local device UUID (`P2pSyncService.getDeviceId`) and user-editable device name. A `PairedDevice` represents one immutable peer identity and may retain multiple `DeviceEndpoint`s (for example, home and work Wi-Fi); never deduplicate or replace peers by pair code or IP address. Migrate legacy `ipAddress` records into endpoint lists without deleting user pairings.
- **Pairing Contract**: QR payloads must carry a protocol version, peer `deviceId`, user-visible name, current IP, and port. A scanner must send its own persisted identity in the handshake; persist a new pairing only after the acknowledgement verifies the target, and use the acknowledged device ID for manual pairing to avoid duplicate cards. Preserve a user-renamed peer name when later discovery events arrive.
- **Per-Peer Sync Routing**: Ping, merge, and auto-sync must use the selected peer's pair secret and endpoint port. Try the most recently successful endpoint first, then fall back to the peer's other saved endpoints. Route save-event auto-sync through `P2pSyncProvider`, never through a synthetic record with an empty pair code.
- **Human-Readable Error Translation**: Use `P2pSyncService.formatUserFriendlyErrorMessage()` to translate raw network exceptions (`SocketException`, `TimeoutException`, `HandshakeFailed`) into clear actionable user guidance. Network socket failures and connection timeouts MUST explicitly guide the user: *"Could not connect to peer device. Ensure Note Taking is open and active on the other device and both are connected to the same Wi-Fi or hotspot."*
- **Dynamic Red Error Status Card**: Hero Status Card in `P2pSyncScreen` MUST dynamically render `colorScheme.errorContainer` background tint, `colorScheme.error` border, and `Icons.sync_problem_rounded` icon when `status == SyncStatus.error`.
- **UI Dialog Exception Guard**: Always wrap asynchronous network pairing and sync calls inside UI dialog `onConfirm` callbacks with `try-catch` to prevent unhandled Dart VM exceptions from bubbling up.
- **Android Emulator NAT & ADB Port Forwarding**:
  - Android Emulator internal NAT requires IP `10.0.2.2` (NOT physical router `192.168.1.x`) to reach host loopback.
  - Re-installing APKs via ADB clears port forward rules. Re-establish ADB port forwarding using `~/Library/Android/sdk/platform-tools/adb forward tcp:8765 tcp:8765` and verify via `adb forward --list`.
- **Permission-Lean Guardrail**: No Bluetooth (`BLUETOOTH_*`) or Location permissions required. Retains minimal network permissions (`INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`).
- **QR Scanner Platform Declarations**: Keep `android.permission.CAMERA` and `NSCameraUsageDescription` present for QR pairing while retaining optional camera hardware declarations for Wi-Fi tablets.

---

## 7. Canonical Feature Imports & Architecture Standards

- **No Re-Export Stubs**: Do NOT create or maintain 1-line re-export stub files in `lib/screens/`, `lib/theme/`, or `lib/data/repositories/`.
- **Direct Canonical Imports**: All screens and repositories must be imported directly from their feature module locations (`lib/features/<module>/presentation/screens/` and `lib/features/<module>/data/`).

---

## 8. Changelogs & Release Notes Standards

- **General User Target**: Release notes and changelogs MUST target everyday general users with friendly, non-technical language (avoid developer jargon such as "SQLCipher", "WorkManager", "State Provider", "Delta JSON", "BackdropFilter").
- **3-Category Grouping & Emojis**: Always group entries into 3 explicit categories using expressive emojis:
  - 🌟 **What's New** (New user-facing features)
  - 🚀 **Improvements** (Usability, UI polish, speed enhancements)
  - 🐛 **Fixes** (Bug fixes and stability resolutions)
- **Play Store Parity**: Maintain identical user-friendly structure across `PLAY_STORE_NOTES.md`, `lib/screens/changelog_screen.dart`, and `lib/widgets/whats_new_sheet.dart`.

---

## 9. Widget Testing & Viewport Configurations

- **Full-Screen Widget Test Viewport Configuration**: When writing widget tests for full-screen wizard screens or multi-page `PageView` components, configure mobile view dimensions to prevent offscreen layout clipping and false hit-test warnings:
  ```dart
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  ```
- **Gesture Hit-Test Tolerances**: Pass `warnIfMissed: false` when invoking `tester.tap()` on list tiles or offscreen buttons inside scrollable page views.

---

## 10. Global Typography & Dynamic Text Scaling

- **Global TextScaler Invariant**: `MaterialApp.builder` in `main.dart` wraps top-level app containers in `MediaQuery` with `textScaler: TextScaler.linear(settings.textSize / 16.0)` to enforce user-configured typography scaling globally across all features.
- **No Static Height Clippings**: Component layouts MUST honor dynamic text scaling without hardcoding static container heights that cause text clipping or overflow when scaled up to Large (20dp).

---

## 11. 0ms Optimistic UI & Silent Background Refresh Invariant

- **0ms Immediate In-Memory Mutation**: All interactive state mutations (Delete, Undo, Pin, Archive, Symptom/Flow toggles) MUST immediately mutate active in-memory lists and notify listeners/trigger `setState` synchronously (0ms UI latency). Database writes persist asynchronously in the background.
- **No Spinner Jitter on User Actions**: Refresh routines (`_refreshTransactions`, `refreshNotes`, `_loadTrashed`) MUST support `{bool showLoading = false}` and ONLY show full-page loading indicators on cold launch when the dataset is empty. Never unmount active lists during background sync or user mutations.
- **Soft-Delete Undo Contract**: All deletion undo handlers must invoke `restoreTransaction(id)` (`UPDATE transactions SET deletedAt = NULL WHERE id = ?`) or `restoreNote(id)` rather than attempting record re-insertion (`createTransaction`/`insertNote`), preventing primary key collisions and tombstone re-import blocks.
- **SMS Epoch Normalization**: All SMS ingestion engines must pass message dates through `SmsParser.resolveMessageDate(messageDate)` to normalize 10-digit second and 13-digit millisecond epoch timestamps, strictly preserving genuine historical arrival dates.

---

## 12. Canonical Module Tools (3-Dot Menu), Dedicated Sort Action & Top Header Symmetry

- **Top App Bar Canonical Action Architecture**: Every primary module header pairs a bold module title (`titleLarge` 18pt bold) and interactive Tonal Scope Pill on the left with a muscle-memory action bar on the right:
  - **Action Row Sequence (Left to Right)**:
    - **Notes**: `[ 🔍 Search ]` $\rightarrow$ `[ 🔃 Sort ]` $\rightarrow$ `[ 🔄 P2P Sync (when paired) ]` $\rightarrow$ `[ ⋮ Notes Tools ]` $\rightarrow$ `[ ⚙️ Settings ]`
    - **Finances**: `[ 🔍 Search ]` $\rightarrow$ `[ 🔄 SMS Sync ]` $\rightarrow$ `[ ⋮ Finances Tools ]` $\rightarrow$ `[ ⚙️ Settings ]`
    - **Health Tracker**: `[ 📅 Today ]` $\rightarrow$ `[ ⋮ Health Tools ]` $\rightarrow$ `[ ⚙️ Settings ]`
- **Dedicated Note Sorting Action (`Icons.sort_rounded`)**:
  - High-frequency view changes must NOT be buried in 3-dot overflow menus. A dedicated Sort action button is placed directly in `HomeAppBar`.
  - Tapping opens an M3 popup menu with checkmarks on active sort criteria: *Last Modified*, *Date Created*, *Title*, *Color*.
- **Scope Pill Dynamic Theming Standard**:
  - Scope pills MUST use M3 Tonal Container styling (`colorScheme.primaryContainer.withValues(alpha: isDark ? 0.35 : 0.45)`) with a `1.0px` primary outline border (`colorScheme.primary.withValues(alpha: 0.28)`), `colorScheme.onSurface` label, and `colorScheme.primary` icons and dropdown chevrons for 100% contrast in dynamic themes.
- **Top Bar Transaction Search Integration**:
  - Tapping `[ 🔍 Search ]` transforms the top bar into full-width search mode (`_isSearching`) with back button, real-time debounced query input, and clear button (matching Notes), auto-switches to the `Ledger` tab, and eliminates redundant inline `TextField` search boxes from scroll views.
- **SMS 24-Hour Default Scan Engine & Real-Time Banner**:
  - Quick sync and app-launch catch-up sync MUST default to scanning the **last 24 hours** (`DateTime.now().subtract(const Duration(hours: 24))`) rather than incremental cutoffs, eliminating skipped-message bugs from "fetch only new".
  - A persistent frosted progress banner is rendered directly below the top app bar across all financial tabs (`Ledger`, `Budgets`, `Split Bills`) during sync with a 1-tap `[ Cancel ]` button, followed by exact-count floating SnackBar feedback upon completion.
- **Canonical 3-Dot Overflow Menu Items**:
  - **Notes Tools (`HomeAppBar`)**:
    1. `Switch to list/grid view` (dynamic icon + text reflecting current mode).
    2. `Manage Folders` (`_showFolderPicker`).
    3. `Manage Tags` (`ManageTagsScreen`).
    4. `Trash Bin` (`FilteredNotesScreen(filterType: FilterType.trash)`).
  - **Finances Tools (`FinancialManagerScreen`)**:
    1. `SMS & Bank Automation` (`SmsRulesScreen`).
    2. `Recurring Subscriptions` (`RecurringRulesSheet`).
    3. `Export Ledger` (`FinancialExportService.showExportSheet`).
    4. `Trash Bin` (`FinancialTrashSheet`).
    5. `Settings` (`SettingsScreen`).
  - **Health Tools (`PeriodTrackerScreen`)**:
    1. `Log Cycle & Symptoms` (`PeriodLogEditorSheet`).
    2. `Cycle Phase Guide` (interactive educational dialog `_showPhaseGuideDialog`).
    3. `Cycle Preferences` (`SettingsScreen`).
- **Touch Target & Constraint Guardrails**:
  - All action bar icons in the top bar MUST use `constraints: const BoxConstraints(minWidth: 40, minHeight: 40)` and `visualDensity: VisualDensity.compact` with `padding: EdgeInsets.zero` to eliminate overlapping hitboxes and guarantee uniform inter-button gaps.
  - Outer horizontal padding MUST be strictly `16dp` left and `16dp` right with ZERO inner edge spacers.
  - Headers hosting title + scope pill stacks MUST specify `toolbarHeight: MediaQuery.of(context).padding.top + 72.0` and child container `height: 60.0` (with `top: padding.top + 6.0, bottom: 6.0`) to avoid sub-pixel layout clipping across high-density mobile displays.

---

## 13. Android App Shortcuts & Deep Intent Routing Protocol

- **Static App Shortcuts (`app_shortcuts.xml`)**:
  - `NEW_NOTE`: Deep link `app://open/new_note` $\rightarrow$ launches `NoteEditorScreen` immediately.
  - `ADD_TRANSACTION`: Deep link `app://open/new_transaction` $\rightarrow$ launches `TransactionEditorScreen`.
  - `SCAN_RECEIPT`: Deep link `app://open/scan_receipt` $\rightarrow$ launches `ReceiptScannerSheet`.
  - `SYNC_DEVICES`: Deep link `app://open/sync_devices` $\rightarrow$ launches `P2pSyncScreen`.
- **Dual-Phase Intent Ingestion**:
  - `MainActivity.kt` handles intents in both `onCreate` (cold launch) and `onNewIntent` (warm resume), passing the target URI to Flutter via `pendingWidgetAction` method channel.
  - `HomeScreen._checkAndProcessPendingIntents()` receives the action string, clears native intent state, and pushes the appropriate modal or route.

---

## 14. Notification Diagnostics & Unit Test Isolation Guardrail

- **In-App Test Diagnostic Trigger**:
  - Provide a direct "Test Notifications" action button in `SettingsScreen` (`NotificationService.showInstantTestNotification()`) that delivers a sample notification 3 seconds out, enabling instant validation without scheduling alarms.
- **Unit Test Native Isolation Guardrail**:
  - Native notification platform plugins require initialized engine bindings that are absent in headless unit/widget tests.
  - In `NotificationService`, guard notification dispatch routines with `if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) return;` to completely prevent `LateInitializationError` from aborting unit tests.





