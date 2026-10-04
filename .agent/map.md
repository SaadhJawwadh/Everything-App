# Everything App 📝 — Developer Map & Rules

> [!IMPORTANT]
> **COMPULSORY RULES FOR AGENT EXECUTION:**
> 1. **Map Files First**: Before reading or editing files for any task, refer to the directory and module maps in this `map.md` file to target only the necessary files. Do not scan the entire workspace unless absolutely required. This is critical for token efficiency.
> 2. **Single Source of Truth**: All layout spacing, border radii, animation curves, and component tokens MUST be referenced from `AppLayout` and `AppTheme` (`lib/core/theme/`). Reusable UI primitives live in `lib/core/ui/`.
> 3. **Feature-Driven Architecture**: Code is organized into explicit domain modules under `lib/features/` (`notes`, `finances`, `health`, `settings`), with decoupled providers and repositories.
> 4. **Build and Test**: Once you implement any change, you must run the build and automated test suite (`flutter test` / `flutter analyze`) to verify the implementation.
> 5. **Haptics and Motion**: Maintain smooth haptics and Material 3 micro-animations on all user interactions.
> 6. **No Direct Commits/Pushes**: Always request explicit, real-time user permission before running `git commit` or `git push`.

---

## 🗺️ Architectural Overview & File Map

The application is built using **Flutter (Dart 3)** and follows a **Feature-Driven Repository-Service-Provider** architecture. Data is stored locally in an encrypted SQLCipher database, and state is managed reactively using `package:provider` and feature `ChangeNotifier` providers.

