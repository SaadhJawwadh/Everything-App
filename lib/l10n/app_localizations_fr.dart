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
}
