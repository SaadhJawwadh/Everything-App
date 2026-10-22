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

  @override
  String get preferencesAndWorkspaces => 'Preferences & Workspaces';

  @override
  String get notesAndEditorWorkspace => 'Notes & Editor Workspace';

  @override
  String get financesAndHealthModules => 'Finances & Health Modules';

  @override
  String get privacyAndSecurity => 'Privacy & Security';

  @override
  String get syncAndBackups => 'Sync & Backups';

  @override
  String get aboutAndDeviceAi => 'About & Device AI';

  @override
  String get startFromTemplate => 'Start from a template';

  @override
  String get templateMeetingNotes => 'Meeting Notes';

  @override
  String get templateMeetingNotesDesc => 'Agenda, discussion, and action items';

  @override
  String get templateShoppingList => 'Shopping List';

  @override
  String get templateShoppingListDesc => 'A ready-to-tick checklist';

  @override
  String get templateJournal => 'Journal';

  @override
  String get templateJournalDesc => 'Daily reflection prompts';

  @override
  String get themeAndColorSystem => 'Theme & Color System';

  @override
  String get appThemeMode => 'App Theme Mode';

  @override
  String get dynamicWallpaperTheme => 'Dynamic Wallpaper Theme';

  @override
  String get dynamicWallpaperSubtitle =>
      'Match app colors with device wallpaper (Android 12+)';

  @override
  String get interactionAndAccessibility => 'Interaction & Accessibility';

  @override
  String get tactileHaptics => 'Tactile Haptics';

  @override
  String get tactileHapticsSubtitle =>
      'Restrained physical feedback for sliders, long-press, and actions';

  @override
  String get textScale => 'Text Scale';

  @override
  String get textScaleSubtitle => 'Global font sizing';

  @override
  String get textScaleSmall => 'Small';

  @override
  String get textScaleMedium => 'Medium';

  @override
  String get textScaleLarge => 'Large';

  @override
  String get appLanguage => 'App Language';

  @override
  String get selectCurrency => 'Select Currency';

  @override
  String noSettingsFound(String query) {
    return 'No settings matching \"$query\"';
  }

  @override
  String get quickSuggestions => 'Quick suggestions:';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get deselectAll => 'Deselect all';

  @override
  String get closeSearch => 'Close search';

  @override
  String get clearQuery => 'Clear query';

  @override
  String get createNewFolder => 'Create New Folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get filterByFolder => 'Filter by folder';

  @override
  String get newFolder => 'New Folder';

  @override
  String get allNotes => 'All Notes';

  @override
  String get checklistsAndTasks => 'Checklists & Tasks';

  @override
  String get archivedNotes => 'Archived Notes';

  @override
  String get trashBin => 'Trash Bin';

  @override
  String get sortNotes => 'Sort notes';

  @override
  String get sortByLastModified => 'Sort by Last Modified';

  @override
  String get sortByDateCreated => 'Sort by Date Created';

  @override
  String get sortByTitle => 'Sort by Title';

  @override
  String get sortByColor => 'Sort by Color';

  @override
  String get importNotes => 'Import Notes';

  @override
  String get switchToGridView => 'Switch to grid view';

  @override
  String get switchToListView => 'Switch to list view';

  @override
  String get selectPeriod => 'Select Period';

  @override
  String get thisMonth => 'This Month';

  @override
  String get lastMonth => 'Last Month';

  @override
  String get last90Days => 'Last 90 Days';

  @override
  String get thisYear => 'This Year';

  @override
  String get allTime => 'All Time (Full History)';

  @override
  String get customDateRange => 'Custom Date Range…';

  @override
  String get customDateRangeSubtitle =>
      'Pick exact start and end dates from calendar';

  @override
  String allTasksCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count tasks completed',
      one: 'All 1 task completed',
    );
    return '$_temp0';
  }

  @override
  String moreItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more items',
      one: '1 more item',
    );
    return '+$_temp0';
  }

  @override
  String get manageCategories => 'Manage Categories';

  @override
  String get restoreDefaults => 'Restore defaults';

  @override
  String get restoreDefaultCategoriesTitle => 'Restore default categories?';

  @override
  String get restoreDefaultCategoriesContent =>
      'Custom categories will be removed and built-in categories reset to their default colors and keywords. Existing transactions keep their category labels.';

  @override
  String get categoriesRestored => 'Categories restored to defaults';

  @override
  String get newCategory => 'New Category';

  @override
  String get editCategory => 'Edit Category';

  @override
  String get categoryName => 'Category Name';

  @override
  String get categoryNameRequired => 'Category name required';

  @override
  String get categoryNameExists => 'Category name already exists';

  @override
  String get icon => 'Icon';

  @override
  String get colour => 'Colour';

  @override
  String get keywords => 'Keywords';

  @override
  String get addKeywordHint => 'Add keyword…';

  @override
  String get noKeywords => 'No keywords';

  @override
  String get deleteCategoryTooltip => 'Delete category';

  @override
  String get editCategoryTooltip => 'Edit category';

  @override
  String get cannotDeleteOtherCategory =>
      'The \"Other\" fallback category cannot be deleted.';

  @override
  String deleteCategoryTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteCategoryContent =>
      'Existing transactions with this category will be reassigned to \"Other\" so your history stays intact.';

  @override
  String get cyclePhaseGuide => 'Cycle Phase Guide';

  @override
  String get menstrualPhase => 'Menstrual Phase';

  @override
  String get menstrualPhaseDays => 'Days 1–5';

  @override
  String get menstrualPhaseDesc =>
      'Uterine lining sheds. Energy is lower; prioritize rest, hydration, and gentle movement.';

  @override
  String get follicularPhase => 'Follicular Phase';

  @override
  String get follicularPhaseDays => 'Days 6–13';

  @override
  String get follicularPhaseDesc =>
      'Estrogen rises as follicles mature. Energy, mood, and creative focus naturally peak.';

  @override
  String get ovulatoryPhase => 'Ovulatory Phase';

  @override
  String get ovulatoryPhaseDays => 'Days 14–16';

  @override
  String get ovulatoryPhaseDesc =>
      'Luteinizing hormone surge triggers egg release. Peak confidence, social energy, and fertility.';

  @override
  String get lutealPhase => 'Luteal Phase';

  @override
  String get lutealPhaseDays => 'Days 17–28';

  @override
  String get lutealPhaseDesc =>
      'Progesterone rises. Energy turns inward; PMS symptoms may occur. Prioritize winding down.';

  @override
  String get symptomCramps => 'Cramps';

  @override
  String get symptomBloating => 'Bloating';

  @override
  String get symptomHeadache => 'Headache';

  @override
  String get symptomFatigue => 'Fatigue';

  @override
  String get symptomAcne => 'Acne';

  @override
  String get symptomMoodSwings => 'Mood Swings';

  @override
  String get symptomNausea => 'Nausea';

  @override
  String get symptomBackache => 'Backache';

  @override
  String get intensityLight => 'Light';

  @override
  String get intensityMedium => 'Medium';

  @override
  String get intensityHeavy => 'Heavy';

  @override
  String get startDateAfterEndDate => 'Start date cannot be after end date';

  @override
  String get overlapDetectedTitle => 'Overlap Detected';

  @override
  String get overlapDetectedMessage =>
      'The selected dates overlap with an existing logged period. Please adjust the dates.';
}
