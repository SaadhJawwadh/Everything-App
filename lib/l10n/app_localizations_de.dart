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

  @override
  String get preferencesAndWorkspaces => 'Einstellungen & Bereiche';

  @override
  String get notesAndEditorWorkspace => 'Notizen & Editor';

  @override
  String get financesAndHealthModules => 'Finanzen & Gesundheit';

  @override
  String get privacyAndSecurity => 'Datenschutz & Sicherheit';

  @override
  String get syncAndBackups => 'Synchronisierung & Backups';

  @override
  String get aboutAndDeviceAi => 'Über die App & KI';

  @override
  String get startFromTemplate => 'Aus Vorlage erstellen';

  @override
  String get templateMeetingNotes => 'Besprechungsnotizen';

  @override
  String get templateMeetingNotesDesc => 'Agenda, Diskussion und Aufgaben';

  @override
  String get templateShoppingList => 'Einkaufsliste';

  @override
  String get templateShoppingListDesc => 'Checkliste zum Abhaken';

  @override
  String get templateJournal => 'Tagebuch';

  @override
  String get templateJournalDesc => 'Tägliche Reflexionsfragen';

  @override
  String get themeAndColorSystem => 'Design & Farbsystem';

  @override
  String get appThemeMode => 'App-Design';

  @override
  String get dynamicWallpaperTheme => 'Dynamische Hintergrundfarben';

  @override
  String get dynamicWallpaperSubtitle =>
      'Farben an das Geräte-Hintergrundbild anpassen (Android 12+)';

  @override
  String get interactionAndAccessibility => 'Interaktion & Barrierefreiheit';

  @override
  String get tactileHaptics => 'Haptisches Feedback';

  @override
  String get tactileHapticsSubtitle =>
      'Dezente Vibration bei Schiebereglern und Aktionen';

  @override
  String get textScale => 'Schriftgröße';

  @override
  String get textScaleSubtitle => 'Globale Textskalierung';

  @override
  String get textScaleSmall => 'Klein';

  @override
  String get textScaleMedium => 'Mittel';

  @override
  String get textScaleLarge => 'Groß';

  @override
  String get appLanguage => 'App-Sprache';

  @override
  String get selectCurrency => 'Währung wählen';

  @override
  String noSettingsFound(String query) {
    return 'Keine Einstellungen für \"$query\" gefunden';
  }

  @override
  String get quickSuggestions => 'Schnellvorschläge:';

  @override
  String get clearSelection => 'Auswahl aufheben';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ausgewählt',
      one: '1 ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Alle auswählen';

  @override
  String get deselectAll => 'Alle abwählen';

  @override
  String get closeSearch => 'Suche schließen';

  @override
  String get clearQuery => 'Eingabe löschen';

  @override
  String get createNewFolder => 'Neuen Ordner erstellen';

  @override
  String get folderName => 'Ordnername';

  @override
  String get filterByFolder => 'Nach Ordner filtern';

  @override
  String get newFolder => 'Neuer Ordner';

  @override
  String get allNotes => 'Alle Notizen';

  @override
  String get checklistsAndTasks => 'Checklisten & Aufgaben';

  @override
  String get archivedNotes => 'Archivierte Notizen';

  @override
  String get trashBin => 'Papierkorb';

  @override
  String get sortNotes => 'Notizen sortieren';

  @override
  String get sortByLastModified => 'Nach Änderungsdatum';

  @override
  String get sortByDateCreated => 'Nach Erstellungsdatum';

  @override
  String get sortByTitle => 'Nach Titel';

  @override
  String get sortByColor => 'Nach Farbe';

  @override
  String get importNotes => 'Notizen importieren';

  @override
  String get switchToGridView => 'Zur Rasteransicht wechseln';

  @override
  String get switchToListView => 'Zur Listenansicht wechseln';

  @override
  String get selectPeriod => 'Zeitraum auswählen';

  @override
  String get thisMonth => 'Diesen Monat';

  @override
  String get lastMonth => 'Letzten Monat';

  @override
  String get last90Days => 'Letzte 90 Tage';

  @override
  String get thisYear => 'Dieses Jahr';

  @override
  String get allTime => 'Gesamter Zeitraum';

  @override
  String get customDateRange => 'Benutzerdefinierter Zeitraum…';

  @override
  String get customDateRangeSubtitle =>
      'Start- und Enddatum im Kalender wählen';

  @override
  String allTasksCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Aufgaben erledigt',
      one: '1 Aufgabe erledigt',
    );
    return '$_temp0';
  }

  @override
  String moreItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weitere Elemente',
      one: '1 weiteres Element',
    );
    return '+$_temp0';
  }

  @override
  String get manageCategories => 'Kategorien verwalten';

  @override
  String get restoreDefaults => 'Standard wiederherstellen';

  @override
  String get restoreDefaultCategoriesTitle =>
      'Standardkategorien wiederherstellen?';

  @override
  String get restoreDefaultCategoriesContent =>
      'Benutzerdefinierte Kategorien werden entfernt und integrierte Kategorien auf ihre Standardfarben und Schlüsselwörter zurückgesetzt. Bestehende Transaktionen behalten ihre Kategoriebezeichnungen.';

  @override
  String get categoriesRestored => 'Kategorien auf Standard zurückgesetzt';

  @override
  String get newCategory => 'Neue Kategorie';

  @override
  String get editCategory => 'Kategorie bearbeiten';

  @override
  String get categoryName => 'Kategoriename';

  @override
  String get categoryNameRequired => 'Kategoriename erforderlich';

  @override
  String get categoryNameExists => 'Kategoriename existiert bereits';

  @override
  String get icon => 'Symbol';

  @override
  String get colour => 'Farbe';

  @override
  String get keywords => 'Schlüsselwörter';

  @override
  String get addKeywordHint => 'Schlüsselwort hinzufügen…';

  @override
  String get noKeywords => 'Keine Schlüsselwörter';

  @override
  String get deleteCategoryTooltip => 'Kategorie löschen';

  @override
  String get editCategoryTooltip => 'Kategorie bearbeiten';

  @override
  String get cannotDeleteOtherCategory =>
      'Die Standardkategorie „Sonstiges“ kann nicht gelöscht werden.';

  @override
  String deleteCategoryTitle(String name) {
    return '„$name“ löschen?';
  }

  @override
  String get deleteCategoryContent =>
      'Bestehende Transaktionen mit dieser Kategorie werden „Sonstiges“ zugewiesen, damit der Verlauf erhalten bleibt.';

  @override
  String get cyclePhaseGuide => 'Zyklusphasen-Leitfaden';

  @override
  String get menstrualPhase => 'Menstruationsphase';

  @override
  String get menstrualPhaseDays => 'Tage 1–5';

  @override
  String get menstrualPhaseDesc =>
      'Die Gebärmutterschleimhaut wird abgestoßen. Geringere Energie; Ruhe, Flüssigkeitszufuhr und sanfte Bewegung bevorzugen.';

  @override
  String get follicularPhase => 'Follikelphase';

  @override
  String get follicularPhaseDays => 'Tage 6–13';

  @override
  String get follicularPhaseDesc =>
      'Östrogen steigt mit der Eizellreifung. Energie, Stimmung und Kreativität erreichen ihren Höhepunkt.';

  @override
  String get ovulatoryPhase => 'Ovulationsphase';

  @override
  String get ovulatoryPhaseDays => 'Tage 14–16';

  @override
  String get ovulatoryPhaseDesc =>
      'LH-Anstieg löst den Eisprung aus. Höchststand an Selbstvertrauen, sozialer Energie und Fruchtbarkeit.';

  @override
  String get lutealPhase => 'Lutealphase';

  @override
  String get lutealPhaseDays => 'Tage 17–28';

  @override
  String get lutealPhaseDesc =>
      'Progesteron steigt. Energie zieht sich nach innen; PMS-Symptome möglich. Entspannung priorisieren.';

  @override
  String get symptomCramps => 'Krämpfe';

  @override
  String get symptomBloating => 'Blähungen';

  @override
  String get symptomHeadache => 'Kopfschmerzen';

  @override
  String get symptomFatigue => 'Müdigkeit';

  @override
  String get symptomAcne => 'Akne';

  @override
  String get symptomMoodSwings => 'Stimmungsschwankungen';

  @override
  String get symptomNausea => 'Übelkeit';

  @override
  String get symptomBackache => 'Rückenschmerzen';

  @override
  String get intensityLight => 'Leicht';

  @override
  String get intensityMedium => 'Mittel';

  @override
  String get intensityHeavy => 'Stark';

  @override
  String get startDateAfterEndDate =>
      'Das Startdatum darf nicht nach dem Enddatum liegen';

  @override
  String get overlapDetectedTitle => 'Überschneidung erkannt';

  @override
  String get overlapDetectedMessage =>
      'Die ausgewählten Daten überschneiden sich mit einer bereits eingetragenen Periode. Bitte Daten anpassen.';
}
