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
