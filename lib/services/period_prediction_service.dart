import 'dart:math' as math;
import '../data/period_log_model.dart';
import '../features/health/data/period_repository.dart';

/// Summary statistical insight for historical menstrual cycles.
class CycleStats {
  final int avgCycleLength;
  final int avgPeriodDuration;
  final double regularityScore; // 0.0 to 100.0%
  final String regularityLabel; // 'Very Regular', 'Regular', 'Mildly Irregular', 'Irregular', 'Not Enough Data'
  final int variationDays;
  final int cycleCount;

  const CycleStats({
    required this.avgCycleLength,
    required this.avgPeriodDuration,
    required this.regularityScore,
    required this.regularityLabel,
    required this.variationDays,
    required this.cycleCount,
  });

  factory CycleStats.initial() {
    return const CycleStats(
      avgCycleLength: PeriodPredictionService.normalCycleLengthDays,
      avgPeriodDuration: 5,
      regularityScore: 100.0,
      regularityLabel: 'Not Enough Data',
      variationDays: 0,
      cycleCount: 0,
    );
  }
}

class PeriodPredictionService {
  static const int normalCycleLengthDays = 28;
  static const int lutealPhaseLengthDays = 14; // Typical days from ovulation to next period

  static List<PeriodLog> _sortLogs(List<PeriodLog> logs) {
    if (logs.length < 2) return logs;
    bool alreadySorted = true;
    for (int i = 0; i < logs.length - 1; i++) {
      if (logs[i].startDate.isBefore(logs[i + 1].startDate)) {
        alreadySorted = false;
        break;
      }
    }
    if (alreadySorted) return logs;
    return List<PeriodLog>.from(logs)..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  /// Calculates the average cycle length based on the last 3-6 logs.
  /// A cycle is the number of days between the start date of one period and the start date of the next.
  static Future<int> calculateAverageCycleLength([List<PeriodLog>? customLogs]) async {
    final rawLogs = customLogs ?? await PeriodRepository.instance.readAllPeriodLogs();
    final logs = _sortLogs(rawLogs);

    if (logs.length < 2) {
      return normalCycleLengthDays;
    }

    int totalDays = 0;
    int cyclesCount = 0;

    final limit = logs.length > 7 ? 7 : logs.length;

    for (int i = 0; i < limit - 1; i++) {
      final currentPeriod = logs[i].startDate;
      final previousPeriod = logs[i + 1].startDate;

      final currentUtc = DateTime.utc(currentPeriod.year, currentPeriod.month, currentPeriod.day);
      final previousUtc = DateTime.utc(previousPeriod.year, previousPeriod.month, previousPeriod.day);

      final diff = currentUtc.difference(previousUtc).inDays;
      if (diff >= 15 && diff <= 60) {
        totalDays += diff;
        cyclesCount++;
      }
    }

    if (cyclesCount == 0) {
      return normalCycleLengthDays;
    }

    return (totalDays / cyclesCount).round();
  }

  /// Calculates average period duration (days bleeding from start to end date).
  static Future<int> calculateAveragePeriodDuration([List<PeriodLog>? customLogs]) async {
    final rawLogs = customLogs ?? await PeriodRepository.instance.readAllPeriodLogs();
    final logs = _sortLogs(rawLogs);
    final finishedLogs = logs.where((l) => l.endDate != null).toList();

    if (finishedLogs.isEmpty) return 5;

    int totalDuration = 0;
    int count = 0;

    for (final log in finishedLogs.take(6)) {
      final s = DateTime.utc(log.startDate.year, log.startDate.month, log.startDate.day);
      final e = DateTime.utc(log.endDate!.year, log.endDate!.month, log.endDate!.day);
      final days = e.difference(s).inDays + 1;
      if (days >= 1 && days <= 14) {
        totalDuration += days;
        count++;
      }
    }

    if (count == 0) return 5;
    return (totalDuration / count).round();
  }

  /// Calculates comprehensive cycle statistics including standard deviation regularity scoring.
  static Future<CycleStats> calculateCycleStats([
    List<PeriodLog>? customLogs,
    int? precomputedAvgCycleLength,
    int? precomputedAvgPeriodDuration,
  ]) async {
    final rawLogs = customLogs ?? await PeriodRepository.instance.readAllPeriodLogs();
    final logs = _sortLogs(rawLogs);

    if (logs.length < 2) {
      return CycleStats.initial();
    }

    final cycleLengths = <int>[];
    final limit = logs.length > 7 ? 7 : logs.length;

    for (int i = 0; i < limit - 1; i++) {
      final currentPeriod = logs[i].startDate;
      final previousPeriod = logs[i + 1].startDate;

      final currentUtc = DateTime.utc(currentPeriod.year, currentPeriod.month, currentPeriod.day);
      final previousUtc = DateTime.utc(previousPeriod.year, previousPeriod.month, previousPeriod.day);

      final diff = currentUtc.difference(previousUtc).inDays;
      if (diff >= 15 && diff <= 60) {
        cycleLengths.add(diff);
      }
    }

    if (cycleLengths.isEmpty) {
      return CycleStats.initial();
    }

    final avgLength = precomputedAvgCycleLength ??
        (cycleLengths.reduce((a, b) => a + b) / cycleLengths.length).round();
    final avgDuration = precomputedAvgPeriodDuration ??
        await calculateAveragePeriodDuration(logs);

    if (cycleLengths.length < 2) {
      return CycleStats(
        avgCycleLength: avgLength,
        avgPeriodDuration: avgDuration,
        regularityScore: 90.0,
        regularityLabel: 'Regular',
        variationDays: 0,
        cycleCount: 1,
      );
    }

    // Standard deviation computation
    final mean = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
    final variance = cycleLengths.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / cycleLengths.length;
    final stdDev = math.sqrt(variance);

    // Max variation from mean
    int maxDiff = 0;
    for (final l in cycleLengths) {
      final d = (l - avgLength).abs();
      if (d > maxDiff) maxDiff = d;
    }

    // Score: 100 - (stdDev * 12), clamped between 20 and 100
    final score = (100.0 - (stdDev * 12.0)).clamp(20.0, 100.0);

    String label;
    if (stdDev <= 1.5) {
      label = 'Very Regular';
    } else if (stdDev <= 3.0) {
      label = 'Regular';
    } else if (stdDev <= 5.5) {
      label = 'Mildly Irregular';
    } else {
      label = 'Irregular';
    }

    return CycleStats(
      avgCycleLength: avgLength,
      avgPeriodDuration: avgDuration,
      regularityScore: score,
      regularityLabel: label,
      variationDays: maxDiff,
      cycleCount: cycleLengths.length,
    );
  }

  /// Calculates the estimated start date of the next period based on the most recent log
  /// and the average cycle length.
  static Future<DateTime?> estimateNextPeriod([
    List<PeriodLog>? customLogs,
    int? precomputedAvgCycleLength,
  ]) async {
    final rawLogs = customLogs ?? await PeriodRepository.instance.readAllPeriodLogs();
    final logs = _sortLogs(rawLogs);
    if (logs.isEmpty) {
      return null;
    }

    final latestLog = logs.first; // newest first
    final avgCycleLength = precomputedAvgCycleLength ?? await calculateAverageCycleLength(logs);

    return DateTime.utc(latestLog.startDate.year, latestLog.startDate.month, latestLog.startDate.day)
        .add(Duration(days: avgCycleLength));
  }

  /// Calculates the estimated ovulation date for the *current* cycle.
  /// Ovulation typically occurs 14 days before the start of the NEXT period.
  static Future<DateTime?> estimateOvulationDate([
    List<PeriodLog>? customLogs,
    DateTime? precomputedNextPeriod,
    int? precomputedAvgCycleLength,
  ]) async {
    final nextPeriod = precomputedNextPeriod ?? await estimateNextPeriod(customLogs, precomputedAvgCycleLength);
    if (nextPeriod == null) return null;

    return nextPeriod.subtract(const Duration(days: lutealPhaseLengthDays));
  }

  /// Returns the number of days until the next predicted period.
  /// Negative means it's overdue.
  static Future<int?> daysUntilNextPeriod([
    List<PeriodLog>? customLogs,
    DateTime? precomputedNextPeriod,
    int? precomputedAvgCycleLength,
  ]) async {
    final nextPeriod = precomputedNextPeriod ?? await estimateNextPeriod(customLogs, precomputedAvgCycleLength);
    if (nextPeriod == null) return null;

    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final nextPeriodDay = DateTime.utc(nextPeriod.year, nextPeriod.month, nextPeriod.day);

    return nextPeriodDay.difference(today).inDays;
  }
}
