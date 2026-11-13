import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:flutter/foundation.dart';
import '../../../data/database_helper.dart';
import '../../../data/period_log_model.dart';
import '../../../data/database_constants.dart';
import '../../../services/notification_service.dart';
import '../../sync/providers/p2p_sync_provider.dart';

class PeriodRepository {
  static final PeriodRepository instance = PeriodRepository._init();
  PeriodRepository._init();
  factory PeriodRepository() => instance;

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db async => await _dbHelper.database;

  Future<PeriodLog> createPeriodLog(PeriodLog log) async {
    final db = await _db;
    await db.delete(TableNames.deletedPeriodLogs, where: 'id = ?', whereArgs: [log.id]);
    await db.insert(TableNames.periodLogs, log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    if (!kIsWeb) {
      try {
        await NotificationService.schedulePeriodNotifications();
      } catch (_) {}
    }
    P2pSyncProvider.activeInstance?.triggerEventSync();
    return log;
  }

  Future<PeriodLog?> readPeriodLog(String id) async {
    final db = await _db;
    final maps = await db.query(TableNames.periodLogs, where: '${PeriodLogFields.id} = ?', whereArgs: [id]);
    return maps.isNotEmpty ? PeriodLog.fromMap(maps.first) : null;
  }

  Future<List<PeriodLog>> readAllPeriodLogs() async {
    final db = await _db;
    final result = await db.query(TableNames.periodLogs, orderBy: '${PeriodLogFields.startDate} DESC');
    return result.map((json) => PeriodLog.fromMap(json)).toList();
  }

  Future<int> updatePeriodLog(PeriodLog log) async {
    final db = await _db;
    final res = await db.update(TableNames.periodLogs, log.toMap(), where: '${PeriodLogFields.id} = ?', whereArgs: [log.id]);
    if (!kIsWeb) {
      try {
        await NotificationService.schedulePeriodNotifications();
      } catch (_) {}
    }
    P2pSyncProvider.activeInstance?.triggerEventSync();
    return res;
  }

  Future<int> deletePeriodLog(String id) async {
    final db = await _db;
    await db.insert(
      TableNames.deletedPeriodLogs,
      {'id': id, 'deletedAt': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final res = await db.delete(TableNames.periodLogs, where: '${PeriodLogFields.id} = ?', whereArgs: [id]);
    if (!kIsWeb) {
      try {
        await NotificationService.schedulePeriodNotifications();
      } catch (_) {}
    }
    P2pSyncProvider.activeInstance?.triggerEventSync();
    return res;
  }

  Future<List<PeriodLog>> searchPeriodLogs(String keyword) async {
    final db = await _db;
    final result = await db.query(TableNames.periodLogs, where: '${PeriodLogFields.notes} LIKE ? OR ${PeriodLogFields.intensity} LIKE ?', whereArgs: ['%$keyword%', '%$keyword%'], orderBy: '${PeriodLogFields.startDate} DESC');
    return result.map((json) => PeriodLog.fromMap(json)).toList();
  }
}