```
lib/
├── core/                             # Core Infrastructure & Shared Design System
│   ├── routes/
│   │   └── app_router.dart           # Centralized route strings and M3 shared-axis transitions
│   ├── theme/
│   │   ├── app_layout.dart           # Single Source of Truth: spacing, padding, radii, motion curves
│   │   └── app_theme.dart            # Single Source of Truth: ColorSchemes & M3 Expressive typography
│   └── ui/                           # Shared Atomic UI Component Library
│       ├── app_bottom_sheet.dart     # Standardized drag-handled modal sheet
│       ├── app_card.dart             # Standardized surface card container
│       ├── app_chip.dart             # Standardized pill/chip widget (tags, categories, phases)
│       ├── app_dialog.dart           # Standardized M3 confirmation & input dialogs
│       ├── app_morphing_fab.dart     # Standardized stadium-to-circle morphing action button
│       ├── expressive_floating_toolbar.dart # Tactile contextual floating action pill toolbar
│       └── expressive_sliver_app_bar.dart # Seamless borderless M3 surface header
├── features/                         # Modular Domain Feature Bundles
│   ├── finances/                     # Financial Manager & Split Bills Feature Module
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   ├── savings_goal_model.dart   # SavingsGoalModel (target, current, monthly breakdown, account routing)
│   │   │   │   └── split_bill_model.dart     # SplitBillModel, SplitParticipantModel, SplitContactModel
│   │   │   ├── repositories/
│   │   │   │   ├── savings_goal_repository.dart# SQLite CRUD, deposits, withdrawals, and completion status
│   │   │   │   └── split_bill_repository.dart# SQLite CRUD, participant syncing, friend contact auto-save
│   │   │   └── transaction_repository.dart   # Transactions, categories, SMS senders CRUD & tombstones
│   │   ├── services/
│   │   │   ├── financial_export_service.dart # RFC 4180 CSV generation & AI analysis prompt export
│   │   │   ├── receipt_scanner_service.dart  # 100% offline ML Kit OCR & on-device AI receipt parsing
│   │   │   ├── spending_forecast_service.dart# Unified active month run-rate forecasting & smoothing
│   │   │   └── split_share_service.dart      # WhatsApp formatted markdown breakdown & reminder dispatches
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── category_management_screen.dart# Custom financial categories controller
│   │   │   │   ├── financial_manager_screen.dart  # Ledger, analytics, split bills tab, bulk AI title refine
│   │   │   │   ├── sms_contacts_screen.dart       # SMS Sender list (block list & custom senders)
│   │   │   │   ├── sms_rules_screen.dart          # Custom SMS pattern definition editor
│   │   │   │   ├── split_bill_editor_screen.dart  # Group bill creator, equal/exact splits, smart tax/tip calculator & mini calc
│   │   │   │   └── transaction_editor_screen.dart # Single transaction editor with inline split button
│   │   │   └── widgets/              # Feature-specific finance UI widgets
│   │   │       ├── account_transfer_sheet.dart    # Dual-account Daily ⇄ Savings inter-vault transfer modal sheet
│   │   │       ├── burn_rate_forecast_card.dart   # Daily Safe-to-Spend burn rate & month-end pacing
│   │   │       ├── category_budgets_card.dart     # Dynamic budget progress card with over-budget alerts
│   │   │       ├── financial_analytics_tab.dart   # Centered interactive donut breakdown & ranked category spend
│   │   │       ├── financial_ledger_tab.dart      # Grouped transactions list, swipe duplicate/delete with undo
│   │   │       ├── financial_trash_sheet.dart     # Trashed transactions manager & bulk purge
│   │   │       ├── minimal_chart_deck.dart        # 3-slide visual intelligence deck (Trajectory, Donut, Budget Pace)
│   │   │       ├── receipt_scanner_sheet.dart     # Camera/Gallery offline OCR receipt scanner modal
│   │   │       ├── recurring_rules_sheet.dart     # Subscriptions & recurring rule manager sheet
│   │   │       ├── savings_goal_deposit_sheet.dart# Target savings allocation & withdrawal modal sheet
│   │   │       ├── savings_goal_editor_sheet.dart # Target goal creator/editor with monthly auto-breakdown
│   │   │       ├── savings_goals_card.dart        # Target savings pockets carousel, progress ring, quick deposit
│   │   │       ├── settle_up_sheet.dart           # Debt settlement sheet with optional Daily Account ledger entry
│   │   │       ├── split_bills_tab.dart           # 3rd Finance tab: Hero summary, People/Bills view, filter chips
│   │   │       ├── teach_sms_rule_sheet.dart      # Interactive SMS rule training modal sheet
│   │   │       └── top_merchants_card.dart        # Top spending destinations & merchant breakdown
│   │   └── providers/
│   │       ├── financial_manager_provider.dart    # Income/expense calculations, filters, state
│   │       ├── savings_goal_provider.dart         # Savings goals reactive state, deposits, auto-rebalance
│   │       └── split_bill_provider.dart           # Split bills state, 0ms optimistic UI, debts & balances
│   ├── health/                       # Health & Period Tracker Feature Module
│   │   ├── data/
│   │   │   └── period_repository.dart# Period logs database operations
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   └── period_tracker_screen.dart# Menstrual calendar & cycle predictions UI
│   │   │   └── widgets/              # Feature-specific health presentation widgets
│   │   │       ├── cycle_insights_card.dart  # Cycle regularity score & duration analytics
│   │   │       ├── cycle_phase_hero_card.dart# Moon phase visualizer & active cycle guidance
│   │   │       ├── period_calendar_card.dart # TableCalendar with semantic phase markers
│   │   │       ├── period_log_dashboard_card.dart# Active period log manager, flow & symptoms
│   │   │       └── period_log_editor_sheet.dart# Modal log editor with overlap validation
│   │   └── providers/
│   │       └── period_tracker_provider.dart# Cycle predictions, stats & symptom state
│   ├── notes/                        # Notes & WYSIWYG Editor Feature Module
│   │   ├── data/
│   │   │   └── note_repository.dart  # Note database CRUD, tagging, trash rotation
│   │   ├── services/
│   │   │   ├── note_expense_embed_service.dart# In-note {{\$amount}} sum calculation & embed chips
│   │   │   ├── note_link_service.dart         # [[Note Title]] bidirectional wiki links & search
│   │   │   └── note_migration_service.dart    # Google Keep JSON & Markdown batch import & parsing
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── filtered_notes_screen.dart # Dedicated viewer for Archive and Trash notes
│   │   │   │   ├── manage_tags_screen.dart    # Tag editor (renaming, deleting)
│   │   │   │   └── note_editor_screen.dart    # WYSIWYG Quill editor, AI actions, toolbar
│   │   │   └── widgets/              # Editor modular presentation widgets
│   │   │       ├── checklist_reorder_sheet.dart# Drag-and-drop checklist task reordering sheet
│   │   │       ├── note_card.dart             # Extracted modular NoteCard list/grid tile
│   │   │       ├── note_color_picker_sheet.dart# Standardized M3 palette seed picker modal
│   │   │       ├── note_editor_bottom_bar.dart# Extracted modular formatting action pill dock
│   │   │       ├── note_migration_sheet.dart  # Google Keep & Markdown file import modal sheet
│   │   │       └── note_search_replace_bar.dart# Keyboard-shortcut aware find/replace toolbar
│   │   └── providers/
│   │       ├── note_editor_provider.dart      # Editor state, dirty tracking, auto-save timer
│   │       └── note_provider.dart             # Colocated core note collection & filter provider
│   ├── settings/                     # App Settings & Preferences Feature Module
│   │   ├── presentation/
│   │   │   └── screens/
│   │   │       ├── onboarding_screen.dart    # Full-screen interactive wizard & setup choices
│   │   │       └── settings_screen.dart      # App options, backup/restore, security controls
│   │   └── providers/
│   │       └── settings_provider.dart        # SharedPreferences state & global app options
│   ├── story_cards/                  # Social Quote & Story Card Studio Module
│   │   ├── models/
│   │   │   ├── story_card_aspect_ratio.dart # Aspect ratios (9:16, 1:1, 4:5) and typography presets
│   │   │   ├── story_card_config.dart       # Live configuration, word limits, title resolution
│   │   │   ├── story_card_layout_mode.dart  # Quote mode vs Article reader mode
│   │   │   └── story_card_theme.dart        # Luxury presets (Editorial, Obsidian Aura, Velvet OLED, etc.)
│   │   ├── services/
│   │   │   ├── story_card_media_service.dart# MediaStore Gallery and Clipboard image saving channels
│   │   │   └── story_card_render_service.dart# High-DPI 3.5x rasterization PNG exporter
│   │   └── presentation/
│   │       └── widgets/
│   │           ├── story_card_preview.dart  # 3-zone publication card layout & canvas
│   │           └── story_card_studio_sheet.dart# Studio customization modal, live preview, export actions
│   └── sync/                         # Master P2P Device Sync Feature Module
│       ├── data/
│       │   └── p2p_pairing_model.dart# Stable peer records and multi-network endpoints
│       ├── presentation/
│       │   ├── screens/
│       │   │   └── p2p_sync_screen.dart# Master P2P control hub, status cards, peer devices
│       │   └── widgets/
│       │       ├── qr_scanner_dialog.dart   # Camera QR code scanner dialog
│       │       └── sync_activity_sheet.dart # Live P2P sync audit activity sheet & endpoint logs
│       └── providers/
│           └── p2p_sync_provider.dart# Stable identity, pairing state, endpoint fallback & sync routing
├── data/                             # Models, Database Helpers & Repositories
│   ├── repositories/
│   │   └── recurring_rule_repository.dart# Subscriptions and recurring expense/income rules
│   ├── category_constants.dart       # Built-in transaction categories and colors
│   ├── category_definition.dart      # Category model (custom names, keywords, colors)
│   ├── database_constants.dart       # Table and column database key names
│   ├── database_helper.dart          # SQLCipher setup, KeyStore/SecureStorage integration
│   ├── database_seed.dart            # Seeds default banks and financial categories
│   ├── note_model.dart               # Note entity model
│   ├── note_templates.dart           # Pre-built markdown note starter templates
│   ├── period_log_model.dart         # Period tracker menstrual entry model
│   ├── recurring_rule_model.dart     # Recurring transaction rule model
│   ├── sms_contact.dart              # SMS contact bank & custom sender rules model
│   ├── transaction_category.dart     # Category matching logic (compound priority)
│   └── transaction_model.dart        # Financial transaction record model
├── providers/                        # Global State Managers
│   └── note_provider.dart            # Note UI state provider (filtering, selection, pagination)
├── services/                         # Business Logic & Platform Integrations
│   ├── backup_service.dart           # AES-256 JSON manual and periodic auto-backups
│   ├── financial_regression_engine.dart# Exponentially-weighted linear regression for trends
│   ├── gemini_nano_service.dart      # Android AI Core & Gemini Nano text refining, tagging
│   ├── local_ai_service.dart         # AI Core interface definitions
│   ├── notification_service.dart     # Local notifications scheduling (reminders & period predictions)
│   ├── offline_ai_fallback_service.dart# Offline heuristic NLP categorizer
│   ├── p2p_sync_service.dart         # Direct REST HTTP/UDP server & peer transport engine
│   ├── period_prediction_service.dart# Rolling menstrual cycle & ovulation estimation
│   ├── sms_constants.dart            # Sri Lankan bank SMS regex & sender mappings
│   ├── sms_parser.dart               # Rules-based SMS debit/credit parser
│   ├── sms_service.dart              # Telephony SMS listener, duplicates, reversals dispatcher
│   ├── sync_crypto_service.dart      # AES-256-GCM payloads encryption & pair key derivation
│   ├── sync_merge_service.dart       # Non-destructive Last-Write-Wins (LWW) bi-directional delta merge engine
│   └── update_rating_service.dart    # Queries GitHub Release API & in-app review prompts
├── utils/                            # App Utilities & Helpers
│   ├── app_constants.dart            # Global Constants & Curated Currencies (CurrencyInfo)
│   ├── app_globals.dart              # Root ScaffoldMessenger key for global SnackBar notifications
│   ├── app_route.dart                # Re-exports lib/core/routes/app_router.dart (AppRoute alias)
│   ├── quill_checklist_helper.dart   # Quill checklist formatting utilities
│   ├── rich_text_utils.dart          # Delta-to-Markdown & Plain Text preview helpers
│   └── widget_helper.dart            # Android widget data updater
├── widgets/                          # Reusable Global UI Widgets
│   ├── editor/
│   │   ├── editor_note_details_sheet.dart# Note info & metadata sheet
│   │   └── editor_table_dialog.dart  # Table insertion configuration dialog
│   ├── home/
│   │   ├── home_app_bar.dart         # Responsive search & custom selection toolbar
│   │   ├── home_tip_card.dart        # Contextual onboarding & feature tips
│   │   ├── note_view_builder.dart    # Grid/List layouts with OpenContainer transitions
│   │   └── universal_search_overlay.dart# Full-screen search overlay
│   ├── bouncing_widget.dart          # Micro-interaction feedback wrapper
│   ├── calculator_dialog.dart        # Financial inline calculations pop-up
│   ├── frosted_glass_sliver_app_bar.dart# Re-exports lib/core/ui/frosted_sliver_app_bar.dart
│   ├── moon_phase_painter.dart       # Canvas moon phase rendering
│   ├── recurring_rules_sheet.dart    # Re-exports feature recurring rules sheet
│   ├── settings_widgets.dart         # Helper UI segments for settings options
│   ├── skeleton_card.dart            # Loading skeleton placeholder cards
│   ├── sms_import_sheet.dart         # Sheet to query & parse SMS inbox history
│   ├── tag_filter_bar.dart           # Multi-tag scrollable selection list
│   └── whats_new_sheet.dart          # M3 multi-card release announcement sheet
└── screens/                          # Top-Level Root Screens
    ├── app_lock_screen.dart          # PIN/Biometric App Lock session supervisor
    ├── changelog_screen.dart         # Chronological release log viewer
    └── home_screen.dart              # Primary multi-tab container & note feed
```

