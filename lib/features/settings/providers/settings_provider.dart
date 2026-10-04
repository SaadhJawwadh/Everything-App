import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/notification_service.dart';
import '../../../services/local_ai_service.dart';
import '../../../services/sms_service.dart';
import '../../../services/backup_service.dart';
import '../../../screens/app_lock_screen.dart';
import '../../../utils/widget_helper.dart';
import '../../../data/custom_sms_rule.dart';
import '../../../data/transaction_model.dart';
import '../../../utils/app_constants.dart';
import '../../../core/services/app_haptics.dart';
import 'dart:convert';

enum NoteViewMode { list, grid }

class SettingsProvider extends ChangeNotifier {
  double _textSize = 16.0;
  ThemeMode _themeMode = ThemeMode.system;

  double get textSize => _textSize;
  ThemeMode get themeMode => _themeMode;

  String get textSizeLabel {
    if (_textSize == 14.0) return 'Small';
    if (_textSize == 20.0) return 'Large';
    return 'Medium';
  }

  bool _useDynamicColor = true;
  bool get useDynamicColor => _useDynamicColor;

  NoteViewMode _noteViewMode = NoteViewMode.grid;

  NoteViewMode get noteViewMode => _noteViewMode;
  
  bool get isGridView => _noteViewMode == NoteViewMode.grid;

  bool _enableHaptics = true;
  bool get enableHaptics => _enableHaptics;

  bool _moveCompletedChecklistsToBottom = false;
  bool get moveCompletedChecklistsToBottom => _moveCompletedChecklistsToBottom;

  bool _showMilestoneDelight = true;
  bool get showMilestoneDelight => _showMilestoneDelight;

  bool _showClarityMosaic = true;
  bool get showClarityMosaic => _showClarityMosaic;

  bool _showTagFilterBar = true;
  bool get showTagFilterBar => _showTagFilterBar;

  bool _minimalEditorMode = false;
  bool get minimalEditorMode => _minimalEditorMode;

  bool _showFinancialManager = false;
  bool get showFinancialManager => _showFinancialManager;

  bool _showSplitBills = false;
  bool get showSplitBills => _showSplitBills;

  bool _enableSavingsVault = true;
  bool get enableSavingsVault => _enableSavingsVault;

  bool _enableSmsImport = true;
  bool get enableSmsImport => _enableSmsImport;

  bool _enableBudgetsAndAnalytics = true;
  bool get enableBudgetsAndAnalytics => _enableBudgetsAndAnalytics;

  bool _enableRecurringRules = true;
  bool get enableRecurringRules => _enableRecurringRules;

  String _account1Name = 'Daily';
  String get account1Name => _account1Name;

  String _account2Name = 'Savings';
  String get account2Name => _account2Name;

  Map<String, String> _categoryAccountRouting = {};
  Map<String, String> get categoryAccountRouting => Map.unmodifiable(_categoryAccountRouting);

  String getAccountDisplayName(String accountKey) {
    if (accountKey == 'savings' || accountKey == AccountType.savings) {
      return _account2Name;
    }
    return _account1Name;
  }

  String _defaultPaymentInfo = '';
  String get defaultPaymentInfo => _defaultPaymentInfo;

  String _currency = 'LKR';
  String get currency => _currency;
  String get currencySymbol => AppConstants.getCurrencyInfo(_currency).symbol;

  bool _autoBackupEnabled = false;
  bool get autoBackupEnabled => _autoBackupEnabled;

  String _autoBackupFrequency = 'daily';
  String get autoBackupFrequency => _autoBackupFrequency;

  String? _autoBackupPath;
  String? get autoBackupPath => _autoBackupPath;

  String? _lastAutoBackupTime;
  String? get lastAutoBackupTime => _lastAutoBackupTime;

  bool _isPeriodTrackerEnabled = false;
  bool get isPeriodTrackerEnabled => _isPeriodTrackerEnabled;

  bool _isDiscreetHealthMode = false;
  bool get isDiscreetHealthMode => _isDiscreetHealthMode;

  bool _appLockEnabled = false;
  bool get appLockEnabled => _appLockEnabled;

  bool _useBiometrics = false;
  bool get useBiometrics => _useBiometrics;

  int _appLockTimeout = 0;
  int get appLockTimeout => _appLockTimeout;

  String _discreetNotificationText = 'Check the app';
  String get discreetNotificationText => _discreetNotificationText;

