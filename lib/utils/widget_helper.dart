import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'app_constants.dart';
import '../data/note_model.dart';
import '../features/finances/data/transaction_repository.dart';
import '../features/finances/services/spending_forecast_service.dart';
import '../features/notes/data/note_repository.dart';
import 'package:uuid/uuid.dart';
import 'quill_checklist_helper.dart';
import 'rich_text_utils.dart';

/// Workmanager task that recomputes widget data in the background so the
/// TODAY figure rolls over at midnight without the app being opened.
const kWidgetRefreshTaskName = 'com.saadhjawwadh.notebook.widgetRefresh';

class WidgetHelper {
  static const MethodChannel _channel = MethodChannel('com.saadhjawwadh.notebook/widget');

  static Future<void> updateWidgetData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currencyCode = prefs.getString('currency') ?? 'LKR';
      final currency = AppConstants.getCurrencyInfo(currencyCode).symbol;

      final repo = TransactionRepository.instance;
      final allTx = await repo.readAllTransactions();

      // Filter out reversals
      final activeTx = allTx.where((t) => t.category != '__reversal__').toList();

      // Today's total spent
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      final todaySpent = activeTx
          .where((t) => t.isExpense && t.date.isAfter(today.subtract(const Duration(seconds: 1))) && t.date.isBefore(tomorrow))
          .fold(0.0, (sum, t) => sum + t.amount);

