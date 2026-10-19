import 'package:flutter/material.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/database_helper.dart';
import '../../../../data/database_constants.dart';
import '../../../../data/transaction_model.dart';
import '../models/split_bill_model.dart';

class SplitBillRepository {
  static final SplitBillRepository instance = SplitBillRepository._();
  SplitBillRepository._();

  DatabaseHelper get _dbHelper => DatabaseHelper.instance;

  Future<List<SplitBillModel>> getSplitBills({
    bool includeSettled = true,
    String? groupTag,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>['${SplitBillFields.deletedAt} IS NULL'];
    final whereArgs = <dynamic>[];

    if (!includeSettled) {
      whereClauses.add("${SplitBillFields.status} != 'settled'");
    }

    if (groupTag != null && groupTag.trim().isNotEmpty && groupTag != 'All') {
      whereClauses.add('${SplitBillFields.groupTag} = ?');
      whereArgs.add(groupTag.trim());
    }

    final billMaps = await db.query(
      TableNames.splitBills,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: '${SplitBillFields.date} DESC',
    );

    if (billMaps.isEmpty) return [];

    final billIds = billMaps.map((b) => b[SplitBillFields.id] as String).toList();
    final participantsMap = await _getParticipantsForBills(db, billIds);

    return billMaps.map((map) {
      final billId = map[SplitBillFields.id] as String;
      final participants = participantsMap[billId] ?? [];
      return SplitBillModel.fromMap(map, participants: participants);
    }).toList();
  }

  Future<Map<String, List<SplitParticipantModel>>> _getParticipantsForBills(
    Database db,
    List<String> billIds,
  ) async {
    if (billIds.isEmpty) return {};
    final placeholders = List.filled(billIds.length, '?').join(',');
    final participantMaps = await db.query(
      TableNames.splitParticipants,
      where: '${SplitParticipantFields.billId} IN ($placeholders)',
      whereArgs: billIds,
    );

    final result = <String, List<SplitParticipantModel>>{};
    for (final pMap in participantMaps) {
      final p = SplitParticipantModel.fromMap(pMap);
      result.putIfAbsent(p.billId, () => []).add(p);
    }
    return result;
  }

  Future<SplitBillModel?> getBillById(String id) async {
    final db = await _dbHelper.database;
    final billMaps = await db.query(
      TableNames.splitBills,
      where: '${SplitBillFields.id} = ?',
      whereArgs: [id],
    );
    if (billMaps.isEmpty) return null;

    final participantMaps = await db.query(
      TableNames.splitParticipants,
      where: '${SplitParticipantFields.billId} = ?',
      whereArgs: [id],
    );
    final participants = participantMaps.map((m) => SplitParticipantModel.fromMap(m)).toList();

    return SplitBillModel.fromMap(billMaps.first, participants: participants);
  }

  Future<SplitBillModel?> getBillByTransactionId(int transactionId) async {
    final db = await _dbHelper.database;
    final billMaps = await db.query(
      TableNames.splitBills,
      where: '${SplitBillFields.transactionId} = ? AND ${SplitBillFields.deletedAt} IS NULL',
      whereArgs: [transactionId],
    );
    if (billMaps.isEmpty) return null;

    final billId = billMaps.first[SplitBillFields.id] as String;
    final participantMaps = await db.query(
      TableNames.splitParticipants,
      where: '${SplitParticipantFields.billId} = ?',
      whereArgs: [billId],
    );
    final participants = participantMaps.map((m) => SplitParticipantModel.fromMap(m)).toList();

    return SplitBillModel.fromMap(billMaps.first, participants: participants);
  }

  Future<void> insertSplitBill(SplitBillModel bill) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        TableNames.splitBills,
        bill.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final p in bill.participants) {
        await txn.insert(
          TableNames.splitParticipants,
          p.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Update contacts directory
        if (p.contactName.trim().toLowerCase() != 'you' && p.contactName.trim().isNotEmpty) {
          await _saveContactInternal(txn, p.contactName.trim());
        }
      }

      if (!bill.isPayerUser && bill.payerName.trim().toLowerCase() != 'you') {
        await _saveContactInternal(txn, bill.payerName.trim());
      }
    });
  }

  Future<void> updateSplitBill(SplitBillModel bill) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        TableNames.splitBills,
        bill.toMap(),
        where: '${SplitBillFields.id} = ?',
        whereArgs: [bill.id],
      );

      // Re-sync participants
      await txn.delete(
        TableNames.splitParticipants,
        where: '${SplitParticipantFields.billId} = ?',
        whereArgs: [bill.id],
      );

      for (final p in bill.participants) {
        await txn.insert(
          TableNames.splitParticipants,
          p.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        if (p.contactName.trim().toLowerCase() != 'you' && p.contactName.trim().isNotEmpty) {
          await _saveContactInternal(txn, p.contactName.trim());
        }
      }

      // Propagate changes to linked ledger transaction if present
      if (bill.transactionId != null) {
        if (bill.isPayerUser) {
          await txn.update(
            TableNames.transactions,
            {
              TransactionFields.amount: bill.totalAmount,
              TransactionFields.description: '${bill.title} (Split: You paid)',
              TransactionFields.date: bill.date.toIso8601String(),
              if (bill.groupTag != null && bill.groupTag!.isNotEmpty)
                TransactionFields.category: bill.groupTag,
            },
            where: '${TransactionFields.id} = ?',
            whereArgs: [bill.transactionId],
          );
        } else {
          // If bill.isPayerUser was changed to false on an existing bill that had a transactionId,
          // soft-delete the old linked ledger transaction and set transactionId = null on split_bills
          await txn.update(
            TableNames.transactions,
            {TransactionFields.deletedAt: DateTime.now().toIso8601String()},
            where: '${TransactionFields.id} = ?',
            whereArgs: [bill.transactionId],
          );
          await txn.update(
            TableNames.splitBills,
            {SplitBillFields.transactionId: null},
            where: '${SplitBillFields.id} = ?',
            whereArgs: [bill.id],
          );
        }
      }
    });
  }

  Future<int?> toggleParticipantPaid(
    String participantId,
    bool hasPaid, {
    int? settlementTransactionId,
  }) async {
    final db = await _dbHelper.database;
    int? removedTxId;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      if (!hasPaid) {
        final current = await txn.query(
          TableNames.splitParticipants,
          columns: [SplitParticipantFields.settlementTransactionId],
          where: '${SplitParticipantFields.id} = ?',
          whereArgs: [participantId],
        );
        if (current.isNotEmpty) {
          removedTxId = current.first[SplitParticipantFields.settlementTransactionId] as int?;
        }
      }

      await txn.update(
        TableNames.splitParticipants,
        {
          SplitParticipantFields.hasPaid: hasPaid ? 1 : 0,
          SplitParticipantFields.paidAt: hasPaid ? now : null,
          SplitParticipantFields.settlementTransactionId: hasPaid ? settlementTransactionId : null,
        },
        where: '${SplitParticipantFields.id} = ?',
        whereArgs: [participantId],
      );

      // Find parent bill and update status
      final pMaps = await txn.query(
        TableNames.splitParticipants,
        where: '${SplitParticipantFields.id} = ?',
        whereArgs: [participantId],
      );
      if (pMaps.isNotEmpty) {
        final billId = pMaps.first[SplitParticipantFields.billId] as String;
        final allPMaps = await txn.query(
          TableNames.splitParticipants,
          where: '${SplitParticipantFields.billId} = ?',
          whereArgs: [billId],
        );
        final participants = allPMaps.map((m) => SplitParticipantModel.fromMap(m)).toList();
        final billMap = await txn.query(
          TableNames.splitBills,
          where: '${SplitBillFields.id} = ?',
          whereArgs: [billId],
        );
        if (billMap.isNotEmpty) {
          final bill = SplitBillModel.fromMap(billMap.first, participants: participants);
          final derivedStatus = bill.computeDerivedStatus();
          await txn.update(
            TableNames.splitBills,
            {SplitBillFields.status: derivedStatus.name},
            where: '${SplitBillFields.id} = ?',
            whereArgs: [billId],
          );
        }
      }
    });
    return removedTxId;
  }

  Future<int?> toggleUserShareForBill(
    String billId,
    bool hasPaid, {
    int? settlementTransactionId,
  }) async {
    final db = await _dbHelper.database;
    int? removedTxId;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final youRows = await txn.query(
        TableNames.splitParticipants,
        where: '${SplitParticipantFields.billId} = ? AND LOWER(TRIM(${SplitParticipantFields.contactName})) = ?',
        whereArgs: [billId, 'you'],
      );

      if (youRows.isNotEmpty) {
        final pId = youRows.first[SplitParticipantFields.id] as String;
        if (!hasPaid) {
          removedTxId = youRows.first[SplitParticipantFields.settlementTransactionId] as int?;
        }
        await txn.update(
          TableNames.splitParticipants,
          {
            SplitParticipantFields.hasPaid: hasPaid ? 1 : 0,
            SplitParticipantFields.paidAt: hasPaid ? now : null,
            SplitParticipantFields.settlementTransactionId: hasPaid ? settlementTransactionId : null,
          },
          where: '${SplitParticipantFields.id} = ?',
          whereArgs: [pId],
        );
      } else if (hasPaid) {
        // Fallback: insert a 'You' participant row if missing
        final billMap = await txn.query(
          TableNames.splitBills,
          where: '${SplitBillFields.id} = ?',
          whereArgs: [billId],
        );
        if (billMap.isNotEmpty) {
          final totalAmt = (billMap.first[SplitBillFields.totalAmount] as num? ?? 0.0).toDouble();
          final existingParts = await txn.query(
            TableNames.splitParticipants,
            where: '${SplitParticipantFields.billId} = ?',
            whereArgs: [billId],
          );
          final divisor = (existingParts.length + 1);
          final shareAmt = divisor > 0 ? (totalAmt / divisor) : totalAmt;
          final pId = '${billId}_you';
          await txn.insert(
            TableNames.splitParticipants,
            {
              SplitParticipantFields.id: pId,
              SplitParticipantFields.billId: billId,
              SplitParticipantFields.contactName: 'You',
              SplitParticipantFields.shareAmount: shareAmt,
              SplitParticipantFields.hasPaid: 1,
              SplitParticipantFields.paidAt: now,
              SplitParticipantFields.settlementTransactionId: settlementTransactionId,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // Re-derive parent bill status
      final allPMaps = await txn.query(
        TableNames.splitParticipants,
        where: '${SplitParticipantFields.billId} = ?',
        whereArgs: [billId],
      );
      final participants = allPMaps.map((m) => SplitParticipantModel.fromMap(m)).toList();
      final billMap = await txn.query(
        TableNames.splitBills,
        where: '${SplitBillFields.id} = ?',
        whereArgs: [billId],
      );
      if (billMap.isNotEmpty) {
        final bill = SplitBillModel.fromMap(billMap.first, participants: participants);
        final derivedStatus = bill.computeDerivedStatus();
        await txn.update(
          TableNames.splitBills,
          {SplitBillFields.status: derivedStatus.name},
          where: '${SplitBillFields.id} = ?',
          whereArgs: [billId],
        );
      }
    });
    return removedTxId;
  }

  Future<void> settleAllForContact(
    String contactName, {
    int? settlementTransactionId,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final normalized = contactName.trim().toLowerCase();

      // 1. Mark as paid in all active bills where the user is the payer
      await txn.rawUpdate('''
        UPDATE ${TableNames.splitParticipants}
        SET ${SplitParticipantFields.hasPaid} = 1,
            ${SplitParticipantFields.paidAt} = ?,
            ${SplitParticipantFields.settlementTransactionId} = ?
        WHERE LOWER(TRIM(${SplitParticipantFields.contactName})) = ?
          AND ${SplitParticipantFields.hasPaid} = 0
          AND ${SplitParticipantFields.billId} IN (
            SELECT ${SplitBillFields.id} FROM ${TableNames.splitBills}
            WHERE ${SplitBillFields.isPayerUser} = 1 AND ${SplitBillFields.deletedAt} IS NULL
          )
      ''', [now, settlementTransactionId, normalized]);

      // 2. Scope friend-payer updates strictly to active bills where friend is payer
      final friendBills = await txn.query(
        TableNames.splitBills,
        where: 'LOWER(TRIM(${SplitBillFields.payerName})) = ? AND ${SplitBillFields.isPayerUser} = 0 AND ${SplitBillFields.deletedAt} IS NULL',
        whereArgs: [normalized],
      );

      for (final bMap in friendBills) {
        final billId = bMap[SplitBillFields.id] as String;
        final youPart = await txn.query(
          TableNames.splitParticipants,
          where: '${SplitParticipantFields.billId} = ? AND LOWER(TRIM(${SplitParticipantFields.contactName})) = \'you\'',
          whereArgs: [billId],
        );

        if (youPart.isNotEmpty) {
          await txn.update(
            TableNames.splitParticipants,
            {
              SplitParticipantFields.hasPaid: 1,
              SplitParticipantFields.paidAt: now,
              SplitParticipantFields.settlementTransactionId: settlementTransactionId,
            },
            where: '${SplitParticipantFields.id} = ?',
            whereArgs: [youPart.first[SplitParticipantFields.id]],
          );
        } else {
          final billTotal = (bMap[SplitBillFields.totalAmount] as num).toDouble();
          final otherParts = await txn.query(
            TableNames.splitParticipants,
            where: '${SplitParticipantFields.billId} = ?',
            whereArgs: [billId],
          );
          final othersSum = otherParts.fold<double>(0.0, (sum, m) => sum + (m[SplitParticipantFields.shareAmount] as num).toDouble());
          final userShare = (billTotal - othersSum) > 0 ? (billTotal - othersSum) : 0.0;
          await txn.insert(
            TableNames.splitParticipants,
            {
              SplitParticipantFields.id: const Uuid().v4(),
              SplitParticipantFields.billId: billId,
              SplitParticipantFields.contactName: 'You',
              SplitParticipantFields.shareAmount: userShare,
              SplitParticipantFields.hasPaid: 1,
              SplitParticipantFields.paidAt: now,
              SplitParticipantFields.settlementTransactionId: settlementTransactionId,
            },
          );
        }

        await txn.update(
          TableNames.splitBills,
          {SplitBillFields.status: SplitStatus.settled.name},
          where: '${SplitBillFields.id} = ?',
          whereArgs: [billId],
        );
      }

      // 3. Recompute computeDerivedStatus() on all affected active bills
      final affectedBills = await txn.rawQuery('''
        SELECT DISTINCT ${SplitParticipantFields.billId} AS bill_id FROM ${TableNames.splitParticipants}
        WHERE LOWER(TRIM(${SplitParticipantFields.contactName})) = ?
          AND ${SplitParticipantFields.billId} IN (
            SELECT ${SplitBillFields.id} FROM ${TableNames.splitBills} WHERE ${SplitBillFields.deletedAt} IS NULL
          )
        UNION
        SELECT ${SplitBillFields.id} AS bill_id FROM ${TableNames.splitBills}
        WHERE LOWER(TRIM(${SplitBillFields.payerName})) = ? AND ${SplitBillFields.deletedAt} IS NULL
      ''', [normalized, normalized]);

      for (final row in affectedBills) {
        final billId = row['bill_id'] as String;
        final allPMaps = await txn.query(
          TableNames.splitParticipants,
          where: '${SplitParticipantFields.billId} = ?',
          whereArgs: [billId],
        );
        final participants = allPMaps.map((m) => SplitParticipantModel.fromMap(m)).toList();
        final billMap = await txn.query(
          TableNames.splitBills,
          where: '${SplitBillFields.id} = ?',
          whereArgs: [billId],
        );
        if (billMap.isNotEmpty) {
          final bill = SplitBillModel.fromMap(billMap.first, participants: participants);
          final derivedStatus = bill.computeDerivedStatus();
          await txn.update(
            TableNames.splitBills,
            {SplitBillFields.status: derivedStatus.name},
            where: '${SplitBillFields.id} = ?',
            whereArgs: [billId],
          );
        }
      }
    });
  }

  Future<List<int>> unsettleAllForContact(String contactName) async {
    final db = await _dbHelper.database;
    final removedTxIds = <int>{};
    await db.transaction((txn) async {
      final normalized = contactName.trim().toLowerCase();

      // Find the most recent settlement batch for this contact across active bills (deletedAt IS NULL)
      final settledRows = await txn.rawQuery('''
        SELECT p.${SplitParticipantFields.id},
               p.${SplitParticipantFields.paidAt},
               p.${SplitParticipantFields.settlementTransactionId},
               p.${SplitParticipantFields.billId}
        FROM ${TableNames.splitParticipants} p
        JOIN ${TableNames.splitBills} b ON p.${SplitParticipantFields.billId} = b.${SplitBillFields.id}
        WHERE b.${SplitBillFields.deletedAt} IS NULL
          AND p.${SplitParticipantFields.hasPaid} = 1
          AND (
            (b.${SplitBillFields.isPayerUser} = 1 AND LOWER(TRIM(p.${SplitParticipantFields.contactName})) = ?)
            OR
            (b.${SplitBillFields.isPayerUser} = 0 AND LOWER(TRIM(b.${SplitBillFields.payerName})) = ? AND LOWER(TRIM(p.${SplitParticipantFields.contactName})) = 'you')
          )
        ORDER BY p.${SplitParticipantFields.paidAt} DESC
      ''', [normalized, normalized]);

      if (settledRows.isEmpty) return;

      final firstRow = settledRows.first;
      final targetTxId = firstRow[SplitParticipantFields.settlementTransactionId] as int?;
      final targetPaidAtStr = firstRow[SplitParticipantFields.paidAt] as String?;
      final targetPaidAt = targetPaidAtStr != null ? DateTime.tryParse(targetPaidAtStr) : null;

      final rowsToReopen = <Map<String, dynamic>>[];
      if (targetTxId != null) {
        for (final r in settledRows) {
          if (r[SplitParticipantFields.settlementTransactionId] == targetTxId) {
            rowsToReopen.add(r);
          }
        }
      } else if (targetPaidAt != null) {
        for (final r in settledRows) {
          final pStr = r[SplitParticipantFields.paidAt] as String?;
          final pDate = pStr != null ? DateTime.tryParse(pStr) : null;
          if (pDate != null && (pDate.difference(targetPaidAt).inSeconds.abs() <= 5)) {
            rowsToReopen.add(r);
          }
        }
      } else {
        rowsToReopen.add(firstRow);
      }

      for (final r in rowsToReopen) {
        final pId = r[SplitParticipantFields.id] as String;
        final txId = r[SplitParticipantFields.settlementTransactionId] as int?;
        if (txId != null) {
          removedTxIds.add(txId);
        }
        await txn.update(
          TableNames.splitParticipants,
          {
            SplitParticipantFields.hasPaid: 0,
            SplitParticipantFields.paidAt: null,
            SplitParticipantFields.settlementTransactionId: null,
          },
          where: '${SplitParticipantFields.id} = ?',
          whereArgs: [pId],
        );
      }

      // Recompute statuses of all bills involved in rowsToReopen
      final billIdsToRecompute = rowsToReopen
          .map((r) => r[SplitParticipantFields.billId] as String)
          .toSet();

      for (final billId in billIdsToRecompute) {
        final allPMaps = await txn.query(
          TableNames.splitParticipants,
          where: '${SplitParticipantFields.billId} = ?',
          whereArgs: [billId],
        );
        final participants = allPMaps.map((m) => SplitParticipantModel.fromMap(m)).toList();
        final billMap = await txn.query(
          TableNames.splitBills,
          where: '${SplitBillFields.id} = ?',
          whereArgs: [billId],
        );
        if (billMap.isNotEmpty) {
          final bill = SplitBillModel.fromMap(billMap.first, participants: participants);
          final derivedStatus = bill.computeDerivedStatus();
          await txn.update(
            TableNames.splitBills,
            {SplitBillFields.status: derivedStatus.name},
            where: '${SplitBillFields.id} = ?',
            whereArgs: [billId],
          );
        }
      }
    });
    return removedTxIds.toList();
  }

  Future<void> softDeleteSplitBill(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      await txn.update(
        TableNames.splitBills,
        {SplitBillFields.deletedAt: now},
        where: '${SplitBillFields.id} = ?',
        whereArgs: [id],
      );

      final maps = await txn.query(
        TableNames.splitBills,
        columns: [SplitBillFields.transactionId],
        where: '${SplitBillFields.id} = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty && maps.first[SplitBillFields.transactionId] != null) {
        final txId = maps.first[SplitBillFields.transactionId] as int;
        await txn.update(
          TableNames.transactions,
          {TransactionFields.deletedAt: now},
          where: '${TransactionFields.id} = ?',
          whereArgs: [txId],
        );
      }
    });
  }

  Future<void> restoreSplitBill(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        TableNames.splitBills,
        {SplitBillFields.deletedAt: null},
        where: '${SplitBillFields.id} = ?',
        whereArgs: [id],
      );

      final maps = await txn.query(
        TableNames.splitBills,
        columns: [SplitBillFields.transactionId],
        where: '${SplitBillFields.id} = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty && maps.first[SplitBillFields.transactionId] != null) {
        final txId = maps.first[SplitBillFields.transactionId] as int;
        await txn.update(
          TableNames.transactions,
          {TransactionFields.deletedAt: null},
          where: '${TransactionFields.id} = ?',
          whereArgs: [txId],
        );
      }
    });
  }

  Future<void> permanentlyDeleteSplitBill(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(
        TableNames.splitParticipants,
        where: '${SplitParticipantFields.billId} = ?',
        whereArgs: [id],
      );
      await txn.delete(
        TableNames.splitBills,
        where: '${SplitBillFields.id} = ?',
        whereArgs: [id],
      );
    });
  }

  Future<List<SplitContactModel>> getRecentContacts({int limit = 20}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      TableNames.splitContacts,
      orderBy: '${SplitContactFields.lastUsed} DESC',
      limit: limit,
    );
    return maps.map((m) => SplitContactModel.fromMap(m)).toList();
  }

  Future<void> saveContact(String name, {String? phoneNumber, int? colorValue}) async {
    final db = await _dbHelper.database;
    await _saveContactInternal(db, name, phoneNumber: phoneNumber, colorValue: colorValue);
  }

  Future<void> _saveContactInternal(
    DatabaseExecutor db,
    String name, {
    String? phoneNumber,
    int? colorValue,
  }) async {
    if (name.trim().isEmpty || name.trim().toLowerCase() == 'you') return;
    final cleanName = name.trim();
    final defaultColors = [
      Colors.indigo.toARGB32(),
      Colors.teal.toARGB32(),
      Colors.deepOrange.toARGB32(),
      Colors.purple.toARGB32(),
      Colors.blue.toARGB32(),
      Colors.amber.toARGB32(),
      Colors.cyan.toARGB32(),
    ];
    final color = colorValue ?? defaultColors[cleanName.hashCode.abs() % defaultColors.length];

    await db.insert(
      TableNames.splitContacts,
      {
        SplitContactFields.name: cleanName,
        SplitContactFields.phoneNumber: phoneNumber,
        SplitContactFields.colorValue: color,
        SplitContactFields.lastUsed: DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, double>> getSummaryMetrics() async {
    final bills = await getSplitBills(includeSettled: false);
    double totalOwedToUser = 0.0;
    double totalUserOwes = 0.0;

    for (final bill in bills) {
      if (bill.isPayerUser) {
        totalOwedToUser += bill.totalOwedToUser;
      } else {
        totalUserOwes += bill.totalUserOwes;
      }
    }

    return {
      'owedToUser': totalOwedToUser,
      'userOwes': totalUserOwes,
      'netBalance': totalOwedToUser - totalUserOwes,
    };
  }

  Future<Map<String, double>> getContactNetBalances() async {
    final bills = await getSplitBills(includeSettled: false);
    final db = await _dbHelper.database;
    final contactMaps = await db.query(TableNames.splitContacts);
    final displayNames = <String, String>{};
    for (final cm in contactMaps) {
      final name = (cm[SplitContactFields.name] as String).trim();
      displayNames[name.toLowerCase()] = name;
    }

    final lowerBalances = <String, double>{};
    final firstSeenCase = <String, String>{};

    for (final bill in bills) {
      if (bill.isPayerUser) {
        // Participants owe user
        for (final p in bill.participants) {
          if (!p.hasPaid && p.contactName.trim().toLowerCase() != 'you') {
            final lower = p.contactName.trim().toLowerCase();
            firstSeenCase.putIfAbsent(lower, () => p.contactName.trim());
            lowerBalances[lower] = (lowerBalances[lower] ?? 0.0) + p.shareAmount;
          }
        }
      } else {
        // User owes payer
        if (!bill.isUserSharePaid) {
          final lower = bill.payerName.trim().toLowerCase();
          firstSeenCase.putIfAbsent(lower, () => bill.payerName.trim());
          lowerBalances[lower] = (lowerBalances[lower] ?? 0.0) - bill.userShare;
        }
      }
    }

    final balances = <String, double>{};
    for (final entry in lowerBalances.entries) {
      final displayName = displayNames[entry.key] ?? firstSeenCase[entry.key] ?? entry.key;
      balances[displayName] = entry.value;
    }

    return balances;
  }
}
