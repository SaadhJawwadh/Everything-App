import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/data/recurring_rule_model.dart';
import 'package:note_taking_app/services/sms_parser.dart';

void main() {
  group('Priority 1 SDLC Fixes: RecurringRule Month-End Recurrence Tests', () {
    test('RecurringRule advance preserves anchorDay across consecutive month advances', () {
      final start = DateTime(2026, 1, 31, 10, 0);
      var rule = RecurringRule(
        id: 'rule-test-1',
        description: 'Monthly Cloud Subscription',
        amount: 29.99,
        category: 'Subscriptions',
        isExpense: true,
        frequency: RecurringFrequency.monthly,
        nextDue: start,
      );

      expect(rule.anchorDay, 31);

      // 1. Advance Jan 31 -> Feb 28 (clamped to 28 days)
      rule = rule.copyWith(nextDue: rule.advance(rule.nextDue));
      expect(rule.nextDue, DateTime(2026, 2, 28, 10, 0));
      expect(rule.anchorDay, 31, reason: 'Anchor day must be preserved as 31');

      // 2. Advance Feb 28 -> March 31 (MUST NOT degrade to March 28!)
      rule = rule.copyWith(nextDue: rule.advance(rule.nextDue));
      expect(rule.nextDue, DateTime(2026, 3, 31, 10, 0),
          reason: 'Advancing from clamped Feb 28 must restore the original 31st for March');
      expect(rule.anchorDay, 31);

      // 3. Advance March 31 -> April 30 (clamped to 30 days)
      rule = rule.copyWith(nextDue: rule.advance(rule.nextDue));
      expect(rule.nextDue, DateTime(2026, 4, 30, 10, 0));
      expect(rule.anchorDay, 31);

      // 4. Advance April 30 -> May 31 (restores 31st)
      rule = rule.copyWith(nextDue: rule.advance(rule.nextDue));
      expect(rule.nextDue, DateTime(2026, 5, 31, 10, 0));
      expect(rule.anchorDay, 31);
    });

    test('RecurringRule advance on mid-month day maintains exact day', () {
      final start = DateTime(2026, 1, 15, 14, 30);
      var rule = RecurringRule(
        id: 'rule-test-2',
        description: 'Mid-Month Rent',
        amount: 1200.0,
        category: 'Housing',
        isExpense: true,
        frequency: RecurringFrequency.monthly,
        nextDue: start,
      );

      rule = rule.copyWith(nextDue: rule.advance(rule.nextDue));
      expect(rule.nextDue, DateTime(2026, 2, 15, 14, 30));

      rule = rule.copyWith(nextDue: rule.advance(rule.nextDue));
      expect(rule.nextDue, DateTime(2026, 3, 15, 14, 30));
    });
  });

  group('Priority 1 SDLC Fixes: SmsParser Multi-Locale Amount Parsing Tests', () {
    test('parseAmountString parses Anglo-American comma-thousands dot-decimal format', () {
      expect(SmsParser.parseAmountString('1,500.50'), 1500.5);
      expect(SmsParser.parseAmountString('1500.50'), 1500.5);
      expect(SmsParser.parseAmountString('1,500'), 1500.0);
      expect(SmsParser.parseAmountString('1,500,000.00'), 1500000.0);
    });

    test('parseAmountString parses European dot-thousands comma-decimal format', () {
      expect(SmsParser.parseAmountString('1.500,50'), 1500.5);
      expect(SmsParser.parseAmountString('12.345,67'), 12345.67);
    });

    test('parseAmountString parses Russian and Slavic space-thousands comma-decimal format', () {
      expect(SmsParser.parseAmountString('1 500,50'), 1500.5);
      expect(SmsParser.parseAmountString('1500,50'), 1500.5);
      expect(SmsParser.parseAmountString('250,75'), 250.75);
      expect(SmsParser.parseAmountString('2 450,00'), 2450.0);
      expect(SmsParser.parseAmountString('10 000,5'), 10000.5);
    });

    test('parseAmountString handles whitespace and edge cases gracefully', () {
      expect(SmsParser.parseAmountString('   '), isNull);
      expect(SmsParser.parseAmountString('450'), 450.0);
      expect(SmsParser.parseAmountString('0.99'), 0.99);
      expect(SmsParser.parseAmountString('0,99'), 0.99);
    });
  });
}
