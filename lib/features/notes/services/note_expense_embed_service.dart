import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../data/note_model.dart';
import '../../../../data/transaction_model.dart';
import '../../finances/providers/financial_manager_provider.dart';

/// Represents a parsed expense embed within a note (e.g. `{{$45.50}}` or `{{₹1200 Lunch}}`).
class NoteExpenseEmbed {
  final double amount;
  final String rawMatch;
  final String currencySymbol;
  final String? customMemo;

  const NoteExpenseEmbed({
    required this.amount,
    required this.rawMatch,
    required this.currencySymbol,
    this.customMemo,
  });
}

/// Service to parse in-note expense syntax and book transactions directly to the financial ledger.
class NoteExpenseEmbedService {
  NoteExpenseEmbedService._();

  // Matches `{{$50}}`, `{{₹500}}`, `{{Rs.1200}}`, `{{50.00 Dinner}}`
  static final RegExp expenseEmbedRegex = RegExp(
    r'\{\{\s*([^\d\s]+)?\s*([0-9]+(?:[\.,][0-9]{1,2})?)\s*([^\}]*)\}\}',
  );

  /// Scans [text] for embedded expense declarations.
  static List<NoteExpenseEmbed> scanExpenseEmbeds(String text) {
    if (text.isEmpty) return const [];
    final matches = expenseEmbedRegex.allMatches(text);
    final results = <NoteExpenseEmbed>[];

    for (final match in matches) {
      final symbol = match.group(1)?.trim() ?? '';
      final amountStr = match.group(2)?.replaceAll(',', '.') ?? '0';
      final memo = match.group(3)?.trim();
      final amount = double.tryParse(amountStr);

      if (amount != null && amount > 0) {
        results.add(NoteExpenseEmbed(
          amount: amount,
          rawMatch: match.group(0) ?? '',
          currencySymbol: symbol.isNotEmpty ? symbol : '',
          customMemo: memo != null && memo.isNotEmpty ? memo : null,
        ));
      }
    }
    return results;
  }

  /// Books an expense embed from [note] into the Financial Ledger.
  static Future<bool> bookExpense({
    required BuildContext context,
    required Note note,
    required NoteExpenseEmbed embed,
    String? category,
  }) async {
    try {
      AppHaptics.lightImpact();
      final finances = context.read<FinancialManagerProvider>();

      final description = embed.customMemo?.isNotEmpty == true
          ? '${note.title}: ${embed.customMemo}'
          : (note.title.isNotEmpty ? note.title : 'Note Expense');

      final transaction = TransactionModel(
        amount: embed.amount,
        isExpense: true,
        category: category ?? 'Shopping',
        date: DateTime.now(),
        description: description,
        account: AccountType.daily,
      );

      await finances.addTransaction(transaction);
      AppHaptics.selectionClick();
      return true;
    } catch (_) {
      return false;
    }
  }
}
