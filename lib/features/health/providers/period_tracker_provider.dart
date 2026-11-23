import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../data/period_log_model.dart';
import '../data/period_repository.dart';
import '../../../services/period_prediction_service.dart';
import '../../../services/p2p_sync_service.dart';

/// Reactive provider managing Menstrual Cycle logs, predictions, phase calculations, and stats.
class PeriodTrackerProvider extends ChangeNotifier {
  List<PeriodLog> _logs = [];
  bool _isLoading = true;
  StreamSubscription? _syncEventsSubscription;

  DateTime? _predictedNextPeriod;
  DateTime? _predictedOvulation;
  int? _daysUntilNext;

  int _avgCycleLength = PeriodPredictionService.normalCycleLengthDays;
  int? _currentCycleDay;
  String _currentPhase = 'No Logs';
  String _phaseDescription = 'Log a period start date to see cycle phases.';
  CycleStats _cycleStats = CycleStats.initial();

  Map<int, PeriodLog> _logsByDayKey = const {};
  Set<int> _predictedDayKeys = const {};
  Set<int> _ovulationDayKeys = const {};
  int? _cachedCycleVariationDays;

  static int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  // Getters
  List<PeriodLog> get logs => List.unmodifiable(_logs);
  bool get isLoading => _isLoading;
  DateTime? get predictedNextPeriod => _predictedNextPeriod;
  DateTime? get predictedOvulation => _predictedOvulation;
  int? get daysUntilNext => _daysUntilNext;
  int get avgCycleLength => _avgCycleLength;
  int? get currentCycleDay => _currentCycleDay;
  String get currentPhase => _currentPhase;
  String get phaseDescription => _phaseDescription;
  CycleStats get cycleStats => _cycleStats;
  bool get isPeriodActive => getCurrentOngoingPeriod() != null;

  /// Difference in days between the longest and shortest historical cycle lengths
  /// when at least 2 completed cycles exist; otherwise null.
  int? get cycleVariationDays => _cachedCycleVariationDays;

  int? _computeCycleVariationDays() {
    if (_logs.length < 3) return null;
    final sortedLogs = List<PeriodLog>.from(_logs)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    final cycleLengths = <int>[];
    for (int i = 0; i < sortedLogs.length - 1; i++) {
      final current = sortedLogs[i].startDate;
      final previous = sortedLogs[i + 1].startDate;
      final currentUtc = DateTime.utc(current.year, current.month, current.day);
      final previousUtc = DateTime.utc(previous.year, previous.month, previous.day);
      final diff = currentUtc.difference(previousUtc).inDays;
      if (diff >= 15 && diff <= 60) {
        cycleLengths.add(diff);
      }
    }

    if (cycleLengths.length < 2) return null;
    int minLen = cycleLengths.first;
    int maxLen = cycleLengths.first;
    for (final len in cycleLengths) {
      if (len < minLen) minLen = len;
      if (len > maxLen) maxLen = len;
    }
    return maxLen - minLen;
  }

  /// Human-readable cycle regularity tier derived from [cycleVariationDays].
  String get cycleRegularityLabel {
    final variation = cycleVariationDays;
    if (variation == null) return 'Building History';
    if (variation <= 4) return 'Consistent';
    if (variation <= 8) return 'Moderate Variation';
    return 'Irregular';
  }

