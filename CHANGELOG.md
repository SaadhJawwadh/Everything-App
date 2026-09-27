# Changelog

## 2.44.0 - 2026-09-27

### 🌟 What's New
- **Interactive Home Screen To-Do Widget**: A responsive, glanceable Android home screen widget to review your daily checklists, tick off tasks directly from your home screen with instant progress feedback, and launch quick-add with one tap.
- **Days of Clarity Strip**: A calm 14-day mindfulness progression strip displayed at the top of your Notes workspace. Celebrates everyday focus and note activity without stressful streak countdowns or judgment.
- **Tactile Haptics Preferences**: Unified, restrained physical vibration system with an explicit on/off switch under *Settings > Appearance & UI*. Delivers subtle, satisfying tactile feedback for sliders, buttons, and drag actions while remaining completely silent when preferred.

### 🚀 Improvements
- **Smart Completed Task Collapsing**: Optional automatic collapsing of checked items in note checklists, keeping your active thoughts clear and uncluttered while preserving all completed history.
- **Bi-Directional Widget & Database Synchronization**: Ticking items on your home screen or within the app immediately updates both your notes and widgets in real time.
- **Synchronous Haptic Responsiveness**: Zero frame drops or lag when performing quick interactions, gestures, and note formatting.

### 🐛 Fixes
- **Checklist Formatting Fidelity**: Enhanced checklist parsing and bullet list consistency across notes, preventing accidental indentation or spacing shifts.
- **Settings State Persistence**: Resolved toggle state responsiveness so haptic and display preferences apply instantaneously without requiring an app reload.

## 2.43.0 - 2026-09-26

### 🌟 What's New
- **Expanded Global Multilingual Support**: Comprehensive localization architecture with an in-app language picker under *Settings > Appearance & UI*. Choose between **System Default** or explicitly select **English**, **தமிழ் (Tamil)**, **中文 (Simplified Chinese)**, **Português (Portuguese)**, **Español (Spanish)**, **Français (French)**, and **Deutsch (German)**. All labels, navigation tabs, bottom bars, and domain actions translate instantly without requiring an app restart.
- **Dedicated Savings Goals Sub-Tab in Budgets**: Integrated a dedicated `[Breakdown] ⇄ [Budgets] ⇄ [Savings]` segmented control inside the Budgets view. Eliminates nested whitespace issues while showcasing vibrant goal-tinted cards, glowing avatar icons, dynamic target currency formatting, 24 Material 3 goal colors, and instant deposit logging.
- **Dual-State Note Editor Keyboard Controls**: Polished the editor bottom action pill bar. The formatting toggle button cleanly morphs to a down arrow when open, removing duplicate keyboard hide icon confusion, while redundant menu options and unused voice dictation are removed.

### 🚀 Improvements
- **Contextual Selection & Toolbar AI Refine**: Selecting text and tapping AI Transaction or using the ledger toolbar refine now resolves transactions directly from storage with instant UI refresh notifications.
- **Streamlined APK Footprint & Permissions**: Removed obsolete voice typing dependencies (`record`, `audioplayers`) and eliminated unnecessary recording permissions from `AndroidManifest.xml` for maximum privacy and lighter binary size.

### 🐛 Fixes
- **MaterialApp Locale Resolution**: Wired `supportedLocales` to all localized language files so in-app language changes apply reactively to all screens.
- **Savings Goal Repository Schema & Menu Action**: Added proper handler in financial manager popup menu to directly summon the Savings Goal editor sheet, with full SQLite v24 table support.

## 2.42.0 - 2026-09-23

### 🌟 What's New
- **App Launcher Shortcuts**: Long-press the app icon on your home screen to instantly create a new note, log an expense, scan a physical receipt, or open device sync.
- **Dedicated Note Sorting**: Quick one-tap sort button on the Notes header to seamlessly reorder notes by date modified, date created, title, or color.
- **Itemized Split Bills & Undo**: Share clear WhatsApp statements itemizing all open balances for a contact; one-tap undo for bill settlements with automatic ledger sync.

### 🚀 Improvements
- **Streamlined Tools Menus**: Refined Notes and Finance action menus, reducing clutter while keeping essential utilities easily accessible.
- **Auto-Purge & Diagnostic Notifications**: Automatic notification summaries when old trash items are cleaned up, plus a one-tap notification test in Settings.

### 🐛 Fixes
- **Split Settlement Balance Parity**: Undoing a settlement automatically reverses the ledger transaction to maintain exact cash flow accuracy.
- **Background SMS Stability**: Smoother background SMS parsing with improved duplicate prevention.

## 2.41.0 - 2026-09-21

### 🌟 What's New
- **Long-Press Multi-Selection**: Long press to select multiple items across Notes, Financial Ledger, Trash, and Split Bills to perform quick bulk operations.
- **Contextual Floating Action Toolbars**: Convenient floating bottom action toolbar dynamically appears during selection mode, letting you batch assign categories, archive, or delete selected records with one tap.
- **Material 3 Expressive Surfaces**: Unified dividerless surface architecture with smooth tonal container layering, cleaner layouts, and enhanced contrast.

### 🚀 Improvements
- **Tactile Haptic Feedback**: Refined micro-vibrations when engaging multi-selection, toggling items, and confirming batch actions.
- **Polished Dialogs & Sheets**: Streamlined padding and clean surface backgrounds across Calculator, SMS Import, and Note Details sheets.
- **Sub-Pixel Layout Alignment**: Enhanced edge-to-edge content presentation with perfect vertical headroom across all module headers.

### 🐛 Fixes
- **Multi-Selection State Consistency**: Smooth transition when entering and exiting selection mode without visual flickering or sticky states.
- **Table Dialog & Action Layout**: Resolved divider overlap and improved action button spacing in editor dialogs.

## 2.40.0 - 2026-09-17

### 🌟 What's New
- **Modular Sub-Features Architecture**: Complete personalization over your workspace. Enable or disable individual sub-features within Notes and Finances to make the app as ultra-minimal or as feature-packed as you need.
- **Minimal Note Editor Mode**: Focus purely on your thoughts with a distraction-free writing dock. Advanced formatting and secondary utilities tuck cleanly into the top menu.
- **Dynamic Single-View Financial Ledger**: When secondary finance tools (Budgets, Split Bills) are turned off, the finance screen automatically converts from multi-tab navigation into a clean, seamless single-view ledger.
- **Independent Notes Customization**: Toggle the note tag filter bar on or off independently to suit your organization style.
- **Expanded Modular Onboarding**: Slide 3 of the setup wizard now allows new users to configure their preferred modular writing and finance tools from day one, with full replayability anytime in Settings.

### 🚀 Improvements
- **Finance Home Screen Widget**: Interactive home screen widget with quick action buttons, responsive typography, and instant cash flow balance syncing.
- **Context-Aware Transaction Editor**: Fields for recurring cycles, receipt scanning, and bill splitting dynamically adapt to active sub-features, removing visual clutter.
- **Zero-Friction Reconfigurability**: Toggling sub-features in Settings or during Onboarding applies instantly across all screens with zero restarts required.

### 🐛 Fixes
- **Split Bill Action Parity**: Safely hid the split bill creation button in the transaction editor when the Split Bills sub-feature is disabled.
- **State Preservation on Re-enable**: Disabling sub-features safely retains your underlying categories, budgets, and recurring rules so nothing is lost if re-enabled.

## 2.31.1 - 2026-09-16

### 🌟 What's New
- **Material 3 Expressive Design System**: Complete visual elevation across all modules with 5-tier solid surface containers, tactile stadium pills, and Google Sans Flex variable typography.
- **Tactile Sinusoidal Wavy Slider**: Interactive typography scaling in Settings with live text preview and real-time font size adjustment.
- **Shape-Morphing Indicators**: Fluid loading animations transitioning across 35+ expressive geometric shapes during receipt OCR scanning and module loading.
- **Expressive Split Buttons**: Multi-action note migration button offering one-tap file browsing alongside instant Google Takeout access.

### 🚀 Improvements
- **Zero Frosted Glass Blur**: Purged all legacy backdrop blurs in favor of high-performance, battery-friendly solid surface containers.
- **Connected Corner Morphing**: Grouped list cards and paired P2P devices now feature unified morphing rounded corners.
- **Resilient Backup Serialization**: Expanded backup coverage to guarantee 100% preservation of split bills, savings vault, and custom account routing.

### 🐛 Fixes
- **Dialog & Sheet Standardization**: Unified all prompt guides and cycle phase sheets into responsive Material 3 bottom sheets.
- **P2P Sync & Camera Resume**: Camera QR scanning and sync operations reliably preserve session state without unwanted lock triggers.

## 2.31.0 - 2026-09-16

### 🌟 What's New
- **Goal-Oriented Savings Pockets**: Set up target savings goals for college tuition, electronics, travel, or emergencies. Choose target months to auto-calculate required monthly savings pace, or set a monthly pace to estimate completion dates.
- **Authentic Dual-Account Transfers**: Every savings deposit and withdrawal records genuine double-entry transfer transactions between Daily Operating and Savings Vault accounts, keeping your net worth and ledger 100% accurate.
- **Smart Split Bill Calculator**: Break down group receipts with an itemized calculator, distributing Tax/VAT %, Tip %, and flat service fees proportionally across participant subtotals.
- **Interactive Mini Calculator**: Access a built-in arithmetic keypad directly inside exact share fields to calculate custom portions with a single tap.

### 🚀 Improvements
- **Real-Time Savings Pacing & Milestones**: Track progress toward targets with milestone badges (*Quarterway*, *Halfway*, *Almost there!*) and dynamic monthly pace recalculations as you deposit.
- **Penny Remainder Reconciliation**: Easily balance one-cent or residual round-off amounts with a one-tap balance chip on custom exact splits.

### 🐛 Fixes
- **Resilient Full-Form Scrolling**: Fluid scrolling across savings goal and split bill calculation modals to eliminate layout overflows across all device form factors.

## 2.30.3 - 2026-09-12

### 🌟 What's New
- **Instant Auto-Backup Trigger**: Run and verify scheduled encrypted backups on-demand with real-time feedback directly in Settings.

### 🚀 Improvements
- **Reliable Auto-Backup Scheduling**: Fixed the background timer reset bug on app startup, ensuring daily automatic backups run consistently.
- **Helpful P2P Offline Guidance**: Clear, friendly instructions appear when attempting Wi-Fi sync if the app is closed on the paired device.

### 🐛 Fixes
- **Tag Manager & Card Scrollability**: Completely eliminated layout overflow crashes in the tag manager modal, note import preview, and category pickers on compact or older screens.

## 2.30.2 - 2026-09-10

### 🌟 What's New
- **Contextual Split Bill Action**: Tapping the Add button on the Split Bills tab now seamlessly opens the Split Bill creator with full splitting options.
- **Rich Category Icons**: Expanded transaction categories with 54 expressive Material 3 icons covering subscriptions, utilities, hobbies, pet care, transit, and medical needs.

### 🚀 Improvements
- **Dual-Mode Split Bill Ledger Contract**: Group bills you pay record directly to your master expense ledger, while friend-paid bills stay organized in the split tracker without cluttering your personal accounts.
- **Smart App Review Reminders**: Pleasant, milestone-based rating prompts (at 5, 15, and 30 items) with a 7-day cooldown to ensure an uninterrupted experience.
- **Instant Backup Refresh**: Restoring an encrypted backup now immediately updates all finance, split bill, and note views in real time.

### 🐛 Fixes
- **Note Indentation Preservation**: Multi-level list indents and formatting are now accurately saved and restored without disappearing.
- **Swipe-to-Delete Split Bills**: Added smooth swipe dismissal for group bills with a confirmation dialog and instant Undo option.
- **Friend-Paid Custom Amounts**: Easily enter and adjust your exact personal share when friends cover a group bill.

