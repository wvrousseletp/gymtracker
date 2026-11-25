import 'enums.dart';
export 'enums.dart';
import 'exercise.dart';

class LogExercise {
  final String name;
  final String muscle;
  final int sets;
  final int completedSets;
  final int reps;
  final double weight;
  final List<double>? weightsPerSet;
  final List<int>? repsPerSet;
  final List<PerformedCardio?>? performedCardios;
  final int rpe;
  final List<bool>? failureReport;
  final List<int?>? failureReps;
  final List<String>? setTypes;
  final List<int?>? rirPerSet;
  final String? executionType;

  LogExercise({
    required this.name,
    required this.muscle,
    required this.sets,
    required this.completedSets,
    required this.reps,
    required this.weight,
    this.weightsPerSet,
    this.repsPerSet,
    this.performedCardios,
    required this.rpe,
    this.failureReport,
    this.failureReps,
    this.setTypes,
    this.rirPerSet,
    this.executionType,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'muscle': muscle,
    'sets': sets,
    'completedSets': completedSets,
    'reps': reps,
    'weight': weight,
    'weightsPerSet': weightsPerSet,
    'repsPerSet': repsPerSet,
    'performedCardios': performedCardios?.map((c) => c?.toJson()).toList(),
    'rpe': rpe,
    'failureReport': failureReport,
    'failureReps': failureReps,
    'setTypes': setTypes,
    'rirPerSet': rirPerSet,
    'executionType': executionType,
  };

  factory LogExercise.fromJson(Map<String, dynamic> json) => LogExercise(
    name: json['name'] ?? '',
    muscle: json['muscle'] ?? 'Geral',
    sets: (json['sets'] as num?)?.toInt() ?? 0,
    completedSets: (json['completedSets'] as num?)?.toInt() ?? 0,
    reps: (json['reps'] as num?)?.toInt() ?? 0,
    weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
    weightsPerSet: json['weightsPerSet'] != null
        ? (json['weightsPerSet'] as List).map<double>((w) => (w as num).toDouble()).toList()
        : null,
    repsPerSet: json['repsPerSet'] != null
        ? (json['repsPerSet'] as List).map<int>((r) => (r as num).toInt()).toList()
        : null,
    performedCardios: json['performedCardios'] != null
        ? (json['performedCardios'] as List).map((c) => c == null ? null : PerformedCardio.fromJson(c)).toList()
        : null,
    rpe: (json['rpe'] as num?)?.toInt() ?? 8,
    failureReport: json['failureReport'] != null ? List<bool>.from(json['failureReport']) : null,
    failureReps: json['failureReps'] != null 
        ? List<int?>.from(json['failureReps']) 
        : (json['failureReport'] != null ? List<int?>.filled((json['failureReport'] as List).length, null) : null),
    setTypes: json['setTypes'] != null
        ? (json['setTypes'] as List).map<String>((t) => t.toString()).toList()
        : null,
    rirPerSet: json['rirPerSet'] != null
        ? (json['rirPerSet'] as List)
            .map<int?>((r) => r == null ? null : (r as num).toInt())
            .toList()
        : null,
    executionType: json['executionType'],
  );
}

class WorkoutRecovery {
  final SleepQuality sleepOk;
  final List<String> pain;
  final bool warmUpDone;

  WorkoutRecovery({
    required this.sleepOk,
    required this.pain,
    required this.warmUpDone,
  });

  Map<String, dynamic> toJson() => {
    'sleepOk': sleepQualityToString(sleepOk),
    'pain': pain,
    'warmUpDone': warmUpDone,
  };

  factory WorkoutRecovery.fromJson(Map<String, dynamic> json) => WorkoutRecovery(
    sleepOk: sleepQualityFromString(json['sleepOk'] ?? 'ok'),
    pain: json['pain'] != null ? List<String>.from(json['pain']) : [],
    warmUpDone: json['warmUpDone'] ?? false,
  );
}

class WorkoutLog {
  final String id;
  final String name;
  final String date; // String ISO
  final int duration; // Segundos
  final int completedSets;
  final int totalSets;
  final double totalWeight; // Volume de carga
  final int rpe; // RPE global
  final String notes;
  final WorkoutRecovery? recovery;
  final List<LogExercise> exercises;
  final int warmupDurationSeconds;
  final int? avgHeartRate;
  final int? activeCalories;

  WorkoutLog({
    required this.id,
    required this.name,
    required this.date,
    required this.duration,
    required this.completedSets,
    required this.totalSets,
    required this.totalWeight,
    required this.rpe,
    required this.notes,
    this.recovery,
    required this.exercises,
    this.warmupDurationSeconds = 0,
    this.avgHeartRate,
    this.activeCalories,
  });

  bool get isRestDayLog {
    final trimmed = name.trim();
    if (trimmed == 'Dia de Descanso' || trimmed.startsWith('Descanso:')) {
      return true;
    }
    return duration == 0 &&
        completedSets == 0 &&
        totalSets == 0 &&
        exercises.isEmpty &&
        trimmed.toLowerCase().contains('descanso');
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'date': date,
    'duration': duration,
    'completedSets': completedSets,
    'totalSets': totalSets,
    'totalWeight': totalWeight,
    'rpe': rpe,
    'notes': notes,
    'recovery': recovery?.toJson(),
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'warmupDurationSeconds': warmupDurationSeconds,
    'avgHeartRate': avgHeartRate,
    'activeCalories': activeCalories,
  };

  factory WorkoutLog.fromJson(Map<String, dynamic> json) => WorkoutLog(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    date: json['date'] ?? '',
    duration: (json['duration'] as num?)?.toInt() ?? 0,
    completedSets: (json['completedSets'] as num?)?.toInt() ?? 0,
    totalSets: (json['totalSets'] as num?)?.toInt() ?? 0,
    totalWeight: (json['totalWeight'] as num?)?.toDouble() ?? 0.0,
    rpe: (json['rpe'] as num?)?.toInt() ?? 8,
    notes: json['notes'] ?? '',
    recovery: json['recovery'] != null ? WorkoutRecovery.fromJson(json['recovery']) : null,
    exercises: json['exercises'] != null
        ? (json['exercises'] as List).map((e) => LogExercise.fromJson(e)).toList()
        : [],
    warmupDurationSeconds: (json['warmupDurationSeconds'] as num?)?.toInt() ?? 0,
    avgHeartRate: (json['avgHeartRate'] as num?)?.toInt(),
    activeCalories: (json['activeCalories'] as num?)?.toInt(),
  );
}
