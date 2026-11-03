import 'package:uuid/uuid.dart';
import 'transaction_category.dart';

class AccountType {
  static const String daily = 'daily';
  static const String savings = 'savings';
}

class TransactionModel {
  final int? id;
  final double amount;
  final String description;
  final DateTime date;
  final bool isExpense;
  final String category;
  final String? smsId;
  final DateTime? deletedAt;
  final String account;
  final bool isAiRefined;
  final DateTime? dateModified;
  final String? uuid;

  TransactionModel({
    this.id,
    required this.amount,
    required this.description,
    required this.date,
    this.isExpense = true,
    this.category = TransactionCategory.other,
    this.smsId,
    this.deletedAt,
    this.account = AccountType.daily,
    this.isAiRefined = false,
    this.dateModified,
    String? uuid,
  }) : uuid = uuid ?? (smsId == null ? const Uuid().v4() : null);

  TransactionModel copy({
    int? id,
    double? amount,
    String? description,
    DateTime? date,
    bool? isExpense,
    String? category,
    String? smsId,
    DateTime? deletedAt,
    String? account,
    bool? isAiRefined,
    DateTime? dateModified,
    String? uuid,
  }) =>
      TransactionModel(
        id: id ?? this.id,
        amount: amount ?? this.amount,
        description: description ?? this.description,
        date: date ?? this.date,
        isExpense: isExpense ?? this.isExpense,
        category: category ?? this.category,
        smsId: smsId ?? this.smsId,
        deletedAt: deletedAt ?? this.deletedAt,
        account: account ?? this.account,
        isAiRefined: isAiRefined ?? this.isAiRefined,
        dateModified: dateModified ?? this.dateModified,
        uuid: uuid ?? this.uuid,
      );

  static TransactionModel fromJson(Map<String, Object?> json) =>
      TransactionModel(
        id: json[TransactionFields.id] as int?,
        amount: (json[TransactionFields.amount] as num? ?? 0).toDouble(),
        description: (json[TransactionFields.description] as String?) ?? '',
        date: DateTime.tryParse(
                (json[TransactionFields.date] as String?) ?? '') ??
            DateTime.now(),
        isExpense: ((json[TransactionFields.isExpense] as int?) ?? 1) == 1,
        category: (json[TransactionFields.category] as String?) ??
            TransactionCategory.other,
        smsId: json[TransactionFields.smsId] as String?,
        deletedAt: json[TransactionFields.deletedAt] != null
            ? DateTime.tryParse(json[TransactionFields.deletedAt] as String)
            : null,
        account: (json[TransactionFields.account] as String?) ?? AccountType.daily,
        isAiRefined: ((json[TransactionFields.isAiRefined] as int?) ?? 0) == 1,
        dateModified: json[TransactionFields.dateModified] != null
            ? DateTime.tryParse(json[TransactionFields.dateModified] as String)
            : null,
        uuid: json[TransactionFields.uuid] as String?,
      );

  Map<String, Object?> toJson() => {
        TransactionFields.id: id,
        TransactionFields.amount: amount,
        TransactionFields.description: description,
        TransactionFields.date: date.toIso8601String(),
        TransactionFields.isExpense: isExpense ? 1 : 0,
        TransactionFields.category: category,
        TransactionFields.smsId: smsId,
        TransactionFields.deletedAt: deletedAt?.toIso8601String(),
        TransactionFields.account: account,
        TransactionFields.isAiRefined: isAiRefined ? 1 : 0,
        TransactionFields.dateModified: (dateModified ?? date).toIso8601String(),
        TransactionFields.uuid: uuid,
      };
}

class TransactionFields {
  static final List<String> values = [
    id,
    amount,
    description,
    date,
    isExpense,
    category,
    smsId,
    deletedAt,
    account,
    isAiRefined,
    dateModified,
    uuid,
  ];

  static const String id = '_id';
  static const String amount = 'amount';
  static const String description = 'description';
  static const String date = 'date';
  static const String isExpense = 'isExpense';
  static const String category = 'category';
  static const String smsId = 'smsId';
  static const String deletedAt = 'deletedAt';
  static const String account = 'account';
  static const String isAiRefined = 'isAiRefined';
  static const String dateModified = 'dateModified';
  static const String uuid = 'uuid';
}