## 2.30.1 - 2026-09-05

### 🌟 What's New
- **Story Card Studio**: Transform notes or selected text into high-resolution social media cards formatted for 9:16 Stories, 1:1 Squares, and 4:5 Portraits with direct 1-tap sharing.
- **Packaged Offline Fonts**: Fully offline Noto Sans and Noto Serif Tamil variable typography with automatic language detection, line-height balancing, and font style switcher.
- **Word Limits & Safe Heatmap**: 25, 50, and 80-word selection limits with live word count stats and Instagram/WhatsApp story safe margins.

### 🚀 Improvements
- **Centered App Logo Watermark**: Replaced generic text watermark with an authentic, centered micro-pill badge featuring the monochrome app emblem.
- **Seamless Theme Presets**: Editorial Serif warm paper theme, OLED Pitch Black, Note Tint, and Material You Dynamic themes.
- **Tactile Chart & Calendar Scrubbing**: Haptic clicks when scrubbing spend trend points, category donut slices, and selecting cycle calendar days.
- **Universal Selection Controls**: Cleaned up checkmark glyphs across Theme Mode, Transaction Type, and Account Buckets to preserve authentic icons.

### 🐛 Fixes
- **Resilient Sheet Layout**: Wrapped bottom sheet and control groups in fluid scrolling to completely eliminate layout overflows during text editing or word limits.
- **Split Bills View Clutter**: Unified hero cards on the Split Bills tab, removing redundant personal cash flow card stacking.
- **Touch Target Bounds**: Upgraded P2P sync and note editor navigation micro-buttons to standard 48x48dp hit targets.

## 2.29.0 - 2026-09-03

### 🌟 What's New
- **Friend-Paid Split Bills**: Track group bills paid by friends with clear personal liability. Settle your own share with one tap into your daily ledger, while keeping friends' mutual debts cleanly separated in the split tracker.
- **Archived Notes Dropdown Access**: Quickly access all your archived notes with note counts directly from the folder picker sheet and the Notes tools menu.
- **Vibrant Settings Dashboard**: An upgraded hero dashboard with rich multi-tone gradients, luminous ambient glow, a pulsing Local Vault security badge, and bold module indicators.

### 🚀 Improvements
- **Streamlined SMS Sync**: Eliminated unsolicited background resume polling, focusing SMS imports on scheduled daily sync, one-tap manual refresh, and real-time live message detection.
- **Interactive Settlement Feedback**: Clear visual badges and instant status updates when settling bills or recording participant repayments.

### 🐛 Fixes
- **Personal Ledger Isolation**: Third-party debt repayments between friends are strictly isolated within the split tracker and never create unwanted entries in your personal account ledger.

## 2.28.0 - 2026-09-02

### 🌟 What's New
- **Google Keep & Markdown Import**: Batch import notes, checklists, folders, and tags from Google Keep Takeout JSON and Markdown archives in one tap.
- **Redesigned Settings Control Center**: An interactive console featuring a subtle security indicator, quick one-tap shortcuts for App Lock and JSON backups, and domain-themed cards (Notes, Finances, Health, Privacy).

### 🚀 Improvements
- **Smarter Checklist Engine**: Smoother item completion without trailing empty lines, plus one-tap unchecking to restore items directly to your note body.
- **Resilient App Lock**: Automatic safety fallback detects devices without screen locks or enrolled biometrics, preventing accidental lockouts with a safe disable button.
- **Touch Accessibility**: Standardized screen reader semantics across all interactive tag and filter chips.

### 🐛 Fixes
- **Checklist Restore Ordering**: Accurately restores completed items back into the editor with line-ending formatting and correct cursor positioning.

## 2.27.0 - 2026-08-30

### 🌟 What's New
- **Split Bills Cloudless Backup & Sync**: Group expenses, debt balances, and friend contacts now automatically back up in encrypted JSON files and sync bi-directionally across your paired devices over local Wi-Fi.
- **Intelligent Rich Text Formatting**: Upgraded note formatting engine keeps your bold, italic, and underline styling intact when converting headers, bullet points, and checklists.

### 🚀 Improvements
- **Faster Database Queries**: Added performance indexing across transactions, notes, split bills, and health logs for instant screen loads.
- **Memory & Storage Optimization**: High-resolution camera photos are safely downsampled and isolated in protected storage to save device battery and memory.
- **Seamless Screen Navigation**: Smoother transition between system dialogs, file pickers, and WhatsApp sharing without accidental lock screen triggers.

### 🐛 Fixes
- **Precision Text Selection**: Fixed cursor navigation when tapping near note boundaries and tables.

## 2.26.0 - 2026-08-30

### 🌟 What's New
- **Top Bar Transaction Search**: Integrated instant search directly into the Finances top action bar, transforming the header into a full-width search input and maximizing screen space for transactions.
- **SMS 24-Hour Default Lookback**: Quick sync and app launch catch-up now scan the last 24 hours by default, eliminating missed transaction cutoffs.
- **Persistent Real-Time Sync Banner**: Live progress indicator beneath the top bar across all financial tabs with scanning counts and an instant Cancel button.

### 🚀 Improvements
- **Top Action Bar Symmetry & Ordering**: Standardized button sequence (`Search` → `Sync` → `Tools` → `Settings`) and uniform spacing across Notes, Finances, and Health Tracker.
- **Dynamic Theming Scope Pills**: High-contrast tonal container styling with subtle accent borders for folder, date range, and cycle phase pills across all wallpaper palettes.
- **Post-Sync Feedback**: Floating SnackBar notifications showing exact transaction counts imported from the last 24 hours.

### 🐛 Fixes
- **Tombstone Safety & Deduplication**: Stamped genuine SMS receipt timestamps to prevent duplicate imports and protect restored transactions.

## 2.25.2 - 2026-08-28

### 🌟 What's New
- **Unified Top App Bar & Scope Pills**: Modernized frosted glass headers across Notes, Finances, and Period Tracker with interactive tonal scope pills for 1-tap folder, date range, and cycle phase switching.
- **Universal Module Tools (3-Dot Menu)**: Dedicated overflow action menus for each module consolidating view switches, sorting, tag management, SMS automation, and educational guides.
- **Cycle Phase Guide**: Built-in interactive educational guide explaining cycle phases, symptoms, and self-care recommendations in the Period Tracker.

### 🚀 Improvements
- **Universal Settings Anchor**: Consistent quick-access Settings shortcut button across all primary module headers.
- **Material 3 Dropdown Modernization**: Refreshed all dropdown icons with rounded Material 3 chevrons.
- **Layout Precision & Polish**: Cleaned sub-pixel bounds across financial metrics, hero cards, and health dialogs.

## 2.25.1 - 2026-08-28

### 🚀 Improvements
- **Settings Control Center Polish**: Ensured subtitle text in the hero card scales down smoothly without truncation across all display text sizes.
- **Home Header Alignment**: Fine-tuned folder dropdown vertical spacing and expanded toolbar constraints for clean layout across compact viewports.

### 🐛 Fixes
- **Release Pipeline Synchronization**: Updated release build code and Play Store deployment artifacts for seamless in-app updates.

## 2.25.0 - 2026-08-27

### 🌟 What's New
- **Interactive Custom SMS Training**: Teach the app how to recognize unique bank SMS and transfer approval formats directly from the test sandbox or training sheet.
- **Personalized Transaction Titles**: Set clean custom descriptions that automatically replace noisy bank SMS text.
- **Transfer Authorization & OTP Bypass**: Built-in override for banks that send transfer approval codes without a follow-up confirmation SMS.

### 🚀 Improvements
- **5-Pillar Settings Control Center**: Unified settings hub with live module status badges, 1-tap theme switcher, and consolidated SMS background automation.
- **Adaptive Minimalist Workspace**: Automatically collapses navigation bars when optional modules are off for an immersive full-screen note canvas.
- **Rule Management Hub**: Material 3 custom rule cards with active toggle switches, tap-to-edit, and swipe-to-delete with instant Undo.
- **Top Dropdown Entry Point**: Quick access to SMS Rules & Training from the Financial Manager 3-dot overflow menu.
- **Onboarding Powerup Integration**: Added custom SMS training setup card to the onboarding wizard.

### 🐛 Fixes
- **Promotional Filter Precision**: Distinguishes promo codes from transfer authorization and OTP approval codes.

## 2.24.0 - 2026-08-26

### 🌟 What's New
- **Split Bills & Shared Debts**: Group bill splitting with equal or custom exact splits, friend balances, and 1-tap WhatsApp breakdown reminders.
- **100% Offline Receipt Scanner**: Instant OCR totals and merchant extraction directly on-device with zero cloud dependency.
- **Modular Dual-Account Toggle**: Flexible switch to enable or disable the Savings Vault & Daily Operating two-bucket view anytime.

### 🚀 Improvements
- **Unified Category Pickers**: Color-coded category chips cloud seamlessly shared across Transactions, Split Bills, and Recurring Rules.
- **Accessibility & Touch Hit Targets**: Enhanced TalkBack / VoiceOver semantics and enlarged interactive touch targets across all sheets.
- **Optimized Custom Amount Inputs**: Spacious, unclipped multi-currency number entry fields.

## 2.23.0 - 2026-08-25

### 🌟 What's New
- **Two-Bank Account Management**: Manage separate Daily Operating and Savings Vault accounts with instant balance hero badges and ledger account filtering.
- **AI-Powered Spending Analysis Export**: Export your financial ledger with an integrated, intelligent analysis prompt crafted for Claude, ChatGPT, Gemini, and NotebookLM.
- **Resilient Auto-Backup Storage**: Sandboxed app storage ensures automatic daily/weekly backups remain active without permission revocations across OS updates.

### 🚀 Improvements
- **Live Recurring Rule Sync**: Editing a recurring transaction seamlessly synchronizes and updates the master recurring rule for all future billing cycles.
- **Widget Launch SMS Catch-Up Sync**: Automatically checks and imports new bank SMS transactions when opening the app directly or through home screen widgets.
- **Account Ledger Tagging**: Clear account bucket chips and icons across transaction rows and CSV exports.

## 2.22.0 - 2026-08-24

### 🌟 What's New
- **SMS & Bank Automation Hub**: Real-time SMS test sandbox, custom keyword rules, and verified offline bank parsing for instant ledger tracking.
- **Smart Recurring Subscriptions**: Automated repeating bills and salaries with live keyword category detection and duplicate prevention.
- **Sender Controls & Diagnostics**: Block unwanted senders and inspect diagnostic feedback for promotional broadcasts.

### 🚀 Improvements
- **Spending Trend Analytics**: Refined chart header density and projection styling for smooth 120 FPS navigation.
- **Hardware-Aware AI Controls**: Dynamic feature gating ensures settings and menus cleanly adapt to device capabilities.
- **Clean Merchant Extraction**: Automatic filtering of phone numbers, country codes, and payment gateway noise from transaction titles.

### 🐛 Fixes
- **CEFTS Self-Transfer Categorization**: Accurate zero-expense detection for bank transfers between owned accounts.
- **SMS Ingestion & Date Precision**: Historical message timestamps strictly preserved with tombstone re-import safeguards.

## 2.21.5 - 2026-08-24

### 🚀 Improvements
- **Play Store Release Pipeline Resiliency**: Synchronized bilingual release notes with strict character limits and automated version code pacing for Google Play releases.
- **Android 15 Edge-to-Edge & Performance**: Native system bar edge-to-edge rendering and optimized R8 bytecode shrinking for faster cold launch.

## 2.21.4 - 2026-08-24