  List<String> _customExpenseRules = [];
  List<String> get customExpenseRules => _customExpenseRules;

  List<String> _customIncomeRules = [];
  List<String> get customIncomeRules => _customIncomeRules;

  List<CustomSmsRule> _customSmsRules = [];
  List<CustomSmsRule> get customSmsRules => _customSmsRules;
  List<CustomSmsRule> get activeCustomSmsRules => _customSmsRules.where((r) => r.isEnabled).toList();

  bool _useOnDeviceAi = false;
  bool get useOnDeviceAi => _useOnDeviceAi;

  bool _isDeviceAiSupported = false;
  bool get isDeviceAiSupported => _isDeviceAiSupported;

  /// True ONLY when the device hardware supports AI (Gemini Nano / AICore) AND the user has enabled it in settings.
  bool get isAiActive => _useOnDeviceAi && _isDeviceAiSupported;

  String? _selectedLanguageCode;
  String get selectedLanguageCode => _selectedLanguageCode ?? 'system';
  Locale? get currentLocale {
    if (_selectedLanguageCode == null ||
        _selectedLanguageCode!.isEmpty ||
        _selectedLanguageCode == 'system') {
      return null;
    }
    return Locale(_selectedLanguageCode!);
  }

  bool _hasSeenOnboarding = false;
  bool get hasSeenOnboarding => _hasSeenOnboarding;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _dailySyncEnabled = false;
  bool get dailySyncEnabled => _dailySyncEnabled;

  String _dailySyncTime = '20:00';
  String get dailySyncTime => _dailySyncTime;

  String _smsSyncFrequency = '12';
  String get smsSyncFrequency => _smsSyncFrequency;

  String _lastSeenVersion = '';
  String get lastSeenVersion => _lastSeenVersion;

  Map<String, double> _categoryBudgets = {};
  Map<String, double> get categoryBudgets => _categoryBudgets;

  int _trashAutoPurgeDays = 30;
  int get trashAutoPurgeDays => _trashAutoPurgeDays;

  bool _showProTips = true;
  bool get showProTips => _showProTips;

  int _lastTipDismissedTimestamp = 0;
  int get lastTipDismissedTimestamp => _lastTipDismissedTimestamp;

  int _currentTipIndex = 0;
  int get currentTipIndex => _currentTipIndex;

  bool get isTipDue {
    if (!_showProTips) return false;
    if (_lastTipDismissedTimestamp == 0) return true;
    final lastDate =
        DateTime.fromMillisecondsSinceEpoch(_lastTipDismissedTimestamp);
    final diff = DateTime.now().difference(lastDate);
    return diff.inHours >= 72; // 3 days
  }

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _textSize = prefs.getDouble('textSize') ?? 16.0;
    final viewModeIndex = prefs.getInt('noteViewMode');
    if (viewModeIndex != null) {
      if (viewModeIndex >= 0 && viewModeIndex < NoteViewMode.values.length) {
        _noteViewMode = NoteViewMode.values[viewModeIndex];
      } else if (viewModeIndex == 2) {
        _noteViewMode = NoteViewMode.grid;
      } else {
        _noteViewMode = NoteViewMode.grid;
      }
    } else {
      final legacyGrid = prefs.getBool('isGridView') ?? true;
      _noteViewMode = legacyGrid ? NoteViewMode.grid : NoteViewMode.list;
    }
    _showFinancialManager = prefs.getBool('showFinancialManager') ?? false;
    _showSplitBills = prefs.getBool('showSplitBills') ?? false;
    _enableSavingsVault = prefs.getBool('enableSavingsVault') ?? true;
    _enableSmsImport = prefs.getBool('enableSmsImport') ?? true;
    _enableBudgetsAndAnalytics = prefs.getBool('enableBudgetsAndAnalytics') ?? true;
    _enableRecurringRules = prefs.getBool('enableRecurringRules') ?? true;
    _showTagFilterBar = prefs.getBool('showTagFilterBar') ?? true;
    _minimalEditorMode = prefs.getBool('minimalEditorMode') ?? false;
    _account1Name = prefs.getString('account1Name') ?? 'Daily';
    _account2Name = prefs.getString('account2Name') ?? 'Savings';
    final routingStr = prefs.getString('categoryAccountRouting');
    if (routingStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(routingStr);
        _categoryAccountRouting = decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {}
    }
    _defaultPaymentInfo = prefs.getString('defaultPaymentInfo') ?? '';
    _currency = prefs.getString('currency') ?? 'LKR';
    _selectedLanguageCode = prefs.getString('selectedLanguageCode');

