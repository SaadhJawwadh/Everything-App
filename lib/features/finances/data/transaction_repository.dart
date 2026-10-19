import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../data/database_helper.dart';
import '../../../data/database_seed.dart';
import '../../../data/category_constants.dart';
import '../../../data/transaction_model.dart';
import '../../../data/database_constants.dart';
import '../../../data/category_definition.dart';
import '../../../data/sms_contact.dart';
import '../../../utils/widget_helper.dart';

class TransactionRepository {
  static final TransactionRepository instance = TransactionRepository._init();
  TransactionRepository._init();
  factory TransactionRepository() => instance;

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db async => await _dbHelper.database;

  Future<TransactionModel> createTransaction(TransactionModel transaction) async {
    final db = await _db;
    final id = await db.insert(TableNames.transactions, transaction.toJson());
    final result = transaction.copy(id: id);
    await WidgetHelper.updateWidgetData();
    return result;
  }

  Future<TransactionModel?> createSmsTransaction(
    TransactionModel transaction, {
    bool bypassTombstones = false,
  }) async {
    final db = await _db;
    final smsId = transaction.smsId;

    if (smsId != null && smsId.isNotEmpty) {
      if (!bypassTombstones) {
        if (await smsExists(smsId)) {
          return null;
        }
      } else {
        await db.delete(
          TableNames.deletedTransactionSmsIds,
          where: 'smsId = ?',
          whereArgs: [smsId],
        );
      }
    }

    final id = await db.insert(
      TableNames.transactions,
      transaction.toJson(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    if (id > 0) {
      final result = transaction.copy(id: id);
      await WidgetHelper.updateWidgetData();
      return result;
    }
    return null;
  }

  Future<TransactionModel?> readTransaction(int id) async {
    final db = await _db;
    final maps = await db.query(TableNames.transactions, columns: TransactionFields.values, where: '${TransactionFields.id} = ?', whereArgs: [id]);
    return maps.isNotEmpty ? TransactionModel.fromJson(maps.first) : null;
  }

  Future<List<TransactionModel>> readAllTransactions({bool includeDeleted = false}) async {
    final db = await _db;
    final where = includeDeleted ? null : '${TransactionFields.deletedAt} IS NULL';
    final result = await db.query(TableNames.transactions, where: where, orderBy: '${TransactionFields.date} DESC');
    return result.map((json) => TransactionModel.fromJson(json)).toList();
  }

  /// Reconciles recurring rules against existing manual or SMS transactions within a ±2 day cycle window.
  Future<TransactionModel?> findMatchingRecurringTransaction({
    required double amount,
    required String description,
    required String category,
    required DateTime targetDate,
    required bool isExpense,
    Duration window = const Duration(days: 2),
  }) async {
    final db = await _db;
    final startDate = targetDate.subtract(window).toIso8601String();
    final endDate = targetDate.add(window).toIso8601String();

    final result = await db.query(
      TableNames.transactions,
      where: '${TransactionFields.deletedAt} IS NULL '
          'AND ${TransactionFields.isExpense} = ? '
          'AND ${TransactionFields.date} >= ? '
          'AND ${TransactionFields.date} <= ?',
      whereArgs: [isExpense ? 1 : 0, startDate, endDate],
    );

    final descLower = description.toLowerCase().trim();
    for (final map in result) {
      final tx = TransactionModel.fromJson(map);
      // Check amount within 1% tolerance or less than 1.0 currency unit difference
      final amountDiff = (tx.amount - amount).abs();
      final isAmountMatch = amountDiff <= (amount * 0.01) || amountDiff < 1.0;
      if (!isAmountMatch) continue;

      final txDescLower = tx.description.toLowerCase().trim();
      final isCategoryMatch = tx.category.toLowerCase() == category.toLowerCase();
      final isDescMatch = descLower.contains(txDescLower) ||
          txDescLower.contains(descLower) ||
          (descLower.isNotEmpty &&
              txDescLower.isNotEmpty &&
              descLower.split(' ').any((w) => w.length > 3 && txDescLower.contains(w)));

      if (isCategoryMatch || isDescMatch) {
        return tx;
      }
    }
    return null;
  }

  Future<List<TransactionModel>> readTrashedTransactions() async {
    final db = await _db;
    final result = await db.query(
      TableNames.transactions,
      where: '${TransactionFields.deletedAt} IS NOT NULL',
      orderBy: '${TransactionFields.deletedAt} DESC',
    );
    return result.map((json) => TransactionModel.fromJson(json)).toList();
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    final db = await _db;
    final count = await db.update(TableNames.transactions, transaction.toJson(), where: '${TransactionFields.id} = ?', whereArgs: [transaction.id]);
    if (count > 0) {
      await WidgetHelper.updateWidgetData();
    }
    return count;
  }

  Future<int> softDeleteTransaction(int id) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final count = await db.update(
      TableNames.transactions,
      {TransactionFields.deletedAt: now},
      where: '${TransactionFields.id} = ?',
      whereArgs: [id],
    );
    if (count > 0) {
      await db.update(
        TableNames.splitBills,
        {SplitBillFields.deletedAt: now},
        where: '${SplitBillFields.transactionId} = ? AND ${SplitBillFields.deletedAt} IS NULL',
        whereArgs: [id],
      );
      await WidgetHelper.updateWidgetData();
    }
    return count;
  }

  Future<int> restoreTransaction(int id) async {
    final db = await _db;
    final count = await db.rawUpdate(
      'UPDATE ${TableNames.transactions} SET ${TransactionFields.deletedAt} = NULL WHERE ${TransactionFields.id} = ?',
      [id],
    );
    if (count > 0) {
      await db.rawUpdate(
        'UPDATE ${TableNames.splitBills} SET ${SplitBillFields.deletedAt} = NULL WHERE ${SplitBillFields.transactionId} = ?',
        [id],
      );
      await WidgetHelper.updateWidgetData();
    }
    return count;
  }

  /// Atomically soft-deletes multiple transactions by ID.
  Future<int> bulkDeleteTransactions(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    int total = 0;
    await db.transaction((txn) async {
      for (final id in ids) {
        total += await txn.update(
          TableNames.transactions,
          {TransactionFields.deletedAt: now},
          where: '${TransactionFields.id} = ?',
          whereArgs: [id],
        );
        await txn.update(
          TableNames.splitBills,
          {SplitBillFields.deletedAt: now},
          where: '${SplitBillFields.transactionId} = ? AND ${SplitBillFields.deletedAt} IS NULL',
          whereArgs: [id],
        );
      }
    });
    if (total > 0) {
      await WidgetHelper.updateWidgetData();
    }
    return total;
  }

  /// Atomically restores multiple soft-deleted transactions by ID.
  Future<int> bulkRestoreTransactions(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await _db;
    int total = 0;
    await db.transaction((txn) async {
      for (final id in ids) {
        total += await txn.rawUpdate(
          'UPDATE ${TableNames.transactions} SET ${TransactionFields.deletedAt} = NULL WHERE ${TransactionFields.id} = ?',
          [id],
        );
        await txn.rawUpdate(
          'UPDATE ${TableNames.splitBills} SET ${SplitBillFields.deletedAt} = NULL WHERE ${SplitBillFields.transactionId} = ?',
          [id],
        );
      }
    });
    if (total > 0) {
      await WidgetHelper.updateWidgetData();
    }
    return total;
  }

  /// Atomically updates the category for multiple transactions by ID.
  Future<int> bulkUpdateCategory(List<int> ids, String category) async {
    if (ids.isEmpty) return 0;
    final db = await _db;
    int total = 0;
    await db.transaction((txn) async {
      for (final id in ids) {
        total += await txn.update(
          TableNames.transactions,
          {TransactionFields.category: category},
          where: '${TransactionFields.id} = ? AND ${TransactionFields.deletedAt} IS NULL',
          whereArgs: [id],
        );
      }
    });
    if (total > 0) {
      await WidgetHelper.updateWidgetData();
    }
    return total;
  }

  /// Atomically updates the account (daily vs savings) for multiple transactions by ID.
  Future<int> bulkUpdateAccount(List<int> ids, String account) async {
    if (ids.isEmpty) return 0;
    final db = await _db;
    int total = 0;
    await db.transaction((txn) async {
      for (final id in ids) {
        total += await txn.update(
          TableNames.transactions,
          {TransactionFields.account: account},
          where: '${TransactionFields.id} = ? AND ${TransactionFields.deletedAt} IS NULL',
          whereArgs: [id],
        );
      }
    });
    if (total > 0) {
      await WidgetHelper.updateWidgetData();
    }
    return total;
  }

  Future<int> permanentlyDeleteTransaction(int id) async {
    final db = await _db;
    final txn = await readTransaction(id);
    if (txn != null && txn.smsId != null && txn.smsId!.isNotEmpty) {
      await db.insert(
        TableNames.deletedTransactionSmsIds,
        {
          'smsId': txn.smsId,
          'deletedAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    final count = await db.delete(TableNames.transactions, where: '${TransactionFields.id} = ?', whereArgs: [id]);
    if (count > 0) {
      await db.update(
        TableNames.splitBills,
        {SplitBillFields.transactionId: null},
        where: '${SplitBillFields.transactionId} = ?',
        whereArgs: [id],
      );
      await WidgetHelper.updateWidgetData();
    }
    return count;
  }

  Future<int> deleteTransaction(int id, {bool soft = true}) async {
    if (soft) {
      return await softDeleteTransaction(id);
    } else {
      return await permanentlyDeleteTransaction(id);
    }
  }

  Future<int> emptyTrash() async {
    final db = await _db;
    final trashed = await readTrashedTransactions();
    for (final t in trashed) {
      if (t.smsId != null && t.smsId!.isNotEmpty) {
        await db.insert(
          TableNames.deletedTransactionSmsIds,
          {
            'smsId': t.smsId,
            'deletedAt': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    final count = await db.delete(
      TableNames.transactions,
      where: '${TransactionFields.deletedAt} IS NOT NULL',
    );
    if (count > 0) {
      await WidgetHelper.updateWidgetData();
    }
    return count;
  }

  Future<int> clearOldTransactionTrash({int days = 30}) async {
    final db = await _db;
    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final oldRows = await db.query(
      TableNames.transactions,
      where: '${TransactionFields.deletedAt} IS NOT NULL AND ${TransactionFields.deletedAt} < ?',
      whereArgs: [cutoff],
    );
    for (final row in oldRows) {
      final smsId = row[TransactionFields.smsId] as String?;
      if (smsId != null && smsId.isNotEmpty) {
        await db.insert(
          TableNames.deletedTransactionSmsIds,
          {
            'smsId': smsId,
            'deletedAt': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    final count = await db.delete(
      TableNames.transactions,
      where: '${TransactionFields.deletedAt} IS NOT NULL AND ${TransactionFields.deletedAt} < ?',
      whereArgs: [cutoff],
    );
    if (count > 0) {
      await WidgetHelper.updateWidgetData();
    }
    return count;
  }

  Future<List<TransactionModel>> searchTransactions(String keyword) async {
    final db = await _db;
    final result = await db.query(
      TableNames.transactions,
      where: '(description LIKE ? OR category LIKE ?) AND ${TransactionFields.deletedAt} IS NULL',
      whereArgs: ['%$keyword%', '%$keyword%'],
      orderBy: 'date DESC',
    );
    return result.map((json) => TransactionModel.fromJson(json)).toList();
  }

  Future<TransactionModel?> findReversalTarget(double amount, DateTime date, {int windowDays = 7}) async {
    final db = await _db;
    final windowStart = date.subtract(Duration(days: windowDays)).toIso8601String();
    final windowEnd = date.toIso8601String();
    final rows = await db.query(
      TableNames.transactions,
      where: 'amount = ? AND isExpense = 1 AND smsId IS NOT NULL AND date >= ? AND date <= ? AND ${TransactionFields.deletedAt} IS NULL',
      whereArgs: [amount, windowStart, windowEnd],
      orderBy: '${TransactionFields.date} DESC',
      limit: 1,
    );
    return rows.isNotEmpty ? TransactionModel.fromJson(rows.first) : null;
  }

  Future<bool> smsExists(String smsId) async {
    if (smsId.isEmpty) return false;
    final db = await _db;

    // Check active or soft-deleted transactions table
    final activeCheck = await db.query(
      TableNames.transactions,
      columns: [TransactionFields.id],
      where: '${TransactionFields.smsId} = ?',
      whereArgs: [smsId],
      limit: 1,
    );
    if (activeCheck.isNotEmpty) return true;

    // Check tombstone table for permanently deleted transactions
    final tombstoneCheck = await db.query(
      TableNames.deletedTransactionSmsIds,
      columns: ['smsId'],
      where: 'smsId = ?',
      whereArgs: [smsId],
      limit: 1,
    );
    return tombstoneCheck.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getMonthlyTransactionSummary(int months) async {
    final db = await _db;
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];
    for (int i = months - 1; i >= 0; i--) {
      final periodStart = DateTime(now.year, now.month - i, 1);
      final periodEnd = DateTime(now.year, now.month - i + 1, 1);
      final rows = await db.rawQuery(
          'SELECT SUM(CASE WHEN isExpense = 0 THEN amount ELSE 0.0 END) AS totalIncome, '
          'SUM(CASE WHEN isExpense = 1 THEN amount ELSE 0.0 END) AS totalExpense '
          'FROM ${TableNames.transactions} '
          'WHERE date >= ? AND date < ? AND category != ? AND ${TransactionFields.deletedAt} IS NULL',
          [
            periodStart.toIso8601String(),
            periodEnd.toIso8601String(),
            '__reversal__'
          ]);
      result.add({
        'month': periodStart,
        'totalIncome': (rows.first['totalIncome'] as num?)?.toDouble() ?? 0.0,
        'totalExpense': (rows.first['totalExpense'] as num?)?.toDouble() ?? 0.0
      });
    }
    return result;
  }

  Future<Map<String, double>> getAllTimeSummary() async {
    final db = await _db;
    final rows = await db.rawQuery(
        'SELECT SUM(CASE WHEN isExpense = 0 THEN amount ELSE 0.0 END) AS totalIncome, '
        'SUM(CASE WHEN isExpense = 1 THEN amount ELSE 0.0 END) AS totalExpense '
        'FROM ${TableNames.transactions} '
        'WHERE category != ? AND ${TransactionFields.deletedAt} IS NULL',
        ['__reversal__']);
    return {
      'totalIncome': (rows.first['totalIncome'] as num?)?.toDouble() ?? 0.0,
      'totalExpense': (rows.first['totalExpense'] as num?)?.toDouble() ?? 0.0
    };
  }

  Future<void> resetCategoriesToDefaults() async {
    final db = await _db;
    await db.delete(TableNames.categoryDefinitions);
    await DatabaseSeed.seedBuiltInCategories(db);
  }

  Future<void> resetBuiltInCategoryKeywords() async {
    final db = await _db;
    for (final name in CategoryConstants.all) {
      final kws = CategoryConstants.keywords[name] ?? <String>[];
      await db.update(
        TableNames.categoryDefinitions,
        {CategoryFields.keywords: jsonEncode(kws)},
        where: '${CategoryFields.name} = ? AND ${CategoryFields.isBuiltIn} = 1',
        whereArgs: [name],
      );
    }
  }

  Future<List<CategoryDefinition>> getAllCategoryDefinitions() async {
    final db = await _db;
    final rows = await db.query(TableNames.categoryDefinitions, orderBy: '${CategoryFields.isBuiltIn} DESC, ${CategoryFields.name} ASC');
    return rows.map(CategoryDefinition.fromMap).toList();
  }

  Future<void> upsertCategoryDefinition(CategoryDefinition def) async {
    await renameCategoryDefinition(def.name, def);
  }

  Future<void> renameCategoryDefinition(String oldName, CategoryDefinition newDef) async {
    final db = await _db;
    await db.transaction((txn) async {
      if (oldName != newDef.name) {
        await txn.update(
          TableNames.transactions,
          {TransactionFields.category: newDef.name},
          where: '${TransactionFields.category} = ?',
          whereArgs: [oldName],
        );
        await txn.update(
          TableNames.recurringRules,
          {RecurringRuleFields.category: newDef.name},
          where: '${RecurringRuleFields.category} = ?',
          whereArgs: [oldName],
        );
        await txn.delete(
          TableNames.categoryDefinitions,
          where: '${CategoryFields.name} = ?',
          whereArgs: [oldName],
        );
      }
      await txn.insert(
        TableNames.categoryDefinitions,
        newDef.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> deleteCategoryDefinition(String name) async {
    if (name == CategoryConstants.other) return;
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        TableNames.transactions,
        {TransactionFields.category: CategoryConstants.other},
        where: '${TransactionFields.category} = ?',
        whereArgs: [name],
      );
      await txn.update(
        TableNames.recurringRules,
        {RecurringRuleFields.category: CategoryConstants.other},
        where: '${RecurringRuleFields.category} = ?',
        whereArgs: [name],
      );
      await txn.delete(
        TableNames.categoryDefinitions,
        where: '${CategoryFields.name} = ?',
        whereArgs: [name],
      );
    });
  }

  Future<List<SmsContact>> getAllSmsContacts() async {
    final db = await _db;
    final rows = await db.query(TableNames.smsContacts, orderBy: '${SmsContactFields.isBuiltIn} DESC, ${SmsContactFields.label} ASC, ${SmsContactFields.id} ASC');
    return rows.map(SmsContact.fromMap).toList();
  }

  Future<void> upsertSmsContact(SmsContact contact) async {
    final db = await _db;
    await db.insert(TableNames.smsContacts, contact.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSmsContact(String id) async {
    final db = await _db;
    await db.delete(TableNames.smsContacts, where: '${SmsContactFields.id} = ? AND ${SmsContactFields.isBuiltIn} = 0', whereArgs: [id]);
  }

  Future<void> setSmsContactBlocked(String id, bool blocked) async {
    final db = await _db;
    await db.update(TableNames.smsContacts, {SmsContactFields.isBlocked: blocked ? 1 : 0}, where: '${SmsContactFields.id} = ?', whereArgs: [id]);
  }

  Future<bool> hasCrossSenderDuplicate(double amount, DateTime date) async {
    final db = await _db;
    final windowStart = date.subtract(const Duration(minutes: 5)).toIso8601String();
    final windowEnd = date.add(const Duration(minutes: 5)).toIso8601String();
    final rows = await db.query(
      TableNames.transactions,
      columns: [TransactionFields.id],
      where: 'amount >= ? AND amount <= ? AND smsId IS NOT NULL AND date >= ? AND date <= ?',
      whereArgs: [amount - 0.005, amount + 0.005, windowStart, windowEnd],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> cleanupDuplicates() async {
    final db = await _db;
    final allTxns = await readAllTransactions();
    if (allTxns.length < 2) return 0;

    final toDeleteIds = <int>{};
    for (int i = 0; i < allTxns.length; i++) {
      final a = allTxns[i];
      if (a.id == null || toDeleteIds.contains(a.id)) continue;

      for (int j = i + 1; j < allTxns.length; j++) {
        final b = allTxns[j];
        if (b.id == null || toDeleteIds.contains(b.id)) continue;

        final isSameAmount = (a.amount - b.amount).abs() < 0.01;
        final isSameType = a.isExpense == b.isExpense;
        final isTimeClose = a.date.difference(b.date).abs() <= const Duration(seconds: 120);

        if (isSameAmount && isSameType && isTimeClose) {
          toDeleteIds.add(b.id!);
        }
      }
    }

    if (toDeleteIds.isNotEmpty) {
      final placeholders = List.filled(toDeleteIds.length, '?').join(',');
      await db.delete(
        TableNames.transactions,
        where: '${TransactionFields.id} IN ($placeholders)',
        whereArgs: toDeleteIds.toList(),
      );
      await WidgetHelper.updateWidgetData();
    }

    return toDeleteIds.length;
  }
}