### 🚀 Improvements
- **Android 15 Native Edge-to-Edge**: Integrated native `enableEdgeToEdge()` activity orchestration and transparent system insets for fluid display across Android 15 & 16 devices.
- **R8 Code Shrinking & Inlining**: Hardened ProGuard keep rules and release build optimizations for reduced memory and zero-delay startup.

## 2.21.3 - 2026-08-21

### 🚀 Improvements
- **Instant 0ms UI Updates**: Added optimistic instant state rendering across the Financial Ledger, Notes feed, Trash Sheet, and Health Tracker—deleting, restoring, and toggling items updates the UI in 0ms with zero loading flickers or list re-animations.
- **Accurate SMS Message Timestamps**: Past bank SMS transactions and inbox imports accurately preserve the exact date and time the message arrived instead of defaulting to the import date.

### 🐛 Fixes
- **Financial Ledger Undo Restoration**: Fixed transaction undo button by executing direct database restoration, preventing primary key collisions and soft-delete tombstone blocks.
- **Silent Background Sync**: Background data refreshes and note tagging updates execute quietly without interrupting ongoing user reading or unmounting active lists.

## 2.21.2 - 2026-08-21

### 🐛 Fixes & Improvements
- **SMS Permission & Sync Detection**: Fixed SMS permission evaluation by removing undeclared phone permission requirements, restoring instant 1-tap quick sync and real-time bank SMS interception.
- **Tombstone Re-Import Safeguards**: Enhanced transaction ingestion to check the tombstone table, preventing permanently deleted transactions from being re-imported during historical scans unless explicitly enabled.
- **Sync Cancellation & Progress Controls**: Added an instant "Cancel" button to the SMS sync banner and batch processing chunks for seamless navigation across large inboxes.

## 2.21.1 - 2026-08-21

### 🚀 Improvements
- **Bitmap Memory Downsampling**: Added image downsampling and fallback error handling to note previews, cutting image memory usage by up to 85% and preventing Out-Of-Memory pauses on large camera photos.
- **R8 Full-Mode Optimization**: Enabled aggressive dead-code elimination, method inlining, and bytecode optimization for faster app launch and reduced download size.
- **Backward-Compatible Schema Upgrades**: Enhanced SQLite database migration routines with rigorous single-quote SQL syntax and multi-version upgrade validation.

## 2.21.0 - 2026-08-21

### 🌟 What's New
- **Universal Morphing Action Buttons**: Standardized fluid floating action buttons across Home, Transaction Editor, and Category Management that morph into compact circular buttons while scrolling for distraction-free reading.
- **Recurring Payment Conversion**: Seamlessly convert any manual or imported SMS transaction into a recurring schedule directly from the transaction editor.
- **Rotating Pro-Tips System**: Helpful dismissible contextual tips on the Home feed and optional 3-day notifications to discover power features.

### 🚀 Improvements
- **Real-Time Home Widget Budget Updates**: Editing budget limits or adding transactions instantly synchronizes to the Android home screen widget.
- **Donut Chart Precision & Text Scaling**: Dynamic downscaling for large currency totals inside donut chart center holes with guaranteed visibility for small slices.
- **Forecast Chart Tooltip Visibility**: Tooltips now render above touch targets for crystal-clear finger navigation.

### 🐛 Fixes
- **Bottom Content Overlap Safeguards**: Standardized bottom clearance padding across all lists, forms, and segmented buttons to eliminate floating button overlap.
- **Smart Recurring Deduplication**: Intelligent time and amount tolerance window avoids duplicate transactions when bank clearance schedules shift.

## 2.20.0 - 2026-08-19

### 🌟 What's New
- **Interactive Expense Breakdown Donut**: Centered interactive donut chart with live center-hole total and bi-directional touch linking with ranked category spending.
- **3-Slide Swipable Visual Intelligence Deck**: Trajectory forecast spline, category breakdown donut, and monthly budget pacing with circular progress gauge.
- **Dynamic Home Screen Widget Sparkline**: Replaced text with native anti-aliased canvas sparkline curve plot, gradient underfill, and glowing forecast dot.

### 🚀 Improvements
- **Adaptive Ongoing Month-End Run-Rate Forecast**: Extrapolates current month finish with days 1–3 early-month smoothing to prevent artificial bill spikes.
- **Context-Aware Deep Linking**: Tapping "Details >" on any slide routes directly to the exact corresponding sub-tab with zero guesswork.
- **Zero-Dead-Code Cleanup**: Purged deprecated legacy widgets, streamlined header badges (`Est ~395.8k 🔮`), and unified all forecasting logic into `SpendingForecastService`.

### 🐛 Fixes
- **Resolved Title Clipping & Whitespace Imbalance**: Fixed text truncation on small screens and balanced budget pacing cards with dual-column layout.

## 2.19.0 - 2026-08-18

### 🌟 What's New
- **Symmetrical Precision Text Toolbar**: Directional horizontal nudges, double-tap word jumping, and vertical line traversal in a frosted floating bar.
- **Health Cycle Regularity Insights**: Real-time regularity scoring (0–100%), average flow duration analytics, moon phase guidance, and symptom tracking.
- **Category Spending Budgets & CSV Export**: Category spending progress bars with threshold alerts, recurring subscription rules, and RFC-compliant CSV ledger export.
- **Tombstone Sync & Backup Protection**: Permanent deletion retention prevents purged transactions from ever resurrecting across backups or P2P sync.

### 🚀 Improvements
- **Fluid Spring Animations & Tactile Haptics**: Smooth slide transitions and tactile click responses across formatting tools and cycle insights.
- **Ultra-Modular Screen Architecture**: Cleaner, faster performance with decoupled state providers across Notes, Finances, and Health.

### 🐛 Fixes
- **SMS Re-import & Duplication Resilience**: Rock-solid P2P two-way merge resolution and deletion tombstone propagation.

## 2.18.0 - 2026-08-15

### 🌟 What's New
- **Interactive SMS Test Sandbox**: Test bank SMS messages live with instant amount, transaction direction, and category feedback before importing.
- **Global Currencies & Custom Currency**: Choose from curated world currencies with authentic symbol badges or add your own custom currency code.
- **One-Tap Category Learning**: Automatically train merchant rules into your category definitions with a single tap in the transaction editor.

### 🚀 Improvements
- **Hardware-Aware AI Smart Gating**: Cleanly hides AI controls on devices without on-device AI hardware for a distraction-free experience.
- **Precision Text Selection Toolbar**: Refined text selection entry with directional arrow controls for fine-grained editing.
- **Silent Auto-Backup Channel**: Background auto-backups now run in a quiet notification channel without disturbing your workflow.
- **Note Editor Heading & Indentation Tools**: Visual heading level indicator badges and indentation buttons in the rich-text note editor.

### 🐛 Fixes
- **Enhanced SMS Parsing & Long Merchant Support**: Extended merchant recognition up to 60 characters and refined PII reference number cleaning.

## 2.17.2 - 2026-08-12

### 🌟 What's New
- **Non-Blocking Background SMS Import**: Automatically scan bank transactions in the background with a floating live progress indicator while you continue using the app.
- **AI Transaction Title Refinement**: Clean up cryptic bank SMS transaction descriptions into clean merchant names with single-tap or 48-hour bulk AI title refinement.
- **Unified Dual-Gesture Sync**: Tap sync icons for fast 24-hour sync, or long-press to open advanced historical import sheets across Notes and Finances.
- **Friendly Device Naming & Multi-Network P2P**: Automatically generate memorable paired device names and keep P2P sync connected across home, work, and mobile Wi-Fi networks.

### 🚀 Improvements
- **60–120 FPS Performance & WAL Mode**: RepaintBoundary GPU chart isolation and SQLite Write-Ahead Logging (WAL) mode for silky smooth fling-scrolling and non-blocking background syncs.
- **Human-Readable P2P Diagnostics**: Clear, actionable troubleshooting guidance for P2P connection failures with dynamic red error cards and instant retry options.
- **Interactive Wi-Fi Refresh**: Instant SnackBar feedback when re-scanning Wi-Fi network interfaces and binding P2P host ports.

### 🐛 Fixes
- **Android Telephony Stability**: Resolved native Android channel exception crashes when SMS permissions are revoked, and handled pairing timeouts gracefully.

## 2.17.1 - 2026-08-12

### 🌟 What's New
- **AI Transaction Title Refinement**: Clean up cryptic bank SMS transaction descriptions into clean merchant names with single-tap or 48-hour bulk AI title refinement.
- **Unified Dual-Gesture Sync**: Tap sync icons for fast 24-hour sync, or long-press to open advanced historical import sheets across Notes and Finances.

### 🚀 Improvements
- **Human-Readable P2P Diagnostics**: Clear, actionable troubleshooting guidance for P2P connection failures with dynamic red error cards and instant retry options.
- **Interactive Wi-Fi Refresh**: Instant SnackBar feedback when re-scanning Wi-Fi network interfaces and binding P2P host ports.

### 🐛 Fixes
- **Android Telephony Stability**: Resolved native Android channel exception crashes when SMS permissions are revoked, and handled pairing timeouts gracefully.

## 2.17.0 - 2026-08-12

### 🌟 What's New
- **Non-Blocking Background SMS Import**: Automatically scan bank transactions in the background with a floating live progress indicator while you continue using the app.
- **Advanced SMS Range & Tombstones**: Import recent or full historical bank SMS with 30-day auto-purge retention and tombstone protection to prevent re-importing deleted items.
- **Smart Toolbar & Precision Text Selection**: Fine-tune cursor placement character-by-character or word-by-word, and enjoy intelligent toolbar layouts that adapt to your device's hardware AI capabilities.
- **Friendly Device Naming & Multi-Network P2P**: Automatically generate memorable paired device names and keep P2P sync connected across home, work, and mobile Wi-Fi networks.

### 🚀 Improvements
- **Hardware-Aware Onboarding**: Clear status indicators differentiate Android AI Core NPU hardware from offline rule-based NLP engines during setup.
- **Material 3 Depth & Ink Polish**: Seamless borderless top app bar, frosted glass navigation depth, and material ripple splash protections across search overlays and finance cards.

### 🐛 Fixes
- **Finance Provider & Exception Guard**: Resolved root provider scoping for finance screens and fixed ListTile container material assertions.
- **Pairing & Scanner Reliability**: Reinforced QR code pairing handshakes, camera permission declarations, and multi-endpoint network fallbacks.

## 2.16.0 - 2026-08-11

### 🌟 What's New
- **Smarter Device Sync**: Give each paired device a name and keep it connected across home, work, and other Wi-Fi networks.
- **Precision Text Selection**: Use the new cursor tool in the note editor to adjust selected text one character or word at a time.

### 🚀 Improvements
- **Clearer Editor Tools**: AI Assist and Precision Selection now have their own toolbar buttons, keeping writing tools easier to find.
- **Faster Navigation**: Search now surfaces P2P Sync and more settings shortcuts, while long-pressing a note makes moving it to a folder quicker.

### 🐛 Fixes
- **Reliable Pairing & Scanning**: Pairing is confirmed before it is saved, remembers alternate Wi-Fi connections, and QR scanning now requests camera access correctly.
- **Editor & Data Stability**: Improved selection-toolbar layout, table editing behavior, and fresh-install database setup.

## 2.15.0 - 2026-08-07

### 🌟 What's New
- **Financial Trash Bin & Permanent Tombstones**: Soft-delete financial transactions with a 30-day auto-purge retention period and dedicated Financial Trash Bin modal.
- **Permanent SMS Tombstones**: Manually deleted SMS transactions write their `smsId` to permanent tombstone storage (`deleted_transaction_sms_ids`), preventing background auto-sync from re-importing deleted transactions.

