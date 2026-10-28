import 'database_constants.dart';
import 'transaction_model.dart';

enum RecurringFrequency {
  daily('daily', 'Daily', 'day'),
  weekly('weekly', 'Weekly', 'week'),
  monthly('monthly', 'Monthly', 'month');

  final String value;
  final String label;
  final String unitName;
  const RecurringFrequency(this.value, this.label, this.unitName);

  static RecurringFrequency fromValue(String value) =>
      RecurringFrequency.values.firstWhere(
        (f) => f.value == value,
        orElse: () => RecurringFrequency.monthly,
      );
}

/// A template that materializes into a real transaction every time its
/// [nextDue] date passes (rent, subscriptions, salary, ...).
class RecurringRule {
  final String id;
  final String description;
  final double amount;
  final String category;
  final bool isExpense;
  final RecurringFrequency frequency;
  final DateTime nextDue;
  final String account;
  final int? _anchorDay;

  /// The original intended day-of-month for recurrence (e.g. 31),
  /// preserved across month-length clamping in shorter months.
  int get anchorDay => _anchorDay ?? nextDue.day;

  const RecurringRule({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.isExpense,
    required this.frequency,
    required this.nextDue,
    this.account = AccountType.daily,
    int? anchorDay,
  }) : _anchorDay = anchorDay;

  RecurringRule copyWith({
    String? id,
    String? description,
    double? amount,
    String? category,
    bool? isExpense,
    RecurringFrequency? frequency,
    DateTime? nextDue,
    String? account,
    int? anchorDay,
  }) =>
      RecurringRule(
        id: id ?? this.id,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        isExpense: isExpense ?? this.isExpense,
        frequency: frequency ?? this.frequency,
        nextDue: nextDue ?? this.nextDue,
        account: account ?? this.account,
        anchorDay: anchorDay ?? this.anchorDay,
      );

  /// The due date that follows [from], respecting month-length clamping
  /// (a rule due on the 31st fires on the 30th/28th in shorter months,
  /// but retains its anchor day for subsequent longer months).
  DateTime advance(DateTime from) {
    switch (frequency) {
      case RecurringFrequency.daily:
        return from.add(const Duration(days: 1));
      case RecurringFrequency.weekly:
        return from.add(const Duration(days: 7));
      case RecurringFrequency.monthly:
        final targetDay = anchorDay;
        final nextMonth = DateTime(from.year, from.month + 1, 1);
        final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
        return DateTime(
          nextMonth.year,
          nextMonth.month,
          targetDay > lastDay ? lastDay : targetDay,
          from.hour,
          from.minute,
        );
    }
  }

  Map<String, Object?> toJson() => {
        RecurringRuleFields.id: id,
        RecurringRuleFields.description: description,
        RecurringRuleFields.amount: amount,
        RecurringRuleFields.category: category,
        RecurringRuleFields.isExpense: isExpense ? 1 : 0,
        RecurringRuleFields.frequency: frequency.value,
        RecurringRuleFields.nextDue: nextDue.toIso8601String(),
        RecurringRuleFields.account: account,
        RecurringRuleFields.anchorDay: anchorDay,
      };

  static RecurringRule fromJson(Map<String, Object?> json) {
    final parsedNextDue = DateTime.tryParse(
            (json[RecurringRuleFields.nextDue] as String?) ?? '') ??
        DateTime.now();
    return RecurringRule(
      id: json[RecurringRuleFields.id] as String,
      description: (json[RecurringRuleFields.description] as String?) ?? '',
      amount: (json[RecurringRuleFields.amount] as num? ?? 0).toDouble(),
      category: (json[RecurringRuleFields.category] as String?) ?? 'Other',
      isExpense: json[RecurringRuleFields.isExpense] == 1,
      frequency: RecurringFrequency.fromValue(
          (json[RecurringRuleFields.frequency] as String?) ?? 'monthly'),
      nextDue: parsedNextDue,
      account:
          (json[RecurringRuleFields.account] as String?) ?? AccountType.daily,
      anchorDay: (json[RecurringRuleFields.anchorDay] as num?)?.toInt(),
    );
  }
}