---

## 🛠️ Core Modules & Feature Breakdown

### 1. Notes & WYSIWYG Editor Module (`lib/features/notes/`)
Manages note creation, organization, formatting, auto-saving, and viewing modes.
*   **Key Features**:
    *   **WYSIWYG Editing**: Uses `flutter_quill` for rich-text delta formats.
    *   **Decoupled State**: `NoteEditorProvider` manages dirty state tracking, auto-save timers (2s), and content mutations.
    *   **Lossless Storage**: Stored in SQLite as Delta JSON arrays, falling back to raw Markdown for legacy notes via `RichTextUtils`.
    *   **Smart Preview**: Renders checklist states (☐/☑) and formats up to 6 lines of plain text directly on home note cards.
    *   **Consecutive Checklist Delta Extraction**: `quill_checklist_helper.dart` extracts consecutive checked blocks and truncates trailing empty markers cleanly, preventing ghost empty checkboxes.
    *   **Google Keep & Markdown Migration**: `NoteMigrationService` parses Google Keep Takeout JSON and Markdown archives in batch with `annotations` web bookmark extraction, companion image resolution, tag preservation, and `Takeout/Keep/` path support.
    *   **Trash Auto-Purge**: Deleted notes are soft-deleted and automatically purged after 7 days via `clearOldTrash()`.
