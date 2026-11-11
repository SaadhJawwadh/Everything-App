import 'dart:async';
import 'dart:convert';
import 'package:another_telephony/telephony.dart' hide NetworkType;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/widgets.dart';
import '../features/finances/data/transaction_repository.dart';
import '../data/transaction_model.dart';
import '../data/transaction_category.dart';
import '../data/sms_contact.dart';
import '../data/custom_sms_rule.dart';
import 'sms_parser.dart';
import 'sms_constants.dart';
import 'gemini_nano_service.dart';
import 'offline_ai_fallback_service.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'notification_service.dart';
import 'dart:io';
import 'native_core_bridge.dart';

enum SmsSyncTrigger { manualDashboard, historicalSheet, backgroundScheduled, catchUp }

class SmsSyncProgress {
  final bool isSyncing;
  final int scanned;
  final int total;
  final int found;
  final int alreadyImported;
  final String? message;

  const SmsSyncProgress({
    required this.isSyncing,
    this.scanned = 0,
    this.total = 0,
    this.found = 0,
    this.alreadyImported = 0,
    this.message,
  });
}

class SmsService {
  static final Telephony telephony = Telephony.instance;

  static bool _isSyncingLock = false;
  static bool get isSyncing => _isSyncingLock;
  static bool _cancelRequested = false;

  static void cancelSync() {
    if (_isSyncingLock) {
      _cancelRequested = true;
      _syncProgressController.add(const SmsSyncProgress(
        isSyncing: false,
        message: 'Sync cancelled by user',
      ));
    }
  }

  static final StreamController<SmsSyncProgress> _syncProgressController =
      StreamController<SmsSyncProgress>.broadcast();
  static Stream<SmsSyncProgress> get syncProgressStream => _syncProgressController.stream;

  static Future<TransactionModel?> _handleNewSms(SmsMessage sms) async {
    await reloadSmsContacts();
    await TransactionCategory.reload();
    final transaction = await _parseWithAiFallback(
      body: sms.body ?? '',
      address: sms.address ?? '',
      messageId: sms.id,
      messageDate: sms.date,
      allowedSenderIds: _allowedSenderIds,
      blockedSenderIds: _blockedSenderIds,
      customExpenseRules: _customExpenseRules,
      customIncomeRules: _customIncomeRules,
      customSmsRules: _customSmsRules,
    );
    if (transaction == null || transaction.smsId == null) {
      return null;
    }
    if (await TransactionRepository.instance.hasCrossSenderDuplicate(transaction.amount, transaction.date)) {
      return null;
    }

    final inserted = await TransactionRepository.instance.createSmsTransaction(transaction);
    if (inserted == null) {
      return null;
    }

    if (sms.address != null && sms.address!.isNotEmpty) {
      await _autoRegisterSender(sms.address!);
    }

    if (transaction.category == SmsConstants.reversalSentinel) {
      final target = await TransactionRepository.instance.findReversalTarget(transaction.amount, transaction.date);
      if (target != null) {
        await TransactionRepository.instance.deleteTransaction(target.id!);
      }
      // Always delete the reversal transaction itself to keep the DB clean
      await TransactionRepository.instance.deleteTransaction(inserted.id!);
      return null;
    } else {
      await NotificationService.showNotification(
        id: inserted.id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
        title: inserted.isExpense ? '💳 Expense Auto-Imported' : '💰 Income Auto-Imported',
        body: '${inserted.isExpense ? "Spent" : "Received"} ${inserted.amount.toStringAsFixed(0)} • ${inserted.description}',
      );
      return inserted;
    }
  }

  static Future<void> _autoRegisterSender(String address) async {
    final cleanAddr = address.trim();
    if (cleanAddr.isEmpty || cleanAddr.length < 2) return;
    final lower = cleanAddr.toLowerCase();
    if (_allowedSenderIds.contains(lower) || _blockedSenderIds.contains(lower)) {
      return;
    }
    try {
      final id = 'sender_${lower.replaceAll(RegExp(r'[^a-z0-9_]'), '_')}';
      await TransactionRepository.instance.upsertSmsContact(SmsContact(
        id: id,
        senderIds: [cleanAddr],
        label: cleanAddr,
        isBuiltIn: false,
        isBlocked: false,
      ));
      _allowedSenderIds.add(lower);
    } catch (e) {
      debugPrint('Error auto-registering sender $cleanAddr: $e');
    }
  }

