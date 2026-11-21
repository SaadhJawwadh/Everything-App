import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'period_prediction_service.dart';
import '../data/repositories/recurring_rule_repository.dart';
import '../features/finances/data/transaction_repository.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../features/notes/data/note_repository.dart';
import 'package:note_taking_app/features/notes/presentation/screens/note_editor_screen.dart';
import '../utils/app_globals.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'period_tracker_channel';
  static const String channelName = 'Period Tracker Alerts';
  static const String channelDescription =
      'Notifications for upcoming and late periods';

  static Future<void> initialize({bool isBackgroundIsolate = false}) async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');

    // For iOS
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) =>
          _handleNotificationTap(response.payload),
    );

    if (!isBackgroundIsolate) {
      // Cold start: the app may have been launched by tapping a notification.
      // Defer handling until the navigator exists (first frame + a beat).
      final launchDetails =
          await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        final payload = launchDetails!.notificationResponse?.payload;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 600),
              () => _handleNotificationTap(payload));
        });
      }
    }
  }

  /// Routes notification taps (`note:`, `period_tracker`, `finance:*`) to the right destination.
  static Future<void> _handleNotificationTap(String? payload) async {
    if (payload == null) return;
    if (payload == 'period_tracker') {
      appTabNavigationRequest.value = 'health';
      return;
    }
    if (payload == 'finance:budgets' || payload == 'finance:ledger') {
      appTabNavigationRequest.value = 'finances';
      return;
    }
    if (!payload.startsWith('note:')) return;
    final noteId = payload.substring(5);
    try {
      final note = await NoteRepository.instance.readNote(noteId);
      if (note == null) return;
      await appNavigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
      );
    } catch (e) {
      debugPrint('Error opening note from notification: $e');
    }
  }

  static Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();
  }

  /// Schedules notifications for the upcoming period based on prediction logic.
  static Future<void> schedulePeriodNotifications() async {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    try {
      // 1. Cancel existing period notifications first (ids 1-3 only — a blanket
      // cancelAll() would also wipe scheduled note reminders).
      await _notificationsPlugin.cancel(1);
      await _notificationsPlugin.cancel(2);
      await _notificationsPlugin.cancel(3);

      // 2. Check if feature is enabled
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('isPeriodTrackerEnabled') ?? false;
      if (!isEnabled) return;

      // 3. Get prediction
      final nextPeriodDate = await PeriodPredictionService.estimateNextPeriod();
      if (nextPeriodDate == null) return; // No logs yet

      // 4. Get notification text setting
      final discreetText =
          prefs.getString('discreetNotificationText') ?? 'Check the app';

      final now = DateTime.now();

      // Schedule: 2 Days before
      final twoDaysBefore = nextPeriodDate.subtract(const Duration(days: 2));
      if (twoDaysBefore.isAfter(now)) {
        await _scheduleNotification(
          id: 1,
          title: 'Reminder',
          body: discreetText,
          scheduledDate: _normalizeTime(twoDaysBefore),
        );
      }

      // Schedule: 1 Day before
      final oneDayBefore = nextPeriodDate.subtract(const Duration(days: 1));
      if (oneDayBefore.isAfter(now)) {
        await _scheduleNotification(
          id: 2,
          title: 'Reminder',
          body: discreetText,
          scheduledDate: _normalizeTime(oneDayBefore),
        );
      }

      // Schedule: 1 Day late
      final oneDayLate = nextPeriodDate.add(const Duration(days: 1));
      if (oneDayLate.isAfter(now)) {
        await _scheduleNotification(
          id: 3,
          title: 'Reminder',
          body: discreetText,
          scheduledDate: _normalizeTime(oneDayLate),
        );
      }
    } catch (e) {
      debugPrint('Error scheduling period notifications: $e');
    }
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('launcher_icon'),
    );
    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
      macOS: darwinPlatformChannelSpecifics,
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'period_tracker',
    );
  }

  /// Helper to set the notification time to 9:00 AM on the target date.
  static DateTime _normalizeTime(DateTime date) {
    return DateTime(date.year, date.month, date.day, 9, 0);
  }

  /// Stable notification id for a note's reminder, namespaced into a high
  /// range so it can never collide with period (1-3) or sync notifications.
  static int noteReminderId(String noteId) =>
      0x4E000000 | (noteId.hashCode & 0x00FFFFFF);

  /// Schedules (or reschedules) the reminder for a note. Clears any previous
  /// one first; does nothing if [when] is in the past.
  static Future<void> scheduleNoteReminder({
    required String noteId,
    required String noteTitle,
    required DateTime when,
  }) async {
    await cancelNoteReminder(noteId);
    if (!when.isAfter(DateTime.now())) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'note_reminder_channel',
      'Note Reminders',
      channelDescription: 'Reminders you set on individual notes',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('launcher_icon'),
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        noteReminderId(noteId),
        'Note reminder',
        noteTitle.trim().isEmpty ? 'You have a note to revisit' : noteTitle.trim(),
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'note:$noteId',
      );
    } catch (_) {
      // Plugin unavailable (tests / unsupported platform) — reminder is
      // still persisted on the note and reschedules on next edit.
    }
  }

  static Future<void> cancelNoteReminder(String noteId) async {
    try {
      await _notificationsPlugin.cancel(noteReminderId(noteId));
    } catch (_) {
      // Plugin unavailable (tests / unsupported platform).
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'daily_sync_channel',
      'Daily Sync Alerts',
      channelDescription: 'Notifications for daily transaction synchronization results',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('launcher_icon'),
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  static Future<void> showBackupNotification({
    required String title,
    required String body,
    int id = 102,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'auto_backup_channel',
      'Auto-Backup Alerts',
      channelDescription: 'Notifications when automatic backups are completed',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: 'ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('launcher_icon'),
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('Error showing auto-backup notification: $e');
    }
  }

  static Future<void> showTestNotification() async {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'system_channel',
      'System & Diagnostics',
      channelDescription: 'Diagnostics and test notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('launcher_icon'),
    );
    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _notificationsPlugin.show(
        0x54455354, // 'TEST'
        '🔔 Notifications Active',
        'Test notification delivered successfully! All alerts and channels are configured properly.',
        platformDetails,
      );
    } catch (e) {
      debugPrint('Error showing test notification: $e');
    }
  }

  static Future<void> showAutoPurgeNotification(int count, int days) async {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'trash_cleanup_channel',
      'Trash & Auto-Purge',
      channelDescription: 'Notifications for automated trash retention cleanup',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: 'ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('launcher_icon'),
    );
    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _notificationsPlugin.show(
        0x50555247, // 'PURG'
        '🗑️ Trash Cleaned',
        'Automatically purged $count note${count == 1 ? '' : 's'} older than $days days.',
        platformDetails,
      );
    } catch (e) {
      debugPrint('Error showing auto-purge notification: $e');
    }
  }

  static const int kProTipNotificationId = 0x544950; // 'TIP'

  static Future<void> schedulePeriodicTips() async {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    try {
      await _notificationsPlugin.cancel(kProTipNotificationId);

      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('showProTips') ?? true;
      if (!isEnabled) return;

      final tipCatalog = [
        'Zero-Cloud Sync: Pair phones & tablets over local Wi-Fi to sync your notes and finances.',
        'SMS Bank Ledger: Enable auto-sync to turn incoming bank SMS alerts into financial transactions.',
        'Split-Axis Steppers: Use directional toolbars in the note editor for rapid cursor navigation.',
        'Recurring Payments: Turn any transaction into a recurring rule to automate bills.',
        'Daily Safe-to-Spend: Assign category limits to unlock real-time monthly spending forecasts.',
        'Biometric Privacy: Protect notes and financial records behind PIN and biometric App Lock.',
        'Discreet Health Alerts: Offline period predictions with customizable discreet notifications.',
      ];

      final tipIndex = (prefs.getInt('currentTipIndex') ?? 0) % tipCatalog.length;
      final tipBody = tipCatalog[tipIndex];

      final targetDate = DateTime.now().add(const Duration(days: 3));
      final scheduledTime = DateTime(targetDate.year, targetDate.month, targetDate.day, 10, 30);

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'pro_tips_channel',
        'Notebook Pro-Tips',
        channelDescription: 'Actionable tips and powerup suggestions',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: 'ic_notification',
        largeIcon: DrawableResourceAndroidBitmap('launcher_icon'),
      );
      const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.zonedSchedule(
        kProTipNotificationId,
        '💡 Everything App Pro-Tip',
        tipBody,
        tz.TZDateTime.from(scheduledTime, tz.local),
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Error scheduling periodic tip notification: $e');
    }
  }

  static Future<void> cancelPeriodicTips() async {
    try {
      await _notificationsPlugin.cancel(kProTipNotificationId);
    } catch (_) {}
  }

  /// Deterministic 24-bit FNV-1a hash (stable across isolates & restarts).
  static int fnv1a24(String input) {
    int hash = 0x811c9dc5;
    for (final byte in utf8.encode(input)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x00FFFFFF;
  }

  static int budgetNotificationId(String category, int threshold) =>
      0x46000000 | fnv1a24('${category.trim().toLowerCase()}:$threshold');

  static int billNotificationId(String ruleId) =>
      0x47000000 | fnv1a24(ruleId);

  static String isoWeekKey(DateTime date) {
    final dayOfYear = int.parse(
      '${date.difference(DateTime(date.year, 1, 1)).inDays + 1}',
    );
    final woy = ((dayOfYear - date.weekday + 10) ~/ 7).clamp(1, 53);
    return '${date.year}-W${woy.toString().padLeft(2, '0')}';
  }

  /// Fires an 80% or 100% category budget threshold alert (deduped once per
  /// category/threshold/month) after a new expense is logged.
  static Future<void> checkBudgetThresholdsForCategory(String category) async {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('showFinancialManager') ?? false)) return;
      if (!(prefs.getBool('budgetAlertsEnabled') ?? true)) return;

      final budgetsRaw = prefs.getString('categoryBudgets');
      if (budgetsRaw == null || budgetsRaw.isEmpty) return;
      final budgetsMap = jsonDecode(budgetsRaw) as Map<String, dynamic>;
      final limit = (budgetsMap[category] as num?)?.toDouble();
      if (limit == null || limit <= 0) return;

      final now = DateTime.now();
      final allTxs = await TransactionRepository.instance.readAllTransactions();
      final monthSpend = allTxs
          .where((t) =>
              t.deletedAt == null &&
              t.isExpense &&
              !t.isTransfer &&
              t.category == category &&
              t.date.year == now.year &&
              t.date.month == now.month)
          .fold<double>(0.0, (sum, t) => sum + t.amount);

      final pct = (monthSpend / limit) * 100.0;
      final threshold = pct >= 100.0 ? 100 : (pct >= 80.0 ? 80 : 0);
      if (threshold == 0) return;

      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final dedupKey = 'budget_alert_${monthKey}_${category.toLowerCase()}_$threshold';
      if (prefs.getBool(dedupKey) ?? false) return;

      await prefs.setBool(dedupKey, true);
      final currency = prefs.getString('currency') ?? 'LKR';
      await _notificationsPlugin.show(
        budgetNotificationId(category, threshold),
        threshold == 100
            ? '$category Budget Reached (100%)'
            : '$category Budget at ${pct.round()}%',
        'Spent $currency ${monthSpend.toStringAsFixed(0)} of $currency ${limit.toStringAsFixed(0)} this month.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'finance_budget_alerts_channel',
            'Budget Alerts',
            channelDescription: 'Warnings when monthly category budgets reach 80% or 100%',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_notification',
            largeIcon: DrawableResourceAndroidBitmap('launcher_icon'),
          ),
        ),
        payload: 'finance:budgets',
      );
    } catch (e) {
      debugPrint('[NotificationService] checkBudgetThresholdsForCategory error: $e');
    }
  }

  /// Checks 48h upcoming recurring bills and optional Sunday Weekly Spend Digest.
  static Future<void> checkUpcomingBillsAndDigest() async {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('showFinancialManager') ?? false)) return;
      final currency = prefs.getString('currency') ?? 'LKR';
      final now = DateTime.now();

      if (prefs.getBool('billRemindersEnabled') ?? true) {
        final rules = await RecurringRuleRepository.instance.readAllRules();
        final horizon = now.add(const Duration(hours: 48));
        for (final rule in rules) {
          if (!rule.isExpense) continue;
          if (rule.nextDue.isAfter(now) && !rule.nextDue.isAfter(horizon)) {
            final dueIso = rule.nextDue.toIso8601String().split('T').first;
            final dedupKey = 'bill_alert_${rule.id}_$dueIso';
            if (prefs.getBool(dedupKey) ?? false) continue;
            await prefs.setBool(dedupKey, true);
            await _notificationsPlugin.show(
              billNotificationId(rule.id),
              'Upcoming Bill: ${rule.description}',
              'Due $dueIso • $currency ${rule.amount.toStringAsFixed(0)} (${rule.category})',
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'finance_bill_reminders_channel',
                  'Bill Reminders',
                  channelDescription: 'Reminders 48 hours before recurring bills are due',
                  importance: Importance.defaultImportance,
                  priority: Priority.defaultPriority,
                  icon: 'ic_notification',
                  largeIcon: DrawableResourceAndroidBitmap('launcher_icon'),
                ),
              ),
              payload: 'finance:ledger',
            );
          }
        }
      }

      if ((prefs.getBool('weeklyDigestEnabled') ?? false) && now.weekday == DateTime.sunday) {
        final weekKey = isoWeekKey(now);
        final dedupKey = 'weekly_digest_$weekKey';
        if (!(prefs.getBool(dedupKey) ?? false)) {
          await prefs.setBool(dedupKey, true);
          final weekAgo = now.subtract(const Duration(days: 7));
          final allTxs = await TransactionRepository.instance.readAllTransactions();
          double weekExpense = 0;
          double weekIncome = 0;
          for (final t in allTxs) {
            if (t.deletedAt != null || t.isTransfer || t.date.isBefore(weekAgo)) continue;
            if (t.isExpense) {
              weekExpense += t.amount;
            } else {
              weekIncome += t.amount;
            }
          }
          await _notificationsPlugin.show(
            0x48000001,
            'Weekly Spend Digest ($weekKey)',
            'Spent $currency ${weekExpense.toStringAsFixed(0)} • Income $currency ${weekIncome.toStringAsFixed(0)} over the last 7 days.',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'finance_weekly_digest_channel',
                'Weekly Spend Digest',
                channelDescription: 'Optional Sunday summary of weekly cash flow',
                importance: Importance.defaultImportance,
                priority: Priority.defaultPriority,
                icon: 'ic_notification',
                largeIcon: DrawableResourceAndroidBitmap('launcher_icon'),
              ),
            ),
            payload: 'finance:ledger',
          );
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] checkUpcomingBillsAndDigest error: $e');
    }
  }
}