*   **Key Files**:
    *   Feature Screen: `lib/features/notes/presentation/screens/note_editor_screen.dart`
    *   State Manager: `lib/features/notes/providers/note_editor_provider.dart`
    *   Database CRUD: `lib/features/notes/data/note_repository.dart`
    *   Migration Service: `lib/features/notes/services/note_migration_service.dart`
    *   Migration UI Sheet: `lib/features/notes/presentation/widgets/note_migration_sheet.dart`
    *   Entity Model: `lib/data/note_model.dart`
    *   Format Conversions: `lib/utils/rich_text_utils.dart`

### 2. Financial Manager Module (`lib/features/finances/`)
A private ledger to track expenses, earnings, and financial habits.
*   **Key Features**:
    *   **Decoupled State**: `FinancialManagerProvider` manages balance calculations, range filters, and transactions reactively.
    *   **Curated & Custom Currencies**: `CurrencyInfo` metadata (`lib/utils/app_constants.dart`) provides authentic currency symbols (`Rs.`, `₹`, `$`, `€`, `£`, `¥`, `د.إ`, `﷼`, `C$`, `A$`, `S$`, `RM`, `NZ$`, `CHF`) and supports custom currency codes.
    *   **SMS Import Rules & Test Sandbox**: Interactive sandbox in `SmsRulesScreen` with clipboard paste and live parsing feedback.
    *   **One-Tap Category Learning**: Contextual suggestion chip in `TransactionEditorScreen` with stopword protection to train custom keywords into `CategoryDefinition`.
    *   **Hardware-Aware AI Gating (`isAiActive`)**: AI refine options and sparkle icons are strictly gated by `settings.isAiActive` (`_useOnDeviceAi && _isDeviceAiSupported`) so devices without Gemini Nano/AICore hardware hide dead controls.
    *   **Tabular Figures & Typography**: All financial ledgers, numbers, and balance cards use `Inter` with tabular figures (`fontFeatures: [FontFeature.tabularFigures()]`).
    *   **Inline Calculator**: Accessible during expense creation inside `CalculatorDialog`.
    *   **Trend Visuals & Regression**: Exponentially-weighted linear regression with Huber-style outlier dampening.
    *   **Double-Level Categorization**: Auto-categorization matches transaction descriptions using keyword rules.
    *   **Contextual Dynamic Action Routing**: `FinancialManagerScreen.activeTabNotifier` synchronizes the active tab with the root FAB to morph into "New Split Bill" when switching to Split Bills.
    *   **Split Bills & Shared Debts**: Full peer-to-peer expense splitting with `SplitBillRepository`, dual-mode ledger routing (master expense recorded when user pays; no personal debit when friend pays), 100% local ML Kit OCR receipt scanning, and swipe-to-delete with undo.