  PeriodTrackerProvider() {
    loadData();
    _syncEventsSubscription = P2pSyncService.instance.syncEvents.listen((result) {
      if (result.success) {
        loadData(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _syncEventsSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadData({bool showLoading = false}) async {
    if (showLoading || _logs.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    _logs = await PeriodRepository.instance.readAllPeriodLogs();
    _avgCycleLength = await PeriodPredictionService.calculateAverageCycleLength(_logs);
    _predictedNextPeriod = await PeriodPredictionService.estimateNextPeriod(_logs, _avgCycleLength);
    _predictedOvulation = await PeriodPredictionService.estimateOvulationDate(_logs, _predictedNextPeriod, _avgCycleLength);
    _daysUntilNext = await PeriodPredictionService.daysUntilNextPeriod(_logs, _predictedNextPeriod, _avgCycleLength);
    _cycleStats = await PeriodPredictionService.calculateCycleStats(_logs, _avgCycleLength);
    _calculateCyclePhase();
    _rebuildCalendarIndex();

    _isLoading = false;
    notifyListeners();
  }

  void _rebuildCalendarIndex() {
    _cachedCycleVariationDays = _computeCycleVariationDays();
    final now = DateTime.now();
    final todayUtc = DateTime.utc(now.year, now.month, now.day);
    final byDay = <int, PeriodLog>{};
    for (final log in _logs) {
      final start = DateTime.utc(log.startDate.year, log.startDate.month, log.startDate.day);
      final end = log.endDate != null
          ? DateTime.utc(log.endDate!.year, log.endDate!.month, log.endDate!.day)
          : todayUtc;
      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        byDay.putIfAbsent(_dayKey(d), () => log);
      }
    }
    _logsByDayKey = byDay;

    final predicted = <int>{};
    if (_predictedNextPeriod != null) {
      final p = DateTime.utc(_predictedNextPeriod!.year, _predictedNextPeriod!.month, _predictedNextPeriod!.day);
      for (int i = 0; i < 5; i++) {
        predicted.add(_dayKey(p.add(Duration(days: i))));
      }
    }
    _predictedDayKeys = predicted;

    final ovulation = <int>{};
    if (_predictedOvulation != null) {
      final p = DateTime.utc(_predictedOvulation!.year, _predictedOvulation!.month, _predictedOvulation!.day);
      for (int i = -1; i <= 1; i++) {
        ovulation.add(_dayKey(p.add(Duration(days: i))));
      }
    }
    _ovulationDayKeys = ovulation;
  }

  void _calculateCyclePhase() {
    if (_logs.isEmpty) {
      _currentCycleDay = null;
      _currentPhase = 'No Logs';
      _phaseDescription = 'Log a period start date to see cycle phases.';
      return;
    }

    final latestLog = _logs.first;
    final now = DateTime.now();
    final todayUtc = DateTime.utc(now.year, now.month, now.day);
    final startUtc = DateTime.utc(latestLog.startDate.year, latestLog.startDate.month, latestLog.startDate.day);

    final diff = todayUtc.difference(startUtc).inDays;

    if (diff < 0) {
      _currentCycleDay = 1;
      _currentPhase = 'Menstrual Phase';
      _phaseDescription = 'Period logged for future date. Cycle tracking will begin automatically.';
      return;
    }

    // Dynamic ovulation calculation based on average cycle length
    final ovulationDay = (_avgCycleLength - PeriodPredictionService.lutealPhaseLengthDays).clamp(8, _avgCycleLength - 4);
    final follicularEnd = ovulationDay - 1;
    final ovulatoryEnd = (ovulationDay + 2).clamp(ovulationDay, _avgCycleLength - 1);

    if (diff >= _avgCycleLength) {
      // Overdue cycle: preserve actual elapsed day count without modulo reset
      final cycleDay = diff + 1;
      _currentCycleDay = cycleDay;
      _currentPhase = 'Late / Overdue';
      final overdueDays = diff - _avgCycleLength + 1;
      _phaseDescription = 'Period expected. Delayed by $overdueDays day${overdueDays == 1 ? '' : 's'}. Prioritize gentle rest.';
      return;
    }

    final cycleDay = diff + 1;
    _currentCycleDay = cycleDay;

    if (cycleDay >= 1 && cycleDay <= 5) {
      _currentPhase = 'Menstrual Phase';
      _phaseDescription = 'Flow begins. Progesterone and estrogen levels drop. Rest and nurture yourself.';
    } else if (cycleDay >= 6 && cycleDay <= follicularEnd) {
      _currentPhase = 'Follicular Phase';
      _phaseDescription = 'Estrogen rises, boosting energy, mood, and focus. Great time for planning.';
    } else if (cycleDay >= ovulationDay && cycleDay <= ovulatoryEnd) {
      _currentPhase = 'Ovulatory Phase';
      _phaseDescription = 'Estrogen peaks, triggering ovulation. High energy and social openness.';
    } else {
      _currentPhase = 'Luteal Phase';
      _phaseDescription = 'Progesterone peaks, winding down energy. Prioritize self-care.';
    }
  }

  PeriodLog? getLogForDay(DateTime day) => _logsByDayKey[_dayKey(day)];

  bool isPredictedDay(DateTime day) => _predictedDayKeys.contains(_dayKey(day));

  bool isOvulationDay(DateTime day) => _ovulationDayKeys.contains(_dayKey(day));

  PeriodLog? getCurrentOngoingPeriod() {
    return _logs.where((l) => l.endDate == null).firstOrNull;
  }

  bool checkOverlap(DateTime start, DateTime? end, [String? excludeId]) {
    final s1 = DateTime.utc(start.year, start.month, start.day);
    final e1 = end != null ? DateTime.utc(end.year, end.month, end.day) : DateTime.utc(2999, 12, 31);

    for (final log in _logs) {
      if (excludeId != null && log.id == excludeId) continue;
      final s2 = DateTime.utc(log.startDate.year, log.startDate.month, log.startDate.day);
      final e2 = log.endDate != null
          ? DateTime.utc(log.endDate!.year, log.endDate!.month, log.endDate!.day)
          : DateTime.utc(2999, 12, 31);

      if (s1.isBefore(e2.add(const Duration(days: 1))) && e1.isAfter(s2.subtract(const Duration(days: 1)))) {
        return true;
      }
    }
    return false;
  }

  Future<bool> togglePeriodStatus() async {
    final now = DateTime.now();
    final todayUtc = DateTime.utc(now.year, now.month, now.day);

    final ongoing = getCurrentOngoingPeriod();
    if (ongoing != null) {
      final updated = ongoing.copyWith(endDate: todayUtc);
      if (checkOverlap(ongoing.startDate, todayUtc, ongoing.id)) {
        return false;
      }
      await PeriodRepository.instance.updatePeriodLog(updated);
    } else {
      if (checkOverlap(todayUtc, null)) {
        return false;
      }
      final newLog = PeriodLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startDate: todayUtc,
        intensity: 'Medium',
      );
      await PeriodRepository.instance.createPeriodLog(newLog);
    }
    await loadData();
    return true;
  }

  Future<bool> createLog(PeriodLog log) async {
    if (checkOverlap(log.startDate, log.endDate)) {
      return false;
    }
    await PeriodRepository.instance.createPeriodLog(log);
    await loadData();
    return true;
  }

  Future<bool> updateLog(PeriodLog log) async {
    if (checkOverlap(log.startDate, log.endDate, log.id)) {
      return false;
    }
    await PeriodRepository.instance.updatePeriodLog(log);
    await loadData();
    return true;
  }

  Future<void> deleteLog(String id) async {
    // 1. Instant optimistic in-memory removal (0ms)
    _logs.removeWhere((l) => l.id == id);
    notifyListeners();

    // 2. Persist in background and recalculate predictions
    await PeriodRepository.instance.deletePeriodLog(id);
    await loadData();
  }

  Future<void> updateIntensity(PeriodLog log, String newIntensity) async {
    final updated = log.copyWith(intensity: newIntensity);
    // 1. Instant optimistic in-memory update (0ms)
    final idx = _logs.indexWhere((l) => l.id == log.id);
    if (idx != -1) {
      _logs[idx] = updated;
      notifyListeners();
    }

    // 2. Persist in background
    await PeriodRepository.instance.updatePeriodLog(updated);
    await loadData();
  }

  Future<void> toggleSymptom(PeriodLog log, String symptom) async {
    final updatedSymptoms = List<String>.from(log.symptoms);
    if (updatedSymptoms.contains(symptom)) {
      updatedSymptoms.remove(symptom);
    } else {
      updatedSymptoms.add(symptom);
    }
    final updated = log.copyWith(symptoms: updatedSymptoms);

    // 1. Instant optimistic in-memory update (0ms)
    final idx = _logs.indexWhere((l) => l.id == log.id);
    if (idx != -1) {
      _logs[idx] = updated;
      notifyListeners();
    }

    // 2. Persist in background
    await PeriodRepository.instance.updatePeriodLog(updated);
    await loadData();
  }
}