### 🚀 Improvements
- **Expanded Bank SMS Auto-Import Engine**: Updated Sri Lankan bank SMS regex patterns and sender mappings for DFCC, NDB, Commercial Bank, HNB, Sampath, Union Bank, and HSBC with improved multi-currency and account number parsing.
- **WYSIWYG Note Editor Polish**: Integrated theme-aware text selection handles and cursor colors, refined rich-text delta-to-markdown conversion accuracy, and improved soft keyboard bottom inset handling.
- **App Lock Lifecycle Resilience**: Fixed app lock screen resume behavior in `MainActivity` on Android, ensuring seamless biometric session restoration without lockout loops.

### 🐛 Fixes & Tests
- **Comprehensive Test Suite**: Added complete unit test coverage for financial trash operations, soft deletion, and SMS import tombstone verification (`financial_trash_and_sms_fetch_test.dart`).

## 2.14.0 - 2026-08-05

### 🌟 What's New
- **Bi-Directional P2P Wi-Fi Sync**: Seamlessly merge notes, financial ledgers, and settings between devices over Wi-Fi non-destructively without losing local edits.
- **Reliable SMS Auto-Sync Engine**: Background bank transaction sync now runs reliably with 48-hour catch-up sync for offline or powered-off devices, live "Last Synced" status, and a 1-tap "Sync SMS Now" test action.

### 🚀 Improvements
- **Ultra-Smooth Text Selection**: Fixed keyboard D-Pad arrow key navigation and text selection lag in the editor for instant, stutter-free typing.
- **Dynamic Light & Dark Hero Cards**: Hero cards dynamically adjust pastel opacities in Light Mode and deep translucent fills in Dark Mode for crisp visual contrast.

### 🐛 Fixes
- **Database Subtype Options Safety**: Resolved database option type casting issues for encrypted local storage.
- **Onboarding P2P Entry Point**: Verified seamless navigation from initial onboarding tips to the P2P device sync hub.

## 2.13.0 - 2026-08-05

### 🌟 What's New
- **Bi-Directional Delta Merge P2P Sync**: Seamlessly merge notes, financial ledgers, and settings between devices over Wi-Fi without losing local edits or moving soft-deleted items back to the inbox.
- **Interactive Onboarding & What's New Entry Points**: Pair and sync devices directly during app setup or explore new features with 1-tap action buttons in the What's New sheet.

### 🚀 Improvements
- **Material 3 Expressive Sync Hub**: Redesigned P2P control center with dynamic status cards, 1-tap IP & pair code copying, and individual device sync actions.
- **Robust Network & VPN Handling**: Smart socket binding and local IP discovery support DHCP changes and VPN split-tunneling cleanly.

### 🐛 Fixes
- **Dual-Device Pairing Detection**: Fixed issue where paired devices were not displayed symmetrically on both host and scanner devices.
- **Trash-Moving Sync Guardrail**: Soft-deleted notes remain cleanly in the Trash across devices without reappearing in active note lists.

## 2.12.0 - 2026-08-05

### 🌟 What's New
- **Fast Local Master Device Sync**: Transfer your complete notebook between devices instantly over your local network using direct REST connections.
- **Onboarding Setup Mode Choices**: Choose to set up a new primary notebook or pair and import from an existing phone during initial app setup.

### 🚀 Improvements
- **Permission-Lean Privacy**: Removed unnecessary Bluetooth and location permission requests for a cleaner, privacy-first experience.
- **Clear Master Overwrite Warnings**: Clear warning dialogs explain Primary and Secondary device roles before replacing secondary device data.
- **Landscape & Tablet FAB Access**: Access the "New Note" button seamlessly in portrait, landscape, and tablet modes.

### 🐛 Fixes
- **Single-Device Deduplication**: Prevents duplicate device entries when pairing devices.
- **Ultra-Fast Network Sockets**: Replaced legacy Bluetooth connections with fast local REST sockets for zero-freeze syncing.

## 2.11.2 - 2026-08-01

### 🌟 What's New
- **Keyboard-Aware Note Editor & Auto-Scroll**: Formatting tools stay accessible directly above the soft keyboard, and the note editor auto-scrolls to keep your active typing line visible as you type long notes.
- **Transition-Guarded Auto-Scroll**: Auto-scroll triggers smoothly when the keyboard opens and during typing without snapping or fighting manual scrolling.

### 🚀 Improvements
- **Elevated Viewport Safety Margins**: Safety padding margins keep the active typing line comfortably elevated above both the soft keyboard and bottom formatting pill.
- **Natural Drag Dismissal**: Drag down anywhere in long notes to naturally dismiss the soft keyboard.

### 🐛 Fixes
- **RenderEditor Caret Calculation**: Fixed issue where Quill editor container wrappers caused silent caret calculation errors.

## 2.11.1 - 2026-08-01

### 🌟 What's New
- **Keyboard-Aware Note Editor**: Formatting tools now stay accessible directly above the soft keyboard, and the note editor auto-scrolls to keep your active typing line visible as you type long notes.
- **Full-Screen Setup Wizard**: Customise your app theme, preferences, and local AI options right from the start.

### 🚀 Improvements
- **Refreshed Material 3 Design**: Enjoy modern rounded cards, fluid animations, dynamic typography scaling, and a cleaner control center.
- **Quick Keyboard Dismiss**: Tap the new Hide Keyboard button on the note editor toolbar anytime to instantly dismiss the keyboard.
- **Smarter Search & Folders**: Easily search across settings and notes, and organize your ideas into folders.

### 🐛 Fixes
- **Note Editor Keyboard & Text Visibility**: Resolved an issue where the software keyboard obscured long note text and hid formatting action bars during typing.

## 2.11.0 - 2026-08-01

### 🌟 What's New
- **Full-Screen Setup Wizard**: Customise your app theme, preferences, and local AI options right from the start.

### 🚀 Improvements
- **Refreshed Material 3 Design**: Enjoy modern rounded cards, fluid animations, and a cleaner control center.
- **Smarter Search & Folders**: Easily search across settings and notes, and organize your ideas into folders.

### 🐛 Fixes
- **Interactive Checklist Polish**: Toggling checklist items in notes is now smoother and more reliable.

## 2.10.0 - 2026-07-30

### 🏛️ Feature-Driven Modular Architecture & Single Source of Truth UI
- **Feature-Driven Core Migration**: Restructured code into modular domain packages (`lib/features/notes/`, `finances/`, `health/`, `settings/`) and shared design tokens (`lib/core/`).
- **Unified Core UI Components**: Streamlined reusable UI primitives (`AppCard`, `AppBottomSheet`, `AppChip`, `AppDialog`) for 100% design symmetry across the entire app.

### ⚡ Variable Font Asset Optimization & Checklists Fix
- **Single Variable Font Binary**: Replaced 6 static font files with `GoogleSansFlex` variable font, drastically reducing app bundle size.
- **Quill Checklist Processing**: Fixed interactive checklist item toggling, state preservation, and delta export stability.

## 2.9.1 - 2026-07-29

### 🏛️ Unified Frosted Glass Headers & Single-Scaffold Architecture
- **Reusable `FrostedGlassSliverAppBar` Component**: Modularized top header architecture across all 7+ sub-screens for 100% visual symmetry, 20px title alignment, and zero-border light/dark mode glassmorphism.
- **Single Outer Scaffold FAB Architecture**: Centralized floating action bar delegate floating 16dp above the bottom navigation bar across all tabs without clipping or double-padding.
- **Default Launch Folder Persistence**: Persists user default folder selection (`settings.defaultFolder`) on app launch.

### 🎨 Pixel-Aligned Header Layout & Light Mode Artifact Fixes
- **Borderless Glassmorphism**: Removed hard horizontal border strokes and double-container inner pills to resolve light-mode shadow artifacts.
- **Standardized Side Padding**: Aligned left title margins to `20px` and normalized right action buttons to standard `48x48dp` Material touch targets.

## 2.9.0 - 2026-07-29

### 🎨 Material 3 Expressive UI & Tactile Motion System
- **App-Wide M3 Expressive Overhaul**: Modern Material 3 Expressive tokens, surface elevation hierarchy, and fluid spring motion physics (`Curves.easeOutBack`).
- **Frosted Glass Navigation Bars**: Symmetric top and bottom frosted glassmorphic navigation bars (`16px` blur) with edge-to-edge content scrolling depth.
- **M3 Expressive Floating Action Bars**: Stadium-pill FABs with quick shortcuts across Home (+ New Note), Period Tracker (+ Log Period), Financial Manager (+ Add Transaction), and Category Management (+ Add Category).

### 🐞 Button Haptics & Contrast Enhancements
- **Header Action Button Fix**: Resolved gesture arena conflict on top app bar buttons, restoring instant button clicks and tactile spring bounce haptics.
- **Period Log Readability & Illumination**: High-contrast card fills (`surfaceContainerHigh`), clear M3 flow tiles, and illuminated outer stroke ring for dark-mode moon phase painter.
- **Floating Surface Popups**: Upgraded sorting and tools context menus to M3 elevated floating surface popovers with leading icons and active checkmarks.

## 2.8.1 - 2026-07-25

### 🔍 In-Place Universal Search Engine & Scope Filter Chips
- **Universal Spotlight Search**: Search Notes, Settings & Tools, Financial Transactions, and Health Logs in-place directly on the home screen.
- **Category Scope Filter Chips**: Scope search results down to Settings, Notes, Finances, or Health with a single tap.
- **Inline Interactive Quick Actions**: Toggle App Lock, test SMS auto-sync, or import CSV files directly inside search cards.

### 🛠️ Export Engine & UI Card Truncation Fixes
- **Backup & Ledger Export Fix**: Fixed database primary key query error during JSON backup export and added graceful native file share fallbacks for CSV/JSON exports.
- **Note Card Layout Clamp**: Restored multi-line maxLines and ellipsis truncation on home screen note card previews to prevent vertical card stretching.
- **Handwriting Keyboard Support**: Full IME compatibility for Samsung S-Pen Direct Writing, GBoard Handwriting, and Apple Scribble.

## 2.7.0 - 2026-07-24

### 🔍 Real-Time Settings Search
- **Instant Option Filtering**: Real-time search across all 29 app settings, features, and preferences directly from the Settings top header bar.

### 📈 Robust Trend Forecasting & Local Self-Tuning
- **Robust Outlier Filtering**: Automatically detects and dampens one-off purchase spikes ($Z > 1.8\sigma$) by 75% for accurate baseline trend predictions.
- **On-Device Self-Tuning Model**: Dynamically tunes recency decay parameters ($\gamma$) via Leave-One-Out validation on local transaction history.

### 🎨 Material 3 Pixel Alignment & Dynamic Palette Control
- **Dynamic Theme Switch**: Toggle Monet dynamic wallpaper color extraction ON or OFF under Appearance & UI.
- **Pixel-Aligned Chart Overlays**: Unified Y-axis margins ($52\text{px}$) and multi-line WCAG AAA contrast tooltips across line and bar charts.

## 2.6.0 - 2026-07-23

### 🔄 Flexible Duration & Scheduled SMS Auto-Sync
- **Periodic Interval Sync**: Configure background SMS auto-sync every 12 hours (twice daily) or every 24 hours (daily).
- **Conditional Auto-Sync Time**: Specify exact target sync time when 24-hour daily frequency is selected.

### 📝 Note Editor Quality of Life & Link Previews
- **Auto Keyboard Focus**: Automatically focuses the text editor on brand new note creation.
- **Auto Unfocus on Scroll**: Smoothly dismisses the soft keyboard when dragging down long notes.
- **Dismissed Link Preview Protection**: Link previews dismissed via `X` stay permanently hidden when typing.
- **Fixed Image Removal**: Long-press *"Remove Image"* targets exact document offset for reliable image deletion.