*   **Key Files**:
    *   Main UI: `lib/features/finances/presentation/screens/financial_manager_screen.dart`
    *   Split Bills Tab & Views: `lib/features/finances/presentation/widgets/split_bills_tab.dart`
    *   Split Bill Editor: `lib/features/finances/presentation/screens/split_bill_editor_screen.dart`
    *   Split Bill State & Provider: `lib/features/finances/providers/split_bill_provider.dart`
    *   Rules & Test Sandbox: `lib/features/finances/presentation/screens/sms_rules_screen.dart`
    *   State Manager: `lib/features/finances/providers/financial_manager_provider.dart`
    *   Database CRUD: `lib/features/finances/data/transaction_repository.dart`
    *   Editor Panel: `lib/features/finances/presentation/screens/transaction_editor_screen.dart`
    *   Custom Categories UI: `lib/features/finances/presentation/screens/category_management_screen.dart`

### 3. Health & Period Tracker Module (`lib/features/health/`)
A fully offline, privacy-first menstrual cycle tracker.
*   **Key Features**:
    *   **Prediction Algorithm**: Computes average cycle length based on the last 3 to 7 logs, dynamically filtering out outliers (unrealistic cycles $<15$ days or $>60$ days).
    *   **Ovulation Calculator**: Predicts ovulation dates exactly 14 days prior to the estimated start date of the next period.
    *   **Semantic Phase Colors**: Phase colors resolved at build time via `AppSemanticColors` (`ThemeExtension`).
    *   **Discreet Notifications**: Schedules upcoming cycle alerts locally using customizable discreet text (e.g. `"Check the app"`).
