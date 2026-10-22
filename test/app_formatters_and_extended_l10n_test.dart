import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/core/utils/app_formatters.dart';
import 'package:note_taking_app/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppFormatters Tests', () {
    testWidgets('formatCurrency formats correctly across different locales and currencies', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', 'US'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              final formattedEn = AppFormatters.formatCurrency(context, 1250.50, currency: r'$');
              expect(formattedEn, contains('1,250.50'));
              expect(formattedEn, contains(r'$'));

              final formattedCompact = AppFormatters.formatCurrency(context, 1500000, currency: r'$', compact: true);
              expect(formattedCompact, anyOf(contains('1.5M'), contains('1.50M')));

              final formattedNoDecimals = AppFormatters.formatCurrency(context, 2500, currency: 'Rs.', showDecimals: false);
              expect(formattedNoDecimals, contains('2,500'));

              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('formatDate, formatTime and formatNumber operate with locale awareness', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', 'US'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              final dt = DateTime(2026, 10, 22, 14, 30);
              final dateStr = AppFormatters.formatDate(context, dt);
              expect(dateStr, contains('2026'));
              expect(dateStr, contains('Oct'));

              final shortDateStr = AppFormatters.formatShortDate(context, dt);
              expect(shortDateStr, contains('Oct'));
              expect(shortDateStr, contains('22'));

              final timeStr = AppFormatters.formatTime(context, dt);
              expect(timeStr, contains('2:30'));

              final dateTimeStr = AppFormatters.formatDateTime(context, dt);
              expect(dateTimeStr, contains('2026'));
              expect(dateTimeStr, contains('2:30'));

              final numStr = AppFormatters.formatNumber(context, 1000000);
              expect(numStr, equals('1,000,000'));

              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('Extended Localization & Plural Grammar Tests', () {
    test('Spanish and French singular plural forms are grammatically accurate', () async {
      final es = await AppLocalizations.delegate.load(const Locale('es'));
      expect(es.allTasksCompleted(1), equals('1 tarea completada'));
      expect(es.allTasksCompleted(5), equals('Todas las 5 tareas completadas'));
      expect(es.moreItems(1), equals('+1 elemento más'));
      expect(es.moreItems(3), equals('+3 elementos más'));

      final fr = await AppLocalizations.delegate.load(const Locale('fr'));
      expect(fr.allTasksCompleted(1), equals('1 tâche terminée'));
      expect(fr.allTasksCompleted(4), equals('Toutes les 4 tâches terminées'));
      expect(fr.moreItems(1), equals('+1 autre élément'));
      expect(fr.moreItems(5), equals('+5 autres éléments'));

      final de = await AppLocalizations.delegate.load(const Locale('de'));
      expect(de.allTasksCompleted(1), equals('1 Aufgabe erledigt'));
      expect(de.allTasksCompleted(3), equals('Alle 3 Aufgaben erledigt'));
    });

    test('All 8 locales load Category Management & Period Tracker keys with 100% parity', () async {
      const locales = ['en', 'ru', 'de', 'es', 'fr', 'pt', 'ta', 'zh'];

      for (final code in locales) {
        final l10n = await AppLocalizations.delegate.load(Locale(code));
        expect(l10n.manageCategories, isNotEmpty, reason: '$code manageCategories');
        expect(l10n.restoreDefaults, isNotEmpty, reason: '$code restoreDefaults');
        expect(l10n.restoreDefaultCategoriesTitle, isNotEmpty, reason: '$code restoreDefaultCategoriesTitle');
        expect(l10n.newCategory, isNotEmpty, reason: '$code newCategory');
        expect(l10n.editCategory, isNotEmpty, reason: '$code editCategory');
        expect(l10n.categoryName, isNotEmpty, reason: '$code categoryName');
        expect(l10n.categoryNameRequired, isNotEmpty, reason: '$code categoryNameRequired');
        expect(l10n.categoryNameExists, isNotEmpty, reason: '$code categoryNameExists');
        expect(l10n.cyclePhaseGuide, isNotEmpty, reason: '$code cyclePhaseGuide');
        expect(l10n.menstrualPhase, isNotEmpty, reason: '$code menstrualPhase');
        expect(l10n.follicularPhase, isNotEmpty, reason: '$code follicularPhase');
        expect(l10n.ovulatoryPhase, isNotEmpty, reason: '$code ovulatoryPhase');
        expect(l10n.lutealPhase, isNotEmpty, reason: '$code lutealPhase');
        expect(l10n.symptomCramps, isNotEmpty, reason: '$code symptomCramps');
        expect(l10n.symptomBloating, isNotEmpty, reason: '$code symptomBloating');
        expect(l10n.symptomHeadache, isNotEmpty, reason: '$code symptomHeadache');
        expect(l10n.symptomFatigue, isNotEmpty, reason: '$code symptomFatigue');
        expect(l10n.symptomAcne, isNotEmpty, reason: '$code symptomAcne');
        expect(l10n.symptomMoodSwings, isNotEmpty, reason: '$code symptomMoodSwings');
        expect(l10n.symptomNausea, isNotEmpty, reason: '$code symptomNausea');
        expect(l10n.symptomBackache, isNotEmpty, reason: '$code symptomBackache');
        expect(l10n.intensityLight, isNotEmpty, reason: '$code intensityLight');
        expect(l10n.intensityMedium, isNotEmpty, reason: '$code intensityMedium');
        expect(l10n.intensityHeavy, isNotEmpty, reason: '$code intensityHeavy');
        expect(l10n.startDateAfterEndDate, isNotEmpty, reason: '$code startDateAfterEndDate');
        expect(l10n.overlapDetectedTitle, isNotEmpty, reason: '$code overlapDetectedTitle');
      }
    });
  });
}