    _autoBackupEnabled = prefs.getBool('autoBackupEnabled') ?? false;
    _autoBackupFrequency = prefs.getString('autoBackupFrequency') ?? 'daily';
    _autoBackupPath = prefs.getString('autoBackupPath');
    _lastAutoBackupTime = prefs.getString('lastAutoBackupTime');

    _isPeriodTrackerEnabled = prefs.getBool('isPeriodTrackerEnabled') ?? false;
    _isDiscreetHealthMode = prefs.getBool('isDiscreetHealthMode') ?? false;
    _appLockEnabled = prefs.getBool('appLockEnabled') ?? false;
    _useBiometrics = prefs.getBool('useBiometrics') ?? false;
    _appLockTimeout = prefs.getInt('appLockTimeout') ?? 0;
    _discreetNotificationText =
        prefs.getString('discreetNotificationText') ?? 'Check the app';

    _customExpenseRules = prefs.getStringList('customExpenseRules') ?? [];
    _customIncomeRules = prefs.getStringList('customIncomeRules') ?? [];

    final storedCustomSmsRules = prefs.getStringList('customSmsRules_v2');
    if (storedCustomSmsRules != null && storedCustomSmsRules.isNotEmpty) {
      _customSmsRules = storedCustomSmsRules
          .map((s) {
            try {
              return CustomSmsRule.fromJson(s);
            } catch (_) {
              return null;
            }
          })
          .whereType<CustomSmsRule>()
          .toList();
    } else {
      _customSmsRules = [];
      for (final r in _customExpenseRules) {
        if (r.trim().isNotEmpty) {
          _customSmsRules.add(CustomSmsRule(
            id: 'exp_${r.hashCode}_${DateTime.now().millisecondsSinceEpoch}',
            keyword: r.trim(),
            type: RuleTransactionType.expense,
            createdAt: DateTime.now(),
          ));
        }
      }
      for (final r in _customIncomeRules) {
        if (r.trim().isNotEmpty) {
          _customSmsRules.add(CustomSmsRule(
            id: 'inc_${r.hashCode}_${DateTime.now().millisecondsSinceEpoch}',
            keyword: r.trim(),
            type: RuleTransactionType.income,
            createdAt: DateTime.now(),
          ));
        }
      }
      if (_customSmsRules.isNotEmpty) {
        await _persistCustomSmsRules(prefs);
      }
    }

    _useOnDeviceAi = prefs.getBool('useOnDeviceAi') ?? false;
    _useDynamicColor = prefs.getBool('useDynamicColor') ?? true;
    _dailySyncEnabled = prefs.getBool('dailySyncEnabled') ?? false;
    _dailySyncTime = prefs.getString('dailySyncTime') ?? '20:00';
    _smsSyncFrequency = prefs.getString('smsSyncFrequency') ?? '12';
    _lastSeenVersion = prefs.getString('lastSeenVersion') ?? '';
    _trashAutoPurgeDays = prefs.getInt('trashAutoPurgeDays') ?? 30;
    _moveCompletedChecklistsToBottom = prefs.getBool('moveCompletedChecklistsToBottom') ?? false;
    _showMilestoneDelight = prefs.getBool('showMilestoneDelight') ?? true;
    _showClarityMosaic = prefs.getBool('showClarityMosaic') ?? true;

    _showProTips = prefs.getBool('showProTips') ?? true;
    _lastTipDismissedTimestamp = prefs.getInt('lastTipDismissedTimestamp') ?? 0;
    _currentTipIndex = prefs.getInt('currentTipIndex') ?? 0;

    _enableHaptics = prefs.getBool('enableHaptics') ?? true;
    AppHaptics.isEnabled = _enableHaptics;