*   **Key Files**:
    *   UI Screen: `lib/features/health/presentation/screens/period_tracker_screen.dart`
    *   Database Operations: `lib/features/health/data/period_repository.dart`
    *   Cycle Predictions Logic: `lib/services/period_prediction_service.dart`
    *   Log Entity: `lib/data/period_log_model.dart`

### 4. Settings & App Preferences Module (`lib/features/settings/`)
Consolidates global app configuration, security timeouts, and data backups.
*   **Key Features**:
    *   **Control Center Hero Cockpit**: Interactive `SettingsHeroCard` with `tune_rounded` console badge, `🛡️ Local Vault` offline badge, and 1-tap interactive action pills (`[ 🔓 Unlocked / 🔒 Protected ]`, `[ ☁️ Manual Backup ]`).
    *   **Domain Themed Sections**: `SettingsSection` applies domain semantic accents (Appearance: Violet, Notes: Amber, Modules: Purple, Finances: Emerald, Health: Rose, Privacy: Indigo, Data: Sky Cyan, About: Slate) with high-contrast subtle container tinting and 1.0px accent borders.
    *   **Resilient App Lock Graceful Fallback**: `AppLockScreen` traps `PlatformException(NotAvailable)` on un-enrolled devices, rendering an informative M3 card and an instant `[ 🔓 Disable App Lock ]` fallback button to prevent soft lockouts.
    *   **Global Provider**: `SettingsProvider` handles dark/light theme modes, dynamic colors, currency preferences, custom rules, and category budgets.
    *   **Backup & Recovery**: Encrypted JSON backups via `BackupService`. Excludes sensitive biometric settings to prevent override via untrusted files.
*   **Key Files**:
    *   UI Screen: `lib/features/settings/presentation/screens/settings_screen.dart`
    *   State Manager: `lib/features/settings/providers/settings_provider.dart`
    *   Dashboard Widgets: `lib/widgets/settings_widgets.dart`
    *   App Lock Supervisor: `lib/screens/app_lock_screen.dart`

