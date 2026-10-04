import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/features/notes/services/note_link_service.dart';
import 'package:note_taking_app/features/notes/services/note_expense_embed_service.dart';
import 'package:note_taking_app/features/sync/providers/p2p_sync_provider.dart';
import 'package:note_taking_app/services/p2p_sync_service.dart';

void main() {
  group('NoteLinkService Wiki-Link Tests', () {
    test('scanLinks - returns empty list for empty string or text without links', () {
      expect(NoteLinkService.scanLinks(''), isEmpty);
      expect(NoteLinkService.scanLinks('Just normal plain text without links'), isEmpty);
      expect(NoteLinkService.scanLinks('[Single brackets] and [[ ]] empty'), isEmpty);
    });

    test('scanLinks - parses single and multiple [[Note Title]] wiki links', () {
      const text = 'Meeting notes: discuss [[Project Roadmap]] and review [[Q3 Financials]].';
      final links = NoteLinkService.scanLinks(text);

      expect(links.length, equals(2));
      expect(links[0].targetTitle, equals('Project Roadmap'));
      expect(links[0].rawMatch, equals('[[Project Roadmap]]'));
      expect(links[0].startIndex, equals(text.indexOf('[[Project Roadmap]]')));

      expect(links[1].targetTitle, equals('Q3 Financials'));
      expect(links[1].rawMatch, equals('[[Q3 Financials]]'));
      expect(links[1].startIndex, equals(text.indexOf('[[Q3 Financials]]')));
    });

    test('scanLinks - trims whitespace inside brackets cleanly', () {
      const text = 'Check out [[   Deep Work Habits   ]] today.';
      final links = NoteLinkService.scanLinks(text);

      expect(links.length, equals(1));
      expect(links[0].targetTitle, equals('Deep Work Habits'));
    });
  });

  group('NoteExpenseEmbedService Tests', () {
    test('scanExpenseEmbeds - returns empty list when no embeds present', () {
      expect(NoteExpenseEmbedService.scanExpenseEmbeds(''), isEmpty);
      expect(NoteExpenseEmbedService.scanExpenseEmbeds('Ordinary grocery list without braces'), isEmpty);
    });

    test('scanExpenseEmbeds - parses standard currency amounts and memos', () {
      const text = 'Trip expenses: {{\$45.50 Dinner}} and {{\$12.00 Metro}}';
      final embeds = NoteExpenseEmbedService.scanExpenseEmbeds(text);

      expect(embeds.length, equals(2));
      expect(embeds[0].amount, equals(45.50));
      expect(embeds[0].currencySymbol, equals(r'$'));
      expect(embeds[0].customMemo, equals('Dinner'));

      expect(embeds[1].amount, equals(12.00));
      expect(embeds[1].currencySymbol, equals(r'$'));
      expect(embeds[1].customMemo, equals('Metro'));
    });

    test('scanExpenseEmbeds - handles multi-currency symbols and comma decimals', () {
      const text = 'Bought supplies {{₹1500 Office stationery}} and {{€25,50 Coffee beans}}';
      final embeds = NoteExpenseEmbedService.scanExpenseEmbeds(text);

      expect(embeds.length, equals(2));
      expect(embeds[0].amount, equals(1500.0));
      expect(embeds[0].currencySymbol, equals('₹'));
      expect(embeds[0].customMemo, equals('Office stationery'));

      expect(embeds[1].amount, equals(25.50));
      expect(embeds[1].currencySymbol, equals('€'));
      expect(embeds[1].customMemo, equals('Coffee beans'));
    });

    test('scanExpenseEmbeds - handles embed without memo or without currency symbol', () {
      const text = 'Quick payment {{50.00}} and {{100 Groceries}}';
      final embeds = NoteExpenseEmbedService.scanExpenseEmbeds(text);

      expect(embeds.length, equals(2));
      expect(embeds[0].amount, equals(50.00));
      expect(embeds[0].currencySymbol, equals(''));
      expect(embeds[0].customMemo, isNull);

      expect(embeds[1].amount, equals(100.0));
      expect(embeds[1].customMemo, equals('Groceries'));
    });
  });

  group('SyncActivityEvent Audit Telemetry Tests', () {
    test('SyncActivityEvent creates correct summary representations', () {
      final now = DateTime.now();
      final successResult = SyncResult(
        success: true,
        syncedCount: 5,
        transportUsed: 'Wi-Fi Direct HTTP',
      );
      final successEvent = SyncActivityEvent(
        timestamp: now,
        result: successResult,
        peerName: 'Pixel 9 Pro',
      );

      expect(successEvent.result.success, isTrue);
      expect(successEvent.peerName, equals('Pixel 9 Pro'));
      expect(successEvent.result.syncedCount, equals(5));
      expect(successEvent.result.transportUsed, equals('Wi-Fi Direct HTTP'));
      expect(successEvent.result.errorMessage, isNull);

      final errorResult = SyncResult(
        success: false,
        syncedCount: 0,
        errorMessage: 'Connection timed out after 5000ms',
      );
      final errorEvent = SyncActivityEvent(
        timestamp: now,
        result: errorResult,
        peerName: 'Galaxy Tab S9',
      );

      expect(errorEvent.result.success, isFalse);
      expect(errorEvent.result.errorMessage, equals('Connection timed out after 5000ms'));
      expect(errorEvent.peerName, equals('Galaxy Tab S9'));
    });
  });
}