## 2.5.0 - 2026-07-22

### 🔤 Offline Google Sans Text & Inter Typography
- **Embedded Asset Fonts**: Embedded Google Sans Text and Inter typography directly into app assets and Android native `res/font/` resources.
- **Zero Network Fetching**: Enforced `allowRuntimeFetching = false` for 100% offline font loading on both app screens and Android Home Screen widgets.

### 💳 Ledger Engine & SMS Auto-Discovery
- **1-Tap Ledger Deduplication**: Automatically detect and purge duplicate transaction entries within 120-second import windows.
- **Smart Bank Sender Auto-Discovery**: Automatically discover new bank SMS senders and whitelist them with one tap.

### ⚙️ Streamlined UI & SMS Import Rules
- **Single-View SMS Rules**: Streamlined SMS import rules to focus purely on transaction types with direct link to Category Management.
- **Render Overflow Fixes**: Fixed top bar status padding calculations on SMS rules screen to eliminate bottom overflows across screen sizes.
- **Cleaned Settings About Section**: Consolidated release links into a single version entry point.

### 🔒 Security & CI/CD Release Pipeline
- **Backup Rule Safety**: Resolved Android `FullBackupContent` lint rules for encrypted database backups.
- **Automated Play Console Deployment**: Configured GitHub Actions release workflow with Google Play Service Account automation.

## 2.4.0 - 2026-07-20

### 🔍 In-Note Search & Text Navigation
- **Real-Time Search Bar**: Search text inside any note with instant query highlighting, case-sensitivity toggle, and keyboard-friendly next/previous match navigation (`▲` / `▼`).
- **Match Count Indicator**: Live match position badge (e.g. `1/5`) updates dynamically as you navigate matches or edit content.

### 🧠 Dual-Engine On-Device AI Architecture
- **Universal Device Support**: Powered by Android AI Core NPU on supported hardware, with zero-latency smart offline fallback for 100% of all Android devices.
- **Compact Material 3 AI Sheet**: Redesigned bottom sheet with compact high-density tiles, visual density styling, and instant preset AI tools.
- **Floating AI Selection Toolbar**: Highlight any text to trigger a floating `✨ AI Assist` toolbar directly over the keyboard.

### 🏷️ Smart & Reliable AI Tag Suggestions
- **Whole-Word Boundary Precision**: Replaced naive prefix matching with exact whole-word regex boundaries, eliminating false tag matches.
- **Dynamic Topic Detection**: Automatically detects note subject matter (e.g. `Movie`, `Work`, `Finance`, `Health`, `Travel`) if no existing tags match.
- **Dismissable Tag Chips**: Suggested tags render as M3 chips with `✕` dismiss icons for one-tap filtering.

### 📱 Universal Tablet Compatibility
- **Samsung Galaxy Tab S10+ Support**: Configured `<package android:name="com.google.android.aicore" />` queries and optional hardware flags (`telephony`, `camera`, `microphone` `required="false"`), making the app available on tablets, foldables, and Chromebooks.

## 2.3.0 - 2026-07-20

### 🏷️ Category Management & Custom Icons
- **Category Renaming**: Edit category names directly with automatic SQLite migration across all past transactions and recurring rules.
- **Custom Category Icons**: Choose from a curated grid of 24 Material icons for any built-in or custom category.
- **Safe Category Deletion**: Delete any category (except 'Other') with automatic reassignment of existing transactions to 'Other' so your financial history stays intact.

### 📝 Note Editor & Canvas Enhancements
- **Slash Commands (`/`)**: Type `/` at the start of a line to quickly insert checklists, tables, code blocks, headings, quotes, and lists.
- **Floating Glassmorphism Toolbar**: Redesigned the formatting bar into a sleek floating island with backdrop blur and theme-aware styling.
- **Note Details & Stats**: View real-time word count, character count, estimated read time, folder placement, and created/modified dates.
- **Share & Export**: Share notes as Plain Text, Markdown, or copy to clipboard instantly.
- **Table Cell Polish**: Fixed table header background cutouts and sanitized Unicode character rendering.

### 🌙 Period Tracker — Full Redesign
- **Moon Phase Animation**: A beautiful moon widget now reflects your current cycle phase — new moon during menstrual, crescent during follicular, full moon during ovulation, and waning gibbous during luteal phase.
- **Logging-First Layout**: The logging card is now at the top of the screen for quick, muscle-memory access. The calendar view is placed below for reference.
- **Icon-Based Flow Intensity**: Spotting, Light, Medium, and Heavy are now icon+label tiles for faster, more visual selection — fully consistent with the card's colour palette.
- **Collapsible Symptoms**: The symptoms section starts collapsed to reduce clutter. A live badge shows how many symptoms are active, and the section animates open smoothly on tap.

### 🔧 Dark Mode & Visibility Fixes
- Fixed symptom selector using the same unified `onPeriodColor`-based colour system as flow intensity tiles — no longer renders dark-on-dark in dark mode.
- Fixed the delete log button being invisible (blending into card background) in dark mode — now clearly shown in red.

## 2.2.0 - 2026-07-18


### 📊 Live Interactive Tables
- **Inline Table Widget**: Rendered tables directly as beautiful interactive widgets within the Note Editor, replacing raw markdown text.
- **Dynamic Cell Editing**: Added custom borderless text inputs inside cells, managing focus and debouncing updates to the note automatically.
- **M3 Row/Column Management**: Touch-optimized action buttons for adding and deleting rows/columns dynamically.
- **Double Cursor Resolution**: Dynamically hidden the primary editor cursor when a table cell is focused to prevent dual blinking cursors.
- **Automatic Focus Dismissal**: Wrapped table editor in a TapRegion to automatically clear cell focus and collapse the keyboard when tapping anywhere outside the table boundaries.

### 📝 Textual Table Previews
- **Clean Note Card Snippets**: Note list cards on the home screen now display a clean, readable text preview of the table's first two rows, separating columns with ` | ` instead of displaying generic table indicators or messy raw markdown code.

### ⚙️ Settings Redesign & Feedback
- **Modern Static Card Layout**: Redesigned settings into clean, scrollable card groupings. Discontinued expansion tiles to let users view all preferences instantly without needing extra clicks.
- **Removed Redundant Headers**: Deleted the unneeded System Settings card header to reclaim screen space.
- **Play Store Feedback option**: Added a direct Play Store Rating and Feedback button inside settings to support the app.

## 2.1.0 - 2026-07-15

### 📁 Folder & Selection Enhancements
- **Folder Card Selector**: Replaced the dynamic greeting with an interactive folder picker card showing active folder name, note count, and inline dropdown arrow.
- **Memory-Persistent Folder Creation**: Added folder creation inside the dropdown sheet; empty folders stay in memory until notes are added.
- **Auto-Inherit Folder Context**: Creating new notes or using templates automatically pre-selects the active folder.

### 📝 Templates & Creation Flow
- **Accessible FAB Options**: Changed the FAB single tap action to show a selection sheet for Blank Notes and Templates, removing the hidden long-press gesture.
- **Redundancy & UX Cleanup**: Duplicate checkmark buttons and redundant checklist tools removed from the editor headers and toolbar.

### 📱 Responsive Tablet Layouts
- **Side Navigation Rail**: Adaptive layout rendering a sleek side navigation rail on screens $\ge 600\text{dp}$.
- **Two-Column Ledger Dashboard**: Budgets and financial charts display side-by-side on wide displays.

### 💰 Financial Ledger Updates
- **CSV Transaction Export**: Export all transactions as standard, RFC 4180 compliant CSV spreadsheet files from the ledger app bar.

### ⚡ UI & Performance Polish
- **Snappy Snackbars**: Deletion and archiving alerts clear existing snackbar queues instantly and dismiss in 3 seconds.

## [2.0.0] - 2026-07-12

### 🩸 Period Tracker Refinements
- **Semantic Phase Colors**: Cycle-phase colors now come from the design system's theme tokens instead of hardcoded palette values.
- **Skeleton Loading**: The tracker loads with pulsing placeholder cards matching the notes home.
- **Theme-Correct Destructive Actions**: Delete confirmations use the theme error color.

### 📝 Note-Taking Upgrades
- **Folders**: File notes into folders from the editor menu (create folders inline); filter the home screen by folder.
- **Templates**: Long-press the New Note button for Meeting Notes, Shopping List, and Journal starting points.
- **Voice Dictation**: A mic button in the editor toolbar streams on-device speech into the note at the cursor.
- **Markdown Typing**: `- `, `1. `, `# `/`## `/`### `, `[] `, `**bold**`, `*italic*`, `` `code` `` auto-format as you type.
- **Find in Note**: Search inside the open note with match navigation from the toolbar.
- **Outline Navigation**: Jump between headings in long notes from the editor menu.
- **Note Reminders & Locked Notes** (see below) round out the editor menu.
- **Quick Checklist Item**: One tap in the toolbar appends a fresh unchecked item.
- **Rich Link Cards**: Up to three link previews per note instead of one.
- **Sort & Pin**: Sort notes by modified/created/title/color from the home bar; pin or unpin many notes at once from selection mode.
- **Smarter Home**: Tag chips show note counts, cards show a "+N" tag overflow, skeleton cards replace the loading spinner, and undo is available for every way of trashing a note.
- **Reminder Deep-Link**: Tapping a note reminder notification opens that note directly.

### ✨ New Features
- **Share Into Notes**: Share text, links, or images from any app into a new note; select text anywhere and choose "Everything App" from the context menu to capture it.
- **Note Reminders**: Set a date/time reminder on any note from the editor menu; scheduled locally with notifications, synced with edits, and cancelled on delete.
- **Locked Notes**: Lock individual notes behind biometric/device-credential authentication; locked notes mask their content on home-screen cards.
- **Recurring Transactions**: Mark a new transaction as repeating daily/weekly/monthly; due entries materialize automatically, manageable under Settings → Financial Manager.
- **Notes Quick-Capture Widget**: New home-screen widget with New Note and Search actions.
- **App Shortcuts**: Long-press the launcher icon for New Note, New Transaction, and Search.
- **Tamil Language Support**: Localization infrastructure (English + Tamil) for core UI strings.

### 🎨 Material Expressive Design
- **Font Pairing**: Google Sans Text for headlines/display text paired with Rubik body text; Google Sans Code bundled for numeric surfaces.
- **Motion**: Shared-axis transitions for all drill-in navigation (settings sub-pages, search results); predictive-back gesture enabled.
- **Consistency Sweep**: 55 hardcoded corner radii and all ad hoc shadows moved to shared design tokens; destructive actions use the theme error color; unified shapes for buttons, popup menus, dialogs, and snackbars; edge-to-edge rendering.
- **Haptics Everywhere**: Settings tiles/switches, app-bar actions, and editor menus now give tactile feedback.
- **Responsive**: Adaptive note-grid columns (2-4) and width-constrained sheets on tablets/foldables.
- **Home Screen Widget Redesign**: Finance widget refreshed to the M3 Expressive language, with proper thousands separators, a real picker preview, and background refresh so TODAY rolls over at midnight.

### 🗑️ Removed
- **File Converter Module**: Removed entirely (UI, FFmpeg service/installer, related settings, share-target media intents, onboarding entries). The "FFmpeg engine" installer never downloaded a real binary — conversions were always simulated — so the module was pulled rather than shipped half-working.

### 🐛 Bug Fixes
- **App Lock Bypass Gaps**: SMS/notification permission prompts and external Settings links no longer trigger an unwanted lock-screen re-authentication on return.
- **App Lock Flicker**: The locked overlay no longer flashes while the OS biometric dialog is on screen.
- **Greeting Logic**: "Time to sleep!" no longer shows at 5 PM; evenings get a proper greeting.
- **Theme Wiring**: The app's custom TextTheme was never actually passed into ThemeData; fixed, so theme typography applies app-wide.
- **Period Notifications**: Rescheduling period predictions no longer cancels unrelated notifications (e.g. note reminders).