### 5. Core Design System & UI Components (`lib/core/`)
*   **Single Source of Truth**: All layout spacing, border radii, animation curves, and colors are defined in `AppLayout` and `AppTheme` (`lib/core/theme/`).
*   **Atomic UI Library**: Reusable UI components in `lib/core/ui/`:
    *   `AppCard`: Standardized card container with single-source-of-truth surface fills and touch feedback.
    *   `AppBottomSheet`: Standardized modal sheet container with drag handle and width constraints.
    *   `AppChip`: Standardized pill/chip widget for tags, categories, phase badges, and filters.
    *   `AppDialog`: Standardized responsive confirmation and input dialogs.
    *   `FrostedGlassSliverAppBar`: Glassmorphic top bar with edge-to-edge blur.

### 6. Master P2P Device Sync (`lib/features/sync/`)
*   **Stable Peer Identity**: `P2pSyncService` persists a UUID per installation. `PairedDevice` records are deduplicated only by that UUID, not by dynamic DHCP IP addresses or pair codes.
*   **Dynamic Wi-Fi Endpoints**: A peer can keep several `DeviceEndpoint` records. The provider migrates legacy single-IP pairing data and tries the most recently successful endpoint before fallbacks.
*   **QR Handshake**: Versioned QR payloads provide the host ID, friendly name, local IP and port; pairing is persisted only after the host acknowledgement succeeds. Device names may be changed after pairing.

---

## 🗄️ Database Schema Map

All tables are defined and created inside `database_helper.dart`.

```mermaid
erDiagram
    notes {
        text id PK
        text title
        text content
        text dateCreated
        text dateModified
        integer color
        integer isPinned
        integer isArchived
        text imagePath
        text category
        text tags
        text previewText
        text deletedAt
    }
    tags {
        text name PK
        integer color
    }
    note_tags {
        text note_id PK, FK
        text tag_name PK, FK
    }
    transactions {
        integer _id PK
        real amount
        text description
        text date
        integer isExpense
        text category
        text account
        text smsId UK
        text deletedAt
    }
    category_definitions {
        text name PK
        integer color
        text keywords
        integer isBuiltIn
        integer iconCodePoint
    }
    sms_contacts {
        text id PK
        text senderIds
        text label
        integer isBuiltIn
        integer isBlocked
    }
    period_logs {
        text id PK
        text startDate
        text endDate
        text intensity
        text notes
        text symptoms
    }
    recurring_rules {
        text id PK
        text description
        real amount
        text category
        integer isExpense
        text frequency
        text nextDue
    }
    deleted_notes {
        text id PK
        text deletedAt
    }
    deleted_transaction_sms_ids {
        text smsId PK
        text deletedAt
    }
    split_bills {
        text id PK
        integer transactionId
        text title
        real totalAmount
        text payerName
        integer isPayerUser
        text splitMode
        text groupTag
        text date
        text notes
        text receiptImagePath
        text status
        text deletedAt
    }
    split_participants {
        text id PK
        text billId FK
        text contactName
        real shareAmount
        integer hasPaid
        text paidAt
    }
    split_contacts {
        text name PK
        text phoneNumber
        integer colorValue
        text lastUsed
    }

    notes ||--o{ note_tags : "has"
    tags ||--o{ note_tags : "groups"
    split_bills ||--o{ split_participants : "has"
```

### Hot-Path Database Composite Indexes
- `idx_transactions_date_account` ON `transactions(date, account)`
- `idx_notes_modified_deleted` ON `notes(modifiedAt, deletedAt)`
- `idx_split_bills_active` ON `split_bills(deletedAt, date)`
- `idx_period_logs_start` ON `period_logs(startDate)`
- `idx_transactions_sms_id` ON `transactions(smsId)`
- `idx_deleted_sms_id` ON `deleted_transaction_sms_ids(smsId)`

---

## 🔄 Core Workflows & Integrations

