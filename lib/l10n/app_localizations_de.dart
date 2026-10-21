// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Everything App';

  @override
  String get navNotes => 'Notizen';

  @override
  String get navFinances => 'Finanzen';

  @override
  String get navTracker => 'Zyklus';

  @override
  String get navSplitBills => 'Rechnungen Teilen';

  @override
  String get greetingMorning => 'Guten Morgen!';

  @override
  String get greetingAfternoon => 'Schon zu Mittag gegessen?';

  @override
  String get greetingEvening => 'Guten Abend!';

  @override
  String get greetingNight => 'Zeit zum Schlafen!';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen',
      one: '1 Notiz',
    );
    return '$_temp0';
  }

  @override
  String get searchNotes => 'Notizen durchsuchen...';

  @override
  String get searchFinances => 'Transaktionen durchsuchen...';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get newNote => 'Neue Notiz';

  @override
  String get newTransaction => 'Neue Transaktion';

  @override
  String get search => 'Suchen';

  @override
  String get save => 'Speichern';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get done => 'Fertig';

  @override
  String get close => 'Schließen';

  @override
  String get filter => 'Filtern';

  @override
  String get sort => 'Sortieren';

  @override
  String get confirm => 'Bestätigen';

  @override
  String get back => 'Zurück';

  @override
  String get copy => 'Kopieren';

  @override
  String get share => 'Teilen';

  @override
  String get clear => 'Löschen';

  @override
  String get apply => 'Anwenden';

  @override
  String get discard => 'Verwerfen';

  @override
  String get undo => 'Rückgängig';

  @override
  String get all => 'Alle';

  @override
  String get copiedToClipboard => 'In die Zwischenablage kopiert';

  @override
  String get pinnedNotes => 'Angeheftete Notizen';

  @override
  String get otherNotes => 'Andere Notizen';

  @override
  String get emptyNotesTitle => 'Noch keine Notizen';

  @override
  String get emptyNotesSubtitle => 'Tippe auf +, um Gedanken festzuhalten';

  @override
  String get archive => 'Archivieren';

  @override
  String get trash => 'Papierkorb';

  @override
  String get restore => 'Wiederherstellen';

  @override
  String get deletePermanently => 'Endgültig löschen';

  @override
  String get lockedNote => 'Gesperrte Notiz';

  @override
  String get appLocked => 'App gesperrt';

  @override
  String get unlock => 'Entsperren';

  @override
  String get noteTitlePlaceholder => 'Titel';

  @override
  String get noteBodyPlaceholder => 'Beginne zu tippen...';

  @override
  String get manageTags => 'Tags verwalten';

  @override
  String get income => 'Einnahmen';

  @override
  String get expense => 'Ausgaben';

  @override
  String get balance => 'Saldo';

  @override
  String get netBalance => 'Nettosaldo';

  @override
  String get monthlySpending => 'Monatliche Ausgaben';

  @override
  String get dailySafeToSpend => 'Heute verfügbar';

  @override
  String get ledger => 'Hauptbuch';

  @override
  String get breakdown => 'Aufschlüsselung';

  @override
  String get budgets => 'Budgets';

  @override
  String get savings => 'Ersparnisse';

  @override
  String get savingsGoals => 'Sparziele';

  @override
  String get deposit => 'Einzahlen';

  @override
  String get dailyAccount => 'Girokonto';

  @override
  String get savingsVault => 'Sparkonto';

  @override
  String get targetAmount => 'Zielbetrag';

  @override
  String get currentAmount => 'Aktueller Betrag';

  @override
  String get noTransactionsYet => 'Noch keine Finanzdaten';

  @override
  String get categories => 'Kategorien';

  @override
  String get splitBillsTitle => 'Rechnungen Teilen';

  @override
  String get settleUp => 'Abrechnen';

  @override
  String get equalSplit => 'Gleichmäßig teilen';

  @override
  String get customSplit => 'Individuell teilen';

  @override
  String get paidBy => 'Bezahlt von';

  @override
  String get sendReminder => 'Erinnerung senden';

  @override
  String cycleDay(int day) {
    return 'Zyklustag $day';
  }

  @override
  String get periodLog => 'Periodenprotokoll';

  @override
  String get symptoms => 'Symptome';

  @override
  String get periodStart => 'Periode begonnen';

  @override
  String get periodEnd => 'Periode beendet';

  @override
  String get regular => 'Regelmäßig';

  @override
  String get irregular => 'Unregelmäßig';

  @override
  String get appearance => 'Erscheinungsbild';

  @override
  String get theme => 'Design';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get themeSystem => 'Systemstandard';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'Systemstandard';

  @override
  String get currency => 'Währung';

  @override
  String get security => 'Sicherheit & Datenschutz';

  @override
  String get backupRestore => 'Sicherung & Wiederherstellung';

  @override
  String get about => 'Über die App';

  @override
  String get onDeviceAi => 'On-Device KI';
}
