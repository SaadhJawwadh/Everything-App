import 'package:flutter/material.dart';
import '../core/theme/app_layout.dart';
import '../core/ui/expressive_sliver_app_bar.dart';
import '../core/ui/app_card.dart';

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const ExpressiveSliverAppBar(
            titleText: 'Changelog',
            showBackButton: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppLayout.spaceXL,
              vertical: AppLayout.spaceL,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildVersionSection(
                  context,
                  version: 'v2.45.0',
                  date: 'October 4, 2026',
                  isLatest: true,
                  changes: [
                    _ChangelogGroup(
                      title: "What's New",
                      items: [
                        'Story Card Studio Article & Reader Mode: Share long notes, checklists, and articles as high-resolution story cards with dedicated Reader Mode, clean divider layout, and dynamic font scaling.',
                        'Inter-Vault Account Transfers: Transfer funds smoothly between Daily Cash Flow and Savings Vault with instant dual-entry tracking and real-time balance calculations.',
                        'In-Note Wiki Links & Expense Embeds: Connect your thoughts with [[Note Title]] bidirectional links, and embed live expense sums using {{\$amount}} tags.',
                        'Period Tracker Discreet Privacy Mode: Keep health tracking private with an ambient moon indicator, toggleable cycle details, and discreet notification alerts.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: 'Improvements',
                      items: [
                        'Checklist Drag-and-Drop Reordering: Seamlessly reorder to-do tasks using drag gestures or the convenient reorder sheet.',
                        'P2P Wi-Fi Sync Audit Activity: Transparent sync logs detailing synced notes, ledger transactions, and connected peer devices.',
                        'Financial Ledger CSV & AI Export: Export complete transaction records to CSV or generate clean prompts for external financial analysis.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: 'Fixes',
                      items: [
                        'Checklist Multi-Level Task Integrity: Preserved sub-items and checklist status across note edits and widget sync.',
                        'Visual Contrast & Theming: Refined dark mode card accents and surface container opacities across all modules.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.44.0',
                  date: 'September 27, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: "What's New",
                      items: [
                        'Interactive Home Screen To-Do Widget: Glanceable Android home screen widget to review your daily checklists, tick off tasks directly from your home screen with instant progress feedback, and launch quick-add with one tap.',
                        'Days of Clarity Strip: Calm 14-day mindfulness progression strip displayed at the top of your Notes workspace, celebrating everyday focus without stressful streak countdowns.',
                        'Tactile Haptics Preferences: Unified physical vibration system with an explicit on/off switch under Settings > Appearance & UI, delivering subtle, satisfying tactile feedback.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: 'Improvements',
                      items: [
                        'Smart Completed Task Collapsing: Optional automatic collapsing of checked items in note checklists, keeping your active thoughts clear and uncluttered.',
                        'Bi-Directional Widget & Database Synchronization: Ticking items on your home screen or within the app immediately updates both your notes and widgets in real time.',
                        'Synchronous Haptic Responsiveness: Zero frame drops or lag when performing quick interactions, gestures, and note formatting.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: 'Fixes',
                      items: [
                        'Checklist Formatting Fidelity: Enhanced checklist parsing and bullet list consistency across notes, preventing accidental indentation or spacing shifts.',
                        'Settings State Persistence: Resolved toggle state responsiveness so haptic and display preferences apply instantaneously without requiring an app reload.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.43.0',
                  date: 'September 26, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: "What's New",
                      items: [
                        'Expanded Global Multilingual Support: Full in-app language picker supporting English, Tamil, Chinese, Portuguese, Spanish, French, and German with instant reactive switching.',
                        'Dedicated Savings Goals Tab: Clean sub-tab inside Budgets featuring 24 Material 3 colors, aggregate vault analytics, and zero nested whitespace.',
                        'Dual-State Editor Keyboard Controls: Cleanly disambiguated formatting dismissal arrow from the keyboard hide button, with streamlined menus.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: 'Improvements',
                      items: [
                        'Contextual Selection & Toolbar AI Refine: Select transaction text or use the ledger toolbar to directly refine entries from storage with instant UI refresh.',
                        'Streamlined App Footprint: Removed obsolete audio recording dependencies and permissions for a smaller, faster app.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: 'Fixes',
                      items: [
                        'MaterialApp Locale Resolution: Corrected supportedLocales registration so all app modules respond immediately to language selection.',
                        'Savings Goal Database & Schema: Complete SQLite table and menu integration for effortless goal creation and deposits.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.42.0',
                  date: 'September 23, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: "What's New",
                      items: [
                        'App Launcher Shortcuts: Long-press the app icon to jump directly into New Note, Add Expense, Scan Receipt, or Sync Devices.',
                        'Dedicated Note Sorting: Convenient one-tap sort button on the Notes header to quickly sort by modified date, created date, title, or color.',
                        'Itemized Split Bills & Undo: Share itemized statements of all pending bills via WhatsApp and undo settlements with automatic ledger sync.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: 'Improvements',
                      items: [
                        'Streamlined Tools Menus: Refined Notes and Finance action menus, reducing visual clutter while keeping essential utilities easily accessible.',
                        'Auto-Purge & Diagnostic Notifications: Helpful notification summaries when old trash notes are cleared, plus a one-tap notification test in Settings.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: 'Fixes',
                      items: [
                        'Split Settlement Balance Parity: Undoing a settlement automatically reverses the ledger transaction to maintain exact cash flow accuracy.',
                        'Background SMS Stability: Smoother background SMS parsing with improved duplicate prevention.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.41.0',
                  date: 'September 21, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: "What's New",
                      items: [
                        'Long-Press Multi-Selection: Select multiple items across Notes, Financial Ledger, Trash, and Split Bills for quick batch operations.',
                        'Contextual Floating Action Toolbars: Smooth floating action toolbar for one-tap batch categories, archiving, and deletion.',
                        'Material 3 Expressive Surfaces: Complete dividerless surface redesign with solid tonal container layering and improved contrast.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: 'Improvements',
                      items: [
                        'Tactile Haptic Feedback: Micro-vibration responses on item selections and bulk action triggers.',
                        'Polished Dialogs & Sheets: Consistent edge-to-edge layouts across Calculator, SMS Import, and Details dialogs.',
                        'Sub-Pixel Layout Alignment: Flawless vertical headroom and symmetry across all module sliver headers.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: 'Fixes',
                      items: [
                        'Multi-Selection State Consistency: Smooth transitions entering and exiting selection modes without flickering.',
                        'Table Dialog & Action Layout: Resolved divider lines and improved button padding in editor dialogs.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.40.0',
                  date: 'September 17, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: "What's New",
                      items: [
                        'Modular Sub-Features Architecture: Toggle individual sub-features within Notes and Finances to make the workspace ultra-minimal or fully featured.',
                        'Minimal Note Editor Mode: Focus cleanly on writing with an uncluttered bottom dock; advanced formatting stays tucked in the top action menu.',
                        'Dynamic Single-View Financial Ledger: Automatically merges multi-tab finances into a focused single-view ledger when secondary tabs are disabled.',
                        'Independent Notes Customization: Easily toggle the tag filter carousel on or off to match your workflow.',
                        'Expanded Modular Onboarding: Customize your modular layout directly during initial setup or replay anytime in Settings.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: 'Improvements',
                      items: [
                        'Interactive Home Widget: Rich cash flow summaries and one-tap quick action deep links directly from your home screen.',
                        'Context-Aware Transaction Editor: Dynamically adapts recurring, receipt OCR, and split bill controls based on active sub-features.',
                        'Zero-Friction Reconfigurability: Live reactivity across all screens when toggling sub-features without needing to restart the app.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: 'Fixes',
                      items: [
                        'Split Bill Action Gating: Seamlessly hides split bill triggers across transaction forms when split bills are disabled.',
                        'Non-Destructive Sub-Feature Toggling: Safely preserves existing budgets, recurring rules, and custom categories during sub-feature toggles.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.31.1',
                  date: 'September 16, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: "What's New",
                      items: [
                        'Material 3 Expressive Design System: Complete visual elevation with 5-tier solid surfaces, tactile stadium pills, and variable typography.',
                        'Tactile Sinusoidal Wavy Slider: Interactive typography scaling in Settings with live text preview and real-time font size adjustment.',
                        'Shape-Morphing Indicators: Fluid loading animations transitioning across 35+ expressive geometric shapes during receipt OCR scanning and module loading.',
                        'Expressive Split Buttons: Multi-action note migration button offering one-tap file browsing alongside instant Google Takeout access.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: 'Improvements',
                      items: [
                        'Zero Frosted Glass Blur: Purged all legacy backdrop blurs in favor of high-performance, battery-friendly solid surface containers.',
                        'Connected Corner Morphing: Grouped list cards and paired P2P devices now feature unified morphing rounded corners.',
                        'Resilient Backup Serialization: Expanded backup coverage to guarantee 100% preservation of split bills, savings vault, and custom account routing.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: 'Fixes',
                      items: [
                        'Dialog & Sheet Standardization: Unified all prompt guides and cycle phase sheets into responsive Material 3 bottom sheets.',
                        'P2P Sync & Camera Resume: Camera QR scanning and sync operations reliably preserve session state without unwanted lock triggers.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.31.0',
                  date: 'September 16, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: "What's New",
                      items: [
                        'Goal-Oriented Savings Pockets: Set target goals with auto-pacing and milestone badges for college, travel, or emergencies.',
                        'Authentic Dual-Account Transfers: Real double-entry transfer transactions between Daily Operating and Savings Vault accounts.',
                        'Smart Split Bill Calculator: Itemized breakdown with proportional tax, tip, and service fee distribution across subtotals.',
                        'Interactive Mini Calculator: Embedded arithmetic keypad directly inside exact share fields for instant portioning.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: 'Improvements',
                      items: [
                        'Real-Time Savings Pacing & Milestones: Progress tracking with milestone badges and dynamic monthly pace recalculations.',
                        'Penny Remainder Reconciliation: Easily balance one-cent or residual round-off differences on custom splits.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: 'Fixes',
                      items: [
                        'Resilient Full-Form Scrolling: Fluid scrolling across savings goals and split bill calculator modals on all screen sizes.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.30.3',
                  date: 'September 12, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: "🌟 What's New",
                      items: [
                        'Instant Auto-Backup Trigger: Run and verify scheduled encrypted backups on-demand with real-time feedback directly in Settings.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Reliable Auto-Backup Scheduling: Fixed the background timer reset bug on app startup, ensuring daily automatic backups run consistently.',
                        'Helpful P2P Offline Guidance: Clear, friendly instructions appear when attempting Wi-Fi sync if the app is closed on the paired device.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Tag Manager & Card Scrollability: Completely eliminated layout overflow crashes in the tag manager modal, note import preview, and category pickers on compact or older screens.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.30.2',
                  date: 'September 10, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: "🌟 What's New",
                      items: [
                        'Contextual Split Bill Action: Tapping the Add button on the Split Bills tab now seamlessly opens the Split Bill creator with full splitting options.',
                        'Rich Category Icons: Expanded transaction categories with 54 expressive Material 3 icons covering subscriptions, utilities, hobbies, pet care, transit, and medical needs.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Dual-Mode Split Bill Ledger Contract: Group bills you pay record directly to your master expense ledger, while friend-paid bills stay organized in the split tracker without cluttering your personal accounts.',
                        'Smart App Review Reminders: Pleasant, milestone-based rating prompts (at 5, 15, and 30 items) with a 7-day cooldown to ensure an uninterrupted experience.',
                        'Instant Backup Refresh: Restoring an encrypted backup now immediately updates all finance, split bill, and note views in real time.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Note Indentation Preservation: Multi-level list indents and formatting are now accurately saved and restored without disappearing.',
                        'Swipe-to-Delete Split Bills: Added smooth swipe dismissal for group bills with a confirmation dialog and instant Undo option.',
                        'Friend-Paid Custom Amounts: Easily enter and adjust your exact personal share when friends cover a group bill.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.30.1',
                  date: 'September 5, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: "🌟 What's New",
                      items: [
                        'Story Card Studio: Transform notes or selected text into high-resolution social media cards formatted for 9:16 Stories, 1:1 Squares, and 4:5 Portraits with direct 1-tap sharing.',
                        'Packaged Offline Fonts: Fully offline Noto Sans and Noto Serif Tamil variable typography with automatic language detection, line-height balancing, and font style switcher.',
                        'Word Limits & Safe Heatmap: 25, 50, and 80-word selection limits with live word count stats and Instagram/WhatsApp story safe margins.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Centered App Logo Watermark: Replaced generic text watermark with an authentic, centered micro-pill badge featuring the monochrome app emblem.',
                        'Seamless Theme Presets: Editorial Serif warm paper theme, OLED Pitch Black, Note Tint, and Material You Dynamic themes.',
                        'Tactile Chart & Calendar Scrubbing: Haptic clicks when scrubbing spend trend points, category donut slices, and selecting cycle calendar days.',
                        'Universal Selection Controls: Cleaned up checkmark glyphs across Theme Mode, Transaction Type, and Account Buckets to preserve authentic icons.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Resilient Sheet Layout: Wrapped bottom sheet and control groups in fluid scrolling to completely eliminate layout overflows during text editing or word limits.',
                        'Split Bills View Clutter: Unified hero cards on the Split Bills tab, removing redundant personal cash flow card stacking.',
                        'Touch Target Bounds: Upgraded P2P sync and note editor navigation micro-buttons to standard 48x48dp hit targets.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.29.0',
                  date: 'September 3, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: "🌟 What's New",
                      items: [
                        'Friend-Paid Split Bills: Track group bills paid by friends with clear personal liability. Settle your own share with one tap into your daily ledger, while keeping friends\' mutual debts cleanly separated in the split tracker.',
                        'Archived Notes Dropdown Access: Quickly access all your archived notes with note counts directly from the folder picker sheet and the Notes tools menu.',
                        'Vibrant Settings Dashboard: An upgraded hero dashboard with rich multi-tone gradients, luminous ambient glow, a pulsing Local Vault security badge, and bold module indicators.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Streamlined SMS Sync: Eliminated unsolicited background resume polling, focusing SMS imports on scheduled daily sync, one-tap manual refresh, and real-time live message detection.',
                        'Interactive Settlement Feedback: Clear visual badges and instant status updates when settling bills or recording participant repayments.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Personal Ledger Isolation: Third-party debt repayments between friends are strictly isolated within the split tracker and never create unwanted entries in your personal account ledger.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.28.0',
                  date: 'September 2, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: "🌟 What's New",
                      items: [
                        'Google Keep & Markdown Import: Batch import notes, checklists, folders, and tags from Google Keep Takeout JSON and Markdown archives in one tap.',
                        'Redesigned Settings Control Center: An interactive console featuring a subtle security indicator, quick one-tap shortcuts for App Lock and JSON backups, and domain-themed cards (Notes, Finances, Health, Privacy).',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Smarter Checklist Engine: Smoother item completion without trailing empty lines, plus one-tap unchecking to restore items directly to your note body.',
                        'Resilient App Lock: Automatic safety fallback detects devices without screen locks or enrolled biometrics, preventing accidental lockouts with a safe disable button.',
                        'Touch Accessibility: Standardized screen reader semantics across all interactive tag and filter chips.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Checklist Restore Ordering: Accurately restores completed items back into the editor with line-ending formatting and correct cursor positioning.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.27.0',
                  date: 'August 30, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: "🌟 What's New",
                      items: [
                        'Split Bills Cloudless Backup & Sync: Group expenses, debt balances, and friend contacts now automatically back up in encrypted JSON files and sync bi-directionally across your paired devices over local Wi-Fi.',
                        'Intelligent Rich Text Formatting: Upgraded note formatting engine keeps your bold, italic, and underline styling intact when converting headers, bullet points, and checklists.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Faster Database Queries: Added performance indexing across transactions, notes, split bills, and health logs for instant screen loads.',
                        'Memory & Storage Optimization: High-resolution camera photos are safely downsampled and isolated in protected storage to save device battery and memory.',
                        'Seamless Screen Navigation: Smoother transition between system dialogs, file pickers, and WhatsApp sharing without accidental lock screen triggers.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Precision Text Selection: Fixed cursor navigation when tapping near note boundaries and tables.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.26.0',
                  date: 'August 30, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: "🌟 What's New",
                      items: [
                        'Top Bar Transaction Search: Integrated instant search directly into the Finances top action bar, maximizing screen space for transactions.',
                        'SMS 24-Hour Default Lookback: Quick sync and app launch catch-up now scan the last 24 hours by default, eliminating missed transaction cutoffs.',
                        'Persistent Real-Time Sync Banner: Live progress indicator beneath the top bar across all financial tabs with scanning counts and an instant Cancel button.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Top Action Bar Symmetry & Ordering: Standardized button sequence (Search → Sync → Tools → Settings) and uniform spacing across Notes, Finances, and Health Tracker.',
                        'Dynamic Theming Scope Pills: High-contrast tonal container styling with subtle accent borders for folder, date range, and cycle phase pills.',
                        'Post-Sync Feedback: Floating SnackBar notifications showing exact transaction counts imported from the last 24 hours.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Tombstone Safety & Deduplication: Stamped genuine SMS receipt timestamps to prevent duplicate imports and protect restored transactions.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.25.2',
                  date: 'August 28, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: "🌟 What's New",
                      items: [
                        'Unified Top App Bar & Scope Pills: Modernized frosted glass headers across Notes, Finances, and Period Tracker with interactive tonal scope pills.',
                        'Universal Module Tools (3-Dot Menu): Dedicated overflow action menus consolidating view modes, sorting, tag management, SMS automation, and educational guides.',
                        'Cycle Phase Guide: Built-in interactive educational guide explaining cycle phases, symptoms, and self-care recommendations.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Universal Settings Anchor: Consistent quick-access Settings shortcut button across all primary module headers.',
                        'Material 3 Dropdown Modernization: Refreshed all dropdown icons with rounded Material 3 chevrons.',
                        'Layout Precision & Polish: Cleaned sub-pixel bounds across financial metrics, hero cards, and health dialogs.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.25.1',
                  date: 'August 28, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Settings Control Center Polish: Ensured subtitle text in the hero card scales down smoothly without truncation across all display text sizes.',
                        'Home Header Alignment: Fine-tuned folder dropdown vertical spacing and expanded toolbar constraints for clean layout across compact viewports.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Release Pipeline Synchronization: Updated release build code and Play Store deployment artifacts for seamless in-app updates.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.25.0',
                  date: 'August 27, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: "🌟 What's New",
                      items: [
                        'Interactive Custom SMS Training: Teach the app how to recognize unique bank SMS and transfer approval formats directly from the test sandbox or training sheet.',
                        'Personalized Transaction Titles: Set clean custom descriptions that automatically replace noisy bank SMS text.',
                        'Transfer Authorization & OTP Bypass: Built-in override for banks that send transfer approval codes without a follow-up confirmation SMS.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        '5-Pillar Settings Control Center: Unified settings hub with live module status badges, 1-tap theme switcher, and consolidated SMS background automation.',
                        'Adaptive Minimalist Workspace: Automatically collapses navigation bars when optional modules are off for an immersive full-screen note canvas.',
                        'Rule Management Hub: Material 3 custom rule cards with active toggle switches, tap-to-edit, and swipe-to-delete with instant Undo.',
                        'Top Dropdown Entry Point: Quick access to SMS Rules & Training from the Financial Manager 3-dot overflow menu.',
                        'Onboarding Powerup Integration: Added custom SMS training setup card to the onboarding wizard.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Promotional Filter Precision: Distinguishes promo codes from transfer authorization and OTP approval codes.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.24.0',
                  date: 'August 26, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: "🌟 What's New",
                      items: [
                        'Split Bills & Shared Debts: Group bill splitting with equal or custom exact splits, friend balances, and 1-tap WhatsApp breakdown reminders.',
                        '100% Offline Receipt Scanner: Instant OCR totals and merchant extraction directly on-device with zero cloud dependency.',
                        'Modular Dual-Account Toggle: Flexible switch to enable or disable the Savings Vault & Daily Operating two-bucket view anytime.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Unified Category Pickers: Color-coded category chips cloud seamlessly shared across Transactions, Split Bills, and Recurring Rules.',
                        'Accessibility & Touch Hit Targets: Enhanced TalkBack / VoiceOver semantics and enlarged interactive touch targets across all sheets.',
                        'Optimized Custom Amount Inputs: Spacious, unclipped multi-currency number entry fields.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.23.0',
                  date: 'August 25, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: "🌟 What's New",
                      items: [
                        'Two-Bank Account Management: Manage separate Daily Operating and Savings Vault accounts with instant balance hero badges and ledger account filtering.',
                        'AI-Powered Spending Analysis Export: Export your financial ledger with an integrated, intelligent analysis prompt crafted for Claude, ChatGPT, Gemini, and NotebookLM.',
                        'Resilient Auto-Backup Storage: Sandboxed app storage ensures automatic daily/weekly backups remain active without permission revocations across OS updates.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Live Recurring Rule Sync: Editing a recurring transaction seamlessly synchronizes and updates the master recurring rule for all future billing cycles.',
                        'Widget Launch SMS Catch-Up Sync: Automatically checks and imports new bank SMS transactions when opening the app directly or through home screen widgets.',
                        'Account Ledger Tagging: Clear account bucket chips and icons across transaction rows and CSV exports.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.22.0',
                  date: 'August 24, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: "🌟 What's New",
                      items: [
                        'SMS & Bank Automation Hub: Real-time SMS test sandbox, custom keyword rules, and verified offline bank parsing for instant ledger tracking.',
                        'Smart Recurring Subscriptions: Automated repeating bills and salaries with live keyword category detection and duplicate prevention.',
                        'Sender Controls & Diagnostics: Block unwanted senders and inspect diagnostic feedback for promotional broadcasts.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Spending Trend Analytics: Refined chart header density and projection styling for smooth 120 FPS navigation.',
                        'Hardware-Aware AI Controls: Dynamic feature gating ensures settings and menus cleanly adapt to device capabilities.',
                        'Clean Merchant Extraction: Automatic filtering of phone numbers, country codes, and payment gateway noise from transaction titles.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'CEFTS Self-Transfer Categorization: Accurate zero-expense detection for bank transfers between owned accounts.',
                        'SMS Ingestion & Date Precision: Historical message timestamps strictly preserved with tombstone re-import safeguards.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.21.5',
                  date: 'August 24, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Play Store Release Pipeline Resiliency: Synchronized bilingual release notes with strict character limits and automated version code pacing for Google Play releases.',
                        'Android 15 Edge-to-Edge & Performance: Native system bar edge-to-edge rendering and optimized R8 bytecode shrinking for faster cold launch.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.21.4',
                  date: 'August 24, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Android 15 Native Edge-to-Edge: Integrated native enableEdgeToEdge() activity orchestration and transparent system insets for fluid display across Android 15 & 16 devices.',
                        'R8 Code Shrinking & Inlining: Hardened ProGuard keep rules and release build optimizations for reduced memory and zero-delay startup.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.21.3',
                  date: 'August 21, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Instant 0ms UI Updates: Added optimistic instant state rendering across the Financial Ledger, Notes feed, Trash Sheet, and Health Tracker—deleting, restoring, and toggling items updates the UI in 0ms with zero loading flickers or list re-animations.',
                        'Accurate SMS Message Timestamps: Past bank SMS transactions and inbox imports accurately preserve the exact date and time the message arrived instead of defaulting to the import date.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Financial Ledger Undo Restoration: Fixed transaction undo button by executing direct database restoration, preventing primary key collisions and soft-delete tombstone blocks.',
                        'Silent Background Sync: Background data refreshes and note tagging updates execute quietly without interrupting ongoing user reading or unmounting active lists.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.21.2',
                  date: 'August 21, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🐛 Fixes & Improvements',
                      items: [
                        'SMS Permission & Sync Detection: Fixed SMS permission evaluation by removing undeclared phone permission requirements, restoring instant 1-tap quick sync and real-time bank SMS interception.',
                        'Tombstone Re-Import Safeguards: Enhanced transaction ingestion to check the tombstone table, preventing permanently deleted transactions from being re-imported during historical scans unless explicitly enabled.',
                        'Sync Cancellation & Progress Controls: Added an instant "Cancel" button to the SMS sync banner and batch processing chunks for seamless navigation across large inboxes.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.21.1',
                  date: 'August 21, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Bitmap Memory Downsampling: Added image downsampling and fallback error handling to note previews, cutting image memory usage by up to 85% and preventing Out-Of-Memory pauses on large camera photos.',
                        'R8 Full-Mode Optimization: Enabled aggressive dead-code elimination, method inlining, and bytecode optimization for faster app launch and reduced download size.',
                        'Backward-Compatible Schema Upgrades: Enhanced SQLite database migration routines with rigorous single-quote SQL syntax and multi-version upgrade validation.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.21.0',
                  date: 'August 21, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🌟 What\'s New',
                      items: [
                        'Universal Morphing Action Buttons: Standardized fluid floating action buttons that dynamically morph into compact circular buttons while scrolling for distraction-free reading.',
                        'Recurring Payment Conversion: Seamlessly convert any manual or imported SMS transaction into a recurring schedule directly from the transaction editor.',
                        'Rotating Pro-Tips System: Helpful dismissible contextual tips on the Home feed and optional 3-day notifications to discover power features.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Real-Time Home Widget Budget Updates: Editing budget limits or adding transactions instantly synchronizes to the Android home screen widget.',
                        'Donut Chart Precision & Text Scaling: Dynamic downscaling for large currency totals inside donut chart center holes with guaranteed visibility for small slices.',
                        'Forecast Chart Tooltip Visibility: Tooltips now render above touch targets for crystal-clear finger navigation.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Bottom Content Overlap Safeguards: Standardized bottom clearance padding across all lists, forms, and segmented buttons to eliminate floating button overlap.',
                        'Smart Recurring Deduplication: Intelligent time and amount tolerance window avoids duplicate transactions when bank clearance schedules shift.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.20.0',
                  date: 'August 19, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🌟 What\'s New',
                      items: [
                        'Interactive Expense Breakdown Donut: Centered donut chart with dynamic center total and bi-directional touch linking with ranked categories.',
                        '3-Slide Swipable Visual Intelligence Deck: Trajectory forecast spline, category breakdown donut, and budget pacing with circular gauge.',
                        'Dynamic Home Screen Widget Sparkline: Native anti-aliased canvas sparkline curve plot, gradient underfill, and glowing forecast dot.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Adaptive Month-End Run-Rate Forecast: Extrapolates current month finish with days 1–3 early-month smoothing to prevent artificial spikes.',
                        'Context-Aware Deep Linking: Tapping "Details >" on any slide routes directly to the exact corresponding sub-tab with zero guesswork.',
                        'Zero-Dead-Code Cleanup: Purged deprecated legacy widgets and unified all forecasting logic into SpendingForecastService.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Resolved Title Clipping & Whitespace: Fixed text truncation on small screens and balanced budget pacing cards with dual-column layout.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.19.0',
                  date: 'August 18, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🌟 What\'s New',
                      items: [
                        'Symmetrical Precision Text Toolbar: Directional horizontal nudges, double-tap word jumping, and vertical line traversal in a frosted floating bar.',
                        'Health Cycle Regularity Insights: Real-time regularity scoring (0–100%), average flow duration analytics, moon phase guidance, and symptom tracking.',
                        'Category Spending Budgets & CSV Export: Category spending progress bars with threshold alerts, recurring subscription rules, and RFC-compliant CSV ledger export.',
                        'Tombstone Sync & Backup Protection: Permanent deletion retention prevents purged transactions from ever resurrecting across backups or P2P sync.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Fluid Spring Animations & Tactile Haptics: Smooth slide transitions and tactile click responses across formatting tools and cycle insights.',
                        'Ultra-Modular Screen Architecture: Cleaner, faster performance with decoupled state providers across Notes, Finances, and Health.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'SMS Re-import & Duplication Resilience: Rock-solid P2P two-way merge resolution and deletion tombstone propagation.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.18.0',
                  date: 'August 15, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🌟 What\'s New',
                      items: [
                        'Interactive SMS Test Sandbox: Test bank SMS messages live with instant amount, transaction direction, and category feedback before importing.',
                        'Global Currencies & Custom Currency: Choose from curated world currencies with authentic symbol badges or add your own custom currency code.',
                        'One-Tap Category Learning: Automatically train merchant rules into your category definitions with a single tap in the transaction editor.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Hardware-Aware AI Smart Gating: Cleanly hides AI controls on devices without on-device AI hardware for a distraction-free experience.',
                        'Precision Text Selection Toolbar: Refined text selection entry with directional arrow controls for fine-grained editing.',
                        'Silent Auto-Backup Channel: Background auto-backups now run in a quiet notification channel without disturbing your workflow.',
                        'Note Editor Heading & Indentation Tools: Visual heading level indicator badges and indentation buttons in the rich-text note editor.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Enhanced SMS Parsing & Long Merchant Support: Extended merchant recognition up to 60 characters and refined PII reference number cleaning.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.17.2',
                  date: 'August 12, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🌟 What\'s New',
                      items: [
                        'Background Bank SMS Auto-Import: Automatically scan bank transactions in the background with a floating M3 progress indicator while using the app.',
                        'AI Transaction Title Refinement: Clean up cryptic bank SMS transaction descriptions into clean merchant names with single-tap or 48-hour bulk AI title refinement.',
                        'Unified Dual-Gesture Sync: Tap sync icons for fast 24-hour sync, or long-press to open advanced historical import sheets across Notes and Finances.',
                        'Friendly Device Naming & Multi-Network P2P: Automatically generate memorable paired device names and keep P2P sync connected across home and work Wi-Fi networks.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        '60–120 FPS Performance & WAL Mode: RepaintBoundary GPU chart isolation and SQLite Write-Ahead Logging (WAL) mode for silky smooth fling-scrolling and non-blocking background syncs.',
                        'Human-Readable P2P Diagnostics: Clear, actionable troubleshooting guidance for P2P connection failures with dynamic red error cards and instant retry options.',
                        'Interactive Wi-Fi Refresh: Instant SnackBar feedback when re-scanning Wi-Fi network interfaces and binding P2P host ports.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Android Telephony Stability: Resolved native Android channel exception crashes when SMS permissions are revoked, and handled pairing timeouts gracefully.',
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppLayout.spaceXL),
                _buildVersionSection(
                  context,
                  version: 'v2.17.1',
                  date: 'August 12, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🌟 What\'s New',
                      items: [
                        'AI Transaction Title Refinement: Clean up cryptic bank SMS transaction descriptions into clean merchant names with single-tap or 48-hour bulk AI title refinement.',
                        'Unified Dual-Gesture Sync: Tap sync icons for fast 24-hour sync, or long-press to open advanced historical import sheets across Notes and Finances.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Human-Readable P2P Diagnostics: Clear, actionable troubleshooting guidance for P2P connection failures with dynamic red error cards and instant retry options.',
                        'Interactive Wi-Fi Refresh: Instant SnackBar feedback when re-scanning Wi-Fi network interfaces and binding P2P host ports.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Android Telephony Stability: Resolved native Android channel exception crashes when SMS permissions are revoked, and handled pairing timeouts gracefully.',
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppLayout.spaceXL),
                _buildVersionSection(
                  context,
                  version: 'v2.17.0',
                  date: 'August 12, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🌟 What\'s New',
                      items: [
                        'Non-Blocking Background SMS Import: Automatically scan bank transactions in the background with a floating live progress indicator while you continue using the app.',
                        'Advanced SMS Range & Tombstones: Import recent or full historical bank SMS with 30-day auto-purge retention and tombstone protection to prevent re-importing deleted items.',
                        'Smart Toolbar & Precision Text Selection: Fine-tune cursor placement character-by-character or word-by-word, and enjoy intelligent toolbar layouts that adapt to your device\'s hardware AI capabilities.',
                        'Friendly Device Naming & Multi-Network P2P: Automatically generate memorable paired device names and keep P2P sync connected across home, work, and mobile Wi-Fi networks.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Hardware-Aware Onboarding: Clear status indicators differentiate Android AI Core NPU hardware from offline rule-based NLP engines during setup.',
                        'Material 3 Depth & Ink Polish: Seamless borderless top app bar, frosted glass navigation depth, and material ripple splash protections across search overlays and finance cards.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Finance Provider & Exception Guard: Resolved root provider scoping for finance screens and fixed ListTile container material assertions.',
                        'Pairing & Scanner Reliability: Reinforced QR code pairing handshakes, camera permission declarations, and multi-endpoint network fallbacks.',
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppLayout.spaceXL),
                _buildVersionSection(
                  context,
                  version: 'v2.16.0',
                  date: 'August 11, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🌟 What\'s New',
                      items: [
                        'Smarter Device Sync: Give each paired device a name and keep it connected across home, work, and other Wi-Fi networks.',
                        'Precision Text Selection: Use the new cursor tool in the note editor to adjust selected text one character or word at a time.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Clearer Editor Tools: AI Assist and Precision Selection now have their own toolbar buttons, keeping writing tools easier to find.',
                        'Faster Navigation: Search now surfaces P2P Sync and more settings shortcuts, while long-pressing a note makes moving it to a folder quicker.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Reliable Pairing & Scanning: Pairing is confirmed before it is saved, remembers alternate Wi-Fi connections, and QR scanning now requests camera access correctly.',
                        'Editor & Data Stability: Improved selection-toolbar layout, table editing behavior, and fresh-install database setup.',
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppLayout.spaceXL),
                _buildVersionSection(
                  context,
                  version: 'v2.14.0',
                  date: 'August 5, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🌟 What\'s New',
                      items: [
                        'Bi-Directional P2P Wi-Fi Sync: Seamlessly merge notes, financial ledgers, and settings between devices over Wi-Fi non-destructively without losing local edits.',
                        'Reliable SMS Auto-Sync Engine: Background bank transaction sync now runs reliably with 48-hour catch-up sync for offline devices, live status badges, and a 1-tap "Sync SMS Now" test action.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Ultra-Smooth Text Selection: Fixed keyboard D-Pad arrow key navigation and text selection lag in the editor for instant, stutter-free typing.',
                        'Dynamic Light & Dark Hero Cards: Hero cards dynamically adjust pastel opacities in Light Mode and deep translucent fills in Dark Mode for crisp visual contrast.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Database Subtype Options Safety: Resolved database option type casting issues for encrypted local storage.',
                        'Onboarding P2P Entry Point: Verified seamless navigation from initial onboarding tips to the P2P device sync hub.',
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppLayout.spaceXL),
                _buildVersionSection(
                  context,
                  version: 'v2.13.0',
                  date: 'August 5, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🌟 What\'s New',
                      items: [
                        'Bi-Directional Delta Merge P2P Sync: Seamlessly merge notes, financial ledgers, and settings between devices over Wi-Fi without losing local edits or moving soft-deleted items back to the inbox.',
                        'Interactive Onboarding & What\'s New Entry Points: Pair and sync devices directly during app setup or explore new features with 1-tap action buttons in the What\'s New sheet.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Material 3 Expressive Sync Hub: Redesigned P2P control center with dynamic status cards, 1-tap IP & pair code copying, and individual device sync actions.',
                        'Robust Network & VPN Handling: Smart socket binding and local IP discovery support DHCP changes and VPN split-tunneling cleanly.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Dual-Device Pairing Detection: Fixed issue where paired devices were not displayed symmetrically on both host and scanner devices.',
                        'Trash-Moving Sync Guardrail: Soft-deleted notes remain cleanly in the Trash across devices without reappearing in active note lists.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.12.0',
                  date: 'August 5, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🌟 What\'s New',
                      items: [
                        'Fast Local Master Device Sync: Transfer your complete notebook between devices instantly over your local network using direct REST connections.',
                        'Onboarding Setup Mode Choices: Choose to set up a new primary notebook or pair and import from an existing phone during initial app setup.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Permission-Lean Privacy: Removed unnecessary Bluetooth and location permission requests for a cleaner experience.',
                        'Clear Master Overwrite Warnings: Helpful warning dialogs explain Primary and Secondary device roles before replacing secondary device data.',
                        'Landscape & Tablet FAB Access: Access the "New Note" button seamlessly in portrait, landscape, and tablet modes.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Single-Device Deduplication: Prevents duplicate device entries when pairing devices.',
                        'Ultra-Fast Network Sockets: Replaced legacy Bluetooth connections with fast local REST sockets for zero-freeze syncing.',
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppLayout.spaceXL),
                _buildVersionSection(
                  context,
                  version: 'v2.11.1',
                  date: 'August 1, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🌟 What\'s New',
                      items: [
                        'Keyboard-Aware Note Editor: Formatting tools now stay accessible directly above the soft keyboard, and the note editor auto-scrolls to keep your active typing line visible as you type long notes.',
                        'Full-Screen Setup Wizard: Customise your app theme, preferences, and local AI options right from the start.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Refreshed Material 3 Design: Enjoy modern rounded cards, fluid animations, dynamic typography scaling, and a cleaner control center.',
                        'Quick Keyboard Dismiss: Tap the new Hide Keyboard button on the note editor toolbar anytime to instantly dismiss the keyboard.',
                        'Smarter Search & Folders: Easily search across settings and notes, and organize your ideas into folders.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Note Editor Keyboard & Text Visibility: Resolved an issue where the software keyboard obscured long note text and hid formatting action bars during typing.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.11.0',
                  date: 'August 1, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🌟 What\'s New',
                      items: [
                        'Full-Screen Setup Wizard: Customise your app theme, preferences, and local AI options right from the start.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Refreshed Material 3 Design: Enjoy modern rounded cards, fluid animations, and a cleaner control center.',
                        'Smarter Search & Folders: Easily search across settings and notes, and organize your ideas into folders.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Interactive Checklist Polish: Toggling checklist items in notes is now smoother and more reliable.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.10.0',
                  date: 'July 30, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🌟 What\'s New',
                      items: [
                        'Full-Screen Setup Wizard: Customise your app theme, preferences, and local AI options right from the start.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Refreshed Material 3 Design: Enjoy modern rounded cards, fluid animations, and a cleaner control center.',
                        'Smarter Search & Folders: Easily search across settings and notes, and organize your ideas into folders.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Interactive Checklist Polish: Toggling checklist items in notes is now smoother and more reliable.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.9.1',
                  date: 'July 29, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Unified Frosted Glass Headers: Clean, symmetric top navigation bar across all app screens.',
                        'Single Action Button: Centralized action button floats comfortably above the bottom navigation bar.',
                        'Default Folder Memory: Automatically opens your preferred folder when starting the app.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Light Mode Visual Fixes: Removed double border lines and shadow artifacts for cleaner light mode viewing.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.9.0',
                  date: 'July 29, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🌟 What\'s New',
                      items: [
                        'Material 3 Expressive Look: Dynamic color themes, rounded card hierarchy, and fluid spring animations.',
                        'Glassmorphic Navigation: Symmetric top and bottom frosted glass bars for immersive reading.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Tactile Button Feedback: Improved touch response and haptics across all buttons and menus.',
                        'Health Tracker Readability: High-contrast cards and illuminated cycle phase rings in dark mode.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.8.1',
                  date: 'July 25, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🌟 What\'s New',
                      items: [
                        'Universal Spotlight Search: Search Notes, Settings, Tools, Finances, and Health in one single search bar.',
                        'Instant Filter Chips: Quickly filter search results by Notes, Finances, or Health with one tap.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🐛 Fixes',
                      items: [
                        'Backup & Export Stability: Fixed file sharing fallbacks and prevented note title clipping on cards.',
                        'Handwriting Support: Smooth typing support for S-Pen and Apple Scribble.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.7.0',
                  date: 'July 24, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Instant Settings Search: Search options directly inside the Settings header bar.',
                        'Smarter Expense Analytics: Intelligent spending trend forecasting dampens one-off purchase spikes automatically.',
                      ],
                    ),
                  ],
                ),
                _buildVersionSection(
                  context,
                  version: 'v2.6.0',
                  date: 'July 23, 2026',
                  isLatest: false,
                  changes: [
                    _ChangelogGroup(
                      title: '🌟 What\'s New',
                      items: [
                        'Scheduled Auto-Sync: Schedule daily automatic bank SMS transaction imports at your chosen time.',
                      ],
                    ),
                    _ChangelogGroup(
                      title: '🚀 Improvements',
                      items: [
                        'Note Editor Enhancements: Auto-keyboard focus on new note creation and auto-dismiss on scroll.',
                      ],
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionSection(
    BuildContext context, {
    required String version,
    required String date,
    bool isLatest = false,
    required List<_ChangelogGroup> changes,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppLayout.spaceXL),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isLatest ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 3,
                  ),
                  boxShadow: isLatest
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
              ),
              Container(
                width: 2,
                height: changes.fold<double>(0.0, (acc, item) => acc + (item.items.length * 28.0) + 70.0),
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
          const SizedBox(width: AppLayout.spaceM),
          Expanded(
            child: AppCard(
              backgroundColor: isLatest
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
                  : theme.colorScheme.surfaceContainerLow,
              padding: const EdgeInsets.all(AppLayout.spaceL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            version,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isLatest ? theme.colorScheme.primary : null,
                            ),
                          ),
                          if (isLatest) ...[
                            const SizedBox(width: AppLayout.spaceS),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                              ),
                              child: Text(
                                'LATEST',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        date,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppLayout.spaceM),
                  ...changes.map((group) {
                    final cleanTitle = group.title.replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]', unicode: true), '').trim();
                    IconData groupIcon = Icons.article_outlined;
                    Color iconColor = theme.colorScheme.primary;
                    final lowerTitle = cleanTitle.toLowerCase();
                    if (lowerTitle.contains("what's new") || lowerTitle.contains("feature")) {
                      groupIcon = Icons.auto_awesome_rounded;
                      iconColor = theme.colorScheme.primary;
                    } else if (lowerTitle.contains("improvement")) {
                      groupIcon = Icons.trending_up_rounded;
                      iconColor = theme.colorScheme.tertiary;
                    } else if (lowerTitle.contains("fix")) {
                      groupIcon = Icons.build_circle_outlined;
                      iconColor = theme.colorScheme.secondary;
                    }
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(groupIcon, size: 18, color: iconColor),
                              const SizedBox(width: AppLayout.spaceXS),
                              Text(
                                cleanTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppLayout.spaceS),
                          ...group.items.map((item) => Padding(
                                padding: const EdgeInsets.only(
                                  left: AppLayout.spaceS,
                                  bottom: AppLayout.spaceS,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• ',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        item,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          const SizedBox(height: AppLayout.spaceM),
                        ],
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangelogGroup {
  final String title;
  final List<String> items;

  _ChangelogGroup({
    required this.title,
    required this.items,
  });
}