    final budgetsStr = prefs.getString('categoryBudgets');
    if (budgetsStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(budgetsStr);
        _categoryBudgets = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
      } catch (_) {}
    }

    _hasSeenOnboarding = prefs.getBool('hasSeenOnboarding_v1') ?? false;

    final themeIndex = prefs.getInt('themeMode') ?? 0;
    _themeMode = _getThemeModeFromInt(themeIndex);

    _isInitialized = true;
    notifyListeners();

    if (_autoBackupEnabled) {
      await syncAutoBackupSchedule();
    }
    if (_dailySyncEnabled) {
      await SmsService.syncDailySyncSchedule();
    }
    if (_isPeriodTrackerEnabled && !kIsWeb) {
      await NotificationService.schedulePeriodNotifications();
    }
    if (_showProTips && !kIsWeb) {
      await NotificationService.schedulePeriodicTips();
    }
  }

  Future<void> setHasSeenOnboarding(bool seen) async {
    _hasSeenOnboarding = seen;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding_v1', seen);
    notifyListeners();
  }

  Future<void> setEnableHaptics(bool value) async {
    _enableHaptics = value;
    AppHaptics.isEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableHaptics', value);
    notifyListeners();
  }

  Future<void> setLastSeenVersion(String version) async {
    _lastSeenVersion = version;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastSeenVersion', version);
    notifyListeners();
  }

  Future<void> setCurrency(String curr) async {
    _currency = curr;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', curr);
    notifyListeners();
  }

  Future<void> setSelectedLanguage(String code) async {
    final clean = code.trim();
    if (clean.isEmpty || clean == 'system') {
      _selectedLanguageCode = null;
    } else {
      _selectedLanguageCode = clean;
    }
    final prefs = await SharedPreferences.getInstance();
    if (_selectedLanguageCode == null) {
      await prefs.remove('selectedLanguageCode');
    } else {
      await prefs.setString('selectedLanguageCode', _selectedLanguageCode!);
    }
    notifyListeners();
  }

  Future<void> setTrashAutoPurgeDays(int days) async {
    _trashAutoPurgeDays = days;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('trashAutoPurgeDays', days);
    notifyListeners();
  }

  Future<void> setMoveCompletedChecklistsToBottom(bool value) async {
    _moveCompletedChecklistsToBottom = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('moveCompletedChecklistsToBottom', value);
    notifyListeners();
  }

  Future<void> setShowMilestoneDelight(bool value) async {
    _showMilestoneDelight = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showMilestoneDelight', value);
    notifyListeners();
  }

  Future<void> setShowClarityMosaic(bool value) async {
    _showClarityMosaic = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showClarityMosaic', value);
    notifyListeners();
  }

  Future<void> _persistCustomSmsRules(SharedPreferences prefs) async {
    final list = _customSmsRules.map((r) => r.toJson()).toList();
    await prefs.setStringList('customSmsRules_v2', list);
    _customExpenseRules = _customSmsRules
        .where((r) => r.isEnabled && r.type == RuleTransactionType.expense)
        .map((r) => r.keyword)
        .toList();
    _customIncomeRules = _customSmsRules
        .where((r) => r.isEnabled && r.type == RuleTransactionType.income)
        .map((r) => r.keyword)
        .toList();
    await prefs.setStringList('customExpenseRules', _customExpenseRules);
    await prefs.setStringList('customIncomeRules', _customIncomeRules);
  }

  Future<void> saveCustomSmsRule(CustomSmsRule rule) async {
    final prefs = await SharedPreferences.getInstance();
    final index = _customSmsRules.indexWhere((r) => r.id == rule.id);
    if (index >= 0) {
      _customSmsRules[index] = rule;
    } else {
      _customSmsRules.insert(0, rule);
    }
    await _persistCustomSmsRules(prefs);
    notifyListeners();
  }

  Future<void> deleteCustomSmsRule(String id) async {
    final prefs = await SharedPreferences.getInstance();
    _customSmsRules.removeWhere((r) => r.id == id);
    await _persistCustomSmsRules(prefs);
    notifyListeners();
  }

  Future<void> toggleCustomSmsRule(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final index = _customSmsRules.indexWhere((r) => r.id == id);
    if (index >= 0) {
      final current = _customSmsRules[index];
      _customSmsRules[index] = current.copyWith(isEnabled: !current.isEnabled);
      await _persistCustomSmsRules(prefs);
      notifyListeners();
    }
  }

  Future<void> restoreCustomSmsRule(CustomSmsRule rule) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_customSmsRules.any((r) => r.id == rule.id)) {
      _customSmsRules.insert(0, rule);
      await _persistCustomSmsRules(prefs);
      notifyListeners();
    }
  }

  Future<void> addCustomRule(String rule, {required bool isExpense}) async {
    final clean = rule.trim();
    if (clean.isEmpty) return;
    final newRule = CustomSmsRule(
      id: '${isExpense ? "exp" : "inc"}_${clean.hashCode}_${DateTime.now().millisecondsSinceEpoch}',
      keyword: clean,
      type: isExpense ? RuleTransactionType.expense : RuleTransactionType.income,
      createdAt: DateTime.now(),
    );
    await saveCustomSmsRule(newRule);
  }

  Future<void> clearCustomRules() async {
    _customSmsRules = [];
    _customExpenseRules = [];
    _customIncomeRules = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('customSmsRules_v2', []);
    await prefs.setStringList('customExpenseRules', []);
    await prefs.setStringList('customIncomeRules', []);
    notifyListeners();
  }

  Future<void> removeCustomRule(String rule, {required bool isExpense}) async {
    final targetType = isExpense ? RuleTransactionType.expense : RuleTransactionType.income;
    final match = _customSmsRules.firstWhere(
      (r) => r.keyword.toLowerCase() == rule.trim().toLowerCase() && r.type == targetType,
      orElse: () => _customSmsRules.firstWhere((r) => r.keyword == rule, orElse: () => CustomSmsRule(id: '', keyword: '', type: targetType, createdAt: DateTime.now())),
    );
    if (match.id.isNotEmpty) {
      await deleteCustomSmsRule(match.id);
    }
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    _autoBackupEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoBackupEnabled', enabled);
    notifyListeners();
    await syncAutoBackupSchedule();
  }

  Future<void> setAutoBackupFrequency(String freq) async {
    _autoBackupFrequency = freq;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('autoBackupFrequency', freq);
    notifyListeners();
    await syncAutoBackupSchedule(existingWorkPolicy: ExistingPeriodicWorkPolicy.replace);
  }

  Future<void> setAutoBackupPath(String? path) async {
    _autoBackupPath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString('autoBackupPath', path);
    } else {
      await prefs.remove('autoBackupPath');
    }
    notifyListeners();
    await syncAutoBackupSchedule(existingWorkPolicy: ExistingPeriodicWorkPolicy.replace);
  }

  Future<void> setLastAutoBackupTime(String? time) async {
    _lastAutoBackupTime = time;
    final prefs = await SharedPreferences.getInstance();
    if (time != null) {
      await prefs.setString('lastAutoBackupTime', time);
    } else {
      await prefs.remove('lastAutoBackupTime');
    }
    notifyListeners();
  }

  void updateLastAutoBackupTime(DateTime? time) {
    if (time != null) {
      _lastAutoBackupTime = time.toIso8601String();
      notifyListeners();
    }
  }

  Future<void> setTextSize(double size) async {
    _textSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('textSize', size);
    notifyListeners();
  }

  Future<void> setNoteViewMode(NoteViewMode mode) async {
    _noteViewMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('noteViewMode', mode.index);
    notifyListeners();
  }

  Future<void> setIsGridView(bool isGrid) async {
    await setNoteViewMode(isGrid ? NoteViewMode.grid : NoteViewMode.list);
  }

  Future<void> setShowFinancialManager(bool show) async {
    _showFinancialManager = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showFinancialManager', show);
    notifyListeners();
  }

  Future<void> setShowSplitBills(bool show) async {
    _showSplitBills = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showSplitBills', show);
    notifyListeners();
  }

  Future<void> setEnableSavingsVault(bool enable) async {
    _enableSavingsVault = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableSavingsVault', enable);
    notifyListeners();
  }

  Future<void> setEnableSmsImport(bool enable) async {
    _enableSmsImport = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableSmsImport', enable);
    notifyListeners();
  }

  Future<void> setEnableBudgetsAndAnalytics(bool enable) async {
    _enableBudgetsAndAnalytics = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableBudgetsAndAnalytics', enable);
    notifyListeners();
  }

  Future<void> setEnableRecurringRules(bool enable) async {
    _enableRecurringRules = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableRecurringRules', enable);
    notifyListeners();
  }

  Future<void> setShowTagFilterBar(bool show) async {
    _showTagFilterBar = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showTagFilterBar', show);
    notifyListeners();
  }

  Future<void> setMinimalEditorMode(bool minimal) async {
    _minimalEditorMode = minimal;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('minimalEditorMode', minimal);
    notifyListeners();
  }

  Future<void> setAccount1Name(String name) async {
    final clean = name.trim().isEmpty ? 'Daily' : name.trim();
    _account1Name = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('account1Name', clean);
    notifyListeners();
  }

  Future<void> setAccount2Name(String name) async {
    final clean = name.trim().isEmpty ? 'Savings' : name.trim();
    _account2Name = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('account2Name', clean);
    notifyListeners();
  }

  Future<void> setCategoryAccountRouting(String category, String? accountKey) async {
    final updated = Map<String, String>.from(_categoryAccountRouting);
    if (accountKey == null || accountKey.isEmpty) {
      updated.remove(category);
    } else {
      updated[category] = accountKey;
    }
    _categoryAccountRouting = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('categoryAccountRouting', jsonEncode(updated));
    notifyListeners();
  }

  Future<void> setDefaultPaymentInfo(String info) async {
    _defaultPaymentInfo = info;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('defaultPaymentInfo', info);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', _getIntFromThemeMode(mode));
    notifyListeners();
    if (!kIsWeb) {
      unawaited(WidgetHelper.updateWidgetData());
      unawaited(WidgetHelper.updateTodoWidgetData());
    }
  }

  Future<void> setUseDynamicColor(bool value) async {
    _useDynamicColor = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useDynamicColor', value);
    notifyListeners();
    if (!kIsWeb) {
      unawaited(WidgetHelper.updateWidgetData());
      unawaited(WidgetHelper.updateTodoWidgetData());
    }
  }

  Future<void> setIsPeriodTrackerEnabled(bool enabled) async {
    _isPeriodTrackerEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPeriodTrackerEnabled', enabled);
    if (!kIsWeb) {
      if (enabled) {
        AppLockScreen.ignoreNextResumeLock();
        await NotificationService.requestPermissions();
      }
      await NotificationService.schedulePeriodNotifications();
    }
    notifyListeners();
  }

  Future<void> setIsDiscreetHealthMode(bool enabled) async {
    _isDiscreetHealthMode = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDiscreetHealthMode', enabled);
    notifyListeners();
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    _appLockEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('appLockEnabled', enabled);
    notifyListeners();
  }

  Future<void> setUseBiometrics(bool use) async {
    _useBiometrics = use;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useBiometrics', use);
    notifyListeners();
  }

  Future<void> setAppLockTimeout(int timeout) async {
    _appLockTimeout = timeout;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('appLockTimeout', timeout);
    notifyListeners();
  }

  Future<void> setDiscreetNotificationText(String text) async {
    _discreetNotificationText = text;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('discreetNotificationText', text);
    if (!kIsWeb) {
      await NotificationService.schedulePeriodNotifications();
    }
    notifyListeners();
  }

  Future<void> setDailySyncEnabled(bool enabled) async {
    _dailySyncEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dailySyncEnabled', enabled);
    notifyListeners();
    await SmsService.syncDailySyncSchedule();
  }

  Future<void> setDailySyncTime(String time) async {
    _dailySyncTime = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dailySyncTime', time);
    notifyListeners();
    await SmsService.syncDailySyncSchedule();
  }

  Future<void> setSmsSyncFrequency(String frequency) async {
    _smsSyncFrequency = frequency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('smsSyncFrequency', frequency);
    notifyListeners();
    await SmsService.syncDailySyncSchedule();
  }

  ThemeMode _getThemeModeFromInt(int value) {
    switch (value) {
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  int _getIntFromThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 1;
      case ThemeMode.dark:
        return 2;
      default:
        return 0;
    }
  }

  Map<String, dynamic> toBackupMap() => {
        'textSize': _textSize,
        'themeMode': _getIntFromThemeMode(_themeMode),
        'isGridView': isGridView,
        'noteViewMode': _noteViewMode.index,
        'showFinancialManager': _showFinancialManager,
        'showSplitBills': _showSplitBills,
        'enableSavingsVault': _enableSavingsVault,
        'account1Name': _account1Name,
        'account2Name': _account2Name,
        'categoryAccountRouting': _categoryAccountRouting,
        'defaultPaymentInfo': _defaultPaymentInfo,
        'trashAutoPurgeDays': _trashAutoPurgeDays,
        'currency': _currency,
        'selectedLanguageCode': _selectedLanguageCode,
        'isPeriodTrackerEnabled': _isPeriodTrackerEnabled,
        'isDiscreetHealthMode': _isDiscreetHealthMode,
        'appLockEnabled': _appLockEnabled,
        'useBiometrics': _useBiometrics,
        'appLockTimeout': _appLockTimeout,
        'discreetNotificationText': _discreetNotificationText,
        'customExpenseRules': _customExpenseRules,
        'customIncomeRules': _customIncomeRules,
        'useOnDeviceAi': _useOnDeviceAi,
        'useDynamicColor': _useDynamicColor,
        'dailySyncEnabled': _dailySyncEnabled,
        'dailySyncTime': _dailySyncTime,
        'smsSyncFrequency': _smsSyncFrequency,
        'showProTips': _showProTips,
        'moveCompletedChecklistsToBottom': _moveCompletedChecklistsToBottom,
        'enableSmsImport': _enableSmsImport,
        'enableBudgetsAndAnalytics': _enableBudgetsAndAnalytics,
        'enableRecurringRules': _enableRecurringRules,
        'showTagFilterBar': _showTagFilterBar,
        'minimalEditorMode': _minimalEditorMode,
      };

  Future<void> restoreFromBackupMap(Map<String, dynamic> map) async {
    try {
      if (map.containsKey('moveCompletedChecklistsToBottom')) {
        _moveCompletedChecklistsToBottom = map['moveCompletedChecklistsToBottom'] == true;
      }
      if (map.containsKey('textSize')) {
        final size = (map['textSize'] as num?)?.toDouble() ?? 16.0;
        if (size >= 8.0 && size <= 32.0) await setTextSize(size);
      }
      if (map.containsKey('themeMode')) {
        final idx = (map['themeMode'] as num?)?.toInt() ?? 0;
        await setThemeMode(_getThemeModeFromInt(idx));
      }
      if (map.containsKey('noteViewMode')) {
        final viewModeIdx = (map['noteViewMode'] as num?)?.toInt() ?? NoteViewMode.grid.index;
        if (viewModeIdx >= 0 && viewModeIdx < NoteViewMode.values.length) {
          await setNoteViewMode(NoteViewMode.values[viewModeIdx]);
        } else if (viewModeIdx == 2) {
          await setNoteViewMode(NoteViewMode.grid);
        }
      } else if (map.containsKey('isGridView')) {
        final grid = map['isGridView'];
        if (grid is bool) await setIsGridView(grid);
      }
      if (map.containsKey('showFinancialManager')) {
        final show = map['showFinancialManager'];
        if (show is bool) {
          await setShowFinancialManager(show);
        }
      }
      if (map.containsKey('showSplitBills')) {
        final val = map['showSplitBills'];
        if (val is bool) await setShowSplitBills(val);
      }
      if (map.containsKey('enableSavingsVault')) {
        final val = map['enableSavingsVault'];
        if (val is bool) await setEnableSavingsVault(val);
      }
      if (map.containsKey('account1Name')) {
        final val = map['account1Name'];
        if (val is String && val.trim().isNotEmpty) await setAccount1Name(val.trim());
      }
      if (map.containsKey('account2Name')) {
        final val = map['account2Name'];
        if (val is String && val.trim().isNotEmpty) await setAccount2Name(val.trim());
      }
      if (map.containsKey('categoryAccountRouting')) {
        final val = map['categoryAccountRouting'];
        if (val is Map) {
          final prefs = await SharedPreferences.getInstance();
          _categoryAccountRouting = val.map((k, v) => MapEntry(k.toString(), v.toString()));
          await prefs.setString('categoryAccountRouting', jsonEncode(_categoryAccountRouting));
        }
      }
      if (map.containsKey('defaultPaymentInfo')) {
        final val = map['defaultPaymentInfo'];
        if (val is String) await setDefaultPaymentInfo(val);
      }
      if (map.containsKey('trashAutoPurgeDays')) {
        final days = (map['trashAutoPurgeDays'] as num?)?.toInt();
        if (days != null && days > 0) await setTrashAutoPurgeDays(days);
      }
      if (map.containsKey('currency')) {
        final curr = map['currency'];
        if (curr is String && curr.isNotEmpty) await setCurrency(curr);
      }
      if (map.containsKey('selectedLanguageCode')) {
        final lang = map['selectedLanguageCode'];
        if (lang is String && lang.isNotEmpty) await setSelectedLanguage(lang);
      }
      if (map.containsKey('isPeriodTrackerEnabled')) {
        final ptEnabled = map['isPeriodTrackerEnabled'];
        if (ptEnabled is bool) await setIsPeriodTrackerEnabled(ptEnabled);
      }
      if (map.containsKey('isDiscreetHealthMode')) {
        final dMode = map['isDiscreetHealthMode'];
        if (dMode is bool) await setIsDiscreetHealthMode(dMode);
      }
      if (map.containsKey('appLockTimeout')) {
        final timeout = (map['appLockTimeout'] as num?)?.toInt();
        if (timeout != null) {
          await setAppLockTimeout(timeout);
        }
      }
      if (map.containsKey('discreetNotificationText')) {
        final txt = map['discreetNotificationText'];
        if (txt is String && txt.isNotEmpty) {
          await setDiscreetNotificationText(txt);
        }
      }
      if (map.containsKey('useOnDeviceAi')) {
        final val = map['useOnDeviceAi'];
        if (val is bool) await setUseOnDeviceAi(val);
      }
      if (map.containsKey('useDynamicColor')) {
        final val = map['useDynamicColor'];
        if (val is bool) await setUseDynamicColor(val);
      }
      if (map.containsKey('customExpenseRules')) {
        final rules = map['customExpenseRules'];
        if (rules is List) {
          final prefs = await SharedPreferences.getInstance();
          _customExpenseRules = List<String>.from(rules);
          await prefs.setStringList('customExpenseRules', _customExpenseRules);
        }
      }
      if (map.containsKey('customIncomeRules')) {
        final rules = map['customIncomeRules'];
        if (rules is List) {
          final prefs = await SharedPreferences.getInstance();
          _customIncomeRules = List<String>.from(rules);
          await prefs.setStringList('customIncomeRules', _customIncomeRules);
        }
      }
      if (map.containsKey('dailySyncEnabled')) {
        final val = map['dailySyncEnabled'];
        if (val is bool) await setDailySyncEnabled(val);
      }
      if (map.containsKey('dailySyncTime')) {
        final val = map['dailySyncTime'];
        if (val is String) await setDailySyncTime(val);
      }
      if (map.containsKey('smsSyncFrequency')) {
        final val = map['smsSyncFrequency'];
        if (val is String) await setSmsSyncFrequency(val);
      }
      if (map.containsKey('showProTips')) {
        final val = map['showProTips'];
        if (val is bool) await setShowProTips(val);
      }
      if (map.containsKey('enableSmsImport')) {
        final val = map['enableSmsImport'];
        if (val is bool) await setEnableSmsImport(val);
      }
      if (map.containsKey('enableBudgetsAndAnalytics')) {
        final val = map['enableBudgetsAndAnalytics'];
        if (val is bool) await setEnableBudgetsAndAnalytics(val);
      }
      if (map.containsKey('enableRecurringRules')) {
        final val = map['enableRecurringRules'];
        if (val is bool) await setEnableRecurringRules(val);
      }
      if (map.containsKey('showTagFilterBar')) {
        final val = map['showTagFilterBar'];
        if (val is bool) await setShowTagFilterBar(val);
      }
      if (map.containsKey('minimalEditorMode')) {
        final val = map['minimalEditorMode'];
        if (val is bool) await setMinimalEditorMode(val);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> checkAiCoreSupport(LocalAiService aiService) async {
    try {
      _isDeviceAiSupported = await aiService.isSupported();
    } catch (_) {
      _isDeviceAiSupported = false;
    }
    notifyListeners();
  }

  Future<void> setUseOnDeviceAi(bool enabled) async {
    _useOnDeviceAi = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useOnDeviceAi', enabled);
    notifyListeners();
  }

  Future<void> setCategoryBudget(String category, double amount) async {
    _categoryBudgets[category] = amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('categoryBudgets', jsonEncode(_categoryBudgets));
    notifyListeners();
    if (!kIsWeb) {
      await WidgetHelper.updateWidgetData();
    }
  }

  Future<void> removeCategoryBudget(String category) async {
    _categoryBudgets.remove(category);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('categoryBudgets', jsonEncode(_categoryBudgets));
    notifyListeners();
    if (!kIsWeb) {
      await WidgetHelper.updateWidgetData();
    }
  }

  Future<void> setShowProTips(bool enabled) async {
    _showProTips = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showProTips', enabled);
    notifyListeners();
    if (!kIsWeb) {
      if (enabled) {
        await NotificationService.schedulePeriodicTips();
      } else {
        await NotificationService.cancelPeriodicTips();
      }
    }
  }

  Future<void> dismissCurrentTip() async {
    _lastTipDismissedTimestamp = DateTime.now().millisecondsSinceEpoch;
    _currentTipIndex = (_currentTipIndex + 1) % 7;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastTipDismissedTimestamp', _lastTipDismissedTimestamp);
    await prefs.setInt('currentTipIndex', _currentTipIndex);
    notifyListeners();
    if (!kIsWeb && _showProTips) {
      await NotificationService.schedulePeriodicTips();
    }
  }
}