      // Month's summaries
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 1);

      final monthTx = activeTx.where((t) => t.date.isAfter(monthStart.subtract(const Duration(seconds: 1))) && t.date.isBefore(monthEnd)).toList();

      final monthSpent = monthTx.where((t) => t.isExpense).fold(0.0, (sum, t) => sum + t.amount);
      final monthIncome = monthTx.where((t) => !t.isExpense).fold(0.0, (sum, t) => sum + t.amount);

      // Format overview strings with thousands separators (LKR 1,250,000)
      final numberFormat = NumberFormat('#,##0');
      final spentTodayStr = '$currency ${numberFormat.format(todaySpent)}';
      final spentMonthStr = '$currency ${numberFormat.format(monthSpent)}';
      final incomeMonthStr = '$currency ${numberFormat.format(monthIncome)}';

      // ── Analytics ──
      // Net cash flow this month
      final net = monthIncome - monthSpent;
      final netStr =
          '${net < 0 ? '-' : '+'}$currency ${numberFormat.format(net.abs())}';

      // Budget progress: total spent vs the sum of all category budgets
      double totalBudget = 0;
      final budgetsStr = prefs.getString('categoryBudgets');
      if (budgetsStr != null) {
        try {
          final Map<String, dynamic> budgets = json.decode(budgetsStr);
          totalBudget =
              budgets.values.fold(0.0, (sum, v) => sum + (v as num).toDouble());
        } catch (_) {}
      }
      final budgetPercent =
          totalBudget > 0 ? ((monthSpent / totalBudget) * 100).round() : -1;
      final budgetLabel = totalBudget > 0
          ? '$currency ${numberFormat.format(monthSpent)} of $currency ${numberFormat.format(totalBudget)}'
          : '';

      // ── Analytics Breakdown ──
      // Top spending categories this month sorted by total expense
      final byCategory = <String, double>{};
      for (final t in monthTx.where((t) => t.isExpense)) {
        byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
      }

      final sortedCategories = byCategory.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      String topCategory = '';
      String topCategoryAmount = '';
      if (sortedCategories.isNotEmpty) {
        topCategory = sortedCategories.first.key;
        topCategoryAmount = '$currency ${numberFormat.format(sortedCategories.first.value)}';
      }

      final categoryBreakdown = sortedCategories.take(3).map((e) {
        final pct = monthSpent > 0 ? ((e.value / monthSpent) * 100).round() : 0;
        return {
          'name': e.key,
          'amount': '$currency ${numberFormat.format(e.value)}',
          'pct': pct,
        };
      }).toList();

      // ── Spending Run-Rate & Forecast Sparkline Data ──
      String forecastAmountStr = '';
      String forecastTrendStr = '';
      bool isTrendingUp = false;
      final sparklinePoints = <double>[];

      try {
        final Map<String, double> categoryBudgetsMap = {};
        if (budgetsStr != null) {
          try {
            final Map<String, dynamic> raw = json.decode(budgetsStr);
            raw.forEach((k, v) => categoryBudgetsMap[k] = (v as num).toDouble());
          } catch (_) {}
        }

        final spendingForecast = SpendingForecastService.calculateMonthlyForecast(
          transactions: allTx,
          categoryBudgets: categoryBudgetsMap,
        );

        forecastAmountStr =
            '~$currency ${numberFormat.format(spendingForecast.projectedMonthEndSpend)}';
        forecastTrendStr = spendingForecast.status == SpendingPaceStatus.overPace
            ? 'Pacing Fast'
            : spendingForecast.status == SpendingPaceStatus.exhausted
                ? 'Exhausted'
                : 'On Track';
        isTrendingUp = spendingForecast.status == SpendingPaceStatus.overPace ||
            spendingForecast.status == SpendingPaceStatus.exhausted;

        final monthlyData = await repo.getMonthlyTransactionSummary(6);
        for (final d in monthlyData) {
          final exp = (d['totalExpense'] as num?)?.toDouble() ??
              (d['expense'] as num?)?.toDouble() ??
              0.0;
          sparklinePoints.add(exp);
        }
        if (spendingForecast.projectedMonthEndSpend > 0) {
          sparklinePoints.add(spendingForecast.projectedMonthEndSpend);
        }
      } catch (_) {}

      // Top 3 recent transactions (kept for backward compatibility)
      final recentList = activeTx.take(3).map((t) {
        return {
          'category': t.category,
          'description': t.description,
          'amount': '${t.isExpense ? '-' : '+'} $currency ${numberFormat.format(t.amount)}',
          'isExpense': t.isExpense,
        };
      }).toList();

      // Save to shared preferences (Dart SharedPreferences automatically prepends 'flutter.')
      await prefs.setString('widget_spent_today', spentTodayStr);
      await prefs.setString('widget_spent_month', spentMonthStr);
      await prefs.setString('widget_income_month', incomeMonthStr);
      await prefs.setString('widget_net_month', netStr);
      await prefs.setBool('widget_net_positive', net >= 0);
      await prefs.setInt('widget_budget_percent', budgetPercent);
      await prefs.setString('widget_budget_label', budgetLabel);
      await prefs.setString('widget_top_category', topCategory);
      await prefs.setString('widget_top_category_amount', topCategoryAmount);
      await prefs.setString('widget_category_breakdown', json.encode(categoryBreakdown));
      await prefs.setString('widget_forecast_amount', forecastAmountStr);
      await prefs.setString('widget_forecast_trend', forecastTrendStr);
      await prefs.setBool('widget_is_trending_up', isTrendingUp);
      await prefs.setString('widget_sparkline_data', json.encode(sparklinePoints));
      await prefs.setString('widget_recent_transactions', json.encode(recentList));

      // Trigger update on native side
      await _channel.invokeMethod('updateWidget');
    } catch (e) {
      // Avoid crashing the app if widget updates fail
      debugPrint('Widget update failed: $e');
    }
  }

  /// Synchronizes any pending checkbox toggles queued by the Android AppWidget
  /// and writes the changes back into the notes database.
  static Future<void> syncPendingTodoToggles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingStr = prefs.getString('widget_pending_toggles');
      if (pendingStr == null || pendingStr.isEmpty || pendingStr == '[]') {
        return;
      }

      final List<dynamic> toggles = json.decode(pendingStr);
      if (toggles.isEmpty) return;

      // Group toggles by noteId and squash redundant intermediate toggles for the same item
      final Map<String, Map<String, Map<String, dynamic>>> byNoteSquashed = {};
      for (final t in toggles) {
        if (t is Map) {
          final noteId = t['noteId'] as String?;
          if (noteId != null && noteId.isNotEmpty) {
            final lineIndex = t['lineIndex'] as int? ?? -1;
            final text = (t['text'] as String?)?.trim();
            // Distinct key: prefer text, fallback to lineIndex
            final itemKey = (text != null && text.isNotEmpty) ? text : 'idx_$lineIndex';
            byNoteSquashed.putIfAbsent(noteId, () => {})[itemKey] = Map<String, dynamic>.from(t);
          }
        }
      }

      final repo = NoteRepository.instance;
      for (final entry in byNoteSquashed.entries) {
        final note = await repo.readNote(entry.key);
        if (note == null) continue;

        final delta = RichTextUtils.contentToDelta(note.content);
        final doc = Document.fromDelta(delta);

        bool changed = false;
        for (final toggle in entry.value.values) {
          final lineIndex = toggle['lineIndex'] as int? ?? -1;
          final isDone = toggle['isDone'] as bool? ?? false;
          final expectedText = toggle['text'] as String?;
          if (lineIndex >= 0 || (expectedText != null && expectedText.isNotEmpty)) {
            final ok = QuillChecklistHelper.toggleChecklistLine(
              doc,
              lineIndex,
              isDone,
              expectedText: expectedText,
            );
            if (ok) changed = true;
          }
        }

        if (changed) {
          note.content = RichTextUtils.deltaToJson(doc.toDelta());
          note.dateModified = DateTime.now();
          await repo.updateNote(note);
        }
      }

      // Clear pending queue once processed
      await prefs.setString('widget_pending_toggles', '[]');
    } catch (e) {
      debugPrint('Sync pending todo toggles failed: $e');
    }
  }

  /// Recomputes checklist notes data for the TODO AppWidget and broadcasts update.
  static Future<void> updateTodoWidgetData() async {
    try {
      await syncPendingTodoToggles();

      final prefs = await SharedPreferences.getInstance();
      final repo = NoteRepository.instance;
      final activeNotes = await repo.readAllNotes(isArchived: false, isTrashed: false);

      final List<Map<String, dynamic>> todoNotes = [];
      int totalItemsCount = 0;
      const int maxTotalItems = 100;
      const int maxItemsPerNote = 30;

      for (final note in activeNotes) {
        // Privacy invariant: Never expose password or biometric-locked notes to unauthenticated widget
        if (note.isLocked) continue;

        // Strict checklist signature check (prevents false-positive matches on words like 'playlist')
        final hasChecklist = note.content.contains('"list":"checked"') ||
            note.content.contains('"list":"unchecked"') ||
            note.content.contains('- [ ]') ||
            note.content.contains('- [x]');
        if (!hasChecklist) continue;

        final delta = RichTextUtils.contentToDelta(note.content);
        final doc = Document.fromDelta(delta);
        final items = QuillChecklistHelper.extractChecklistData(doc);
        if (items.isNotEmpty) {
          final boundedItems = items.take(maxItemsPerNote).toList();
          todoNotes.add({
            'id': note.id,
            'title': note.title.trim().isEmpty ? 'Untitled Note' : note.title.trim(),
            'items': boundedItems.map((it) => it.toJson()).toList(),
          });
          totalItemsCount += boundedItems.length;
          if (totalItemsCount >= maxTotalItems) break;
        }
      }

      await prefs.setString('widget_todo_notes_json', json.encode(todoNotes));

      final activeNoteId = prefs.getString('widget_active_note_id');
      if (activeNoteId != null && activeNoteId != 'ALL_NOTES') {
        final exists = todoNotes.any((n) => n['id'] == activeNoteId);
        if (!exists) {
          await prefs.setString('widget_active_note_id', 'ALL_NOTES');
        }
      }

      await _channel.invokeMethod('updateWidget');
    } catch (e) {
      debugPrint('Todo widget update failed: $e');
    }
  }

  /// Appends a new checklist item to the specified note (or default/new checklist note)
  /// and updates widget data.
  static Future<void> quickAddTask({
    String? noteId,
    required String taskText,
  }) async {
    final cleaned = taskText.trim();
    if (cleaned.isEmpty) return;

    try {
      await syncPendingTodoToggles();

      final repo = NoteRepository.instance;
      Note? targetNote;

      if (noteId != null && noteId.isNotEmpty && noteId != 'ALL_NOTES') {
        targetNote = await repo.readNote(noteId);
      }

      if (targetNote == null) {
        // Find existing "My Tasks" or first checklist note
        final activeNotes = await repo.readAllNotes(isArchived: false, isTrashed: false);
        for (final n in activeNotes) {
          if (n.isLocked) continue;
          final titleLower = n.title.trim().toLowerCase();
          if (titleLower == 'my tasks' ||
              titleLower == 'todo' ||
              titleLower == 'tasks') {
            targetNote = n;
            break;
          }
        }

        if (targetNote == null && activeNotes.isNotEmpty) {
          for (final n in activeNotes) {
            if (n.isLocked) continue;
            // Strict checklist signature check
            if (n.content.contains('"list":"checked"') ||
                n.content.contains('"list":"unchecked"') ||
                n.content.contains('- [ ]') ||
                n.content.contains('- [x]')) {
              targetNote = n;
              break;
            }
          }
        }
      }

      if (targetNote != null) {
        final delta = RichTextUtils.contentToDelta(targetNote.content);
        final doc = Document.fromDelta(delta);
        QuillChecklistHelper.appendChecklistItem(doc, cleaned);
        targetNote.content = RichTextUtils.deltaToJson(doc.toDelta());
        targetNote.dateModified = DateTime.now();
        await repo.updateNote(targetNote);
      } else {
        // Create new "My Tasks" note with authentic UUIDv4 identifier
        final now = DateTime.now();
        final doc = Document();
        QuillChecklistHelper.appendChecklistItem(doc, cleaned);
        final newNote = Note(
          id: const Uuid().v4(),
          title: 'My Tasks',
          content: RichTextUtils.deltaToJson(doc.toDelta()),
          dateCreated: now,
          dateModified: now,
          category: 'Notes',
        );
        await repo.createNote(newNote);
      }

      await updateTodoWidgetData();
    } catch (e) {
      debugPrint('Quick add task failed: $e');
    }
  }

  /// Requests the host launcher to pin the Todo & Checklist widget to the home screen.
  static Future<bool> pinTodoWidget() async {
    try {
      final res = await _channel.invokeMethod<bool>('pinTodoWidget');
      return res ?? false;
    } catch (e) {
      debugPrint('Pin widget failed: $e');
      return false;
    }
  }
}
