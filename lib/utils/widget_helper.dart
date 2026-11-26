import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'app_constants.dart';
import '../data/note_model.dart';
import '../data/transaction_model.dart';
import '../features/finances/data/repositories/split_bill_repository.dart';
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

  static Future<void>? _financeActiveFuture;
  static bool _financeDirty = false;

  static Future<void>? _todoActiveFuture;
  static bool _todoDirty = false;

  /// Pushes non-sensitive widget configuration & privacy flags to the native
  /// `WidgetCacheStore` and triggers launcher shortcut / component state sync.
  static Future<void> syncWidgetConfig({
    bool? showFinancialManager,
    bool? appLockEnabled,
    bool? lockFinances,
    bool? hideWidgetDataWhenLocked,
    bool? screenshotShieldEnabled,
    bool? useDynamicColor,
    String? languageCode,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        'showFinancialManager':
            showFinancialManager ?? (prefs.getBool('showFinancialManager') ?? false),
        'appLockEnabled':
            appLockEnabled ?? (prefs.getBool('appLockEnabled') ?? false),
        'lockFinances': lockFinances ?? (prefs.getBool('lockFinances') ?? false),
        'hideWidgetDataWhenLocked':
            hideWidgetDataWhenLocked ?? (prefs.getBool('hideWidgetDataWhenLocked') ?? false),
        'screenshotShieldEnabled':
            screenshotShieldEnabled ?? (prefs.getBool('screenshotShieldEnabled') ?? false),
        'useDynamicColor':
            useDynamicColor ?? (prefs.getBool('useDynamicColor') ?? true),
        'languageCode':
            languageCode ?? (prefs.getString('selectedLanguageCode') ?? 'system'),
      };
      await _channel.invokeMethod('syncWidgetConfig', payload);
    } on MissingPluginException {
      // Ignore missing native implementation silently in background isolates / tests
    } catch (e) {
      debugPrint('Sync widget config failed: $e');
    }
  }

  /// Coalesces rapid consecutive calls to refresh financial widget metrics so
  /// batch imports or rapid row edits trigger at most one trailing recompute.
  static Future<void> updateWidgetData() {
    if (_financeActiveFuture != null) {
      _financeDirty = true;
      return _financeActiveFuture!;
    }
    _financeActiveFuture = _runFinanceLoop();
    return _financeActiveFuture!;
  }

  static Future<void> _runFinanceLoop() async {
    try {
      do {
        _financeDirty = false;
        await _performUpdateWidgetData();
      } while (_financeDirty);
    } finally {
      _financeActiveFuture = null;
    }
  }

  static Future<void> _performUpdateWidgetData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currencyCode = prefs.getString('currency') ?? 'LKR';
      final currency = AppConstants.getCurrencyInfo(currencyCode).symbol;
      final account1Name = prefs.getString('account1Name') ?? 'Daily';
      final account2Name = prefs.getString('account2Name') ?? 'Savings';
      final enableSavingsVault = prefs.getBool('enableSavingsVault') ?? true;
      final enableBudgetsAndAnalytics =
          prefs.getBool('enableBudgetsAndAnalytics') ?? true;
      final showSplitBills = prefs.getBool('showSplitBills') ?? false;

      final repo = TransactionRepository.instance;
      final allTx = await repo.readAllTransactions();

      // Filter out reversals and neutral double-entry transfers
      final activeTx = allTx
          .where((t) =>
              t.category != '__reversal__' &&
              t.category.toLowerCase() != 'transfer')
          .toList();

      // Exact calendar boundaries [today 00:00, tomorrow 00:00) & [monthStart, monthEnd)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 1);

      final todaySpent = activeTx
          .where((t) =>
              t.isExpense &&
              !t.date.isBefore(today) &&
              t.date.isBefore(tomorrow))
          .fold(0.0, (sum, t) => sum + t.amount);

      final monthTx = activeTx
          .where((t) =>
              !t.date.isBefore(monthStart) && t.date.isBefore(monthEnd))
          .toList();

      final monthSpent =
          monthTx.where((t) => t.isExpense).fold(0.0, (sum, t) => sum + t.amount);
      final monthIncome = monthTx
          .where((t) => !t.isExpense)
          .fold(0.0, (sum, t) => sum + t.amount);

      // Dual-account cash flow split for current month (transfers included per account)
      double dailyNet = 0.0;
      double savingsNet = 0.0;
      for (final t in allTx) {
        if (t.category == '__reversal__') continue;
        if (t.date.isBefore(monthStart) || !t.date.isBefore(monthEnd)) continue;
        final isSavings =
            t.account == 'savings' || t.account == AccountType.savings;
        final delta = t.isExpense ? -t.amount : t.amount;
        if (isSavings) {
          savingsNet += delta;
        } else {
          dailyNet += delta;
        }
      }

      final numberFormat = NumberFormat('#,##0.##', Intl.defaultLocale);
      String formatUnsigned(double value) =>
          '$currency ${numberFormat.format(value)}';
      String formatSigned(double value) =>
          '${value < 0 ? '-' : '+'}$currency ${numberFormat.format(value.abs())}';
      String formatBalance(double value) =>
          '${value < 0 ? '-' : ''}$currency ${numberFormat.format(value.abs())}';

      final spentTodayStr = formatUnsigned(todaySpent);
      final spentMonthStr = formatUnsigned(monthSpent);
      final incomeMonthStr = formatUnsigned(monthIncome);
      final net = monthIncome - monthSpent;
      final netStr = formatSigned(net);
      final dailyBalanceStr = formatBalance(dailyNet);
      final savingsBalanceStr = formatBalance(savingsNet);

      // Budget progress & category map
      double totalBudget = 0;
      final Map<String, double> categoryBudgetsMap = {};
      final budgetsStr = prefs.getString('categoryBudgets');
      if (budgetsStr != null && budgetsStr.isNotEmpty) {
        try {
          final Map<String, dynamic> raw = json.decode(budgetsStr);
          raw.forEach((k, v) {
            final amount = (v as num).toDouble();
            categoryBudgetsMap[k] = amount;
            totalBudget += amount;
          });
        } catch (_) {}
      }
      final budgetPercent =
          totalBudget > 0 ? ((monthSpent / totalBudget) * 100).round() : -1;
      final budgetLabel = totalBudget > 0
          ? '$currency ${numberFormat.format(monthSpent)} / $currency ${numberFormat.format(totalBudget)}'
          : '';

      // Top spending category this month
      final byCategory = <String, double>{};
      for (final t in monthTx.where((t) => t.isExpense)) {
        byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
      }
      final sortedCategories = byCategory.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topCategory =
          sortedCategories.isNotEmpty ? sortedCategories.first.key : '';
      final topCategoryAmount = sortedCategories.isNotEmpty
          ? formatUnsigned(sortedCategories.first.value)
          : '';

      // Spending run-rate & forecast sparkline (using filtered activeTx)
      String forecastAmountStr = '';
      String forecastPace = 'on_track';
      final sparklinePoints = <double>[];

      try {
        final spendingForecast =
            SpendingForecastService.calculateMonthlyForecast(
          transactions: activeTx,
          categoryBudgets: categoryBudgetsMap,
        );

        forecastAmountStr =
            '~${formatUnsigned(spendingForecast.projectedMonthEndSpend)}';
        forecastPace = switch (spendingForecast.status) {
          SpendingPaceStatus.overPace => 'over_pace',
          SpendingPaceStatus.exhausted => 'exhausted',
          _ => 'on_track',
        };

        final rawPoints = <double>[];
        final monthlyData = await repo.getMonthlyTransactionSummary(6);
        for (final d in monthlyData) {
          final exp = (d['totalExpense'] as num?)?.toDouble() ??
              (d['expense'] as num?)?.toDouble() ??
              0.0;
          rawPoints.add(exp);
        }
        if (spendingForecast.projectedMonthEndSpend > 0) {
          rawPoints.add(spendingForecast.projectedMonthEndSpend);
        }
        final firstNonZeroIdx = rawPoints.indexWhere((v) => v > 0);
        if (firstNonZeroIdx >= 0) {
          sparklinePoints.addAll(rawPoints.sublist(firstNonZeroIdx));
        }
      } catch (_) {}

      // Split Bills pending net balance (only when Split Bills is enabled)
      String splitBillsPendingStr = '';
      if (showSplitBills) {
        try {
          final metrics = await SplitBillRepository.instance.getSummaryMetrics();
          final owed = metrics['owedToUser'] ?? 0.0;
          final owes = metrics['userOwes'] ?? 0.0;
          final splitNet = metrics['netBalance'] ?? 0.0;
          if (owed > 0 || owes > 0) {
            splitBillsPendingStr = formatSigned(splitNet);
          }
        } catch (_) {}
      }

      final snapshotMap = <String, dynamic>{
        'spentToday': spentTodayStr,
        'spentMonth': spentMonthStr,
        'incomeMonth': incomeMonthStr,
        'netMonth': netStr,
        'netPositive': net >= 0,
        'netBalance': net,
        'totalIncome': monthIncome,
        'totalExpense': monthSpent,
        'currencySymbol': currency,
        'account1Name': account1Name,
        'account2Name': account2Name,
        'dailyBalance': dailyBalanceStr,
        'savingsBalance': savingsBalanceStr,
        'enableSavingsVault': enableSavingsVault,
        'enableBudgetsAndAnalytics': enableBudgetsAndAnalytics,
        'showSplitBills': showSplitBills,
        'splitBillsPending': splitBillsPendingStr,
        'budgetPercent': budgetPercent,
        'budgetLabel': budgetLabel,
        'topCategory': topCategory,
        'topCategoryAmount': topCategoryAmount,
        'forecastAmount': forecastAmountStr,
        'forecastPace': forecastPace,
        'sparklinePoints': sparklinePoints,
        'hasEnoughSparklineData': sparklinePoints.length >= 2,
      };

      final jsonStr = json.encode(snapshotMap);
      try {
        await _channel.invokeMethod('syncFinanceSnapshot', jsonStr);
      } on MissingPluginException {
        // Background isolate (Workmanager / Telephony): stage for EverythingApplication
        await prefs.setString('widget_bg_staging_finance', jsonStr);
      }
    } catch (e) {
      debugPrint('Widget update failed: $e');
    }
  }

  /// Synchronizes any pending checkbox toggles queued by the Android AppWidget
  /// and writes the changes back into the notes database.
  static Future<void> syncPendingTodoToggles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool usedChannel = false;
      String? pendingStr;

      try {
        pendingStr =
            await _channel.invokeMethod<String>('getPendingTodoToggles');
        if (pendingStr != null) {
          usedChannel = true;
        }
      } on MissingPluginException {
        pendingStr = null;
      } catch (_) {
        pendingStr = null;
      }

      if (pendingStr == null) {
        try {
          await prefs.reload();
        } catch (_) {}
        pendingStr = prefs.getString('widget_pending_toggles');
      }

      if (pendingStr == null || pendingStr.isEmpty || pendingStr == '[]') {
        return;
      }

      final List<dynamic> toggles = json.decode(pendingStr);
      if (toggles.isEmpty) return;

      // Group toggles by noteId and squash redundant intermediate toggles;
      // match by lineIndex >= 0 first, falling back to trimmed text.
      final Map<String, Map<String, Map<String, dynamic>>> byNoteSquashed = {};
      int maxProcessedTimestamp = 0;
      for (final t in toggles) {
        if (t is Map) {
          final ts = t['timestamp'] as int? ?? 0;
          if (ts > maxProcessedTimestamp) {
            maxProcessedTimestamp = ts;
          }
          final noteId = t['noteId'] as String?;
          if (noteId != null && noteId.isNotEmpty) {
            final lineIndex = t['lineIndex'] as int? ?? -1;
            final text = (t['text'] as String?)?.trim();
            final itemKey = lineIndex >= 0
                ? 'idx_$lineIndex'
                : ((text != null && text.isNotEmpty) ? 'txt_$text' : '');
            if (itemKey.isNotEmpty) {
              byNoteSquashed.putIfAbsent(noteId, () => {})[itemKey] =
                  Map<String, dynamic>.from(t);
            }
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
          if (lineIndex >= 0 ||
              (expectedText != null && expectedText.isNotEmpty)) {
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

      // Preserve any toggles queued while SQLite writes were in flight
      String? latestPendingStr;
      if (usedChannel) {
        try {
          latestPendingStr =
              await _channel.invokeMethod<String>('getPendingTodoToggles');
        } catch (_) {}
      } else {
        try {
          await prefs.reload();
        } catch (_) {}
        latestPendingStr = prefs.getString('widget_pending_toggles');
      }

      final List<dynamic> remainingToggles = [];
      if (latestPendingStr != null &&
          latestPendingStr.isNotEmpty &&
          latestPendingStr != '[]') {
        try {
          final latestList = json.decode(latestPendingStr);
          if (latestList is List) {
            for (final item in latestList) {
              if (item is Map) {
                final ts = item['timestamp'] as int? ?? 0;
                if (ts > maxProcessedTimestamp) {
                  remainingToggles.add(item);
                }
              }
            }
          }
        } catch (_) {}
      }

      final remainingJson =
          remainingToggles.isEmpty ? '[]' : json.encode(remainingToggles);
      if (usedChannel) {
        try {
          await _channel.invokeMethod('setPendingTodoToggles', remainingJson);
          return;
        } on MissingPluginException {
          // Fall through to legacy prefs write
        }
      }
      await prefs.setString('widget_pending_toggles', remainingJson);
    } catch (e) {
      debugPrint('Sync pending todo toggles failed: $e');
    }
  }

  /// Coalesces rapid consecutive calls to recompute checklist widget data.
  static Future<void> updateTodoWidgetData() {
    if (_todoActiveFuture != null) {
      _todoDirty = true;
      return _todoActiveFuture!;
    }
    _todoActiveFuture = _runTodoLoop();
    return _todoActiveFuture!;
  }

  static Future<void> _runTodoLoop() async {
    try {
      do {
        _todoDirty = false;
        await _performUpdateTodoWidgetData();
      } while (_todoDirty);
    } finally {
      _todoActiveFuture = null;
    }
  }

  static Future<void> _performUpdateTodoWidgetData() async {
    try {
      await syncPendingTodoToggles();

      final prefs = await SharedPreferences.getInstance();
      try {
        await prefs.reload();
      } catch (_) {}
      final repo = NoteRepository.instance;
      final activeNotes = await repo.readActiveChecklistNotes();

      Map<String, String> activeNoteIdsMap = {};
      bool usedChannelForActiveIds = false;
      try {
        final channelMap = await _channel
            .invokeMapMethod<String, String>('getWidgetActiveNoteIds');
        if (channelMap != null) {
          activeNoteIdsMap = Map<String, String>.from(channelMap);
          usedChannelForActiveIds = true;
        }
      } on MissingPluginException {
        // Fallback below
      } catch (_) {}

      if (!usedChannelForActiveIds) {
        final activeNoteId = prefs.getString('widget_active_note_id');
        if (activeNoteId != null) {
          activeNoteIdsMap['global'] = activeNoteId;
        }
        for (final key in prefs.getKeys()) {
          if (key.startsWith('widget_active_note_id_')) {
            final widgetSpecificId = prefs.getString(key);
            if (widgetSpecificId != null) {
              activeNoteIdsMap[key.replaceFirst('widget_active_note_id_', '')] =
                  widgetSpecificId;
            }
          }
        }
      }

      final pinnedNoteIds = <String>{};
      for (final id in activeNoteIdsMap.values) {
        if (id.isNotEmpty && id != 'ALL_NOTES') {
          pinnedNoteIds.add(id);
        }
      }
      final remainingPinnedIds = Set<String>.from(pinnedNoteIds);

      final List<Map<String, dynamic>> todoNotes = [];
      int totalItemsCount = 0;
      const int maxTotalItems = 100;
      const int maxItemsPerNote = 30;

      for (final note in activeNotes) {
        // Privacy invariant: Never expose password or biometric-locked notes to unauthenticated widget
        if (note.isLocked) continue;

        final isPinnedToWidget = pinnedNoteIds.contains(note.id);
        remainingPinnedIds.remove(note.id);
        if (totalItemsCount >= maxTotalItems && !isPinnedToWidget) {
          if (remainingPinnedIds.isEmpty) break;
          continue;
        }

        // Strict checklist signature check (prevents false-positive matches on words like 'playlist')
        final hasChecklist = note.content.contains('"list":"checked"') ||
            note.content.contains('"list":"unchecked"') ||
            note.content.contains('- [ ]') ||
            note.content.contains('- [x]') ||
            note.content.contains('- [X]');
        if (!hasChecklist) continue;

        final delta = RichTextUtils.contentToDelta(note.content);
        final doc = Document.fromDelta(delta);
        final items = QuillChecklistHelper.extractChecklistData(doc);
        if (items.isNotEmpty) {
          final totalCount = items.length;
          final checkedCount = items.where((it) => it.isDone).length;
          final pendingItems = items.where((it) => !it.isDone).toList();
          final pendingCount = pendingItems.length;
          final boundedPending = pendingItems.take(maxItemsPerNote).toList();

          todoNotes.add({
            'id': note.id,
            'title':
                note.title.trim().isEmpty ? 'Untitled Note' : note.title.trim(),
            'pendingCount': pendingCount,
            'checkedCount': checkedCount,
            'totalCount': totalCount,
            'items': boundedPending
                .map((it) => {
                      'lineIndex': it.lineIndex,
                      'text': it.text,
                      'isDone': it.isDone,
                    })
                .toList(),
          });
          totalItemsCount += boundedPending.length;
          if (totalItemsCount >= maxTotalItems && remainingPinnedIds.isEmpty) {
            break;
          }
        }
      }

      final jsonStr = json.encode(todoNotes);
      try {
        await _channel.invokeMethod('syncTodoSnapshot', jsonStr);
      } on MissingPluginException {
        await prefs.setString('widget_bg_staging_todo', jsonStr);
      }

      // Synchronize and clean up per-widget active note titles and deleted IDs
      final Map<String, Map<String, String>> titleUpdates = {};
      for (final entry in activeNoteIdsMap.entries) {
        final key = entry.key;
        final noteId = entry.value;
        if (noteId.isNotEmpty && noteId != 'ALL_NOTES') {
          final matchedIdx = todoNotes.indexWhere((n) => n['id'] == noteId);
          if (matchedIdx < 0) {
            titleUpdates[key] = {
              'id': 'ALL_NOTES',
              'title': 'All Action Items',
            };
          } else {
            final matchedTitle =
                todoNotes[matchedIdx]['title'] as String? ?? 'Checklist';
            titleUpdates[key] = {
              'id': noteId,
              'title': matchedTitle,
            };
          }
        }
      }

      if (titleUpdates.isNotEmpty) {
        bool updatedViaChannel = false;
        try {
          await _channel.invokeMethod(
            'updateWidgetActiveNoteTitles',
            titleUpdates,
          );
          updatedViaChannel = true;
        } on MissingPluginException {
          updatedViaChannel = false;
        }
        if (!updatedViaChannel || !usedChannelForActiveIds) {
          for (final entry in titleUpdates.entries) {
            final key = entry.key;
            final idVal = entry.value['id']!;
            final titleVal = entry.value['title']!;
            if (key == 'global') {
              if (prefs.containsKey('widget_active_note_id')) {
                await prefs.setString('widget_active_note_id', idVal);
                await prefs.setString('widget_active_note_title', titleVal);
              }
            } else {
              if (prefs.containsKey('widget_active_note_id_$key')) {
                await prefs.setString('widget_active_note_id_$key', idVal);
                await prefs.setString(
                    'widget_active_note_title_$key', titleVal);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Todo widget update failed: $e');
    }
  }

  /// Appends a new checklist item to the specified note (or default/new checklist note)
  /// and updates widget data. Returns the updated or newly created [Note].
  static Future<Note?> quickAddTask({
    String? noteId,
    required String taskText,
  }) async {
    final cleaned = taskText.trim();
    if (cleaned.isEmpty) return null;

    try {
      await syncPendingTodoToggles();

      final repo = NoteRepository.instance;
      Note? targetNote;

      if (noteId != null && noteId.isNotEmpty && noteId != 'ALL_NOTES') {
        targetNote = await repo.readNote(noteId);
      }

      if (targetNote == null) {
        // Check if any Todo widget instance has a specific active note pinned
        final candidateIds = <String>[];
        try {
          final channelMap = await _channel
              .invokeMapMethod<String, String>('getWidgetActiveNoteIds');
          if (channelMap != null) {
            for (final entry in channelMap.entries) {
              if (entry.key != 'global' &&
                  entry.value.isNotEmpty &&
                  entry.value != 'ALL_NOTES') {
                candidateIds.add(entry.value);
              }
            }
          }
        } catch (_) {}

        if (candidateIds.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          for (final key in prefs.getKeys()) {
            if (key.startsWith('widget_active_note_id_')) {
              final candidateId = prefs.getString(key);
              if (candidateId != null &&
                  candidateId.isNotEmpty &&
                  candidateId != 'ALL_NOTES') {
                candidateIds.add(candidateId);
              }
            }
          }
        }

        for (final candidateId in candidateIds) {
          final n = await repo.readNote(candidateId);
          if (n != null && !n.isLocked && n.deletedAt == null && !n.isArchived) {
            targetNote = n;
            break;
          }
        }
      }

      if (targetNote == null) {
        // Find existing "My Tasks" / "Quick Tasks" or first pinned checklist note
        final activeNotes =
            await repo.readAllNotes(isArchived: false, isTrashed: false);
        for (final n in activeNotes) {
          if (n.isLocked) continue;
          final titleLower = n.title.trim().toLowerCase();
          if (titleLower == 'my tasks' ||
              titleLower == 'quick tasks' ||
              titleLower == 'todo' ||
              titleLower == 'tasks') {
            targetNote = n;
            break;
          }
        }

        if (targetNote == null && activeNotes.isNotEmpty) {
          for (final n in activeNotes) {
            if (n.isLocked) continue;
            // Strict checklist signature check (activeNotes is already ordered with isPinned DESC)
            if (n.content.contains('"list":"checked"') ||
                n.content.contains('"list":"unchecked"') ||
                n.content.contains('- [ ]') ||
                n.content.contains('- [x]') ||
                n.content.contains('- [X]')) {
              targetNote = n;
              break;
            }
          }
        }
      }

      Note savedNote;
      if (targetNote != null) {
        final delta = RichTextUtils.contentToDelta(targetNote.content);
        final doc = Document.fromDelta(delta);
        QuillChecklistHelper.appendChecklistItem(doc, cleaned);
        targetNote.content = RichTextUtils.deltaToJson(doc.toDelta());
        targetNote.dateModified = DateTime.now();
        await repo.updateNote(targetNote);
        savedNote = targetNote;
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
        savedNote = newNote;
      }

      unawaited(updateTodoWidgetData());
      return savedNote;
    } catch (e) {
      debugPrint('Quick add task failed: $e');
      return null;
    }
  }

  /// Requests the host launcher to pin an Android widget of the specified [widgetType]
  /// ('todo' or 'finance') to the home screen.
  static Future<bool> requestPinWidget(String widgetType) async {
    try {
      final res = await _channel.invokeMethod<bool>('requestPinAppWidget', {
        'type': widgetType,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('Pin widget failed: $e');
      return false;
    }
  }

  /// Requests the host launcher to pin the Todo & Checklist widget to the home screen.
  static Future<bool> pinTodoWidget() => requestPinWidget('todo');
}