### SMS Transaction Auto-Import Workflow

```mermaid
sequenceDiagram
    autonumber
    participant Telephony as OS Telephony API
    participant Service as SmsService
    participant Parser as SmsParser
    participant AI as GeminiNanoService
    participant DB as TransactionRepository
    participant UI as State Provider / UI Stream

    Telephony->>Service: Incoming SMS Event
    Note over Service: Reads sender name & body
    Service->>Parser: parseMessage()
    
    alt Regex Matches
        Parser-->>Service: Return TransactionModel
    else Regex Fails & AI Enabled
        Service->>AI: parseSmsTransaction(body)
        AI-->>Service: Return AI Parsed Fields
        Service->>Parser: Build Transaction
    end

    alt Is Transaction Valid?
        Service->>DB: hasCrossSenderDuplicate(amount, date)
        
        alt No Duplicate Found
            Service->>DB: createSmsTransaction(transaction)
            
            alt Is Reversal Sentence?
                Service->>DB: findReversalTarget(amount, date)
                DB-->>Service: Target Found
                Service->>DB: deleteTransaction(Target ID)
                Service->>DB: deleteTransaction(Reversal ID)
            end
            
            Service->>UI: Emit to incomingTransactions Stream
            UI->>UI: Update Ledger Balance UI
        end
    end
```

---

## 🚀 Deployment & CI/CD Pipeline

*   **Version Automation (`deploy.sh`)**:
    *   Run the script: `./deploy.sh 2.22.0`
    *   **Version Code Generation**: Computes numeric build code:
        $$\text{buildNumber} = (\text{major} \times 10000) + (\text{minor} \times 100) + \text{patch}$$
    *   **YAML Updates**: Replaces version in `pubspec.yaml`.
    *   **Automated Tagging**: Commits changes, tags release, and pushes tag to GitHub, triggering CI/CD.
*   **Play Store Assets (`distribution/playstore_assets/`)**:
    *   `00_feature_graphic_banner.jpg`: 1024×500 promotional hero banner.
    *   `01_playstore_notes_editor.jpg`: Notes and Quill editor mockup card.
    *   `02_playstore_sms_ledger_trends.jpg`: Smart SMS Ledger and Spending Trend mockup card.
    *   `03_playstore_donut_breakdown.jpg`: Interactive Donut chart and category budgets mockup card.
    *   `04_playstore_offline_privacy_sync.jpg`: Zero-cloud privacy and P2P Wi-Fi sync mockup card.
*   **Automated Real-World Test Suites**:
    *   `test/note_migration_and_split_sync_test.dart`: Validates Google Keep JSON & Markdown batch import, empty checklist boundary isolation, and Split Bills 2-way ledger synchronization.
    *   `test/top_bar_search_and_sms_24h_sync_test.dart`: Validates Top Bar transaction search mode, 24-hour default SMS scan engine, persistent real-time sync progress banner, and top app bar action symmetry.
    *   `test/split_bill_features_test.dart`: Validates Split Bills mathematics, OCR offline parsing, settle-up sheet, and WhatsApp reminder generators.
    *   `test/period_tracker_phase4_features_test.dart`: Validates period predictions, regularity scoring, symptom toggles, and cycle phase cards.
    *   `test/financial_trash_and_sms_fetch_test.dart`: Validates financial trash bin, tombstone re-import prevention, soft-delete UNDO restoration, and SMS cancel tokens.
    *   `test/features/sms_and_recurring_overhaul_test.dart`: Validates Fuel Pass quota filtering, CEFTS self-transfers, Amana Bank, COMBANK, PickMe Food merchant cleaning, recurring keyword auto-detection, and duplicate prevention.
    *   `test/upgrade_backward_compatibility_test.dart`: Validates database schema migrations, SharedPreferences resiliency, and What's New version card rendering across release cycles.
    *   `test/qol_editor_sms_backup_test.dart`: Validates launcher shortcut intent constants, auto-backup notifications, and SMS parsing stability.

