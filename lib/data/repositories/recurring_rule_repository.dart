import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database_helper.dart';
import '../database_constants.dart';
import '../recurring_rule_model.dart';
import '../transaction_model.dart';
import '../../features/finances/data/transaction_repository.dart';

class RecurringRuleRepository {
  static final RecurringRuleRepository instance = RecurringRuleRepository._init();
  RecurringRuleRepository._init();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db async {
    final db = await _dbHelper.database;
    await DatabaseHelper.ensureRecurringRulesColumns(db);
    return db;
  }

  static const Set<String> _matchingStopwords = {
    'payment',
    'purchase',
    'debit',
    'credit',
    'transfer',
    'monthly',
    'weekly',
    'daily',
    'subscription',
    'subscriptions',
    'bill',
    'bills',
    'card',
    'bank',
    'online',
    'store',
    'shop',
    'paid',
    'from',
    'with',
    'auto',
    'recurring',
  };

  Future<RecurringRule> createRule(RecurringRule rule) async {
    final db = await _db;
    final allRules = await readAllRules();
    final descLower = rule.description.trim().toLowerCase();
    RecurringRule? existing;
    for (final r in allRules) {
      if (r.description.trim().toLowerCase() == descLower && r.frequency == rule.frequency) {
        existing = r;
        break;
      }
    }

    if (existing != null) {
      final updated = existing.copyWith(
        amount: rule.amount,
        category: rule.category,
        isExpense: rule.isExpense,
        nextDue: rule.nextDue,
        account: rule.account,
        anchorDay: rule.anchorDay,
      );
      await db.update(
        TableNames.recurringRules,
        updated.toJson(),
        where: '${RecurringRuleFields.id} = ?',
        whereArgs: [updated.id],
      );
      return updated;
    } else {
      await db.insert(
        TableNames.recurringRules,
        rule.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return rule;
    }
  }

  Future<void> updateRule(RecurringRule rule) async {
    final db = await _db;
    await db.update(
      TableNames.recurringRules,
      rule.toJson(),
      where: '${RecurringRuleFields.id} = ?',
      whereArgs: [rule.id],
    );
  }

  Future<List<RecurringRule>> readAllRules() async {
    final db = await _db;
    final rows = await db.query(TableNames.recurringRules,
        orderBy: '${RecurringRuleFields.nextDue} ASC');
    return rows.map(RecurringRule.fromJson).toList();
  }

  Future<RecurringRule?> findMatchingRule({
    required String description,
    required String category,
    required bool isExpense,
    double? amount,
  }) async {
    final descLower = description.trim().toLowerCase();
    if (descLower.isEmpty) return null;

    final allRules = await readAllRules();
    final catLower = category.trim().toLowerCase();

    for (final rule in allRules) {
      if (rule.isExpense != isExpense) continue;
      final ruleDescLower = rule.description.trim().toLowerCase();
      if (ruleDescLower.isEmpty) continue;
      final ruleCatLower = rule.category.trim().toLowerCase();

      final isExactDesc = ruleDescLower == descLower;
      if (isExactDesc) return rule;

      final isAmountClose = amount == null ||
          (rule.amount - amount).abs() < 1.0 ||
          (rule.amount - amount).abs() <= (rule.amount * 0.05);

      final minLen = descLower.length < ruleDescLower.length
          ? descLower.length
          : ruleDescLower.length;
      final isSubstring = minLen >= 3 &&
          (descLower.contains(ruleDescLower) || ruleDescLower.contains(descLower));

      final ruleWords = ruleDescLower
          .split(RegExp(r'[^a-z0-9]+'))
          .where((w) => w.length > 3 && !_matchingStopwords.contains(w))
          .toSet();
      final descWords = descLower
          .split(RegExp(r'[^a-z0-9]+'))
          .where((w) => w.length > 3 && !_matchingStopwords.contains(w))
          .toSet();
      final isWordMatch = ruleWords.isNotEmpty &&
          descWords.any((w) => ruleWords.contains(w));

      if ((isSubstring || isWordMatch) &&
          (ruleCatLower == catLower || isAmountClose)) {
        return rule;
      }
    }
    return null;
  }

  Future<void> deleteRule(String id) async {
    final db = await _db;
    await db.delete(TableNames.recurringRules,
        where: '${RecurringRuleFields.id} = ?', whereArgs: [id]);
  }

  static Duration _deduplicationWindowFor(RecurringFrequency frequency) {
    switch (frequency) {
      case RecurringFrequency.daily:
        return Duration.zero;
      case RecurringFrequency.weekly:
        return const Duration(days: 2);
      case RecurringFrequency.monthly:
        return const Duration(days: 3);
    }
  }

  /// Inserts a real transaction for every period that has elapsed on every
  /// rule, then advances the rule's next-due date. Returns how many
  /// transactions were created. Safe to call on every dashboard refresh.
  Future<int> materializeDueRules({bool force = false}) async {
    if (!force) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final isEnabled = prefs.getBool('enableRecurringRules') ?? true;
        if (!isEnabled) return 0;
      } catch (_) {}
    }

    final now = DateTime.now();
    final rules = await readAllRules();
    var created = 0;

    for (var rule in rules) {
      // Cap the catch-up loop so a rule due years in the past can't flood
      // the ledger in one refresh.
      var iterations = 0;
      var advanced = false;
      final dedupWindow = _deduplicationWindowFor(rule.frequency);

      while (!rule.nextDue.isAfter(now) && iterations < 36) {
        // Smart cycle-aware deduplication: check if a transaction (manual or SMS)
        // already exists within the frequency-scoped window of this due date.
        final existingMatch =
            await TransactionRepository.instance.findMatchingRecurringTransaction(
          amount: rule.amount,
          description: rule.description,
          category: rule.category,
          targetDate: rule.nextDue,
          isExpense: rule.isExpense,
          window: dedupWindow,
        );

        if (existingMatch == null) {
          await TransactionRepository.instance.createTransaction(
            TransactionModel(
              amount: rule.amount,
              description: rule.description,
              date: rule.nextDue,
              isExpense: rule.isExpense,
              category: rule.category,
              account: rule.account,
            ),
          );
          created++;
        }
        iterations++;
        rule = rule.copyWith(
          nextDue: rule.advance(rule.nextDue),
          anchorDay: rule.anchorDay,
        );
        advanced = true;
      }
      if (advanced) {
        final db = await _db;
        await db.update(
          TableNames.recurringRules,
          {
            RecurringRuleFields.nextDue: rule.nextDue.toIso8601String(),
            RecurringRuleFields.anchorDay: rule.anchorDay,
          },
          where: '${RecurringRuleFields.id} = ?',
          whereArgs: [rule.id],
        );
      }
    }
    return created;
  }
}
