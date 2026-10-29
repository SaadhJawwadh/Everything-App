import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../data/note_model.dart';
import '../../../data/transaction_model.dart';
import '../../../features/finances/data/transaction_repository.dart';
import '../../../features/finances/providers/financial_manager_provider.dart';
import '../../../features/notes/data/note_repository.dart';
import '../../../features/notes/providers/note_provider.dart';
import '../../../utils/rich_text_utils.dart';
import '../../../utils/widget_helper.dart';

class AppFunctionInboxService {
  static const String queueKey = 'pending_appfunctions_queue';
  static bool _isDraining = false;

  /// Drains any actions queued by Android AppFunctions (e.g. via Gemini or Assistant)
  /// and applies them to local storage with immediate visual undo SnackBar feedback.
  static Future<void> drainPendingQueue(BuildContext context) async {
    if (_isDraining) return;
    _isDraining = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawQueue = prefs.getString(queueKey);
      if (rawQueue == null || rawQueue.isEmpty || rawQueue == '[]') {
        _isDraining = false;
        return;
      }

      List<dynamic> items;
      try {
        items = jsonDecode(rawQueue) as List<dynamic>;
      } catch (e) {
        debugPrint('[AppFunctionInboxService] Corrupt queue json: $e');
        await prefs.remove(queueKey);
        _isDraining = false;
        return;
      }

      if (items.isEmpty) {
        _isDraining = false;
        return;
      }

      // Atomically clear queue from SharedPreferences
      await prefs.setString(queueKey, '[]');

      final txRepo = TransactionRepository.instance;
      final noteRepo = NoteRepository.instance;

      final processedDescriptions = <String>[];
      final createdTxIds = <int>[];
      final modifiedNotes = <Note>[];
      final createdNotes = <Note>[];

      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final action = item['action'] as String?;

        if (action == 'log_expense') {
          final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
          final description = item['description'] as String? ?? 'Expense';
          final category = item['category'] as String? ?? 'Shopping';
          final accountType = item['accountType'] as String? ?? 'daily';
          final isExpense = item['isExpense'] as bool? ?? true;

          final tx = TransactionModel(
            amount: amount,
            description: description,
            date: DateTime.now(),
            isExpense: isExpense,
            category: category,
            account: accountType,
          );

          final createdTx = await txRepo.createTransaction(tx);
          if (createdTx.id != null) {
            createdTxIds.add(createdTx.id!);
          }
          processedDescriptions.add('${isExpense ? "Expense" : "Income"}: $description');
        } else if (action == 'add_task') {
          final title = item['title'] as String? ?? '';
          if (title.isNotEmpty) {
            final savedNote = await WidgetHelper.quickAddTask(
              taskText: title,
            );
            if (savedNote != null) {
              modifiedNotes.add(savedNote);
              processedDescriptions.add('Task: $title');
            }
          }
        } else if (action == 'create_note') {
          final title = item['title'] as String? ?? 'Untitled Note';
          final content = item['content'] as String? ?? '';
          final folder = item['folder'] as String? ?? 'Notes';
          final now = DateTime.now();

          final delta = RichTextUtils.markdownToDelta(content);
          final note = Note(
            id: const Uuid().v4(),
            title: title,
            content: RichTextUtils.deltaToJson(delta),
            dateCreated: now,
            dateModified: now,
            category: folder,
          );
          await noteRepo.createNote(note);
          createdNotes.add(note);
          processedDescriptions.add('Note: $title');
        }
      }

      // Refresh providers
      if (context.mounted) {
        final finProvider = context.read<FinancialManagerProvider>();
        final noteProvider = context.read<NoteProvider>();
        try {
          await finProvider.loadTransactions();
        } catch (_) {}
        try {
          await noteProvider.refreshNotes();
        } catch (_) {}
      }

      try {
        await WidgetHelper.updateWidgetData();
      } catch (_) {}
      try {
        await WidgetHelper.updateTodoWidgetData();
      } catch (_) {}

      // Show floating undo SnackBar if actions were executed
      if (processedDescriptions.isNotEmpty && context.mounted) {
        final summary = processedDescriptions.length == 1
            ? processedDescriptions.first
            : '${processedDescriptions.length} AI Assistant actions applied';

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Theme.of(context).colorScheme.primary,
              onPressed: () async {
                for (final id in createdTxIds) {
                  await txRepo.deleteTransaction(id, soft: false);
                }
                for (final note in createdNotes) {
                  await noteRepo.deleteNote(note.id);
                }
                if (context.mounted) {
                  final finProvider = context.read<FinancialManagerProvider>();
                  final noteProvider = context.read<NoteProvider>();
                  try {
                    await finProvider.loadTransactions();
                  } catch (_) {}
                  try {
                    await noteProvider.refreshNotes();
                  } catch (_) {}
                }
                try {
                  await WidgetHelper.updateWidgetData();
                } catch (_) {}
                try {
                  await WidgetHelper.updateTodoWidgetData();
                } catch (_) {}
              },
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('[AppFunctionInboxService] Error draining queue: $e');
    } finally {
      _isDraining = false;
    }
  }
}