  static Set<String> _allowedSenderIds = {};
  static Set<String> _blockedSenderIds = {};
  static var _customExpenseRules = <String>[];
  static var _customIncomeRules = <String>[];
  static var _customSmsRules = <CustomSmsRule>[];
  static var _categoryAccountRouting = <String, String>{};

  static Future<void> reloadSmsContacts() async {
    final contacts = await TransactionRepository.instance.getAllSmsContacts();
    final allowed = <String>{};
    final blocked = <String>{};
    for (final c in contacts) {
      if (c.isBlocked) {
        blocked.addAll(c.senderIds.map((s) => s.toLowerCase()));
      } else {
        allowed.addAll(c.senderIds.map((s) => s.toLowerCase()));
      }
    }
    _allowedSenderIds = allowed;
    _blockedSenderIds = blocked;
    try {
      final prefs = await SharedPreferences.getInstance();
      _customExpenseRules = prefs.getStringList('customExpenseRules') ?? [];
      _customIncomeRules = prefs.getStringList('customIncomeRules') ?? [];
      final storedRules = prefs.getStringList('customSmsRules_v2');
      if (storedRules != null) {
        _customSmsRules = storedRules
            .map((s) {
              try {
                return CustomSmsRule.fromJson(s);
              } catch (_) {
                return null;
              }
            })
            .whereType<CustomSmsRule>()
            .toList();
      }
      final routingStr = prefs.getString('categoryAccountRouting');
      if (routingStr != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(routingStr);
          _categoryAccountRouting = decoded.map((k, v) => MapEntry(k, v.toString()));
        } catch (_) {}
      } else {
        _categoryAccountRouting = {};
      }
    } catch (_) {}
  }

  static Future<void> init() async {
    try {
      await reloadSmsContacts();
      await TransactionCategory.reload();
      if (await hasPermission()) {
        await _startTelephonyListening();
        await syncDailySyncSchedule();
      }
    } catch (e) {
      debugPrint('SmsService init error: $e');
    }
  }

  static Future<bool> requestPermissions() async {
    try {
      final status = await Permission.sms.request();
      final granted = status.isGranted;
      if (granted) {
        await _startTelephonyListening();
        await syncDailySyncSchedule();
      }
      return granted;
    } catch (e) {
      debugPrint('SmsService.requestPermissions error: $e');
      return false;
    }
  }

  static Future<bool> hasPermission() async {
    try {
      final smsStatus = await Permission.sms.status;
      return smsStatus.isGranted;
    } catch (e) {
      debugPrint('SmsService.hasPermission isolate warning: $e');
      return true; // Fallback in background isolate so getInboxSms can attempt scanning
    }
  }

  static Future<int> syncInboxFrom(
    DateTime from, {
    bool bypassTombstones = false,
    void Function(int scanned, int total, int found)? onProgress,
    void Function(int alreadyImported)? onAlreadyImported,
  }) async {
    if (!await hasPermission()) {
      return 0;
    }
    await reloadSmsContacts();
    await TransactionCategory.reload();

    final startMs = from.millisecondsSinceEpoch;
    final startSec = from.millisecondsSinceEpoch ~/ 1000;

    List<SmsMessage> messages = await telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE, SmsColumn.ID],
      filter: SmsFilter.where(SmsColumn.DATE).greaterThanOrEqualTo(startMs.toString()),
    );

    if (messages.isEmpty) {
      final secMessages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE, SmsColumn.ID],
        filter: SmsFilter.where(SmsColumn.DATE).greaterThanOrEqualTo(startSec.toString()),
      );
      if (secMessages.isNotEmpty) {
        messages = secMessages;
      }
    }

    int count = 0;
    int alreadyImported = 0;
    int processed = 0;
    final total = messages.length;
    onProgress?.call(0, total, 0);

    for (var m in messages) {
      if (_cancelRequested) {
        debugPrint('[SmsService] Sync cancelled during processing');
        break;
      }

      processed++;
      if (processed % 25 == 0) {
        await Future.delayed(Duration.zero);
      }

      final msgDate = SmsParser.resolveMessageDate(m.date);
      if (msgDate.isBefore(from)) {
        onProgress?.call(processed, total, count);
        continue;
      }

      final t = await _parseWithAiFallback(
        body: m.body ?? '',
        address: m.address ?? '',
        messageId: m.id,
        messageDate: m.date,
        allowedSenderIds: _allowedSenderIds,
        blockedSenderIds: _blockedSenderIds,
        customExpenseRules: _customExpenseRules,
        customIncomeRules: _customIncomeRules,
        customSmsRules: _customSmsRules,
      );

      if (t == null || t.smsId == null) {
        onProgress?.call(processed, total, count);
        continue;
      }
      if (await TransactionRepository.instance.hasCrossSenderDuplicate(t.amount, t.date)) {
        onProgress?.call(processed, total, count);
        continue;
      }

      final exists = await TransactionRepository.instance.smsExists(t.smsId!);
      if (exists && !bypassTombstones) {
        alreadyImported++;
        onAlreadyImported?.call(alreadyImported);
        onProgress?.call(processed, total, count);
        continue;
      }

      final inserted = await TransactionRepository.instance.createSmsTransaction(
        t,
        bypassTombstones: bypassTombstones,
      );
      if (inserted == null) {
        onProgress?.call(processed, total, count);
        continue;
      }
      if (m.address != null && m.address!.isNotEmpty) {
        await _autoRegisterSender(m.address!);
      }
      count++;
      onProgress?.call(processed, total, count);

      if (t.category == SmsConstants.reversalSentinel) {
        final target = await TransactionRepository.instance.findReversalTarget(t.amount, t.date);
        if (target != null) {
          await TransactionRepository.instance.deleteTransaction(target.id!);
        }
        await TransactionRepository.instance.deleteTransaction(inserted.id!);
      }
    }
    return count;
  }

  /// Scans recent inbox SMS for unlisted sender handles that look like financial/bank senders.
  static Future<List<String>> discoverNewBankSenders() async {
    if (!await hasPermission()) return [];
    await reloadSmsContacts();

    final messages = await telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY],
    );

    final candidates = <String>{};
    for (var m in messages) {
      final address = (m.address ?? '').trim();
      final body = m.body ?? '';
      if (address.isEmpty || body.isEmpty) continue;
      if (!NativeCoreBridge.instance.containsDigits(body)) continue;

      final addrLower = address.toLowerCase();
      if (_allowedSenderIds.contains(addrLower) || _blockedSenderIds.contains(addrLower)) {
        continue;
      }
      final isKnownBank = SmsConstants.bankSenders.any((s) => address.toUpperCase().contains(s.toUpperCase()));
      if (isKnownBank) continue;

      final hasFinancialTerms = SmsConstants.amountRegex.hasMatch(body) ||
          SmsConstants.bareAmountRegex.hasMatch(body) ||
          SmsConstants.debitRegex.hasMatch(body) ||
          SmsConstants.creditRegex.hasMatch(body);

      if (hasFinancialTerms && address.length >= 3) {
        candidates.add(address);
      }
    }
    return candidates.toList();
  }

  static final StreamController<TransactionModel> _smsStreamController = StreamController<TransactionModel>.broadcast();
  static bool _isListeningToTelephony = false;

  static Stream<TransactionModel> get incomingTransactions {
    _startTelephonyListening();
    return _smsStreamController.stream;
  }

  static Future<void> _startTelephonyListening() async {
    if (_isListeningToTelephony) return;
    try {
      if (!await hasPermission()) {
        _isListeningToTelephony = false;
        return;
      }
      _isListeningToTelephony = true;
      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) async {
          await reloadSmsContacts();
          await TransactionCategory.reload();
          final inserted = await _handleNewSms(message);
          if (inserted != null) {
            _smsStreamController.add(inserted);
          }
        },
        onBackgroundMessage: backgroundMessageHandler,
      );
    } catch (e) {
      _isListeningToTelephony = false;
      debugPrint('Error starting telephony listener safely: $e');
    }
  }

  @Deprecated('Use incomingTransactions instead to avoid memory leaks')
  static void listenForSms({required Function(TransactionModel) onNew}) {
    incomingTransactions.listen(onNew);
  }

  static Future<TransactionModel?> _parseWithAiFallback({
    required String body,
    required String address,
    required int? messageId,
    required int? messageDate,
    required Set<String> allowedSenderIds,
    required Set<String> blockedSenderIds,
    required List<String> customExpenseRules,
    required List<String> customIncomeRules,
    List<CustomSmsRule>? customSmsRules,
  }) async {
    if (body.trim().isEmpty) return null;

    TransactionModel? transaction;

    final prefs = await SharedPreferences.getInstance();
    final useAi = prefs.getBool('useOnDeviceAi') ?? false;
    final preferredCurrency = prefs.getString('currency');

    // 1. Try AI-First (Gemini Nano) if enabled and supported
    if (useAi && SmsParser.isPotentiallyRelevant(
          body: body,
          address: address,
          allowedSenderIds: allowedSenderIds,
          blockedSenderIds: blockedSenderIds,
          preferredCurrency: preferredCurrency,
          customSmsRules: customSmsRules,
        )) {
      await TransactionCategory.reload();
      final activeCategories = TransactionCategory.allNames;
      final aiService = GeminiNanoService();

      try {
        if (await aiService.isSupported()) {
          final aiParsed = await aiService.parseSmsTransaction(body, activeCategories);
          if (aiParsed != null && aiParsed['amount'] != null && (aiParsed['amount'] as num) > 0) {
            final date = SmsParser.resolveMessageDate(messageDate);
            final normalizedBody = body.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
            final smsId = messageId != null
                ? '${messageId}_$messageDate'
                : 'hash_${address.toLowerCase()}_${normalizedBody.hashCode}_$messageDate';

            final description = aiParsed['description'] ?? aiParsed['merchant'] ?? 'AI Parsed Transaction';
            String category = aiParsed['category'] ?? 'Other';
            if (category == 'Other' || !activeCategories.contains(category)) {
              category = TransactionCategory.fromDescriptionCached('$description $body');
            }

            final matchingRule = customSmsRules?.cast<CustomSmsRule?>().firstWhere(
              (r) => r != null && r.isEnabled && body.toLowerCase().contains(r.keyword.toLowerCase()),
              orElse: () => null,
            );
            final account = SmsParser.resolveAccount(
              body: body,
              category: category,
              matchingRule: matchingRule,
              categoryAccountRouting: _categoryAccountRouting,
            );

            transaction = TransactionModel(
              amount: (aiParsed['amount'] as num).toDouble(),
              description: description,
              date: date,
              isExpense: aiParsed['isExpense'] ?? true,
              category: category,
              smsId: smsId,
              account: account,
              isAiRefined: true,
            );
          }
        }
      } catch (e) {
        debugPrint('On-device AI SMS parsing failed: $e');
      }
    }

    // 2. Fallback to Regex parser if AI did not return a valid transaction
    if (transaction == null) {
      transaction = SmsParser.parseMessage(
        body: body,
        address: address,
        messageId: messageId,
        messageDate: messageDate,
        allowedSenderIds: allowedSenderIds,
        blockedSenderIds: blockedSenderIds,
        customExpenseRules: customExpenseRules,
        customIncomeRules: customIncomeRules,
        customSmsRules: customSmsRules,
        preferredCurrency: preferredCurrency,
        categoryAccountRouting: _categoryAccountRouting,
      );

      // AI Refinement Step: Refine description of regex-parsed transaction if AI is enabled and supported
      if (transaction != null && useAi) {
        try {
          final aiService = GeminiNanoService();
          if (await aiService.isSupported()) {
            final refined = await aiService.refineTransactionDescription(
              transaction.description,
              body,
            );
            if (refined != null && refined.isNotEmpty) {
              transaction = transaction.copy(description: refined, isAiRefined: true);
            }
          }
        } catch (e) {
          debugPrint('AI Refinement failed: $e');
        }
      }
    }

    // 3. Fallback to Generic Offline NLP Engine if Regex parser also failed
    if (transaction == null &&
        SmsParser.isPotentiallyRelevant(
          body: body,
          address: address,
          allowedSenderIds: allowedSenderIds,
          blockedSenderIds: blockedSenderIds,
        )) {
      await TransactionCategory.reload();
      final activeCategories = TransactionCategory.allNames;
      final aiParsed = OfflineAiFallbackService.parseSmsTransaction(body, activeCategories);

      if (aiParsed != null && aiParsed['amount'] != null && (aiParsed['amount'] as num) > 0) {
        final date = SmsParser.resolveMessageDate(messageDate);
        final normalizedBody = body.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
        final smsId = messageId != null
            ? '${messageId}_$messageDate'
            : 'hash_${address.toLowerCase()}_${normalizedBody.hashCode}_$messageDate';

        final description = aiParsed['description'] ?? aiParsed['merchant'] ?? 'Offline Parsed Transaction';
        String category = aiParsed['category'] ?? 'Other';
        if (category == 'Other' || !activeCategories.contains(category)) {
          category = TransactionCategory.fromDescriptionCached('$description $body');
        }

        final matchingRule = customSmsRules?.cast<CustomSmsRule?>().firstWhere(
          (r) => r != null && r.isEnabled && body.toLowerCase().contains(r.keyword.toLowerCase()),
          orElse: () => null,
        );
        final account = SmsParser.resolveAccount(
          body: body,
          category: category,
          matchingRule: matchingRule,
          categoryAccountRouting: _categoryAccountRouting,
        );

        transaction = TransactionModel(
          amount: (aiParsed['amount'] as num).toDouble(),
          description: description,
          date: date,
          isExpense: aiParsed['isExpense'] ?? true,
          category: category,
          smsId: smsId,
          account: account,
          isAiRefined: true,
        );
      }
    }

    return transaction;
  }

  /// Unified, thread-safe entry point for SMS synchronization across manual & background triggers.
  static Future<int> performSmsSync({
    required SmsSyncTrigger trigger,
    DateTime? fromTime,
    bool bypassTombstones = false,
    void Function(int scanned, int total, int found)? onProgress,
  }) async {
    if (_isSyncingLock) {
      debugPrint('[SmsService] Sync already active. Skipping trigger: $trigger');
      return 0;
    }
    _isSyncingLock = true;
    _cancelRequested = false;
    _syncProgressController.add(const SmsSyncProgress(isSyncing: true, message: 'Initializing SMS scanner...'));

    try {
      if (!await hasPermission()) {
        _syncProgressController.add(const SmsSyncProgress(isSyncing: false, message: 'SMS permission not granted.'));
        return 0;
      }

      await reloadSmsContacts();
      await TransactionCategory.reload();

      final prefs = await SharedPreferences.getInstance();
      DateTime startCutoff;

      if (fromTime != null) {
        startCutoff = fromTime;
      } else {
        // Default to scanning the last 24 hours (eliminating "fetch only new" skipping bugs)
        startCutoff = DateTime.now().subtract(const Duration(hours: 24));
      }

      int currentAlreadyImported = 0;
      final count = await syncInboxFrom(
        startCutoff,
        bypassTombstones: bypassTombstones,
        onAlreadyImported: (already) {
          currentAlreadyImported = already;
        },
        onProgress: (scanned, total, found) {
          onProgress?.call(scanned, total, found);
          _syncProgressController.add(SmsSyncProgress(
            isSyncing: true,
            scanned: scanned,
            total: total,
            found: found,
            alreadyImported: currentAlreadyImported,
          ));
        },
      );

      if (_cancelRequested) {
        debugPrint('[SmsService] Sync cancelled, skipping completion update');
        _syncProgressController.add(SmsSyncProgress(
          isSyncing: false,
          scanned: 0,
          total: 0,
          found: count,
          alreadyImported: currentAlreadyImported,
          message: 'Sync cancelled by user',
        ));
        return count;
      }

      final now = DateTime.now();
      await prefs.setString('lastSmsSyncTime', now.toIso8601String());
      await prefs.setInt('lastSmsSyncCount', count);

      String completionMsg;
      if (count > 0 && currentAlreadyImported > 0) {
        completionMsg = 'Imported $count new transaction${count == 1 ? "" : "s"} ($currentAlreadyImported up-to-date)';
      } else if (count > 0) {
        completionMsg = 'Imported $count transaction${count == 1 ? "" : "s"}';
      } else if (currentAlreadyImported > 0) {
        completionMsg = 'All $currentAlreadyImported recent transaction${currentAlreadyImported == 1 ? " is" : "s are"} up-to-date';
      } else {
        completionMsg = 'Up to date • No new transactions found';
      }

      _syncProgressController.add(SmsSyncProgress(
        isSyncing: false,
        scanned: 0,
        total: 0,
        found: count,
        alreadyImported: currentAlreadyImported,
        message: completionMsg,
      ));

      return count;
    } catch (e) {
      debugPrint('SmsService.performSmsSync error: $e');
      _syncProgressController.add(SmsSyncProgress(isSyncing: false, message: 'Sync error: $e'));
      return 0;
    } finally {
      _isSyncingLock = false;
    }
  }

  /// Manually triggers the exact daily auto-sync pipeline (scanning recent SMS)
  /// and updates SharedPreferences last sync stats. Returns the count of imported transactions.
  static Future<int> performDailySyncManualTrigger({
    void Function(int scanned, int total, int found)? onProgress,
  }) async {
    return performSmsSync(
      trigger: SmsSyncTrigger.manualDashboard,
      onProgress: onProgress,
    );
  }

  static const kDailySyncTaskName = 'com.saadhjawwadh.notebook.dailySync';

  static Duration calculateDailySyncDelay(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final now = DateTime.now();
      var target = DateTime(now.year, now.month, now.day, hour, minute);
      if (target.isBefore(now)) {
        target = target.add(const Duration(days: 1));
      }
      return target.difference(now);
    } catch (e) {
      debugPrint('Error calculating delay: $e');
      return const Duration(hours: 24);
    }
  }

  static Future<void> syncDailySyncSchedule() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('dailySyncEnabled') ?? false;

      // Cancel any existing task first to avoid multiple triggers
      await Workmanager().cancelByUniqueName(kDailySyncTaskName);

      if (!enabled) return;

      final timeStr = prefs.getString('dailySyncTime') ?? '20:00';
      final delay = calculateDailySyncDelay(timeStr);
      await Workmanager().registerOneOffTask(
        kDailySyncTaskName,
        kDailySyncTaskName,
        initialDelay: delay,
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(
          networkType: NetworkType.notRequired,
        ),
      );
      debugPrint('Daily SMS Auto-Sync task scheduled for $timeStr with delay: $delay');
    } catch (e) {
      debugPrint('Error scheduling SMS auto-sync: $e');
    }
  }

  static Future<bool> performDailyTransactionSync() async {
    WidgetsFlutterBinding.ensureInitialized();
    bool success = false;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Double-check settings and permission
      if (!(prefs.getBool('dailySyncEnabled') ?? false)) return true;
      if (!await hasPermission()) return true;

      final count = await performSmsSync(trigger: SmsSyncTrigger.backgroundScheduled);

      // Notify the user ONLY if 1 or more new transactions were synced
      if (count > 0) {
        await NotificationService.showNotification(
          id: 101,
          title: '💳 SMS Auto-Sync Complete',
          body: 'Synced $count new bank transaction${count == 1 ? "" : "s"} from your messages.',
        );
      }

      success = true;
    } catch (e) {
      debugPrint('performDailyTransactionSync error: $e');
      success = false;
    } finally {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('dailySyncEnabled') ?? false) {
          final timeStr = prefs.getString('dailySyncTime') ?? '20:00';
          final delay = calculateDailySyncDelay(timeStr);
          await Workmanager().registerOneOffTask(
            kDailySyncTaskName,
            kDailySyncTaskName,
            initialDelay: delay,
            existingWorkPolicy: ExistingWorkPolicy.replace,
            constraints: Constraints(
              networkType: NetworkType.notRequired,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error re-registering daily sync task: $e');
      }
    }
    return success;
  }

  /// Deprecated: Streamlined to Scheduled Daily Auto-Sync, Live Listener, and Manual Triggers only.
  /// Unsolicited background polling on app launch and resume has been removed to conserve battery and CPU.
  @Deprecated('Use performDailySyncManualTrigger or scheduled daily auto-sync instead')
  static Future<void> performAppLaunchCatchUpSync({bool force = false}) async {
    // Only execute if explicitly forced by a direct caller
    if (!force) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final fmEnabled = prefs.getBool('showFinancialManager') ?? false;
      final dailySyncEnabled = prefs.getBool('dailySyncEnabled') ?? false;
      if (!fmEnabled && !dailySyncEnabled) return;
      if (!await hasPermission()) return;

      final count = await performSmsSync(
        trigger: SmsSyncTrigger.catchUp,
        fromTime: DateTime.now().subtract(const Duration(hours: 24)),
      );
      debugPrint('Forced catch-up sync completed: $count transactions imported');
    } catch (e) {
      debugPrint('Forced catch-up sync error: $e');
    }
  }

  /// Attempts to locate the original raw SMS body from the device inbox using transaction.smsId.
  static Future<String?> getOriginalSmsBody(TransactionModel transaction) async {
    if (transaction.smsId == null) return null;
    try {
      final parts = transaction.smsId!.split('_');
      final messageId = int.tryParse(parts.first);
      if (messageId != null && await hasPermission()) {
        final messages = await telephony.getInboxSms(
          columns: [SmsColumn.BODY, SmsColumn.ID],
          filter: SmsFilter.where(SmsColumn.ID).equals(messageId.toString()),
        );
        if (messages.isNotEmpty && messages.first.body != null && messages.first.body!.isNotEmpty) {
          return messages.first.body;
        }
      }
    } catch (e) {
      debugPrint('SmsService.getOriginalSmsBody error: $e');
    }
    return null;
  }

  /// Refines a single transaction using Gemini Nano AI.
  /// First attempts full SMS re-parsing using the original SMS body if available;
  /// falls back to refining the current description string directly.
  static Future<TransactionModel?> refineSingleTransactionWithAi(TransactionModel transaction) async {
    final aiService = GeminiNanoService();
    if (!await aiService.isSupported()) return null;

    await TransactionCategory.reload();
    final activeCategories = TransactionCategory.allNames;
    final fullSmsBody = await getOriginalSmsBody(transaction);

    if (fullSmsBody != null && fullSmsBody.isNotEmpty) {
      try {
        final aiParsed = await aiService.parseSmsTransaction(fullSmsBody, activeCategories);
        if (aiParsed != null) {
          final description = (aiParsed['description'] ?? aiParsed['merchant'] ?? transaction.description).toString().trim();
          String category = aiParsed['category'] ?? transaction.category;
          if (category == 'Other' || !activeCategories.contains(category) || category.isEmpty) {
            category = TransactionCategory.fromDescriptionCached('$description $fullSmsBody');
          }
          if (description.isNotEmpty && (description != transaction.description.trim() || category != transaction.category)) {
            return transaction.copy(
              description: description,
              category: category,
            );
          }
        }
      } catch (e) {
        debugPrint('AI re-parsing failed: $e');
      }
    }

    // Fallback refinement using current description text
    try {
      final refinedDesc = await aiService.refineTransactionDescription(
        transaction.description,
        fullSmsBody ?? transaction.description,
      );
      final finalDesc = (refinedDesc != null && refinedDesc.trim().isNotEmpty)
          ? refinedDesc.trim()
          : transaction.description.trim();

      String finalCategory = transaction.category;
      if (finalCategory == 'Other' || !activeCategories.contains(finalCategory) || finalCategory.isEmpty) {
        finalCategory = TransactionCategory.fromDescriptionCached('$finalDesc ${fullSmsBody ?? ""}');
      }

      if (finalDesc != transaction.description.trim() || finalCategory != transaction.category) {
        return transaction.copy(
          description: finalDesc,
          category: finalCategory,
        );
      }
    } catch (e) {
      debugPrint('AI description refinement failed: $e');
    }

    return null;
  }

  /// Bulk refines unrefined SMS transactions created within a smart window (start of today or since last sync, max 24 hours).
  /// Returns the total count of successfully refined transactions.
  static Future<int> performBulkAiRefine({
    Duration? lookbackWindow,
    void Function(int processed, int total)? onProgress,
  }) async {
    final aiService = GeminiNanoService();
    if (!await aiService.isSupported()) return 0;

    final now = DateTime.now();
    // Default to scanning the full 24-hour window so background auto-fetched transactions
    // that arrived earlier in the day or overnight are comprehensively refined.
    final cutoff = now.subtract(lookbackWindow ?? const Duration(hours: 24));

    final allTransactions = await TransactionRepository.instance.readAllTransactions();
    final candidates = allTransactions.where((t) {
      return t.deletedAt == null &&
          t.smsId != null &&
          !t.isAiRefined &&
          (t.date.isAfter(cutoff) || t.date.isAtSameMomentAs(cutoff));
    }).toList();

    if (candidates.isEmpty) return 0;

    int refinedCount = 0;
    int processedCount = 0;
    onProgress?.call(0, candidates.length);

    for (final t in candidates) {
      processedCount++;
      final refined = await refineSingleTransactionWithAi(t);
      if (refined != null) {
        final updated = refined.copy(isAiRefined: true);
        await TransactionRepository.instance.updateTransaction(updated);
        refinedCount++;
      } else {
        // Even if description wasn't altered, mark as AI checked so we don't repeat
        await TransactionRepository.instance.updateTransaction(t.copy(isAiRefined: true));
      }
      onProgress?.call(processedCount, candidates.length);
    }

    return refinedCount;
  }
}

