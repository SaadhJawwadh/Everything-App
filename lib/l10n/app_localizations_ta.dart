// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get appTitle => 'Everything App';

  @override
  String get navNotes => 'குறிப்புகள்';

  @override
  String get navFinances => 'நிதி';

  @override
  String get navTracker => 'சுழற்சி';

  @override
  String get navSplitBills => 'பில் பகிர்வு';

  @override
  String get greetingMorning => 'காலை வணக்கம்!';

  @override
  String get greetingAfternoon => 'மதிய உணவு சாப்பிட்டீர்களா?';

  @override
  String get greetingEvening => 'மாலை வணக்கம்!';

  @override
  String get greetingNight => 'தூங்க வேண்டிய நேரம்!';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count குறிப்புகள்',
      one: '1 குறிப்பு',
    );
    return '$_temp0';
  }

  @override
  String get searchNotes => 'குறிப்புகளைத் தேடுங்கள்...';

  @override
  String get searchFinances => 'பரிவர்த்தனைகளைத் தேடுங்கள்...';

  @override
  String get settingsTitle => 'அமைப்புகள்';

  @override
  String get newNote => 'புதிய குறிப்பு';

  @override
  String get newTransaction => 'புதிய பரிவர்த்தனை';

  @override
  String get search => 'தேடு';

  @override
  String get save => 'சேமி';

  @override
  String get cancel => 'ரத்து செய்';

  @override
  String get delete => 'நீக்கு';

  @override
  String get edit => 'திருத்து';

  @override
  String get done => 'முடிந்தது';

  @override
  String get close => 'மூடு';

  @override
  String get filter => 'வடிகட்டு';

  @override
  String get sort => 'வரிசைப்படுத்து';

  @override
  String get confirm => 'உறுதிப்படுத்து';

  @override
  String get back => 'பின்செல்';

  @override
  String get copy => 'நகலெடு';

  @override
  String get share => 'பகிர்';

  @override
  String get clear => 'அழி';

  @override
  String get apply => 'பயன்படுத்து';

  @override
  String get discard => 'நிராகரி';

  @override
  String get undo => 'செயல்தவிர்';

  @override
  String get all => 'அனைத்தும்';

  @override
  String get copiedToClipboard => 'கிளிப்போர்டில் நகலெடுக்கப்பட்டது';

  @override
  String get pinnedNotes => 'முக்கிய குறிப்புகள்';

  @override
  String get otherNotes => 'மற்ற குறிப்புகள்';

  @override
  String get emptyNotesTitle => 'குறிப்புகள் எதுவும் இல்லை';

  @override
  String get emptyNotesSubtitle => 'உங்கள் எண்ணங்களை எழுத + தட்டவும்';

  @override
  String get archive => 'காப்பகம்';

  @override
  String get trash => 'குப்பைத்தொட்டி';

  @override
  String get restore => 'மீட்டமை';

  @override
  String get deletePermanently => 'நிரந்தரமாக நீக்கு';

  @override
  String get lockedNote => 'பூட்டிய குறிப்பு';

  @override
  String get appLocked => 'செயலி பூட்டப்பட்டுள்ளது';

  @override
  String get unlock => 'திற';

  @override
  String get noteTitlePlaceholder => 'தலைப்பு';

  @override
  String get noteBodyPlaceholder => 'எழுதத் தொடங்குங்கள்...';

  @override
  String get manageTags => 'குறிச்சொற்கள்';

  @override
  String get income => 'வருமானம்';

  @override
  String get expense => 'செலவு';

  @override
  String get balance => 'இருப்பு';

  @override
  String get netBalance => 'நிகர இருப்பு';

  @override
  String get monthlySpending => 'மாதாந்திர செலவு';

  @override
  String get dailySafeToSpend => 'இன்றைய பாதுகாப்பான செலவு';

  @override
  String get ledger => 'பேரேடு';

  @override
  String get breakdown => 'பகுப்பாய்வு';

  @override
  String get budgets => 'திட்டமிடல்';

  @override
  String get savings => 'சேமிப்பு';

  @override
  String get savingsGoals => 'சேமிப்பு இலக்குகள்';

  @override
  String get deposit => 'வைப்புத்தொகை';

  @override
  String get dailyAccount => 'தினசரி கணக்கு';

  @override
  String get savingsVault => 'சேமிப்பு பெட்டகம்';

  @override
  String get targetAmount => 'இலக்குத் தொகை';

  @override
  String get currentAmount => 'தற்போதைய தொகை';

  @override
  String get noTransactionsYet => 'பரிவர்த்தனைகள் எதுவும் இல்லை';

  @override
  String get categories => 'வகைகள்';

  @override
  String get splitBillsTitle => 'பில் பகிர்வு';

  @override
  String get settleUp => 'கணக்கு முடி';

  @override
  String get equalSplit => 'சம பகிர்வு';

  @override
  String get customSplit => 'தனிப்பயன் பகிர்வு';

  @override
  String get paidBy => 'செலுத்தியவர்';

  @override
  String get sendReminder => 'நினைவூட்டல் அனுப்பு';

  @override
  String cycleDay(int day) {
    return 'சுழற்சி நாள் $day';
  }

  @override
  String get periodLog => 'மாதவிடாய் பதிவு';

  @override
  String get symptoms => 'அறிகுறிகள்';

  @override
  String get periodStart => 'மாதவிடாய் தொடங்கியது';

  @override
  String get periodEnd => 'மாதவிடாய் முடிந்தது';

  @override
  String get regular => 'வழக்கமானது';

  @override
  String get irregular => 'முறையற்றது';

  @override
  String get appearance => 'தோற்றம் & வடிவமைப்பு';

  @override
  String get theme => 'வண்ணக்கலவை';

  @override
  String get themeLight => 'வெளிச்சம்';

  @override
  String get themeDark => 'இருள்';

  @override
  String get themeSystem => 'கணினி இயல்புநிலை';

  @override
  String get language => 'மொழி';

  @override
  String get languageSystem => 'கணினி இயல்புநிலை';

  @override
  String get currency => 'நாணயம்';

  @override
  String get security => 'பாதுகாப்பு & தனியுரிமை';

  @override
  String get backupRestore => 'காப்புப்பிரதி & மீட்பு';

  @override
  String get about => 'பற்றி';

  @override
  String get onDeviceAi => 'சாதனத்தின் உள்ளக AI';

  @override
  String get preferencesAndWorkspaces => 'விருப்பத்தேர்வுகள் & பகுதிகள்';

  @override
  String get notesAndEditorWorkspace => 'குறிப்புகள் & தொகுப்பான்';

  @override
  String get financesAndHealthModules => 'நிதி & நல்வாழ்வு';

  @override
  String get privacyAndSecurity => 'தனியுரிமை & பாதுகாப்பு';

  @override
  String get syncAndBackups => 'ஒத்திசைவு & காப்புநகல்கள்';

  @override
  String get aboutAndDeviceAi => 'பயன்பாடு & செயற்கை நுண்ணறிவு';

  @override
  String get startFromTemplate => 'வார்ப்புருவிலிருந்து தொடங்கவும்';

  @override
  String get templateMeetingNotes => 'கூட்டக் குறிப்புகள்';

  @override
  String get templateMeetingNotesDesc =>
      'நிகழ்ச்சி நிரல், கலந்துரையாடல் மற்றும் பணிகள்';

  @override
  String get templateShoppingList => 'பொருட்கள் பட்டியல்';

  @override
  String get templateShoppingListDesc =>
      'சரிபார்க்கக்கூடிய சரிபார்ப்புப் பட்டியல்';

  @override
  String get templateJournal => 'தினசரி இதழ்';

  @override
  String get templateJournalDesc => 'தினசரி சிந்தனைத் தூண்டல்கள்';

  @override
  String get themeAndColorSystem => 'வண்ண அமைப்பு & தீம்';

  @override
  String get appThemeMode => 'பயன்பாட்டு தீம்';

  @override
  String get dynamicWallpaperTheme => 'வால்பேப்பர் வண்ணங்கள்';

  @override
  String get dynamicWallpaperSubtitle =>
      'சாதன வால்பேப்பருடன் வண்ணங்களை இணைக்கவும் (Android 12+)';

  @override
  String get interactionAndAccessibility => 'பயன்பாடு & அணுகல்தன்மை';

  @override
  String get tactileHaptics => 'தொடுதல் அதிர்வு';

  @override
  String get tactileHapticsSubtitle =>
      'நகர்த்தல்கள் மற்றும் செயல்களுக்கான மெல்லிய அதிர்வு';

  @override
  String get textScale => 'எழுத்து அளவு';

  @override
  String get textScaleSubtitle => 'முழுமையான எழுத்து அளவுரு';

  @override
  String get textScaleSmall => 'சிறியது';

  @override
  String get textScaleMedium => 'நடுத்தரம்';

  @override
  String get textScaleLarge => 'பெரியது';

  @override
  String get appLanguage => 'பயன்பாட்டு மொழி';

  @override
  String get selectCurrency => 'நாணயத்தைத் தேர்ந்தெடுக்கவும்';

  @override
  String noSettingsFound(String query) {
    return '\"$query\" உடன் பொருந்தும் அமைப்புகள் எதுவும் இல்லை';
  }

  @override
  String get quickSuggestions => 'விரைவான பரிந்துரைகள்:';

  @override
  String get clearSelection => 'தேர்வை அழி';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count தேர்ந்தெடுக்கப்பட்டன',
      one: '1 தேர்ந்தெடுக்கப்பட்டது',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'அனைத்தையும் தேர்ந்தெடு';

  @override
  String get deselectAll => 'தேர்வை நீக்கு';

  @override
  String get closeSearch => 'தேடலை மூடு';

  @override
  String get clearQuery => 'தேடலை அழி';

  @override
  String get createNewFolder => 'புதிய கோப்புறையை உருவாக்கு';

  @override
  String get folderName => 'கோப்புறை பெயர்';

  @override
  String get filterByFolder => 'கோப்புறை வாரியாக வடிகட்டு';

  @override
  String get newFolder => 'புதிய கோப்புறை';

  @override
  String get allNotes => 'அனைத்து குறிப்புகள்';

  @override
  String get checklistsAndTasks => 'சரிபார்ப்பு பட்டியல்கள் மற்றும் பணிகள்';

  @override
  String get archivedNotes => 'காப்பகப்படுத்தப்பட்டவை';

  @override
  String get trashBin => 'குப்பைத்தொட்டி';

  @override
  String get sortNotes => 'குறிப்புகளை வரிசைப்படுத்து';

  @override
  String get sortByLastModified => 'கடைசியாக மாற்றியபடி';

  @override
  String get sortByDateCreated => 'உருவாக்கிய தேதிப்படி';

  @override
  String get sortByTitle => 'தலைப்பு வாரியாக';

  @override
  String get sortByColor => 'வண்ணம் வாரியாக';

  @override
  String get importNotes => 'குறிப்புகளை இறக்குமதி செய்';

  @override
  String get switchToGridView => 'கட்டம் பார்வைக்கு மாறு';

  @override
  String get switchToListView => 'பட்டியல் பார்வைக்கு மாறு';

  @override
  String get selectPeriod => 'காலத்தைத் தேர்ந்தெடுக்கவும்';

  @override
  String get thisMonth => 'இந்த மாதம்';

  @override
  String get lastMonth => 'கடந்த மாதம்';

  @override
  String get last90Days => 'கடந்த 90 நாட்கள்';

  @override
  String get thisYear => 'இந்த ஆண்டு';

  @override
  String get allTime => 'முழு வரலாறு';

  @override
  String get customDateRange => 'தனிப்பயன் தேதி வரம்பு…';

  @override
  String get customDateRangeSubtitle =>
      'நாட்காட்டியில் இருந்து தொடக்க மற்றும் முடிவு தேதிகளை தேர்வு செய்க';

  @override
  String allTasksCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'அனைத்து $count பணிகளும் முடிந்தன',
      one: '1 பணியும் முடிந்தது',
    );
    return '$_temp0';
  }

  @override
  String moreItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'மேலும் $count உருப்படிகள்',
      one: 'மேலும் 1 உருப்படி',
    );
    return '+$_temp0';
  }

  @override
  String get manageCategories => 'வகைகளை நிர்வகி';

  @override
  String get restoreDefaults => 'இயல்புநிலையை மீட்டமை';

  @override
  String get restoreDefaultCategoriesTitle => 'இயல்புநிலை வகைகளை மீட்டமைக்கவா?';

  @override
  String get restoreDefaultCategoriesContent =>
      'தனிப்பயன் வகைகள் நீக்கப்படும், மேலும் உள்ளமைக்கப்பட்ட வகைகள் அவற்றின் இயல்புநிலை நிறங்கள் மற்றும் முக்கிய சொற்களுக்கு மீட்டமைக்கப்படும். ஏற்கனவே உள்ள பரிவர்த்தனைகள் அவற்றின் வகை லேபிள்களைத் தக்க வைத்துக் கொள்ளும்.';

  @override
  String get categoriesRestored => 'வகைகள் இயல்புநிலைக்கு மீட்டமைக்கப்பட்டன';

  @override
  String get newCategory => 'புதிய வகை';

  @override
  String get editCategory => 'வகையைத் திருத்து';

  @override
  String get categoryName => 'வகைப் பெயர்';

  @override
  String get categoryNameRequired => 'வகைப் பெயர் தேவை';

  @override
  String get categoryNameExists => 'வகைப் பெயர் ஏற்கனவே உள்ளது';

  @override
  String get icon => 'சின்னம்';

  @override
  String get colour => 'வண்ணம்';

  @override
  String get keywords => 'முக்கிய வார்த்தைகள்';

  @override
  String get addKeywordHint => 'முக்கிய சொல்லைச் சேர்க்கவும்…';

  @override
  String get noKeywords => 'முக்கிய வார்த்தைகள் இல்லை';

  @override
  String get deleteCategoryTooltip => 'வகையை நீக்கு';

  @override
  String get editCategoryTooltip => 'வகையைத் திருத்து';

  @override
  String get cannotDeleteOtherCategory =>
      'இயல்புநிலை \"மற்றவை\" வகையை நீக்க முடியாது.';

  @override
  String deleteCategoryTitle(String name) {
    return '\"$name\" வகையை நீக்கவா?';
  }

  @override
  String get deleteCategoryContent =>
      'உங்கள் வரலாறு மாறாமல் இருக்க இந்த வகையைக் கொண்ட தற்போதைய பரிவர்த்தனைகள் \"மற்றவை\" வகைக்கு மாற்றப்படும்.';

  @override
  String get cyclePhaseGuide => 'சுழற்சி நிலை வழிகாட்டி';

  @override
  String get menstrualPhase => 'மாதவிடாய் நிலை';

  @override
  String get menstrualPhaseDays => 'நாட்கள் 1–5';

  @override
  String get menstrualPhaseDesc =>
      'கருப்பை புறணி வெளியேறுகிறது. ஆற்றல் குறைவாக இருக்கும்; ஓய்வு, நீரேற்றம் மற்றும் மென்மையான அசைவுகளுக்கு முன்னுரிமை கொடுங்கள்.';

  @override
  String get follicularPhase => 'நுண்ணறை நிலை';

  @override
  String get follicularPhaseDays => 'நாட்கள் 6–13';

  @override
  String get follicularPhaseDesc =>
      'நுண்ணறைகள் முதிர்ச்சியடையும் போது ஈஸ்ட்ரோஜன் உயர்கிறது. ஆற்றல், மனநிலை மற்றும் படைப்பாற்றல் உச்சத்தை அடைகின்றன.';

  @override
  String get ovulatoryPhase => 'கருமுட்டை வெளியேற்ற நிலை';

  @override
  String get ovulatoryPhaseDays => 'நாட்கள் 14–16';

  @override
  String get ovulatoryPhaseDesc =>
      'ஹார்மோன் எழுச்சி கருமுட்டை வெளியீட்டைத் தூண்டுகிறது. தன்னம்பிக்கை, சமூக ஆற்றல் மற்றும் கருவுறுதல் உச்சத்தில் இருக்கும்.';

  @override
  String get lutealPhase => 'லூட்டல் நிலை';

  @override
  String get lutealPhaseDays => 'நாட்கள் 17–28';

  @override
  String get lutealPhaseDesc =>
      'புரோஜெஸ்ட்டிரோன் உயர்கிறது. ஆற்றல் குறையலாம்; பி.எம்.எஸ் அறிகுறிகள் ஏற்படலாம். தளர்வுக்கு முன்னுரிமை கொடுங்கள்.';

  @override
  String get symptomCramps => 'தசைப்பிடிப்பு';

  @override
  String get symptomBloating => 'வயிற்று உப்புசம்';

  @override
  String get symptomHeadache => 'தலைவலி';

  @override
  String get symptomFatigue => 'சோர்வு';

  @override
  String get symptomAcne => 'முகப்பரு';

  @override
  String get symptomMoodSwings => 'மனநிலை மாற்றங்கள்';

  @override
  String get symptomNausea => 'குமட்டல்';

  @override
  String get symptomBackache => 'முதுகு வலி';

  @override
  String get intensityLight => 'குறைவு';

  @override
  String get intensityMedium => 'நடுத்தரம்';

  @override
  String get intensityHeavy => 'அதிகம்';

  @override
  String get startDateAfterEndDate =>
      'தொடக்க தேதி முடிவு தேதிக்குப் பிறகு இருக்க முடியாது';

  @override
  String get overlapDetectedTitle => 'முரண்பாடு கண்டறியப்பட்டது';

  @override
  String get overlapDetectedMessage =>
      'தேர்ந்தெடுக்கப்பட்ட தேதிகள் ஏற்கனவே பதிவுசெய்யப்பட்ட மாதவிடாய் காலத்துடன் முரண்படுகின்றன. தேதிகளை சரிசெய்யவும்.';
}