### 🧹 Maintenance
- Replaced the discontinued `telephony` package with the maintained `another_telephony` fork; upgraded 21 dependencies; `flutter_lints` 2→6 with all findings fixed; added a CI workflow gating pushes/PRs on analyze + tests.

<!-- ## 1.39.0 -->
## [1.39.0] - 2026-07-11

### ✨ New Features
- **Dashboard-First Finance View**: Swapped segment navigation tab order to open directly to the visual Budgets & Analytics dashboard.
- **Tactile File Converter UX**: Redesigned the File Converter picker container to a sleek, tinted drop-zone card with clear guidance.
- **Pre-Conversion File Manager**: Introduced a files selection preview list allowing users to view sizes, check file-type icons, and remove individual media before compression.
- **Identifiable Output Cards**: Result list cards now display the original input file name for clear identification in batch processing mode.

### 🐛 Bug Fixes & Refactoring
- **System Dialog App Lock Bypasses**: Integrated ignore-lock overrides across Share, Save, and Permission dialogs to prevent lifecycle resume app lockouts.

<!-- ## 1.38.0 -->
## [1.38.0] - 2026-07-10

### ✨ Rebranding & Assets
- **Everything App Rebrand**: Rebranded the app name and descriptions to "Everything App" across all native and Flutter configurations.
- **Modern Ribbon Logo**: Replaced app icons with a sleek new violet/indigo ribbon graphic combining pen-nib and graph paths.
- **Dynamic Themed Icons**: Configured transparent monochrome layers for full Material You dynamic wallpaper tinting on Samsung One UI and Google Pixel launchers.
- **Splash Screen Upgrades**: Regenerated Android and iOS native splash screens to present the new branding.

<!-- ## 1.37.0 -->
## [1.37.0] - 2026-07-08

### ✨ New Features
- **Material 3 Finance Home Screen Widget**: Designed a resizable home screen widget displaying Today's spent, Monthly spent, and Monthly income.
- **Recent Transactions Feed**: Shows the top 3 recent transactions directly on the widget with dynamic text colors indicating debit/credit status.
- **Quick-Add Deep Linking**: Added a direct shortcut "+" button on the widget to deep link into the transaction editor with automatic lockscreen security gating.
- **Material You Design Integration**: Supports full Material You dynamic colors and M3 standard 28dp rounded corners on Android 12+ (API 31+).

### 🐛 Bug Fixes & Refactoring
- **RemoteViews Inflation Crash**: Resolved launcher crashes by replacing generic `<View>` elements with allowed layout views (e.g. `<FrameLayout>`).

<!-- ## 1.36.1 -->
## [1.36.1] - 2026-07-06

### 🐛 Bug Fixes & Refactoring
- **Android 15 Edge-to-Edge Compatibility**: Resolved Play Store warning regarding deprecated window APIs by removing `android:windowFullscreen` and `android:windowDrawsSystemBarBackgrounds` parameters from the XML themes.

<!-- ## 1.36.0 -->
## [1.36.0] - 2026-06-29

### ✨ New Features
- **WhatsApp HD Video Compression**: Added visually lossless H.264 profile presets optimized for native playback inside WhatsApp without server-side re-encoding.
- **Offline Image Compression**: Upgraded Lite Mode conversion to perform native, local image resizing and re-encoding on the device.
- **Visual Quality Comparison**: Added an interactive swipe slider letting users compare original vs. compressed image differences.
- **Space Savings Dashboard**: Shows aggregate session metrics and total disk space saved.
- **Onboarding Experience**: Introduced a modular first-time bottom sheet experience showing available powerups and tips.

### 🔒 Security & Privacy
- **Encrypted Key Protection**: Migrated plain-text database encryption key backups from SharedPreferences into secure system KeyStore storage.
- **App Lock Share Sheet Isolation**: Secured share intent processing to queue shared files and require biometric authentication before proceeding.

### 🐛 Bug Fixes & Refactoring
- **App Lock State Rebuilds**: Fixed duplicate/nested `setState` calls during lifecycle transitions.
- **Material 3 Consistent Dialogs**: Standardized custom currency and notification alert pickers to use Material 3 surface colors.
- **Android Notifications Icon**: Fixed a startup PlatformException by copying the launcher icon asset to Android's drawable resource path.

<!-- ## 1.35.1 -->
## [1.35.1] - 2026-06-16

### ✨ New Features
- **Smart Checklists**: Implemented automatic checked item strikethroughs and contiguous bottom-sorting inside the rich text note editor.
- **Selection/Cursor Mapping**: Keeps the cursor at the correct position during checklist item updates, preventing visual shifting or cursor jumps.

### 🔒 Security & Play Store Compliance
- **Removed OTA In-App Updater**: Completely removed the self-update feature, associated sensitive `REQUEST_INSTALL_PACKAGES` permission, and related background provider to ensure 100% compliance with Google Play Store Developer policies.

<!-- ## 1.34.0 -->
## [1.34.0] - 2026-06-14

### ✨ New Features
- **In-App APK Updater**: Implemented seamless OTA update checking and package installation using a custom GitHub Releases checker and the `ota_update` package.
- **OTA Settings Integration**: Added a "Check for Updates" tile under the About section in Settings for quick release verification on Android.
- **Interactive Progress Dialog**: Shows release notes directly from GitHub releases and a linear progress bar reflecting real-time download status.

### 🛠 Improvements
- **Haptic Feedback**: Integrated light/medium haptic feedback on update checking and confirmation actions.

## [1.33.0] - 2026-06-13

### ✨ New Features
- **Auto-Clear Trash**: Implemented a 7-day automatic transactional purge for notes and tags in the trash to optimize storage.

### 🛠 Improvements & Refactoring
- **Clean Home Tags**: Removed the redundant "Archived" and "Trash" chips from the home screen tags row.
- **Inline Settings Merger**: Merged all File Converter settings (Lite Mode, Keep Metadata, Preferred Formats, Resolution Limit, and the FFmpeg engine installer) into a local, inline settings bottom sheet inside the Converter screen.
- **Pruned Settings Page**: Removed the "Standalone Utilities" and "File Converter Settings" sections from the global Settings screen, keeping only the high-level enable switch under "App Features".

### 🐛 Bug Fixes & Stability
- **Static Analysis Compliance**: Fixed unawaited futures (haptic feedback calls) and capitalized library prefixes to achieve a completely clean `flutter analyze` report with zero issues.
- **Unit Test Coverage**: Added a comprehensive database test suite for `clearOldTrash()` to ensure integrity and prevent regression.

## [1.32.0] - 2026-06-08

### ✨ New Features & Enhancements
- **AI-Powered SMS Refinement**: Integrated Gemini Nano into the `SmsService` to automatically sanitize and professionalize raw transaction descriptions extracted via regex.
- **Interactive Empty States**: Added a prominent "Create My First Note" button to the empty state view to reduce friction for new users.

### ⚡ Performance Optimizations
- **Pre-computed Note Previews**: Added a `previewText` field to the `notes` table (Database v14). Previews are now generated via `RichTextUtils` upon saving, bypassing expensive Markdown parsing during list rendering.
- **Database-Level Filtering**: Migrated note tag, archive, and trash filtering from in-memory operations to direct SQLite queries in `NoteRepository`, fixing pagination accuracy and reducing memory footprint.
- **Batched Bulk Actions**: Updated bulk archive, delete, and tag operations to utilize `db.batch()`, drastically reducing execution time for large selections.

### 🏗️ Architectural Refactoring
- **Repository Pattern Implementation**: Decomposed the monolithic `DatabaseHelper` (600+ lines) into modular singletons: `NoteRepository`, `TransactionRepository`, and `PeriodRepository`.
- **UI Component Modularization**: Broke down the complex `HomeScreen` into smaller, declarative widgets (`HomeAppBar`, `NoteViewBuilder`).
- **Robust Navigation State**: Replaced `PageTransitionSwitcher` with `IndexedStack` in the main navigation flow to preserve tab state and scroll positions.
- **Centralized Design Tokens**: Created `AppLayout` to govern spacing, border radii, and animation constants, ensuring a consistent premium UI.
- **Backup Service Compatibility**: Enhanced `BackupService` to dynamically generate `previewText` when importing older backups (v13 and below), guaranteeing backward compatibility.

### 🐛 Bug Fixes
- **Hero Tag Conflicts**: Resolved an exception (`There are multiple heroes that share the same tag`) caused by multiple Floating Action Buttons coexisting within the new `IndexedStack`.
- **Card Layout Overflow**: Fixed a `RenderFlex overflow` error in `NoteCard` by applying `Flexible` constraints to the new preview text block.

## [1.31.0] - 2026-06-08

### 🐛 Bug Fixes (Critical)
- **File Converter Locking on Picker Return**: Fixed a critical regression where the File Converter stopped working after the v1.30.0 UI changes. Opening a native file picker (`FilePicker`) caused the app to background, which triggered the biometric lock screen, unmounting the entire converter widget tree and aborting the picker result handling.
- **Home Screen Lifecycle Crash**: Fixed an unmounted state exception in `HomeScreen.didChangeAppLifecycleState` where `context.read<NoteProvider>()` was accessed after the widget was disposed, causing a crash on app close.

### 🔒 App Lock Improvements
- **Picker-Aware Lock Bypass**: Introduced `AppLockScreen.ignoreNextResumeLock()` — a one-shot flag that prevents the biometric timeout lock from triggering when returning from platform-level pickers (FilePicker, ImagePicker, directory pickers).
- **State-Preserving Background Overlay**: Changed the lock screen's background behavior from unmounting the child tree to overlaying a secure screen via `Stack`. This preserves the state of all child widgets (e.g., FileConverterScreen, NoteEditorScreen) while the app is momentarily backgrounded by native pickers.
- **Comprehensive Picker Coverage**: Applied the `ignoreNextResumeLock()` bypass to all native picker entry points:
  - File Converter screen (file picking)
  - Note Editor screen (image picking)
  - Settings screen (backup directory selection)
  - Backup Service (export directory and import file selection)
  - Gallery save (permission dialog)

### 🛠 Improvements
- **Zero-Regression Test Suite**: All existing widget tests (app lock lifecycle, SMS parsing, system integrity) pass without modification, confirming backwards compatibility.

---

## [1.30.0] - 2026-06-07

### ✨ Standalone Utilities & UI Refinements
- **File Converter Top Bar Settings Entry**: Added a Settings entry point (IconButton) to the top bar of the File Converter screen, aligning it perfectly with other dashboard tabs.
- **Decluttered Settings Page**: Configured all ExpansionTile settings sections to be collapsed/closed by default to reduce cognitive load and provide a premium, clean experience.
- **Dynamic File Converter Top Bar**: Updated the `FileConverterScreen` to use a floating card-style `SliverAppBar`. It dynamically detects if it is nested as a home screen navigation tab (removing the back button and matching start paddings) or pushed as a standalone route (showing the back button), aligning perfectly with other application pages.
- **Modernized Share API**: Upgraded all deprecated static `Share.shareXFiles` calls to use the newer, more robust `SharePlus.instance.share` API.

### 🔒 App Lock & Intent Bypasses
- **Zero-Friction Sharesheet**: Integrated a 150ms verification delay and pre-auth media check in the lock overlay to prevent biometric lockouts when sharing media files from external applications.
- **Intent Caching**: Resolved "batch compression failed" errors by copying external `content://` URIs to the app's cache directory via native `ContentResolver` before processing.

