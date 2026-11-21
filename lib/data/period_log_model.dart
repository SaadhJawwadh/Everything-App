import 'dart:convert';

class PeriodLog {
  final String id;
  final DateTime startDate;
  final DateTime? endDate;
  final String intensity; // e.g., 'Spotting', 'Light', 'Medium', 'Heavy'
  final String notes;
  final List<String> symptoms;
  final DateTime? updatedAt;

  PeriodLog({
    required this.id,
    required this.startDate,
    this.endDate,
    required this.intensity,
    this.notes = '',
    this.symptoms = const [],
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'intensity': intensity,
      'notes': notes,
      'symptoms': jsonEncode(symptoms),
      'updatedAt': (updatedAt ?? endDate ?? startDate).toIso8601String(),
    };
  }

  factory PeriodLog.fromMap(Map<String, dynamic> map) {
    List<String> symptomsList = [];
    if (map['symptoms'] != null) {
      try {
        final decoded = jsonDecode(map['symptoms'] as String);
        if (decoded is List) {
          symptomsList = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        // Fallback for list type if it's somehow decoded already
        if (map['symptoms'] is List) {
          symptomsList = (map['symptoms'] as List).map((e) => e.toString()).toList();
        }
      }
    }

    return PeriodLog(
      id: map['id'] as String,
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'] as String)
          : null,
      intensity: map['intensity'] as String,
      notes: map['notes'] as String? ?? '',
      symptoms: symptomsList,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory PeriodLog.fromJson(String source) =>
      PeriodLog.fromMap(json.decode(source) as Map<String, dynamic>);

  PeriodLog copyWith({
    String? id,
    DateTime? startDate,
    DateTime? endDate,
    String? intensity,
    String? notes,
    List<String>? symptoms,
    DateTime? updatedAt,
  }) {
    return PeriodLog(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      intensity: intensity ?? this.intensity,
      notes: notes ?? this.notes,
      symptoms: symptoms ?? this.symptoms,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PeriodLog &&
        other.id == id &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.intensity == intensity &&
        other.notes == notes &&
        listEquals(other.symptoms, symptoms);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        startDate.hashCode ^
        endDate.hashCode ^
        intensity.hashCode ^
        notes.hashCode ^
        symptoms.hashCode;
  }
}

// Simple listEquals helper
bool listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  if (identical(a, b)) return true;
  for (int index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}
