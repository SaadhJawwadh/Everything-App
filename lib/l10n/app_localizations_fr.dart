// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Everything App';

  @override
  String get navNotes => 'Notes';

  @override
  String get navFinances => 'Finances';

  @override
  String get navTracker => 'Cycle';

  @override
  String get navSplitBills => 'Partage d\'Additions';

  @override
  String get greetingMorning => 'Bonjour !';

  @override
  String get greetingAfternoon => 'Bon appétit !';

  @override
  String get greetingEvening => 'Bonsoir !';

  @override
  String get greetingNight => 'Il est l\'heure de dormir !';

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
  String get searchNotes => 'Rechercher des notes...';

  @override
  String get searchFinances => 'Rechercher des transactions...';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get newNote => 'Nouvelle Note';

  @override
  String get newTransaction => 'Nouvelle Transaction';

  @override
  String get search => 'Rechercher';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get edit => 'Modifier';

  @override
  String get done => 'Terminé';

  @override
  String get close => 'Fermer';

  @override
  String get filter => 'Filtrer';

  @override
  String get sort => 'Trier';

  @override
  String get confirm => 'Confirmer';

  @override
  String get back => 'Retour';

  @override
  String get copy => 'Copier';

  @override
  String get share => 'Partager';

  @override
  String get clear => 'Effacer';

  @override
  String get apply => 'Appliquer';

  @override
  String get discard => 'Abandonner';

  @override
  String get undo => 'Annuler';

  @override
  String get all => 'Tout';

  @override
  String get copiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get pinnedNotes => 'Notes Épinglées';

  @override
  String get otherNotes => 'Autres Notes';

  @override
  String get emptyNotesTitle => 'Aucune note pour le moment';

  @override
  String get emptyNotesSubtitle => 'Appuyez sur + pour capturer vos pensées';

  @override
  String get archive => 'Archiver';

  @override
  String get trash => 'Corbeille';

  @override
  String get restore => 'Restaurer';

  @override
  String get deletePermanently => 'Supprimer Définitivement';

  @override
  String get lockedNote => 'Note verrouillée';

  @override
  String get appLocked => 'Application Verrouillée';

  @override
  String get unlock => 'Déverrouiller';

  @override
  String get noteTitlePlaceholder => 'Titre';

  @override
  String get noteBodyPlaceholder => 'Commencez à écrire...';

  @override
  String get manageTags => 'Gérer les Tags';

  @override
  String get income => 'Revenus';

  @override
  String get expense => 'Dépenses';

  @override
  String get balance => 'Solde';

  @override
  String get netBalance => 'Solde Net';

  @override
  String get monthlySpending => 'Dépenses du Mois';

  @override
  String get dailySafeToSpend => 'Budget Disponible Aujourd\'hui';

  @override
  String get ledger => 'Grand livre';

  @override
  String get breakdown => 'Répartition';

  @override
  String get budgets => 'Budgets';

  @override
  String get savings => 'Épargne';

  @override
  String get savingsGoals => 'Objectifs d\'Épargne';

  @override
  String get deposit => 'Déposer';

  @override
  String get dailyAccount => 'Compte Courant';

  @override
  String get savingsVault => 'Coffre d\'Épargne';

  @override
  String get targetAmount => 'Montant Cible';

  @override
  String get currentAmount => 'Montant Actuel';

  @override
  String get noTransactionsYet => 'Aucune donnée financière pour le moment';

  @override
  String get categories => 'Catégories';

  @override
  String get splitBillsTitle => 'Partage d\'Additions';

  @override
  String get settleUp => 'Régler les Comptes';

  @override
  String get equalSplit => 'Partage Égal';

  @override
  String get customSplit => 'Partage Personnalisé';

  @override
  String get paidBy => 'Payé par';

  @override
  String get sendReminder => 'Envoyer un Rappel';

  @override
  String cycleDay(int day) {
    return 'Jour $day du cycle';
  }

  @override
  String get periodLog => 'Suivi des Règles';

  @override
  String get symptoms => 'Symptômes';

  @override
  String get periodStart => 'Début des Règles';

  @override
  String get periodEnd => 'Fin des Règles';

  @override
  String get regular => 'Régulier';

  @override
  String get irregular => 'Irrégulier';

  @override
  String get appearance => 'Apparence et Interface';

  @override
  String get theme => 'Thème';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeSystem => 'Par Défaut du Système';

  @override
  String get language => 'Langue';

  @override
  String get languageSystem => 'Par Défaut du Système';

  @override
  String get currency => 'Devise';

  @override
  String get security => 'Sécurité et Confidentialité';

  @override
  String get backupRestore => 'Sauvegarde et Restauration';

  @override
  String get about => 'À Propos';

  @override
  String get onDeviceAi => 'IA sur l\'Appareil';

  @override
  String get preferencesAndWorkspaces => 'Préférences et espaces';

  @override
  String get notesAndEditorWorkspace => 'Notes et éditeur';

  @override
  String get financesAndHealthModules => 'Finances et santé';

  @override
  String get privacyAndSecurity => 'Confidentialité et sécurité';

  @override
  String get syncAndBackups => 'Synchronisation et sauvegardes';

  @override
  String get aboutAndDeviceAi => 'À propos et IA';

  @override
  String get startFromTemplate => 'Partir d\'un modèle';

  @override
  String get templateMeetingNotes => 'Notes de réunion';

  @override
  String get templateMeetingNotesDesc => 'Ordre du jour, discussion et actions';

  @override
  String get templateShoppingList => 'Liste de courses';

  @override
  String get templateShoppingListDesc => 'Liste à cocher prête à l\'emploi';

  @override
  String get templateJournal => 'Journal';

  @override
  String get templateJournalDesc => 'Réflexions quotidiennes';

  @override
  String get themeAndColorSystem => 'Thème et couleurs';

  @override
  String get appThemeMode => 'Mode du thème';

  @override
  String get dynamicWallpaperTheme => 'Couleurs dynamiques';

  @override
  String get dynamicWallpaperSubtitle =>
      'Harmoniser les couleurs avec le fond d\'écran (Android 12+)';

  @override
  String get interactionAndAccessibility => 'Interaction et accessibilité';

  @override
  String get tactileHaptics => 'Retour haptique';

  @override
  String get tactileHapticsSubtitle =>
      'Vibrations légères pour les gestes et actions';

  @override
  String get textScale => 'Taille du texte';

  @override
  String get textScaleSubtitle => 'Taille de police globale';

  @override
  String get textScaleSmall => 'Petit';

  @override
  String get textScaleMedium => 'Moyen';

  @override
  String get textScaleLarge => 'Grand';

  @override
  String get appLanguage => 'Langue de l\'app';

  @override
  String get selectCurrency => 'Sélectionner la devise';

  @override
  String noSettingsFound(String query) {
    return 'Aucun paramètre trouvé pour \"$query\"';
  }

  @override
  String get quickSuggestions => 'Suggestions rapides :';

  @override
  String get clearSelection => 'Effacer la sélection';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnés',
      one: '1 sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get deselectAll => 'Tout désélectionner';

  @override
  String get closeSearch => 'Fermer la recherche';

  @override
  String get clearQuery => 'Effacer la requête';

  @override
  String get createNewFolder => 'Créer un nouveau dossier';

  @override
  String get folderName => 'Nom du dossier';

  @override
  String get filterByFolder => 'Filtrer par dossier';

  @override
  String get newFolder => 'Nouveau dossier';

  @override
  String get allNotes => 'Toutes les notes';

  @override
  String get checklistsAndTasks => 'Listes et tâches';

  @override
  String get archivedNotes => 'Notes archivées';

  @override
  String get trashBin => 'Corbeille';

  @override
  String get sortNotes => 'Trier les notes';

  @override
  String get sortByLastModified => 'Par dernière modification';

  @override
  String get sortByDateCreated => 'Par date de création';

  @override
  String get sortByTitle => 'Par titre';

  @override
  String get sortByColor => 'Par couleur';

  @override
  String get importNotes => 'Importer des notes';

  @override
  String get switchToGridView => 'Passer en vue grille';

  @override
  String get switchToListView => 'Passer en vue liste';

  @override
  String get selectPeriod => 'Sélectionner la période';

  @override
  String get thisMonth => 'Ce mois-ci';

  @override
  String get lastMonth => 'Le mois dernier';

  @override
  String get last90Days => '90 derniers jours';

  @override
  String get thisYear => 'Cette année';

  @override
  String get allTime => 'Tout l\'historique';

  @override
  String get customDateRange => 'Plage de dates personnalisée…';

  @override
  String get customDateRangeSubtitle =>
      'Choisir les dates exactes sur le calendrier';

  @override
  String allTasksCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Toutes les $count tâches terminées',
      one: '1 tâche terminée',
    );
    return '$_temp0';
  }

  @override
  String moreItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autres éléments',
      one: '1 autre élément',
    );
    return '+$_temp0';
  }

  @override
  String get manageCategories => 'Gérer les catégories';

  @override
  String get restoreDefaults => 'Restaurer les valeurs par défaut';

  @override
  String get restoreDefaultCategoriesTitle =>
      'Restaurer les catégories par défaut ?';

  @override
  String get restoreDefaultCategoriesContent =>
      'Les catégories personnalisées seront supprimées et les catégories intégrées retrouveront leurs couleurs et mots-clés par défaut. Les transactions existantes conservent leurs étiquettes.';

  @override
  String get categoriesRestored => 'Catégories restaurées par défaut';

  @override
  String get newCategory => 'Nouvelle catégorie';

  @override
  String get editCategory => 'Modifier la catégorie';

  @override
  String get categoryName => 'Nom de la catégorie';

  @override
  String get categoryNameRequired => 'Nom de catégorie requis';

  @override
  String get categoryNameExists => 'Ce nom de catégorie existe déjà';

  @override
  String get icon => 'Icône';

  @override
  String get colour => 'Couleur';

  @override
  String get keywords => 'Mots-clés';

  @override
  String get addKeywordHint => 'Ajouter un mot-clé…';

  @override
  String get noKeywords => 'Aucun mot-clé';

  @override
  String get deleteCategoryTooltip => 'Supprimer la catégorie';

  @override
  String get editCategoryTooltip => 'Modifier la catégorie';

  @override
  String get cannotDeleteOtherCategory =>
      'La catégorie par défaut « Autre » ne peut pas être supprimée.';

  @override
  String deleteCategoryTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get deleteCategoryContent =>
      'Les transactions existantes avec cette catégorie seront réaffectées à « Autre » pour préserver votre historique.';

  @override
  String get cyclePhaseGuide => 'Guide des phases du cycle';

  @override
  String get menstrualPhase => 'Phase menstruelle';

  @override
  String get menstrualPhaseDays => 'Jours 1–5';

  @override
  String get menstrualPhaseDesc =>
      'Desquamation de la muqueuse utérine. Énergie plus basse ; privilégiez repos, hydratation et mouvements doux.';

  @override
  String get follicularPhase => 'Phase folliculaire';

  @override
  String get follicularPhaseDays => 'Jours 6–13';

  @override
  String get follicularPhaseDesc =>
      'Les œstrogènes augmentent avec la maturation des follicules. Énergie, humeur et créativité sont au plus haut.';

  @override
  String get ovulatoryPhase => 'Phase ovulatoire';

  @override
  String get ovulatoryPhaseDays => 'Jours 14–16';

  @override
  String get ovulatoryPhaseDesc =>
      'Le pic de LH déclenche l\'ovulation. Confiance, énergie sociale et fertilité maximales.';

  @override
  String get lutealPhase => 'Phase lutéale';

  @override
  String get lutealPhaseDays => 'Jours 17–28';

  @override
  String get lutealPhaseDesc =>
      'La progestérone augmente. L\'énergie diminue ; le SPM peut apparaître. Privilégiez la détente.';

  @override
  String get symptomCramps => 'Crampes';

  @override
  String get symptomBloating => 'Ballonnements';

  @override
  String get symptomHeadache => 'Maux de tête';

  @override
  String get symptomFatigue => 'Fatigue';

  @override
  String get symptomAcne => 'Acné';

  @override
  String get symptomMoodSwings => 'Sautes d\'humeur';

  @override
  String get symptomNausea => 'Nausées';

  @override
  String get symptomBackache => 'Mal de dos';

  @override
  String get intensityLight => 'Légère';

  @override
  String get intensityMedium => 'Moyenne';

  @override
  String get intensityHeavy => 'Forte';

  @override
  String get startDateAfterEndDate =>
      'La date de début ne peut pas être postérieure à la date de fin';

  @override
  String get overlapDetectedTitle => 'Chevauchement détecté';

  @override
  String get overlapDetectedMessage =>
      'Les dates sélectionnées chevauchent une période déjà enregistrée. Veuillez ajuster les dates.';
}