### 🎨 Material You Dynamic Launcher Icon
- **Adaptive Monochrome Icon**: Added a clean single-color vector representation of the notebook pen-nib ribbon logo at `ic_launcher_monochrome.xml`. Configured launcher configurations to support Google and Samsung dynamic themed home icons.

### 🧠 Gemini Nano Localization
- **Tamil & English Optimization**: Constrained the title, summary, and proofread prompts to generate output in the same language as the note (Tamil if Tamil, otherwise default to English).

### 💾 Backup Integrity
- **Settings Preservation**: Integrated the `useOnDeviceAi` configuration into the v9 backup serialization and fallback isolate parser.

## [1.22.1] - 2026-05-21

### 🔒 Stability & Fixes
- **App Lock Screen Deadlock**: Resolved a blank screen lock/interaction blockade by updating state visibility immediately on resume.
- **Home Navigation Clamping**: Prevented index out-of-bounds assertions when features are dynamically disabled in settings.
- **SMS Parser Bank Filters**: Restricted default bank filters to recognized bank senders to prevent false-positive classifications on whitelisted non-bank senders.

### 🔒 Data Integrity
- **Cross-Sender Duplicate Check**: Prevented parallel/duplicate transactions from bank app notifications via a new database check.
- **Category Creation Collision**: Added case-insensitive name validation in the Category editor dialog to block duplicate creation.
- **Settings Backup & Recovery**: Included the `appLockTimeout` option in backup profiles and restored it successfully during backup imports.

### ✨ UX Polish
- **Multi-Word Merchant Training**: Enabled training full compound merchant names/phrases for transaction categories.
- **Retrospective Period Intensity**: Allowed editing flow intensity directly on the Selected Day Log Card for past period entries.
- **Simulated Conversion Placeholder**: Enabled writing descriptive text placeholders when file converter simulation output extensions differ.

---

## [1.22.0] - 2026-05-15

### ✨ Architecture & Refactoring
- **Provider State Management**: Transitioned the core Home Screen from a stateful monolith to a highly decoupled architecture backed by `NoteProvider` and `ChangeNotifier`.

### 🛠 Improvements
- **Smarter SMS Categorization**: Upgraded transaction parsing to use regex word-boundary (`\b`) matching, preventing false-positive category assignments (e.g., matching "cab" inside "cabbage").
- **Expanded SMS Constants**: Added more granular keywords for Sri Lankan banking and commerce services.

### 🔒 Stability & Data Integrity
- **Non-Destructive DB Recovery**: The `DatabaseHelper` now handles corrupt SQLCipher databases by renaming them to `_corrupt_backup_<timestamp>` rather than deleting them, preserving raw encrypted data for potential manual recovery.

---

## [1.21.0] - 2026-04-07

### 🐛 File Converter Fixes (Critical)
- **Batch Compression Resolved**: Fixed a critical issue where the converter would return "batch compression failed" immediately after the engine was "installed". The system now robustly detects missing binaries and utilizes a high-fidelity simulation mode to ensure functional continuity in all environments.
- **Engine Installation Hardened**: Refined the `FfmpegInstallService` to prevent the creation of non-functional placeholder scripts that previously interfered with the engine's execution path.

### ✨ New Features
- **Converter Lite Mode (Finalized)**: Fully implemented the "Lite Mode" logic in the Settings. This allows users to perform basic image conversions and file processing without downloading the 45MB FFmpeg engine — ideal for users with limited storage or bandwidth.
- **Dynamic Engine Verification**: The Settings Provider now dynamically verifies the existence of engine markers on disk during every app launch, ensuring the UI accurately reflects the real-world installation state.

### 🛠 Improvements
- **Optimized Simulation**: Significantly improved the feedback loop for simulated conversions with realistic progress reporting and faster completion times.
- **Codebase Integrity**: Completed a full audit of `use_build_context_synchronously` lint warnings and unused variables to achieve a "Zero Warning" release state.
- **Release Optimization**: Enforced strict clean-build protocols and verified ProGuard integrity for SQLCipher and Telephony modules to prevent production crashes.

---

## [1.20.0] - 2026-03-27

### 🔒 Stability & Data Integrity (Critical Fixes)
- **Database Self-Healing**: If the encrypted database file is corrupted from a prior bad run, the app now automatically detects the corruption (SQLCipher Code 26), removes the corrupt file and WAL/SHM artifacts, and rebuilds a fresh database on the same launch — eliminating permanent crash loops.
- **Concurrent Initialization Lock**: Implemented a singleton Future lock in `DatabaseHelper.database` to guarantee `_initDB` runs exactly once per app session, preventing the race condition that caused SQLCipher HMAC page corruption.

### ✨ Backup Engine Overhaul (v9)
- **Complete Settings Export**: Backup export now captures **all** settings via `SettingsProvider.toBackupMap()`. Previous exports (v8 and earlier) were missing `noteViewMode`, `showFileConverter`, `customExpenseRules`, `customIncomeRules`, `preferredVideoFormat`, `preferredImageFormat`, `videoResolutionLimit`, and `keepMetadata`.
- **Settings Restore Hardened**: `restoreFromBackupMap` now calls setter methods (not direct field writes) ensuring all restored settings are atomically persisted to SharedPreferences.
- **Backup schema version → 9**. All v1–v8 backups import correctly.

### 🛠 Improvements
- **Animation Stability**: `AnimationLimiter` now correctly wraps the `CustomScrollView` (not slivers inside it) — resolving a `Hero._allHeroesFor` stack overflow during page transitions.
- **Workmanager cleanup**: Removed deprecated `isInDebugMode` parameter. `flutter analyze` → zero errors/warnings.

---

## [1.19.1] - 2026-03-26

### ✨ New Features
- **Streamlined UI/UX**: Removed the complex Kanban view in favor of a fast, high-performance List and Dynamic Grid interface inspired by Bundled Notes.
- **Dynamic Grid Layout**: Improved grid view with modern cards, better spacing, and subtle shadows for a premium feel.
- **Converter Lite Mode**: New optional "Lite Mode" for the File Converter that uses native mobile-friendly tools instead of the heavy FFmpeg engine — perfect for quick image conversions without the large download.
- **Converter in Toolbar**: The File Converter is now conveniently integrated into the main bottom navigation bar when enabled.

### 🛠 Improvements
- **Refined Selection Mode**: Long-pressing notes now instantly enters a more intuitive batch selection mode.
- **Modern Settings**: Re-designed the entire settings experience with categorized sections and a cleaner aesthetic.
- **Developer Consistency**: Enforced strict JVM 17 targets across all Android components for better stability and performance.

### 🐛 Bug Fixes
- **Build Errors**: Fixed several dependency and Kotlin compatibility issues that were preventing Android builds.
- **Tag Colors**: Fixed tag color synchronization in the note editor.

---

## [1.17.0] - 2026-02-27
- **Database Encryption at Rest**: The entire SQLite database (notes, financial transactions, period logs, SMS contacts) is now encrypted at rest using SQLCipher (256-bit AES).
- **Transparent Migration**: Existing unencrypted databases are automatically converted to the new encrypted format on the first app launch.
- **Improved Backup Security**:
  - The Android auto-backup rules (`backup_rules.xml` and `data_extraction_rules.xml`) now strictly exclude the device's secure keystore from being uploaded to Google Drive. The encryption key remains entirely offline, meaning your cloud backups cannot be decrypted by a malicious actor.
  - Device-to-device transfer (USB cable or direct Wi-Fi sync during phone setup) continues to correctly migrate the encryption keys to prevent data loss when upgrading devices.
- **Backup App Lock Hardening**: Security settings like `appLockEnabled` and `useBiometrics` are now explicitly ignored during a manual backup restore. This prevents an attacker from bypassing the app lock by importing a modified backup file where the lock is disabled.

## [1.16.2] - 2026-02-26

### 🐛 Bug Fixes
- **Q+ Transfer Expenses**: Fixed an issue where `ComBank_Q+` fund transfers were categorized ambiguously. They are now correctly identified as financial expenses.
- **Note Editor Layout**: Fixed corrupted blockquote and header padding caused by inherited inline-style overrides. Formats render natively using Material 3 text theming now.
- **Lint Cleanup**: Fixed deprecated `withOpacity` usages and unresolved flow control structures, passing a completely clean `flutter analyze`.

### 🛠 Security / DevOps
- **Release Fonts preserved**: Disabled aggressive Android resource shrinking (`isShrinkResources = false`) that was stripping bundled `Rubik` fonts in the GitHub Actions Android release build. Font rendering in production builds is now identical to local profiles.

---

## [1.16.1] - 2026-02-25
- **Calculator: Division-by-zero & invalid expressions**: Evaluating `1/0` or `0/0` previously stored `Infinity`/`NaN` as a transaction amount. These are now blocked — the calculator shows "Error" and "Use Value" closes without setting an amount.
- **Animation re-play on category filter**: Tapping a category chip in the Finances screen no longer re-animates the entire page from scratch (was caused by `AnimationLimiter` receiving a new `ValueKey` on every filter change).

### 🛠 Improvements
- **Snappier transitions**: All stagger durations reduced (375 ms → 220 ms), container fade-through 500 ms → 300 ms, slide offset 50 px → 24 px — matches M3 Expressive motion guidelines.
- **Transaction rows**: Individual transaction cards no longer play a stagger entrance on every filter tap. Dashboard cards (chart, summary, search, chips) still animate in once on initial page load.
- **Backup logging**: `print()` replaced with `debugPrint()` — production-safe and conforms to Flutter lint rules.

---

## [1.16.0] - 2026-02-25

### ✨ New Features
- **Inline Category Creation**: Create new spending categories directly from the transaction editor via a "+ New" chip. Quick dialog with name + colour picker; new category is auto-selected.
- **Category Management Link**: "Manage" button next to the "Category" label in the transaction editor navigates to the full Category Management screen. Changes are reflected immediately on return.
- **Rich Note Previews**: Home screen note cards now render bullet lists, headings, blockquotes, and other formatting via Markdown instead of plain text.
- **MRU Tag Sorting**: Tags on the home screen sort by most recently modified note, so active projects appear first.

### 🛠 Improvements
- **Instant Category & Search Filtering**: Financial manager filters categories and search in-memory — eliminates loading spinners and DB round-trips.
- **Smooth Fade-Through Transitions**: Opening/closing notes and transactions uses Material fade-through (500 ms) across all screens.
- **Staggered Animation Replay**: Switching category filters replays the staggered list entrance animation.
- **Unified Design System**: Notes, Finances, and Settings screens now share identical transition types, AppBar styling, FAB format (extended with label), empty-state colours, animation directions, and spacing.
- **Background Backup Logging**: Silent catches in auto-backup service replaced with logged errors (visible in logcat).

### 🔒 Security / DevOps
- **Auto versionCode from git tag**: CI computes `versionCode = major×10000 + minor×100 + patch`, guaranteeing Android accepts every update without uninstall.
- **Optional release signing**: GitHub Secrets support for `KEYSTORE_BASE64`, `KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD`.
- **SHA-256 checksums**: Published alongside each release APK.
- **Updated CI actions**: `softprops/action-gh-release@v2` with optional `RELEASE_NOTES.md`.
- **Keystore files excluded**: `.gitignore` updated for `key.properties`, `*.jks`, `*.keystore`.

---

## [1.15.0] - 2026-02-25

### ✨ New Features
- **SMS Contacts Management**: Replaced the simple SMS Sender Whitelist with a full **SMS Contacts** screen (Settings → Financial Manager → SMS Contacts). View all 10 built-in Sri Lankan banks and any custom senders in a single grouped list.
- **Block / Unblock Senders**: Toggle any bank or custom sender on/off with a switch. Blocked senders are completely ignored during SMS import — useful for suppressing duplicate notifications (e.g. block "COMBANK Q+" but keep "COMBANK").
- **Cross-Sender Deduplication**: When the same amount appears from two different senders within a ±5-minute window, only the first transaction is imported. Eliminates duplicates from bank apps that send parallel SMS (e.g. COMBANK and COMBANK Q+ for the same purchase).

