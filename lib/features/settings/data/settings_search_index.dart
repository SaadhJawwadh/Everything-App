import 'package:flutter/material.dart';

/// Single source of truth index item for settings search.
class SettingsIndexItem {
  final String id;
  final String title;
  final String subtitle;
  final String section; // 'Appearance', 'Features', 'Finances', 'Security', 'Data', 'About'
  final IconData icon;
  final List<String> keywords;
  final String? settingKey;

  const SettingsIndexItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.section,
    required this.icon,
    required this.keywords,
    this.settingKey,
  });

  /// Evaluates whether this settings item matches [query] across title, subtitle,
  /// section name, or keyword synonyms.
  bool matches(String query, {String? sectionFilter}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    if (sectionFilter != null && sectionFilter != 'All' && section.toLowerCase() != sectionFilter.toLowerCase()) {
      return false;
    }
    if (title.toLowerCase().contains(q)) return true;
    if (subtitle.toLowerCase().contains(q)) return true;
    if (section.toLowerCase().contains(q)) return true;
    if (keywords.any((k) => k.toLowerCase().contains(q))) return true;
    return false;
  }
}

/// Master index of searchable settings items for both in-settings search and top-bar universal search.
class SettingsSearchIndex {
  static const List<SettingsIndexItem> items = [
    // 1. Appearance
    SettingsIndexItem(
      id: 'theme',
      title: 'Theme',
      subtitle: 'System Default, Light, or OLED Dark mode',
      section: 'Appearance',
      icon: Icons.palette_outlined,
      keywords: ['theme', 'dark mode', 'light mode', 'oled', 'pitch black', 'system theme', 'night mode', 'appearance', 'colors'],
      settingKey: 'themeMode',
    ),
    SettingsIndexItem(
      id: 'dynamic_color',
      title: 'Dynamic Wallpaper Theme',
      subtitle: 'Match app colors with device wallpaper (Android 12+)',
      section: 'Appearance',
      icon: Icons.color_lens_outlined,
      keywords: ['dynamic color', 'material you', 'wallpaper', 'monet', 'accent color', 'palette'],
      settingKey: 'useDynamicColor',
    ),
    SettingsIndexItem(
      id: 'text_size',
      title: 'Text Size',
      subtitle: 'Adjust note editor and UI font scaling',
      section: 'Appearance',
      icon: Icons.text_fields_rounded,
      keywords: ['text size', 'font size', 'scale', 'zoom', 'large text', 'small text', 'reading', 'typography'],
      settingKey: 'textSize',
    ),
    SettingsIndexItem(
      id: 'show_pro_tips',
      title: 'Show Pro-Tips',
      subtitle: 'Rotate actionable powerup tips on home screen',
      section: 'Appearance',
      icon: Icons.lightbulb_outline_rounded,
      keywords: ['tips', 'pro tips', 'hints', 'help', 'powerup', 'guide'],
      settingKey: 'showProTips',
    ),
    SettingsIndexItem(
      id: 'home_screen_widgets',
      title: 'Home Screen Widgets',
      subtitle: 'Pin Checklist, Financial Manager, or Unified Dual-Domain widgets',
      section: 'Appearance',
      icon: Icons.widgets_outlined,
      keywords: ['widget', 'home screen', 'launcher', 'todo widget', 'finance widget', 'pin widget'],
    ),

    // 2. Features & Modules
    SettingsIndexItem(
      id: 'manage_tags',
      title: 'Manage Tags',
      subtitle: 'Rename, colorize, or delete note tags',
      section: 'Features',
      icon: Icons.label_outline_rounded,
      keywords: ['tags', 'labels', 'manage tags', 'tag color', 'rename tag', 'note organization'],
    ),
    SettingsIndexItem(
      id: 'trash_auto_purge',
      title: 'Trash Auto-Purge',
      subtitle: 'Automatically delete notes in trash after 7, 14, or 30 days',
      section: 'Features',
      icon: Icons.auto_delete_outlined,
      keywords: ['trash', 'bin', 'purge', 'auto delete', 'recycle bin', 'permanently delete', 'cleanup'],
      settingKey: 'trashAutoPurgeDays',
    ),
    SettingsIndexItem(
      id: 'gemini_nano_ai',
      title: 'Gemini Nano On-Device AI',
      subtitle: 'Offline note summaries, tag suggestions & smart SMS parsing',
      section: 'Features',
      icon: Icons.auto_awesome_outlined,
      keywords: ['gemini', 'nano', 'ai', 'artificial intelligence', 'summarize', 'offline ai', 'aicore', 'smart parse', 'refine'],
      settingKey: 'useOnDeviceAi',
    ),
    SettingsIndexItem(
      id: 'period_tracker',
      title: 'Period Tracker',
      subtitle: 'Discreet cycle logging, ovulation predictions & moon phase',
      section: 'Features',
      icon: Icons.water_drop_outlined,
      keywords: ['period', 'cycle', 'health', 'menstrual', 'ovulation', 'fertility', 'lunar', 'symptoms'],
      settingKey: 'isPeriodTrackerEnabled',
    ),
    SettingsIndexItem(
      id: 'discreet_health_mode',
      title: 'Discreet Privacy Mode',
      subtitle: 'Conceal cycle day numbers and phases on dashboard with tap-to-reveal',
      section: 'Features',
      icon: Icons.visibility_off_outlined,
      keywords: ['discreet', 'privacy', 'hide cycle', 'period privacy', 'notification text'],
      settingKey: 'isDiscreetHealthMode',
    ),

    // 3. Finances & Banking
    SettingsIndexItem(
      id: 'financial_manager',
      title: 'Financial Manager',
      subtitle: 'Expense tracking, SMS bank ledger & budgets',
      section: 'Finances',
      icon: Icons.account_balance_wallet_outlined,
      keywords: ['finances', 'financial manager', 'money', 'ledger', 'expense', 'income', 'transactions', 'bank'],
      settingKey: 'showFinancialManager',
    ),
    SettingsIndexItem(
      id: 'currency',
      title: 'Currency Symbol & Code',
      subtitle: 'Set preferred authentic currency (Rs., ₹, \$, €, £, ¥, etc.)',
      section: 'Finances',
      icon: Icons.monetization_on_outlined,
      keywords: ['currency', 'symbol', 'dollar', 'rupee', 'euro', 'pound', 'yen', 'rs', 'inr', 'usd', 'money symbol'],
      settingKey: 'currency',
    ),
    SettingsIndexItem(
      id: 'category_budgets',
      title: 'Category Budgets',
      subtitle: 'Set monthly spending limits and budget alerts per category',
      section: 'Finances',
      icon: Icons.pie_chart_outline_rounded,
      keywords: ['budget', 'spending limit', 'target', 'monthly budget', 'category budget', 'alert limit'],
    ),
    SettingsIndexItem(
      id: 'savings_goals',
      title: 'Savings Goals & Vault',
      subtitle: 'Goal-oriented pockets, milestone tracking & vault transfers',
      section: 'Finances',
      icon: Icons.savings_outlined,
      keywords: ['savings', 'savings goals', 'vault', 'piggy bank', 'pocket', 'reserve', 'emergency fund', 'deposit'],
    ),
    SettingsIndexItem(
      id: 'split_bills',
      title: 'Split Bills & Shared Debts',
      subtitle: 'Group bill splitting, participant settlements & WhatsApp reminders',
      section: 'Finances',
      icon: Icons.call_split_rounded,
      keywords: ['split bills', 'split', 'iou', 'shared debt', 'group expense', 'friends', 'settle up', 'whatsapp'],
      settingKey: 'showSplitBills',
    ),
    SettingsIndexItem(
      id: 'sms_auto_sync',
      title: 'SMS Bank Auto-Sync',
      subtitle: 'Daily background SMS transaction import & real-time parser',
      section: 'Finances',
      icon: Icons.sync_outlined,
      keywords: ['sms sync', 'bank sms', 'auto sync', 'daily sync', 'telephony', 'import sms', 'bank parser'],
      settingKey: 'smsAutoSync',
    ),
    SettingsIndexItem(
      id: 'sms_contacts',
      title: 'SMS Contacts & Senders',
      subtitle: 'Manage recognized bank sender IDs and block spam senders',
      section: 'Finances',
      icon: Icons.contacts_outlined,
      keywords: ['sms contacts', 'senders', 'bank senders', 'whitelist', 'blacklist', 'blocked senders'],
    ),
    SettingsIndexItem(
      id: 'sms_rules',
      title: 'SMS Parsing Rules',
      subtitle: 'Custom keywords for income/expense detection & category assignment',
      section: 'Finances',
      icon: Icons.rule_folder_outlined,
      keywords: ['sms rules', 'custom rules', 'parser rules', 'auto categorize', 'keywords', 'train parser'],
    ),
    SettingsIndexItem(
      id: 'recurring_rules',
      title: 'Recurring Transactions',
      subtitle: 'Subscriptions and repeating income/expense cycles',
      section: 'Finances',
      icon: Icons.event_repeat_outlined,
      keywords: ['recurring', 'subscriptions', 'repeating', 'auto pay', 'monthly bill', 'salary'],
    ),

    // 4. Security & Privacy
    SettingsIndexItem(
      id: 'app_lock',
      title: 'App Lock & Security',
      subtitle: 'Biometric fingerprint, Face ID & PIN passcode protection',
      section: 'Security',
      icon: Icons.lock_outlined,
      keywords: ['app lock', 'security', 'pin', 'passcode', 'biometrics', 'fingerprint', 'face unlock', 'privacy', 'timeout', 'lock'],
      settingKey: 'appLockEnabled',
    ),

    // 5. Data & Sync
    SettingsIndexItem(
      id: 'encrypted_backups',
      title: 'Encrypted Backups',
      subtitle: 'AES-256 encrypted JSON backups and automatic protected storage',
      section: 'Data',
      icon: Icons.backup_outlined,
      keywords: ['backup', 'export', 'restore', 'encrypted', 'json', 'saf', 'storage', 'save data', 'cloudless'],
    ),
    SettingsIndexItem(
      id: 'csv_import_export',
      title: 'CSV Import & Export',
      subtitle: 'Import and export transaction records in standard CSV format',
      section: 'Data',
      icon: Icons.file_download_outlined,
      keywords: ['csv', 'excel', 'spreadsheet', 'export csv', 'import csv', 'export transactions'],
    ),
    SettingsIndexItem(
      id: 'google_keep_import',
      title: 'Google Keep Import',
      subtitle: 'Import notes, archives, checklists & images from Google Takeout ZIP',
      section: 'Data',
      icon: Icons.archive_outlined,
      keywords: ['google keep', 'takeout', 'import notes', 'keep notes', 'migration', 'zip import'],
    ),
    SettingsIndexItem(
      id: 'p2p_sync',
      title: 'P2P Device Sync',
      subtitle: 'Sync notes and data directly between devices over local Wi-Fi',
      section: 'Data',
      icon: Icons.devices_rounded,
      keywords: ['sync', 'p2p', 'wifi sync', 'peer to peer', 'device sync', 'beacon', 'pair code', 'qr code'],
    ),
    SettingsIndexItem(
      id: 'database_snapshots',
      title: 'Database Snapshots & Recovery',
      subtitle: 'Inspect or restore rolling pre-migration & pre-sync snapshots',
      section: 'Data',
      icon: Icons.restore_rounded,
      keywords: ['snapshot', 'recovery', 'restore database', 'rollback', 'migration'],
    ),

    // 6. About & System
    SettingsIndexItem(
      id: 'changelog',
      title: 'What\'s New / Changelog',
      subtitle: 'View latest release highlights and version history',
      section: 'About',
      icon: Icons.new_releases_outlined,
      keywords: ['changelog', 'whats new', 'updates', 'version', 'release notes', 'history'],
    ),
    SettingsIndexItem(
      id: 'onboarding_replay',
      title: 'Replay Onboarding',
      subtitle: 'Tour features, personalization, and core architecture setup',
      section: 'About',
      icon: Icons.explore_outlined,
      keywords: ['onboarding', 'tutorial', 'tour', 'setup wizard', 'welcome', 'guide'],
    ),
  ];

  /// Returns all items matching [query], optionally filtered by [section].
  static List<SettingsIndexItem> search(String query, {String? section}) {
    return items.where((item) => item.matches(query, sectionFilter: section)).toList();
  }
}
