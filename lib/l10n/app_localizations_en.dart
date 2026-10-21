// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Everything App';

  @override
  String get navNotes => 'Notes';

  @override
  String get navFinances => 'Finances';

  @override
  String get navTracker => 'Tracker';

  @override
  String get navSplitBills => 'Split Bills';

  @override
  String get greetingMorning => 'Morning, Sun Shine!';

  @override
  String get greetingAfternoon => 'Had Lunch?';

  @override
  String get greetingEvening => 'Good Evening!';

  @override
  String get greetingNight => 'Time to sleep!';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
    );
    return '$_temp0';
  }

  @override
  String get searchNotes => 'Search notes...';

  @override
  String get searchFinances => 'Search transactions...';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get newNote => 'New Note';

  @override
  String get newTransaction => 'New Transaction';

  @override
  String get search => 'Search';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get done => 'Done';

  @override
  String get close => 'Close';

  @override
  String get filter => 'Filter';

  @override
  String get sort => 'Sort';

  @override
  String get confirm => 'Confirm';

  @override
  String get back => 'Back';

  @override
  String get copy => 'Copy';

  @override
  String get share => 'Share';

  @override
  String get clear => 'Clear';

  @override
  String get apply => 'Apply';

  @override
  String get discard => 'Discard';

  @override
  String get undo => 'Undo';

  @override
  String get all => 'All';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get pinnedNotes => 'Pinned Notes';

  @override
  String get otherNotes => 'Other Notes';

  @override
  String get emptyNotesTitle => 'No notes yet';

  @override
  String get emptyNotesSubtitle => 'Tap + to capture your thoughts';

  @override
  String get archive => 'Archive';

  @override
  String get trash => 'Trash';

  @override
  String get restore => 'Restore';

  @override
  String get deletePermanently => 'Delete Permanently';

  @override
  String get lockedNote => 'Locked note';

  @override
  String get appLocked => 'App Locked';

  @override
  String get unlock => 'Unlock';

  @override
  String get noteTitlePlaceholder => 'Title';

  @override
  String get noteBodyPlaceholder => 'Start typing...';

  @override
  String get manageTags => 'Manage Tags';

  @override
  String get income => 'Income';

  @override
  String get expense => 'Expense';

  @override
  String get balance => 'Balance';

  @override
  String get netBalance => 'Net Balance';

  @override
  String get monthlySpending => 'Monthly Spending';

  @override
  String get dailySafeToSpend => 'Safe to Spend Today';

  @override
  String get ledger => 'Ledger';

  @override
  String get breakdown => 'Breakdown';

  @override
  String get budgets => 'Budgets';

  @override
  String get savings => 'Savings';

  @override
  String get savingsGoals => 'Savings Goals';

  @override
  String get deposit => 'Deposit';

  @override
  String get dailyAccount => 'Daily Account';

  @override
  String get savingsVault => 'Savings Vault';

  @override
  String get targetAmount => 'Target Amount';

  @override
  String get currentAmount => 'Current Amount';

  @override
  String get noTransactionsYet => 'No financial data yet';

  @override
  String get categories => 'Categories';

  @override
  String get splitBillsTitle => 'Split Bills';

  @override
  String get settleUp => 'Settle Up';

  @override
  String get equalSplit => 'Equal Split';

  @override
  String get customSplit => 'Custom Split';

  @override
  String get paidBy => 'Paid by';

  @override
  String get sendReminder => 'Send Reminder';

  @override
  String cycleDay(int day) {
    return 'Cycle Day $day';
  }

  @override
  String get periodLog => 'Period Log';

  @override
  String get symptoms => 'Symptoms';

  @override
  String get periodStart => 'Period Started';

  @override
  String get periodEnd => 'Period Ended';

  @override
  String get regular => 'Regular';

  @override
  String get irregular => 'Irregular';

  @override
  String get appearance => 'Appearance & UI';

  @override
  String get theme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System Default';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System Default';

  @override
  String get currency => 'Currency';

  @override
  String get security => 'Security & Privacy';

  @override
  String get backupRestore => 'Backup & Restore';

  @override
  String get about => 'About';

  @override
  String get onDeviceAi => 'On-Device AI';
}
