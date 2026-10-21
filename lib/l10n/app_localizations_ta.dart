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
  String get restore => 'மீட்டெடு';

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
}
