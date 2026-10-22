import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('pt'),
    Locale('ru'),
    Locale('ta'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Everything App'**
  String get appTitle;

  /// No description provided for @navNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get navNotes;

  /// No description provided for @navFinances.
  ///
  /// In en, this message translates to:
  /// **'Finances'**
  String get navFinances;

  /// No description provided for @navTracker.
  ///
  /// In en, this message translates to:
  /// **'Tracker'**
  String get navTracker;

  /// No description provided for @navSplitBills.
  ///
  /// In en, this message translates to:
  /// **'Split Bills'**
  String get navSplitBills;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning, Sun Shine!'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Had Lunch?'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening!'**
  String get greetingEvening;

  /// No description provided for @greetingNight.
  ///
  /// In en, this message translates to:
  /// **'Time to sleep!'**
  String get greetingNight;

  /// No description provided for @noteCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 note} other{{count} notes}}'**
  String noteCount(int count);

  /// No description provided for @searchNotes.
  ///
  /// In en, this message translates to:
  /// **'Search notes...'**
  String get searchNotes;

  /// No description provided for @searchFinances.
  ///
  /// In en, this message translates to:
  /// **'Search transactions...'**
  String get searchFinances;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @newNote.
  ///
  /// In en, this message translates to:
  /// **'New Note'**
  String get newNote;

  /// No description provided for @newTransaction.
  ///
  /// In en, this message translates to:
  /// **'New Transaction'**
  String get newTransaction;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @pinnedNotes.
  ///
  /// In en, this message translates to:
  /// **'Pinned Notes'**
  String get pinnedNotes;

  /// No description provided for @otherNotes.
  ///
  /// In en, this message translates to:
  /// **'Other Notes'**
  String get otherNotes;

  /// No description provided for @emptyNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get emptyNotesTitle;

  /// No description provided for @emptyNotesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap + to capture your thoughts'**
  String get emptyNotesSubtitle;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @trash.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trash;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @deletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete Permanently'**
  String get deletePermanently;

  /// No description provided for @lockedNote.
  ///
  /// In en, this message translates to:
  /// **'Locked note'**
  String get lockedNote;

  /// No description provided for @appLocked.
  ///
  /// In en, this message translates to:
  /// **'App Locked'**
  String get appLocked;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @noteTitlePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get noteTitlePlaceholder;

  /// No description provided for @noteBodyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Start typing...'**
  String get noteBodyPlaceholder;

  /// No description provided for @manageTags.
  ///
  /// In en, this message translates to:
  /// **'Manage Tags'**
  String get manageTags;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @netBalance.
  ///
  /// In en, this message translates to:
  /// **'Net Balance'**
  String get netBalance;

  /// No description provided for @monthlySpending.
  ///
  /// In en, this message translates to:
  /// **'Monthly Spending'**
  String get monthlySpending;

  /// No description provided for @dailySafeToSpend.
  ///
  /// In en, this message translates to:
  /// **'Safe to Spend Today'**
  String get dailySafeToSpend;

  /// No description provided for @ledger.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get ledger;

  /// No description provided for @breakdown.
  ///
  /// In en, this message translates to:
  /// **'Breakdown'**
  String get breakdown;

  /// No description provided for @budgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get budgets;

  /// No description provided for @savings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get savings;

  /// No description provided for @savingsGoals.
  ///
  /// In en, this message translates to:
  /// **'Savings Goals'**
  String get savingsGoals;

  /// No description provided for @deposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get deposit;

  /// No description provided for @dailyAccount.
  ///
  /// In en, this message translates to:
  /// **'Daily Account'**
  String get dailyAccount;

  /// No description provided for @savingsVault.
  ///
  /// In en, this message translates to:
  /// **'Savings Vault'**
  String get savingsVault;

  /// No description provided for @targetAmount.
  ///
  /// In en, this message translates to:
  /// **'Target Amount'**
  String get targetAmount;

  /// No description provided for @currentAmount.
  ///
  /// In en, this message translates to:
  /// **'Current Amount'**
  String get currentAmount;

  /// No description provided for @noTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No financial data yet'**
  String get noTransactionsYet;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @splitBillsTitle.
  ///
  /// In en, this message translates to:
  /// **'Split Bills'**
  String get splitBillsTitle;

  /// No description provided for @settleUp.
  ///
  /// In en, this message translates to:
  /// **'Settle Up'**
  String get settleUp;

  /// No description provided for @equalSplit.
  ///
  /// In en, this message translates to:
  /// **'Equal Split'**
  String get equalSplit;

  /// No description provided for @customSplit.
  ///
  /// In en, this message translates to:
  /// **'Custom Split'**
  String get customSplit;

  /// No description provided for @paidBy.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get paidBy;

  /// No description provided for @sendReminder.
  ///
  /// In en, this message translates to:
  /// **'Send Reminder'**
  String get sendReminder;

  /// No description provided for @cycleDay.
  ///
  /// In en, this message translates to:
  /// **'Cycle Day {day}'**
  String cycleDay(int day);

  /// No description provided for @periodLog.
  ///
  /// In en, this message translates to:
  /// **'Period Log'**
  String get periodLog;

  /// No description provided for @symptoms.
  ///
  /// In en, this message translates to:
  /// **'Symptoms'**
  String get symptoms;

  /// No description provided for @periodStart.
  ///
  /// In en, this message translates to:
  /// **'Period Started'**
  String get periodStart;

  /// No description provided for @periodEnd.
  ///
  /// In en, this message translates to:
  /// **'Period Ended'**
  String get periodEnd;

  /// No description provided for @regular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get regular;

  /// No description provided for @irregular.
  ///
  /// In en, this message translates to:
  /// **'Irregular'**
  String get irregular;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance & UI'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get themeSystem;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get languageSystem;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security & Privacy'**
  String get security;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupRestore;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @onDeviceAi.
  ///
  /// In en, this message translates to:
  /// **'On-Device AI'**
  String get onDeviceAi;

  /// No description provided for @preferencesAndWorkspaces.
  ///
  /// In en, this message translates to:
  /// **'Preferences & Workspaces'**
  String get preferencesAndWorkspaces;

  /// No description provided for @notesAndEditorWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Notes & Editor Workspace'**
  String get notesAndEditorWorkspace;

  /// No description provided for @financesAndHealthModules.
  ///
  /// In en, this message translates to:
  /// **'Finances & Health Modules'**
  String get financesAndHealthModules;

  /// No description provided for @privacyAndSecurity.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get privacyAndSecurity;

  /// No description provided for @syncAndBackups.
  ///
  /// In en, this message translates to:
  /// **'Sync & Backups'**
  String get syncAndBackups;

  /// No description provided for @aboutAndDeviceAi.
  ///
  /// In en, this message translates to:
  /// **'About & Device AI'**
  String get aboutAndDeviceAi;

  /// No description provided for @startFromTemplate.
  ///
  /// In en, this message translates to:
  /// **'Start from a template'**
  String get startFromTemplate;

  /// No description provided for @templateMeetingNotes.
  ///
  /// In en, this message translates to:
  /// **'Meeting Notes'**
  String get templateMeetingNotes;

  /// No description provided for @templateMeetingNotesDesc.
  ///
  /// In en, this message translates to:
  /// **'Agenda, discussion, and action items'**
  String get templateMeetingNotesDesc;

  /// No description provided for @templateShoppingList.
  ///
  /// In en, this message translates to:
  /// **'Shopping List'**
  String get templateShoppingList;

  /// No description provided for @templateShoppingListDesc.
  ///
  /// In en, this message translates to:
  /// **'A ready-to-tick checklist'**
  String get templateShoppingListDesc;

  /// No description provided for @templateJournal.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get templateJournal;

  /// No description provided for @templateJournalDesc.
  ///
  /// In en, this message translates to:
  /// **'Daily reflection prompts'**
  String get templateJournalDesc;

  /// No description provided for @themeAndColorSystem.
  ///
  /// In en, this message translates to:
  /// **'Theme & Color System'**
  String get themeAndColorSystem;

  /// No description provided for @appThemeMode.
  ///
  /// In en, this message translates to:
  /// **'App Theme Mode'**
  String get appThemeMode;

  /// No description provided for @dynamicWallpaperTheme.
  ///
  /// In en, this message translates to:
  /// **'Dynamic Wallpaper Theme'**
  String get dynamicWallpaperTheme;

  /// No description provided for @dynamicWallpaperSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Match app colors with device wallpaper (Android 12+)'**
  String get dynamicWallpaperSubtitle;

  /// No description provided for @interactionAndAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Interaction & Accessibility'**
  String get interactionAndAccessibility;

  /// No description provided for @tactileHaptics.
  ///
  /// In en, this message translates to:
  /// **'Tactile Haptics'**
  String get tactileHaptics;

  /// No description provided for @tactileHapticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restrained physical feedback for sliders, long-press, and actions'**
  String get tactileHapticsSubtitle;

  /// No description provided for @textScale.
  ///
  /// In en, this message translates to:
  /// **'Text Scale'**
  String get textScale;

  /// No description provided for @textScaleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Global font sizing'**
  String get textScaleSubtitle;

  /// No description provided for @textScaleSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get textScaleSmall;

  /// No description provided for @textScaleMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get textScaleMedium;

  /// No description provided for @textScaleLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get textScaleLarge;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguage;

  /// No description provided for @selectCurrency.
  ///
  /// In en, this message translates to:
  /// **'Select Currency'**
  String get selectCurrency;

  /// No description provided for @noSettingsFound.
  ///
  /// In en, this message translates to:
  /// **'No settings matching \"{query}\"'**
  String noSettingsFound(String query);

  /// No description provided for @quickSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Quick suggestions:'**
  String get quickSuggestions;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 selected} other{{count} selected}}'**
  String selectedCount(int count);

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get deselectAll;

  /// No description provided for @closeSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get closeSearch;

  /// No description provided for @clearQuery.
  ///
  /// In en, this message translates to:
  /// **'Clear query'**
  String get clearQuery;

  /// No description provided for @createNewFolder.
  ///
  /// In en, this message translates to:
  /// **'Create New Folder'**
  String get createNewFolder;

  /// No description provided for @folderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderName;

  /// No description provided for @filterByFolder.
  ///
  /// In en, this message translates to:
  /// **'Filter by folder'**
  String get filterByFolder;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get newFolder;

  /// No description provided for @allNotes.
  ///
  /// In en, this message translates to:
  /// **'All Notes'**
  String get allNotes;

  /// No description provided for @checklistsAndTasks.
  ///
  /// In en, this message translates to:
  /// **'Checklists & Tasks'**
  String get checklistsAndTasks;

  /// No description provided for @archivedNotes.
  ///
  /// In en, this message translates to:
  /// **'Archived Notes'**
  String get archivedNotes;

  /// No description provided for @trashBin.
  ///
  /// In en, this message translates to:
  /// **'Trash Bin'**
  String get trashBin;

  /// No description provided for @sortNotes.
  ///
  /// In en, this message translates to:
  /// **'Sort notes'**
  String get sortNotes;

  /// No description provided for @sortByLastModified.
  ///
  /// In en, this message translates to:
  /// **'Sort by Last Modified'**
  String get sortByLastModified;

  /// No description provided for @sortByDateCreated.
  ///
  /// In en, this message translates to:
  /// **'Sort by Date Created'**
  String get sortByDateCreated;

  /// No description provided for @sortByTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort by Title'**
  String get sortByTitle;

  /// No description provided for @sortByColor.
  ///
  /// In en, this message translates to:
  /// **'Sort by Color'**
  String get sortByColor;

  /// No description provided for @importNotes.
  ///
  /// In en, this message translates to:
  /// **'Import Notes'**
  String get importNotes;

  /// No description provided for @switchToGridView.
  ///
  /// In en, this message translates to:
  /// **'Switch to grid view'**
  String get switchToGridView;

  /// No description provided for @switchToListView.
  ///
  /// In en, this message translates to:
  /// **'Switch to list view'**
  String get switchToListView;

  /// No description provided for @selectPeriod.
  ///
  /// In en, this message translates to:
  /// **'Select Period'**
  String get selectPeriod;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @lastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last Month'**
  String get lastMonth;

  /// No description provided for @last90Days.
  ///
  /// In en, this message translates to:
  /// **'Last 90 Days'**
  String get last90Days;

  /// No description provided for @thisYear.
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get thisYear;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All Time (Full History)'**
  String get allTime;

  /// No description provided for @customDateRange.
  ///
  /// In en, this message translates to:
  /// **'Custom Date Range…'**
  String get customDateRange;

  /// No description provided for @customDateRangeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick exact start and end dates from calendar'**
  String get customDateRangeSubtitle;

  /// No description provided for @allTasksCompleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{All 1 task completed} other{All {count} tasks completed}}'**
  String allTasksCompleted(int count);

  /// No description provided for @moreItems.
  ///
  /// In en, this message translates to:
  /// **'+{count, plural, =1{1 more item} other{{count} more items}}'**
  String moreItems(int count);

  /// No description provided for @manageCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage Categories'**
  String get manageCategories;

  /// No description provided for @restoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get restoreDefaults;

  /// No description provided for @restoreDefaultCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore default categories?'**
  String get restoreDefaultCategoriesTitle;

  /// No description provided for @restoreDefaultCategoriesContent.
  ///
  /// In en, this message translates to:
  /// **'Custom categories will be removed and built-in categories reset to their default colors and keywords. Existing transactions keep their category labels.'**
  String get restoreDefaultCategoriesContent;

  /// No description provided for @categoriesRestored.
  ///
  /// In en, this message translates to:
  /// **'Categories restored to defaults'**
  String get categoriesRestored;

  /// No description provided for @newCategory.
  ///
  /// In en, this message translates to:
  /// **'New Category'**
  String get newCategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get editCategory;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category Name'**
  String get categoryName;

  /// No description provided for @categoryNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Category name required'**
  String get categoryNameRequired;

  /// No description provided for @categoryNameExists.
  ///
  /// In en, this message translates to:
  /// **'Category name already exists'**
  String get categoryNameExists;

  /// No description provided for @icon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get icon;

  /// No description provided for @colour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get colour;

  /// No description provided for @keywords.
  ///
  /// In en, this message translates to:
  /// **'Keywords'**
  String get keywords;

  /// No description provided for @addKeywordHint.
  ///
  /// In en, this message translates to:
  /// **'Add keyword…'**
  String get addKeywordHint;

  /// No description provided for @noKeywords.
  ///
  /// In en, this message translates to:
  /// **'No keywords'**
  String get noKeywords;

  /// No description provided for @deleteCategoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete category'**
  String get deleteCategoryTooltip;

  /// No description provided for @editCategoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategoryTooltip;

  /// No description provided for @cannotDeleteOtherCategory.
  ///
  /// In en, this message translates to:
  /// **'The \"Other\" fallback category cannot be deleted.'**
  String get cannotDeleteOtherCategory;

  /// No description provided for @deleteCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteCategoryTitle(String name);

  /// No description provided for @deleteCategoryContent.
  ///
  /// In en, this message translates to:
  /// **'Existing transactions with this category will be reassigned to \"Other\" so your history stays intact.'**
  String get deleteCategoryContent;

  /// No description provided for @cyclePhaseGuide.
  ///
  /// In en, this message translates to:
  /// **'Cycle Phase Guide'**
  String get cyclePhaseGuide;

  /// No description provided for @menstrualPhase.
  ///
  /// In en, this message translates to:
  /// **'Menstrual Phase'**
  String get menstrualPhase;

  /// No description provided for @menstrualPhaseDays.
  ///
  /// In en, this message translates to:
  /// **'Days 1–5'**
  String get menstrualPhaseDays;

  /// No description provided for @menstrualPhaseDesc.
  ///
  /// In en, this message translates to:
  /// **'Uterine lining sheds. Energy is lower; prioritize rest, hydration, and gentle movement.'**
  String get menstrualPhaseDesc;

  /// No description provided for @follicularPhase.
  ///
  /// In en, this message translates to:
  /// **'Follicular Phase'**
  String get follicularPhase;

  /// No description provided for @follicularPhaseDays.
  ///
  /// In en, this message translates to:
  /// **'Days 6–13'**
  String get follicularPhaseDays;

  /// No description provided for @follicularPhaseDesc.
  ///
  /// In en, this message translates to:
  /// **'Estrogen rises as follicles mature. Energy, mood, and creative focus naturally peak.'**
  String get follicularPhaseDesc;

  /// No description provided for @ovulatoryPhase.
  ///
  /// In en, this message translates to:
  /// **'Ovulatory Phase'**
  String get ovulatoryPhase;

  /// No description provided for @ovulatoryPhaseDays.
  ///
  /// In en, this message translates to:
  /// **'Days 14–16'**
  String get ovulatoryPhaseDays;

  /// No description provided for @ovulatoryPhaseDesc.
  ///
  /// In en, this message translates to:
  /// **'Luteinizing hormone surge triggers egg release. Peak confidence, social energy, and fertility.'**
  String get ovulatoryPhaseDesc;

  /// No description provided for @lutealPhase.
  ///
  /// In en, this message translates to:
  /// **'Luteal Phase'**
  String get lutealPhase;

  /// No description provided for @lutealPhaseDays.
  ///
  /// In en, this message translates to:
  /// **'Days 17–28'**
  String get lutealPhaseDays;

  /// No description provided for @lutealPhaseDesc.
  ///
  /// In en, this message translates to:
  /// **'Progesterone rises. Energy turns inward; PMS symptoms may occur. Prioritize winding down.'**
  String get lutealPhaseDesc;

  /// No description provided for @symptomCramps.
  ///
  /// In en, this message translates to:
  /// **'Cramps'**
  String get symptomCramps;

  /// No description provided for @symptomBloating.
  ///
  /// In en, this message translates to:
  /// **'Bloating'**
  String get symptomBloating;

  /// No description provided for @symptomHeadache.
  ///
  /// In en, this message translates to:
  /// **'Headache'**
  String get symptomHeadache;

  /// No description provided for @symptomFatigue.
  ///
  /// In en, this message translates to:
  /// **'Fatigue'**
  String get symptomFatigue;

  /// No description provided for @symptomAcne.
  ///
  /// In en, this message translates to:
  /// **'Acne'**
  String get symptomAcne;

  /// No description provided for @symptomMoodSwings.
  ///
  /// In en, this message translates to:
  /// **'Mood Swings'**
  String get symptomMoodSwings;

  /// No description provided for @symptomNausea.
  ///
  /// In en, this message translates to:
  /// **'Nausea'**
  String get symptomNausea;

  /// No description provided for @symptomBackache.
  ///
  /// In en, this message translates to:
  /// **'Backache'**
  String get symptomBackache;

  /// No description provided for @intensityLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get intensityLight;

  /// No description provided for @intensityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get intensityMedium;

  /// No description provided for @intensityHeavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy'**
  String get intensityHeavy;

  /// No description provided for @startDateAfterEndDate.
  ///
  /// In en, this message translates to:
  /// **'Start date cannot be after end date'**
  String get startDateAfterEndDate;

  /// No description provided for @overlapDetectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Overlap Detected'**
  String get overlapDetectedTitle;

  /// No description provided for @overlapDetectedMessage.
  ///
  /// In en, this message translates to:
  /// **'The selected dates overlap with an existing logged period. Please adjust the dates.'**
  String get overlapDetectedMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'de',
        'en',
        'es',
        'fr',
        'pt',
        'ru',
        'ta',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'ta':
      return AppLocalizationsTa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
