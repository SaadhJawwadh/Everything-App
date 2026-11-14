import 'package:sqflite_sqlcipher/sqflite.dart';
import '../data/database_helper.dart';
import '../utils/rich_text_utils.dart';
import '../utils/widget_helper.dart';

class SyncMergeResult {
  final int notesMerged;
  final int transactionsMerged;
  final int periodLogsMerged;
  final int categoriesMerged;
  final int splitBillsMerged;
  final int savingsGoalsMerged;

  SyncMergeResult({
    this.notesMerged = 0,
    this.transactionsMerged = 0,
    this.periodLogsMerged = 0,
    this.categoriesMerged = 0,
    this.splitBillsMerged = 0,
    this.savingsGoalsMerged = 0,
  });

  int get totalMerged =>
      notesMerged +
      transactionsMerged +
      periodLogsMerged +
      categoriesMerged +
      splitBillsMerged +
      savingsGoalsMerged;
}

class SyncMergeService {
  static final SyncMergeService instance = SyncMergeService._init();
  SyncMergeService._init();
  factory SyncMergeService() => instance;

  /// Performs an atomic, non-destructive bi-directional Last-Write-Wins (LWW) merge.
  Future<SyncMergeResult> mergeRemoteData(Map<String, dynamic> remoteData) async {
    // Automatically capture a pre-sync local rolling snapshot before executing remote merge
    await DatabaseHelper.instance.createPreSyncSnapshot();

    final db = await DatabaseHelper.instance.database;

    int notesMerged = 0;
    int transactionsMerged = 0;
    int periodLogsMerged = 0;
    int categoriesMerged = 0;
    int splitBillsMerged = 0;
    int savingsGoalsMerged = 0;

    await db.transaction((txn) async {
      // 0. Merge Tombstones (deleted_notes & deleted_transaction_sms_ids)
      final Set<String> tombstoneIds = {};
      try {
        final existingTombstones = await txn.query('deleted_notes');
        for (final row in existingTombstones) {
          final id = row['id'] as String?;
          if (id != null) tombstoneIds.add(id);
        }

        if (remoteData.containsKey('deletedNotes') && remoteData['deletedNotes'] is List) {
          final batch = txn.batch();
          for (final item in remoteData['deletedNotes'] as List) {
            if (item is Map && item['id'] != null) {
              final tid = item['id'].toString();
              tombstoneIds.add(tid);
              batch.insert('deleted_notes', Map<String, Object?>.from(item), conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          }
          await batch.commit(noResult: true);
        }
      } catch (_) {}

      final Set<String> tombstoneSmsIds = {};
      try {
        final existingTxTombstones = await txn.query('deleted_transaction_sms_ids');
        for (final row in existingTxTombstones) {
          final sid = row['smsId'] as String?;
          if (sid != null) tombstoneSmsIds.add(sid);
        }

        if (remoteData.containsKey('deletedTransactionSmsIds') && remoteData['deletedTransactionSmsIds'] is List) {
          final batch = txn.batch();
          for (final item in remoteData['deletedTransactionSmsIds'] as List) {
            if (item is Map && item['smsId'] != null) {
              final sid = item['smsId'].toString();
              tombstoneSmsIds.add(sid);
              batch.insert('deleted_transaction_sms_ids', Map<String, Object?>.from(item), conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          }
          await batch.commit(noResult: true);
        }
      } catch (_) {}

      final Set<String> tombstonePeriodLogIds = {};
      try {
        final existingPeriodTombstones = await txn.query('deleted_period_logs');
        for (final row in existingPeriodTombstones) {
          final pid = row['id'] as String?;
          if (pid != null) tombstonePeriodLogIds.add(pid);
        }

        if (remoteData.containsKey('deletedPeriodLogs') && remoteData['deletedPeriodLogs'] is List) {
          final batch = txn.batch();
          for (final item in remoteData['deletedPeriodLogs'] as List) {
            if (item is Map && item['id'] != null) {
              final pid = item['id'].toString();
              tombstonePeriodLogIds.add(pid);
              batch.insert('deleted_period_logs', Map<String, Object?>.from(item), conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          }
          await batch.commit(noResult: true);
        }
      } catch (_) {}

      // 1. Merge Notes
      if (remoteData.containsKey('notes') && remoteData['notes'] is List) {
        final List remoteNotes = remoteData['notes'] as List;
        final localNotesRows = await txn.query('notes');
        final Map<String, Map<String, dynamic>> localNotesMap = {};
        for (final row in localNotesRows) {
          final id = row['id'] as String?;
          if (id != null) localNotesMap[id] = Map<String, dynamic>.from(row);
        }

        final batch = txn.batch();

        for (final item in remoteNotes) {
          if (item is! Map) continue;
          final remoteRow = Map<String, Object?>.from(item)..remove('tags');
          final id = remoteRow['id'] as String?;
          if (id == null || id.isEmpty) continue;

          // Guard Rail: If this note was permanently purged (tombstoned), do not resurrect it!
          if (tombstoneIds.contains(id)) {
            if (localNotesMap.containsKey(id)) {
              batch.delete('notes', where: 'id = ?', whereArgs: [id]);
            }
            continue;
          }

          // Convert boolean attributes to integer for SQLite compatibility
          if (remoteRow['isArchived'] is bool) {
            remoteRow['isArchived'] = (remoteRow['isArchived'] as bool) ? 1 : 0;
          }
          if (remoteRow['isPinned'] is bool) {
            remoteRow['isPinned'] = (remoteRow['isPinned'] as bool) ? 1 : 0;
          }
          if (remoteRow['isLocked'] is bool) {
            remoteRow['isLocked'] = (remoteRow['isLocked'] as bool) ? 1 : 0;
          }
          if (!remoteRow.containsKey('previewText') || remoteRow['previewText'] == null) {
            final content = remoteRow['content'] as String? ?? '';
            remoteRow['previewText'] = RichTextUtils.contentToPlainText(content, maxLines: 6);
          }
          if (!remoteRow.containsKey('category') || remoteRow['category'] == null || (remoteRow['category'] as String).isEmpty) {
            remoteRow['category'] = 'Notes';
          }

          final localRow = localNotesMap[id];
          if (localRow == null) {
            // New remote note: insert locally
            batch.insert('notes', remoteRow, conflictAlgorithm: ConflictAlgorithm.replace);
            notesMerged++;
          } else {
            // Existing note on both devices: Last-Write-Wins comparison
            final localModStr = localRow['dateModified'] as String? ?? localRow['dateCreated'] as String? ?? '';
            final remoteModStr = remoteRow['dateModified'] as String? ?? remoteRow['dateCreated'] as String? ?? '';

            final localMod = DateTime.tryParse(localModStr) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final remoteMod = DateTime.tryParse(remoteModStr) ?? DateTime.fromMillisecondsSinceEpoch(0);

            final localDeletedAt = localRow['deletedAt'] as String?;
            final remoteDeletedAt = remoteRow['deletedAt'] as String?;

            // If remote note was soft-deleted and local note was active
            if (remoteDeletedAt != null && localDeletedAt == null) {
              final remoteDelDate = DateTime.tryParse(remoteDeletedAt) ?? remoteMod;
              if (remoteDelDate.isAfter(localMod) ||
                  remoteDelDate.isAtSameMomentAs(localMod) ||
                  remoteMod.isAfter(localMod) ||
                  remoteMod.difference(localMod).inSeconds.abs() <= 5) {
                batch.update(
                  'notes',
                  remoteRow,
                  where: 'id = ?',
                  whereArgs: [id],
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
                notesMerged++;
                continue;
              }
            }

            // If local note was soft-deleted and remote note is active:
            // Only restore local note if remote modification date is strictly AFTER local deletedAt date!
            if (localDeletedAt != null && remoteDeletedAt == null) {
              final localDelDate = DateTime.tryParse(localDeletedAt) ?? localMod;
              if (!remoteMod.isAfter(localDelDate)) {
                // Keep local note in Trash
                continue;
              }
            }

            final shouldUpdate = remoteMod.isAfter(localMod) ||
                (remoteMod.difference(localMod).inSeconds.abs() <= 5 &&
                    remoteRow['isArchived'] != localRow['isArchived']) ||
                (remoteMod.isAtSameMomentAs(localMod) &&
                    remoteRow['content'] != localRow['content'] &&
                    remoteRow['content'].toString().compareTo(localRow['content'].toString()) > 0);

            if (shouldUpdate) {
              batch.update(
                'notes',
                remoteRow,
                where: 'id = ?',
                whereArgs: [id],
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              notesMerged++;
            }
          }
        }
        await batch.commit(noResult: true);
      }

      // 2. Merge Tags & Note-Tags
      if (remoteData.containsKey('tags') && remoteData['tags'] is List) {
        final batch = txn.batch();
        for (final item in remoteData['tags'] as List) {
          if (item is Map && item['name'] != null) {
            batch.insert('tags', Map<String, Object?>.from(item), conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
        await batch.commit(noResult: true);
      }

      if (remoteData.containsKey('noteTags') && remoteData['noteTags'] is List) {
        final batch = txn.batch();
        for (final item in remoteData['noteTags'] as List) {
          if (item is Map) {
            final map = Map<String, Object?>.from(item);
            final tagName = map['tag_name'] as String?;
            if (tagName != null && tagName.isNotEmpty) {
              batch.insert('tags', {'name': tagName}, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
            batch.insert('note_tags', map, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
        await batch.commit(noResult: true);
      }

      // 3. Merge Transactions
      if (remoteData.containsKey('transactions') && remoteData['transactions'] is List) {
        final List remoteTxList = remoteData['transactions'] as List;
        final localTxRows = await txn.query('transactions');
        final Map<String, Map<String, dynamic>> localSmsMap = {};
        final Map<String, Map<String, dynamic>> localUuidMap = {};
        final Map<String, Map<String, dynamic>> localFingerprintMap = {};

        for (final row in localTxRows) {
          final smsId = row['smsId'] as String?;
          if (smsId != null && smsId.isNotEmpty) {
            localSmsMap[smsId] = Map<String, dynamic>.from(row);
          }
          final uuid = row['uuid'] as String?;
          if (uuid != null && uuid.isNotEmpty) {
            localUuidMap[uuid] = Map<String, dynamic>.from(row);
          }
          final date = row['date'] as String? ?? '';
          final amt = row['amount']?.toString() ?? '';
          final desc = row['description'] as String? ?? '';
          localFingerprintMap['$date|$amt|$desc'] = Map<String, dynamic>.from(row);
        }

        final batch = txn.batch();
        for (final item in remoteTxList) {
          if (item is! Map) continue;
          final remoteMap = Map<String, Object?>.from(item)..remove('_id');

          if (remoteMap['isExpense'] is bool) {
            remoteMap['isExpense'] = (remoteMap['isExpense'] as bool) ? 1 : 0;
          }
          if (remoteMap['isAiRefined'] is bool) {
            remoteMap['isAiRefined'] = (remoteMap['isAiRefined'] as bool) ? 1 : 0;
          }
          if (!remoteMap.containsKey('category') || remoteMap['category'] == null) {
            remoteMap['category'] = 'Other';
          }

          final smsId = remoteMap['smsId'] as String?;
          final uuid = remoteMap['uuid'] as String?;

          // Check if transaction matches an existing local record
          Map<String, dynamic>? localTx;
          if (smsId != null && smsId.isNotEmpty) {
            localTx = localSmsMap[smsId];
          } else if (uuid != null && uuid.isNotEmpty) {
            localTx = localUuidMap[uuid];
          } else {
            final date = remoteMap['date'] as String? ?? '';
            final amt = remoteMap['amount']?.toString() ?? '';
            final desc = remoteMap['description'] as String? ?? '';
            localTx = localFingerprintMap['$date|$amt|$desc'];
          }

          // Case A: SMS transaction tombstone guard
          if (smsId != null && smsId.isNotEmpty && tombstoneSmsIds.contains(smsId)) {
            if (localTx != null) {
              batch.delete('transactions', where: 'smsId = ?', whereArgs: [smsId]);
            }
            continue;
          }

          if (localTx == null) {
            // New transaction: insert locally
            batch.insert('transactions', remoteMap, conflictAlgorithm: ConflictAlgorithm.ignore);
            transactionsMerged++;
            if (smsId != null && smsId.isNotEmpty) {
              localSmsMap[smsId] = remoteMap;
            }
            if (uuid != null && uuid.isNotEmpty) {
              localUuidMap[uuid] = remoteMap;
            }
            final date = remoteMap['date'] as String? ?? '';
            final amt = remoteMap['amount']?.toString() ?? '';
            final desc = remoteMap['description'] as String? ?? '';
            localFingerprintMap['$date|$amt|$desc'] = remoteMap;
          } else {
            // Existing transaction: Apply Last-Write-Wins (LWW) comparison
            final localId = localTx['_id'];
            final localModStr = localTx['dateModified'] as String? ?? localTx['date'] as String? ?? '';
            final remoteModStr = remoteMap['dateModified'] as String? ?? remoteMap['date'] as String? ?? '';
            final localMod = DateTime.tryParse(localModStr) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final remoteMod = DateTime.tryParse(remoteModStr) ?? DateTime.fromMillisecondsSinceEpoch(0);

            final localDeletedAt = localTx['deletedAt'] as String?;
            final remoteDeletedAt = remoteMap['deletedAt'] as String?;

            // 1. Soft-delete LWW handling
            if (remoteDeletedAt != null && localDeletedAt == null) {
              final remoteDelDate = DateTime.tryParse(remoteDeletedAt) ?? remoteMod;
              if (remoteDelDate.isAfter(localMod) ||
                  remoteDelDate.isAtSameMomentAs(localMod) ||
                  remoteMod.isAfter(localMod) ||
                  remoteMod.difference(localMod).inSeconds.abs() <= 5) {
                batch.update(
                  'transactions',
                  {'deletedAt': remoteDeletedAt, 'dateModified': remoteModStr},
                  where: '_id = ?',
                  whereArgs: [localId],
                );
                transactionsMerged++;
                continue;
              }
            }

            // If locally soft-deleted, only restore if remote edit is strictly AFTER local deletion
            if (localDeletedAt != null && remoteDeletedAt == null) {
              final localDelDate = DateTime.tryParse(localDeletedAt) ?? localMod;
              if (!remoteMod.isAfter(localDelDate)) {
                // Keep local transaction deleted
                continue;
              }
            }

            // 2. Data field LWW update: remote wins if remoteMod >= localMod (with 5s skew tolerance)
            final shouldUpdate = remoteMod.isAfter(localMod) ||
                (remoteMod.difference(localMod).inSeconds.abs() <= 5 &&
                    (remoteMap['category'] != localTx['category'] ||
                        remoteMap['account'] != localTx['account'] ||
                        remoteMap['isAiRefined'] != localTx['isAiRefined'] ||
                        remoteMap['description'] != localTx['description'] ||
                        remoteMap['amount'] != localTx['amount']));

            if (shouldUpdate) {
              batch.update(
                'transactions',
                {
                  'amount': remoteMap['amount'],
                  'description': remoteMap['description'],
                  'date': remoteMap['date'],
                  'isExpense': remoteMap['isExpense'],
                  'category': remoteMap['category'],
                  'account': remoteMap['account'],
                  'isAiRefined': remoteMap['isAiRefined'],
                  'deletedAt': remoteMap['deletedAt'],
                  'dateModified': remoteModStr,
                  if (uuid != null && uuid.isNotEmpty) 'uuid': uuid,
                },
                where: '_id = ?',
                whereArgs: [localId],
              );
              transactionsMerged++;
            }
          }
        }
        await batch.commit(noResult: true);
      }

      // 4. Merge Category Definitions
      if (remoteData.containsKey('categoryDefinitions') && remoteData['categoryDefinitions'] is List) {
        final batch = txn.batch();
        for (final item in remoteData['categoryDefinitions'] as List) {
          if (item is Map) {
            final map = Map<String, Object?>.from(item);
            if (map['isBuiltIn'] is bool) {
              map['isBuiltIn'] = (map['isBuiltIn'] as bool) ? 1 : 0;
            }
            batch.insert('category_definitions', map, conflictAlgorithm: ConflictAlgorithm.ignore);
            categoriesMerged++;
          }
        }
        await batch.commit(noResult: true);
      }

      // 5. Merge SMS Contacts
      if (remoteData.containsKey('smsContacts') && remoteData['smsContacts'] is List) {
        final batch = txn.batch();
        for (final item in remoteData['smsContacts'] as List) {
          if (item is Map) {
            final map = Map<String, Object?>.from(item);
            if (map['isBuiltIn'] is bool) {
              map['isBuiltIn'] = (map['isBuiltIn'] as bool) ? 1 : 0;
            }
            batch.insert('sms_contacts', map, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
        await batch.commit(noResult: true);
      }

      // 6. Merge Period Logs
      if (tombstonePeriodLogIds.isNotEmpty) {
        for (final tid in tombstonePeriodLogIds) {
          await txn.delete('period_logs', where: 'id = ?', whereArgs: [tid]);
        }
      }

      if (remoteData.containsKey('periodLogs') && remoteData['periodLogs'] is List) {
        final localLogs = await txn.query('period_logs');
        final localLogMap = {
          for (final l in localLogs)
            if (l['id'] != null) l['id'].toString(): l,
        };
        final batch = txn.batch();
        for (final item in remoteData['periodLogs'] as List) {
          if (item is Map) {
            final map = Map<String, Object?>.from(item);
            final logId = map['id']?.toString();
            if (logId != null && tombstonePeriodLogIds.contains(logId)) {
              continue; // Skip resurrecting deleted period log
            }
            final local = logId != null ? localLogMap[logId] : null;
            if (local == null) {
              batch.insert('period_logs', map, conflictAlgorithm: ConflictAlgorithm.replace);
              periodLogsMerged++;
            } else {
              final localModStr = local['dateModified']?.toString() ??
                  local['updatedAt']?.toString() ??
                  local['endDate']?.toString() ??
                  local['startDate']?.toString() ??
                  '';
              final remoteModStr = map['dateModified']?.toString() ??
                  map['updatedAt']?.toString() ??
                  map['endDate']?.toString() ??
                  map['startDate']?.toString() ??
                  '';
              final localMod = DateTime.tryParse(localModStr) ?? DateTime.fromMillisecondsSinceEpoch(0);
              final remoteMod = DateTime.tryParse(remoteModStr) ?? DateTime.fromMillisecondsSinceEpoch(0);
              if (remoteMod.isAfter(localMod) ||
                  remoteMod.difference(localMod).inSeconds.abs() <= 5) {
                batch.update('period_logs', map, where: 'id = ?', whereArgs: [logId]);
                periodLogsMerged++;
              }
            }
          }
        }
        await batch.commit(noResult: true);
      }

      // 7. Merge Recurring Rules
      if (remoteData.containsKey('recurringRules') && remoteData['recurringRules'] is List) {
        final localRules = await txn.query('recurring_rules');
        final localRuleMap = {
          for (final r in localRules)
            if (r['id'] != null) r['id'].toString(): r,
        };
        final batch = txn.batch();
        for (final item in remoteData['recurringRules'] as List) {
          if (item is Map) {
            final map = Map<String, Object?>.from(item);
            if (map['isExpense'] is bool) {
              map['isExpense'] = (map['isExpense'] as bool) ? 1 : 0;
            }
            final idKey = map['id']?.toString();
            final local = idKey != null ? localRuleMap[idKey] : null;
            if (local != null) {
              final localGen = DateTime.tryParse(local['lastGeneratedDate']?.toString() ?? '');
              final remoteGen = DateTime.tryParse(map['lastGeneratedDate']?.toString() ?? '');
              if (localGen != null && (remoteGen == null || localGen.isAfter(remoteGen))) {
                map['lastGeneratedDate'] = local['lastGeneratedDate'];
              }
            }
            batch.insert('recurring_rules', map, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
        await batch.commit(noResult: true);
      }

      // 8. Merge Split Bills, Participants & Contacts
      if (remoteData.containsKey('splitBills') && remoteData['splitBills'] is List) {
        final localBills = await txn.query('split_bills');
        final localBillMap = {for (final b in localBills) b['id'] as String: b};
        final batch = txn.batch();
        for (final item in remoteData['splitBills'] as List) {
          if (item is Map) {
            final map = Map<String, Object?>.from(item);
            if (map['isPayerUser'] is bool) {
              map['isPayerUser'] = (map['isPayerUser'] as bool) ? 1 : 0;
            }
            final id = map['id'] as String?;
            if (id == null) continue;

            final local = localBillMap[id];
            if (local == null) {
              batch.insert('split_bills', map, conflictAlgorithm: ConflictAlgorithm.replace);
              splitBillsMerged++;
            } else {
              final localDeleted = local['deletedAt'] as String?;
              final remoteDeleted = map['deletedAt'] as String?;
              if (localDeleted != null && remoteDeleted == null) {
                // Keep locally soft-deleted state
                continue;
              } else if (remoteDeleted != null && localDeleted == null) {
                batch.update('split_bills', {'deletedAt': remoteDeleted}, where: 'id = ?', whereArgs: [id]);
                splitBillsMerged++;
              } else {
                final localModStr = local['dateModified']?.toString() ??
                    local['updatedAt']?.toString() ??
                    local['createdAt']?.toString() ??
                    '';
                final remoteModStr = map['dateModified']?.toString() ??
                    map['updatedAt']?.toString() ??
                    map['createdAt']?.toString() ??
                    '';
                final localMod = DateTime.tryParse(localModStr) ?? DateTime.fromMillisecondsSinceEpoch(0);
                final remoteMod = DateTime.tryParse(remoteModStr) ?? DateTime.fromMillisecondsSinceEpoch(0);
                final remoteIsNewerOrSameWindow = remoteMod.isAfter(localMod) ||
                    remoteMod.difference(localMod).inSeconds.abs() <= 5;
                const statusRank = {'unsettled': 0, 'partial': 1, 'settled': 2};
                final localRank = statusRank[local['status']?.toString() ?? 'unsettled'] ?? 0;
                final remoteRank = statusRank[map['status']?.toString() ?? 'unsettled'] ?? 0;
                if (!remoteIsNewerOrSameWindow) {
                  if (remoteRank > localRank) {
                    batch.update('split_bills', {'status': map['status']}, where: 'id = ?', whereArgs: [id]);
                    splitBillsMerged++;
                  }
                  continue;
                }
                if (localRank > remoteRank) {
                  map['status'] = local['status'];
                }
                batch.update('split_bills', map, where: 'id = ?', whereArgs: [id]);
                splitBillsMerged++;
              }
            }
          }
        }
        await batch.commit(noResult: true);
      }
      if (remoteData.containsKey('splitParticipants') && remoteData['splitParticipants'] is List) {
        final localParticipants = await txn.query('split_participants');
        final localPartMap = {for (final p in localParticipants) p['id'] as String: p};
        final batch = txn.batch();
        for (final item in remoteData['splitParticipants'] as List) {
          if (item is Map) {
            final map = Map<String, Object?>.from(item);
            if (map['hasPaid'] is bool) {
              map['hasPaid'] = (map['hasPaid'] as bool) ? 1 : 0;
            }
            final id = map['id'] as String?;
            if (id == null) continue;

            final local = localPartMap[id];
            if (local == null) {
              batch.insert('split_participants', map, conflictAlgorithm: ConflictAlgorithm.replace);
            } else {
              final localPaid = (local['hasPaid'] as num?)?.toInt() == 1;
              final remotePaid = (map['hasPaid'] as num?)?.toInt() == 1;
              if (remotePaid && !localPaid) {
                batch.update('split_participants', map, where: 'id = ?', whereArgs: [id]);
              } else if (!remotePaid && localPaid) {
                continue;
              } else {
                batch.update('split_participants', map, where: 'id = ?', whereArgs: [id]);
              }
            }
          }
        }
        await batch.commit(noResult: true);
      }
      if (remoteData.containsKey('splitContacts') && remoteData['splitContacts'] is List) {
        final batch = txn.batch();
        for (final item in remoteData['splitContacts'] as List) {
          if (item is Map) {
            batch.insert('split_contacts', Map<String, Object?>.from(item), conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
        await batch.commit(noResult: true);
      }
      // 9. Merge Savings Goals
      final savingsList = remoteData['savingsGoals'] ?? remoteData['savings_goals'];
      if (savingsList is List) {
        final localGoals = await txn.query('savings_goals');
        final localGoalMap = {for (final g in localGoals) g['id'] as String: g};
        final batch = txn.batch();
        for (final item in savingsList) {
          if (item is Map) {
            final map = Map<String, Object?>.from(item);
            if (map['isCompleted'] is bool) {
              map['isCompleted'] = (map['isCompleted'] as bool) ? 1 : 0;
            }
            map['createdAt'] ??= DateTime.now().toIso8601String();
            final id = map['id'] as String?;
            if (id == null) continue;

            final local = localGoalMap[id];
            if (local == null) {
              batch.insert('savings_goals', map, conflictAlgorithm: ConflictAlgorithm.replace);
              savingsGoalsMerged++;
            } else {
              final localDeleted = local['deletedAt'] as String?;
              final remoteDeleted = map['deletedAt'] as String?;
              if (localDeleted != null && remoteDeleted == null) {
                // Keep locally soft-deleted state
                continue;
              } else if (remoteDeleted != null && localDeleted == null) {
                batch.update('savings_goals', {'deletedAt': remoteDeleted}, where: 'id = ?', whereArgs: [id]);
                savingsGoalsMerged++;
              } else {
                final localModStr = local['dateModified']?.toString() ??
                    local['updatedAt']?.toString() ??
                    local['completedAt']?.toString() ??
                    local['createdAt']?.toString() ??
                    '';
                final remoteModStr = map['dateModified']?.toString() ??
                    map['updatedAt']?.toString() ??
                    map['completedAt']?.toString() ??
                    map['createdAt']?.toString() ??
                    '';
                final localMod = DateTime.tryParse(localModStr) ?? DateTime.fromMillisecondsSinceEpoch(0);
                final remoteMod = DateTime.tryParse(remoteModStr) ?? DateTime.fromMillisecondsSinceEpoch(0);
                final remoteIsNewerOrSameWindow = remoteMod.isAfter(localMod) ||
                    remoteMod.difference(localMod).inSeconds.abs() <= 5;
                final localCompleted = (local['isCompleted'] as num?)?.toInt() == 1;
                final remoteCompleted = (map['isCompleted'] as num?)?.toInt() == 1;
                if (!remoteIsNewerOrSameWindow) {
                  if (!localCompleted && remoteCompleted) {
                    batch.update(
                      'savings_goals',
                      {'isCompleted': 1, 'completedAt': map['completedAt']},
                      where: 'id = ?',
                      whereArgs: [id],
                    );
                    savingsGoalsMerged++;
                  }
                  continue;
                }
                if (localCompleted && !remoteCompleted) {
                  map['isCompleted'] = 1;
                  map['completedAt'] ??= local['completedAt'];
                }
                batch.update('savings_goals', map, where: 'id = ?', whereArgs: [id]);
                savingsGoalsMerged++;
              }
            }
          }
        }
        await batch.commit(noResult: true);
      }
    });

    if (notesMerged > 0) {
      try {
        await WidgetHelper.updateTodoWidgetData();
      } catch (_) {}
    }

    if (transactionsMerged > 0) {
      try {
        await WidgetHelper.updateWidgetData();
      } catch (_) {}
    }

    return SyncMergeResult(
      notesMerged: notesMerged,
      transactionsMerged: transactionsMerged,
      periodLogsMerged: periodLogsMerged,
      categoriesMerged: categoriesMerged,
      splitBillsMerged: splitBillsMerged,
      savingsGoalsMerged: savingsGoalsMerged,
    );
  }
}
