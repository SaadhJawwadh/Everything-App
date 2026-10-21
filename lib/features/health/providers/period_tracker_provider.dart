import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../data/period_log_model.dart';
import '../data/period_repository.dart';
import '../../../services/period_prediction_service.dart';
import '../../../services/notification_service.dart';
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

    if (!kIsWeb) {
      await NotificationService.schedulePeriodNotifications();
    }

    _isLoading = false;
    notifyListeners();
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

  PeriodLog? getLogForDay(DateTime day) {
    final targetDay = DateTime.utc(day.year, day.month, day.day);
    for (final log in _logs) {
      final startDate = DateTime.utc(log.startDate.year, log.startDate.month, log.startDate.day);
      final endDate = log.endDate != null
          ? DateTime.utc(log.endDate!.year, log.endDate!.month, log.endDate!.day)
          : DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day);

      if (targetDay.isAtSameMomentAs(startDate) ||
          targetDay.isAtSameMomentAs(endDate) ||
          (targetDay.isAfter(startDate) && targetDay.isBefore(endDate.add(const Duration(days: 1))))) {
        return log;
      }
    }
    return null;
  }

  bool isPredictedDay(DateTime day) {
    if (_predictedNextPeriod == null) return false;
    final d = DateTime.utc(day.year, day.month, day.day);
    final p = DateTime.utc(_predictedNextPeriod!.year, _predictedNextPeriod!.month, _predictedNextPeriod!.day);
    return d.isAtSameMomentAs(p) || (d.isAfter(p) && d.isBefore(p.add(const Duration(days: 5))));
  }

  bool isOvulationDay(DateTime day) {
    if (_predictedOvulation == null) return false;
    final d = DateTime.utc(day.year, day.month, day.day);
    final p = DateTime.utc(_predictedOvulation!.year, _predictedOvulation!.month, _predictedOvulation!.day);
    final start = p.subtract(const Duration(days: 1));
    final end = p.add(const Duration(days: 1));
    return d.isAtSameMomentAs(start) || d.isAtSameMomentAs(end) || d.isAtSameMomentAs(p);
  }

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