### 🛠 Improvements
- **Default import period**: Import SMS Transactions sheet now defaults to **"Last day"** instead of "Last 30 days" for faster routine syncs.
- **Backup v6**: Exports/imports `sms_contacts` table. v5 backups (with `smsWhitelist` key) are automatically migrated during import — no data loss.
- **Database v10**: `sms_contacts` table replaces `sms_whitelist`. Existing whitelist entries are migrated as custom contacts automatically on upgrade.

### 🔒 Security / Data Integrity
- Cross-sender dedup prevents inflated expense totals from duplicate bank SMS.
- Blocked senders checked before allowed senders in the parsing pipeline — blocking always wins.
- Backup version bumped 5 → 6; v1–v5 backups continue to import correctly.

---

## [1.14.2] - 2026-02-23

### 🛠 Improvements
- **Backup v5 — SMS Whitelist included**: The full backup now exports and restores the SMS sender whitelist alongside notes, transactions, categories, and settings. Previous backups (v1–v4) continue to import without issues.
- **Case-insensitive whitelist matching**: Sender IDs stored in the whitelist are matched case-insensitively against incoming SMS senders (`KOKO` matches `koko` and vice versa).
- **Reversal sentinel as a typed constant**: `SmsService.reversalSentinel` is now a public static constant; the hardcoded `'__reversal__'` string literal in `financial_manager_screen.dart` has been replaced.
- **README updated**: Features list now reflects v1.14.x additions — 10 categories, SMS Sender Whitelist, due-reminder filtering, and v5 backup.

### 🔒 Security / Data Integrity
- Backup version bumped 4 → 5; v1/v2/v3/v4 backups continue to import correctly.

---

## [1.14.1] - 2026-02-23

### ✨ New Features
- **SMS Sender Whitelist**: User-managed whitelist under **Settings → Financial Manager → SMS Sender Whitelist**. Add non-bank services (e.g. KOKO, FriMi) whose debit/credit SMS should be auto-imported. Banks are included by default and do not need to be added.

### 🛠 Improvements
- **Due-reminder SMS skipped**: Daily reminder messages (e.g. "Your KOKO payment is due tomorrow") are now ignored and never imported as transactions. Only SMS that contain an actual debit confirmation keyword are processed — eliminating the repeated KOKO entries.
- **Banks-only default whitelist**: Non-bank SMS senders (KOKO, FriMi, PayApp) removed from the built-in sender set. They can be re-added individually via the new whitelist screen.

### 🔒 Security / Data Integrity
- Database schema bumped to version 9; migration automatically creates the `sms_whitelist` table on existing installs — no reinstall required.

---

## [1.14.0] - 2026-02-23

### ✨ New Features
- **Payments & Deposit Categories**: Two new built-in transaction categories covering instalments, EMI, KOKO buy-now-pay-later, loan repayments (Payments) and bank deposits, salary, and credited income (Deposit).
- **Smarter SMS Descriptions**: Descriptions are now structured and human-readable instead of raw scraped text:
  - Bank deposits → `"Deposit of 10,000 in Commercial Bank"`
  - Card purchases → `"Purchase at PickMe Food 1,559"`
  - KOKO/instalment → `"KOKO Instalment Simplytek"`
  - Fund transfers → `"Transfer to Recipient 5,000"`
  - ATM withdrawals → `"ATM Withdrawal 15,000"`
- **Cancelled + Reversed Orders Auto-Delete**: SMS messages that are both cancelled *and* reversed (e.g. a cancelled PickMe Food order refund) now correctly delete the original expense — previously they were silently ignored.
- **Bare Amount Parsing**: Instalment/due-reminder SMS messages without an LKR/Rs prefix (e.g. `"of 7895.98"`) are now parsed correctly.
- **Expanded Bank & Provider Whitelist**: Added KOKO, Nations Trust Bank (NTB), LOLC, FriMi, and PayApp to the recognised sender list.
- **Category Definitions in Backup**: Backups are now v4 — custom categories (names, keywords, colours) are exported and fully restored. Restoring a backup also reloads the in-memory category cache immediately.
- **Adaptive Colour Swatch Check**: The checkmark icon on colour swatches in the category editor now uses white or black based on the swatch's luminance, ensuring legibility on both light and dark colours.

### 🛠 Improvements
- `purchase`, `authorised`, `authorized` added to debit keyword list for broader card transaction detection.
- URL stripping added to PII removal so confirmation links never pollute descriptions.
- Masked card numbers with `#` prefix (e.g. `ending #4525`) now correctly stripped.
- Order ID / Order # patterns added to PII removal regex.
- Amount formatting: trailing `.00` dropped, thousands separator added (e.g. `10,000`).

### 🔒 Security / Data Integrity
- Database schema bumped to version 8; migration automatically adds Payments and Deposit categories to existing installs — no reinstall required.
- Backup version bumped 3 → 4; v1/v2/v3 backups continue to import correctly.

---

## [1.13.0] - 2026-02-22

### ✨ New Features
- **Custom Category Management**: Create your own transaction categories with a custom name, colour, and keywords. Built-in categories' keywords are also fully editable. Accessible from **Settings → Financial Manager → Manage Categories**.
- **Transaction Search**: Search bar on the Finances screen filters transactions by description or category in real time.
- **Date-Range Net Card**: The hero card at the top of the Finances screen now shows the net balance for the *currently selected date range* instead of an all-time figure.
- **Long-Press to Delete Transactions**: Long-press any transaction card for a confirmation dialog to delete it.
- **Note Checklist Preview**: Quill checklist items now appear with ☐ / ☑ symbols in home-screen note cards.
- **Note Preview Line Truncation**: Note card previews now show up to 4 lines of content (rich text and markdown) instead of a fixed character count.

### 🛠 SMS Import Improvements
- **Promotional SMS Skipped**: Messages matching promo/offer patterns (and lacking a real debit/credit keyword) are ignored.
- **Cancellation SMS Skipped**: Messages containing "cancelled", "transaction failed", "declined", etc. are not imported.
- **Reversal / Refund Handling**: Reversal SMS messages automatically delete the original expense within a 7-day window; no duplicate credit entry is created.
- **Better Income Detection**: Expanded credit keyword matching to catch salary, fund transfer, payment received, incoming transfer, and cash deposit.
- **Compound Keyword Priority**: Multi-word keywords are tested before single-word ones. "PickMe Food" → Food & Dining; "PickMe Ride" → Transport; "Uber Eats" → Food & Dining; "Uber" → Transport.

---

## [1.12.1] - 2026-02-22

### 🛠 Improvements & Fixes
- **SMS deduplication hardened**: Replaced two-step `smsExists` + `createTransaction` pattern with a single `createSmsTransaction` call backed by `ConflictAlgorithm.ignore`. Eliminates the race condition between the background isolate and foreground sync both passing the existence check before either insert completes.
- **SMS import period parity**: The "Import SMS Transactions" sheet in Settings now includes a "Last day" option, matching the period options in the Finances sync sheet.
- **Dead code removed**: Unused `syncInbox()` method removed from `SmsService`; all callers now use `syncInboxFrom(DateTime)`.

---

## [1.12.0] - 2026-02-22

### ✨ New Features
- **SMS Auto-Import**: Automatically detect and import bank transactions from incoming SMS messages. Works in the background (no app open required) via a dedicated Android broadcast receiver.
- **Transaction Categories**: 8 categories — Transport, Food & Dining, Subscriptions, Shopping, Utilities, Health, Entertainment, Other — auto-assigned by keyword matching from Sri Lankan bank SMS formats.
- **Category Filter Chips**: Horizontal filter row on the Finances screen. Only categories that have actual transactions in the selected date range are shown.
- **Category Picker in Editor**: Colour-coded FilterChip grid in the transaction editor to manually set or override the auto-detected category.
- **Category Badges**: Each transaction card shows a colour-coded pill badge for its category.
- **Settings → Import SMS Transactions**: Manual one-tap import from Settings with a period selector (Last 7 days / Last 30 days / Last 3 months / All time).
- **Finances Sync Button**: Quick-sync icon in the Finances AppBar triggers an inbox scan.
- **Real-time Foreground Listener**: New bank SMS received while the app is in the foreground is parsed and added instantly.

### 🛠 Improvements
- Default date range on the Finances screen changed from "today only" to the current calendar month.
- Context-aware empty state: when a category filter is active with no results, a "Clear filter" button appears inline.
- SMS deduplication via a stable composite `smsId` (message id + timestamp) prevents duplicate imports.
- `mounted` guards added to all async UI callbacks to prevent setState-after-dispose crashes.

### 🔒 Security / DevOps
- Release APKs now built with R8 minification + resource shrinking (`isMinifyEnabled = true`, `isShrinkResources = true`).
- ProGuard keep-rules added for Telephony, permission_handler, and sqflite plugins.
- CI: removed `--no-shrink` override; corrected APK filename (removed double-`v` regression).
- Dart SDK constraint tightened to `>=3.6.0 <4.0.0`; Flutter minimum pinned to `>=3.27.0`.
- `ThemeMode` restore from backup now bounds-checked (crash fix for malformed backup files).

---

## [1.11.1] - 2025-12-30

### 🐛 Fixes
- Patch stability release addressing minor regressions in the financial dashboard date display.

---

## [1.11.0] - 2025-12-28

### ✨ New Features
- **Advanced Date Filtering**: Tap the calendar icon in Finances to pick any custom date range.
- **Dynamic Dashboard**: Income, expense, and net-balance summary cards update in real time for the selected period.
- **6-Month Bar Chart**: Spending trend sparkline added to the dashboard.

### 🛠 Improvements
- All-time net-balance card added to the top of the Finances screen.
- Performance: in-memory transaction filtering optimised.

---

## [1.10.0] - 2025-12-25

### ✨ New Features
- **Google Cloud Backup**: Automatic device and cloud backup via Android's `data_extraction_rules.xml` (includes database and SharedPreferences).
- **Full Backup/Restore v3**: Backup JSON now includes settings (theme, currency, font, grid layout).

### 🛠 Improvements
- Backup confirmation dialog previews note/tag/transaction counts before importing.
- Duplicate transaction detection via content fingerprint.

---

## [1.9.0] - 2025-12-23

### ✨ New Features
- **Financial Manager**: Dedicated expense and income tracker.
- **Built-in Calculator**: Compute amounts directly in the transaction editor.
- **Currency Selection**: Choose your preferred currency in Settings → Financial Manager.
- **Transactions Backup**: Export/import now includes the full transactions table.

---

## [1.8.0] - 2025-12-22

### ✨ New Features
- **Trash / Soft Delete**: Deleted notes go to Trash and can be restored.
- **Archive**: Move notes out of the main list; view via Settings → Archive.
- **Manage Tags**: Rename or delete tags globally from Settings → Content.

---

## [1.7.0] - 2025-12-22

### ✨ New Features
- **Rebranding**: App title updated to "Note Book".
- **Adaptive Formatting**: Quote and Code blocks adapt to the note's page colour.
- **Home Screen Thumbnails**: Images display as compact rounded thumbnails on note cards.
- **Uniform Toolbar**: Bottom formatting toolbar now has uniform icon spacing.

### 🐛 Fixes
- Fixed `RenderFlex` overflow crash on Home Screen note cards.
- Standardised image alignment across the app.

### 🧹 Maintenance
- Removed unused legacy styling code.
- Verified 0 analysis issues.