@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Setup SharedPreferences and database config for the isolate
    await SmsService.reloadSmsContacts();
    await TransactionCategory.reload();

    final contacts = await TransactionRepository.instance.getAllSmsContacts();
    final allowed = <String>{};
    final blocked = <String>{};
    for (final c in contacts) {
      if (c.isBlocked) {
        blocked.addAll(c.senderIds.map((s) => s.toLowerCase()));
      } else {
        allowed.addAll(c.senderIds.map((s) => s.toLowerCase()));
      }
    }

    final transaction = await SmsService._parseWithAiFallback(
      body: message.body ?? '',
      address: message.address ?? '',
      messageId: message.id,
      messageDate: message.date,
      allowedSenderIds: allowed,
      blockedSenderIds: blocked,
      customExpenseRules: SmsService._customExpenseRules,
      customIncomeRules: SmsService._customIncomeRules,
      customSmsRules: SmsService._customSmsRules,
    );
    if (transaction != null) {
      if (await TransactionRepository.instance.hasCrossSenderDuplicate(transaction.amount, transaction.date)) {
        return;
      }
      final inserted = await TransactionRepository.instance.createSmsTransaction(transaction);
      if (inserted != null) {
        if (transaction.category == SmsConstants.reversalSentinel) {
          final target = await TransactionRepository.instance.findReversalTarget(transaction.amount, transaction.date);
          if (target != null) {
            await TransactionRepository.instance.deleteTransaction(target.id!);
          }
          await TransactionRepository.instance.deleteTransaction(inserted.id!);
        } else {
          await NotificationService.showNotification(
            id: inserted.id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
            title: inserted.isExpense ? '💳 Expense Auto-Imported' : '💰 Income Auto-Imported',
            body: '${inserted.isExpense ? "Spent" : "Received"} ${inserted.amount.toStringAsFixed(0)} • ${inserted.description}',
          );
        }
      }
    }
  } catch (e) {
    debugPrint('backgroundMessageHandler error: $e');
  }
}
