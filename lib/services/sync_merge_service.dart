import 'package:sqflite_sqlcipher/sqflite.dart';
import '../data/database_helper.dart';
import '../utils/rich_text_utils.dart';
import '../utils/widget_helper.dart';

class SyncMergeResult {
  final int notesMerged;
  final int transactionsMerged;
  final int periodLogsMerged;
  final int categoriesMerged;

  SyncMergeResult({
    this.notesMerged = 0,
    this.transactionsMerged = 0,
    this.periodLogsMerged = 0,
    this.categoriesMerged = 0,
  });
}

class SyncMergeService {
  static final SyncMergeService instance = SyncMergeService._init();
  SyncMergeService._init();
  factory SyncMergeService() => instance;

  /// Performs an atomic, non-destructive bi-directional Last-Write-Wins (LWW) merge.
  Future<SyncMergeResult> mergeRemoteData(Map<String, dynamic> remoteData) async {
    final db = await DatabaseHelper.instance.database;

    int notesMerged = 0;
    int transactionsMerged = 0;
    int periodLogsMerged = 0;
    int categoriesMerged = 0;

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
                    remoteRow['isArchived'] != localRow['isArchived']);

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
        final Set<String> localTxFingerprints = {};

        for (final row in localTxRows) {
          final smsId = row['smsId'] as String?;
          if (smsId != null && smsId.isNotEmpty) {
            localSmsMap[smsId] = Map<String, dynamic>.from(row);
          }
          final date = row['date'] as String? ?? '';
          final amt = row['amount']?.toString() ?? '';
          final desc = row['description'] as String? ?? '';
          localTxFingerprints.add('$date|$amt|$desc');
        }

        final batch = txn.batch();
        for (final item in remoteTxList) {
          if (item is! Map) continue;
          final remoteMap = Map<String, Object?>.from(item)..remove('_id');

          if (remoteMap['isExpense'] is bool) {
            remoteMap['isExpense'] = (remoteMap['isExpense'] as bool) ? 1 : 0;
          }
          if (!remoteMap.containsKey('category') || remoteMap['category'] == null) {
            remoteMap['category'] = 'Other';
          }

          final smsId = remoteMap['smsId'] as String?;
          if (smsId != null && smsId.isNotEmpty) {
            // Guard: If this transaction was permanently purged, do not resurrect and delete if present locally
            if (tombstoneSmsIds.contains(smsId)) {
              if (localSmsMap.containsKey(smsId)) {
                batch.delete('transactions', where: 'smsId = ?', whereArgs: [smsId]);
              }
              continue;
            }

            if (!localSmsMap.containsKey(smsId)) {
              batch.insert('transactions', remoteMap, conflictAlgorithm: ConflictAlgorithm.ignore);
              transactionsMerged++;
            }
          } else {
            final date = remoteMap['date'] as String? ?? '';
            final amt = remoteMap['amount']?.toString() ?? '';
            final desc = remoteMap['description'] as String? ?? '';
            final fingerprint = '$date|$amt|$desc';
            if (!localTxFingerprints.contains(fingerprint)) {
              batch.insert('transactions', remoteMap, conflictAlgorithm: ConflictAlgorithm.ignore);
              localTxFingerprints.add(fingerprint);
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
        final batch = txn.batch();
        for (final item in remoteData['periodLogs'] as List) {
          if (item is Map) {
            final logId = item['id']?.toString();
            if (logId != null && tombstonePeriodLogIds.contains(logId)) {
              continue; // Skip resurrecting deleted period log
            }
            batch.insert('period_logs', Map<String, Object?>.from(item), conflictAlgorithm: ConflictAlgorithm.replace);
            periodLogsMerged++;
          }
        }
        await batch.commit(noResult: true);
      }

      // 7. Merge Recurring Rules
      if (remoteData.containsKey('recurringRules') && remoteData['recurringRules'] is List) {
        final batch = txn.batch();
        for (final item in remoteData['recurringRules'] as List) {
          if (item is Map) {
            final map = Map<String, Object?>.from(item);
            if (map['isExpense'] is bool) {
              map['isExpense'] = (map['isExpense'] as bool) ? 1 : 0;
            }
            batch.insert('recurring_rules', map, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
        await batch.commit(noResult: true);
      }

      // 8. Merge Split Bills, Participants & Contacts
      if (remoteData.containsKey('splitBills') && remoteData['splitBills'] is List) {
        final batch = txn.batch();
        for (final item in remoteData['splitBills'] as List) {
          if (item is Map) {
            batch.insert('split_bills', Map<String, Object?>.from(item), conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
        await batch.commit(noResult: true);
      }
      if (remoteData.containsKey('splitParticipants') && remoteData['splitParticipants'] is List) {
        final batch = txn.batch();
        for (final item in remoteData['splitParticipants'] as List) {
          if (item is Map) {
            batch.insert('split_participants', Map<String, Object?>.from(item), conflictAlgorithm: ConflictAlgorithm.replace);
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
        final batch = txn.batch();
        for (final item in savingsList) {
          if (item is Map) {
            batch.insert('savings_goals', Map<String, Object?>.from(item), conflictAlgorithm: ConflictAlgorithm.replace);
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
    );
  }
}
