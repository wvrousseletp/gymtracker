import 'enums.dart';

class LibraryExercise {
  final String id;
  final String name;
  final String muscle;
  final MeasurementType measurementType;
  final String? executionType;  // 'isometric' ou null
  final String? notes;
  final bool isStationary;

  LibraryExercise({
    required this.id,
    required this.name,
    required this.muscle,
    required this.measurementType,
    this.executionType,
    this.notes,
    this.isStationary = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscle': muscle,
    'measurementType': measurementTypeToString(measurementType),
    'executionType': executionType ?? 'Livre',
    'notes': notes,
    'isStationary': isStationary,
  };

  factory LibraryExercise.fromJson(Map<String, dynamic> json) => LibraryExercise(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    muscle: json['muscle'] ?? 'Geral',
    measurementType: measurementTypeFromString(json['measurementType'] ?? 'reps'),
    executionType: json['executionType'] ?? 'Livre',
    notes: json['notes'],
    isStationary: json['isStationary'] ?? false,
  );
}

class RoutineExercise {
  final String id;
  final String exerciseId;
  final int sets; // Para cardio tradicional, pode ser 0 ou 1 (único segmento)
  final int reps; // Segundos para isometria/tempo, ou contagem de repetições
  final int rest; // Descanso em segundos
  final double weight;
  final List<double>? weightsPerSet;
  final List<int>? repsPerSet;
  // Cardio-specific fields
  final bool isCardio; // Se true, usa distance/duration em vez de sets/reps
  final bool allowCardioSets; // Se true, permite múltiplos sets (para HIIT)

  RoutineExercise({
    required this.id,
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.rest,
    required this.weight,
    this.weightsPerSet,
    this.repsPerSet,
    this.isCardio = false,
    this.allowCardioSets = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'sets': sets,
    'reps': reps,
    'rest': rest,
    'weight': weight,
    'weightsPerSet': weightsPerSet,
    'repsPerSet': repsPerSet,
    'isCardio': isCardio,
    'allowCardioSets': allowCardioSets,
  };

  factory RoutineExercise.fromJson(Map<String, dynamic> json) {
    return RoutineExercise(
      id: json['id'] ?? '',
      exerciseId: json['exerciseId'] ?? '',
      sets: json['sets'] is int ? json['sets'] : (json['sets'] as num?)?.toInt() ?? 3,
      reps: json['reps'] is int ? json['reps'] : (json['reps'] as num?)?.toInt() ?? 10,
      rest: json['rest'] is int ? json['rest'] : (json['rest'] as num?)?.toInt() ?? 60,
      weight: json['weight'] is double ? json['weight'] : (json['weight'] as num?)?.toDouble() ?? 0.0,
      weightsPerSet: json['weightsPerSet'] != null
          ? (json['weightsPerSet'] as List).map<double>((w) => (w as num).toDouble()).toList()
          : null,
      repsPerSet: json['repsPerSet'] != null
          ? (json['repsPerSet'] as List).map<int>((r) => (r as num).toInt()).toList()
          : null,
      isCardio: json['isCardio'] ?? false,
      allowCardioSets: json['allowCardioSets'] ?? false,
    );
  }
}

class PerformedCardio {
  final double distanceKm;
  final int durationSeconds;

  PerformedCardio({
    required this.distanceKm,
    required this.durationSeconds,
  });

  Map<String, dynamic> toJson() => {
    'distanceKm': distanceKm,
    'durationSeconds': durationSeconds,
  };

  factory PerformedCardio.fromJson(Map<String, dynamic> json) {
    return PerformedCardio(
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class ActiveExercise {
  final String id;
  final String name;
  final String muscle;
  final String? executionType;
  final MeasurementType measurementType;
  final int sets;
  final int reps;
  final int rest;
  final double weight;
  final List<bool> setsState;
  final List<PerformedCardio?> performedCardios;
  final List<bool> failureReport;
  final List<int?> failureReps;
  final List<double>? weightsPerSet;
  final List<int>? repsPerSet;
  // Cardio-specific fields
  final bool isCardio;
  final bool allowCardioSets;
  final bool isStationary;
  // Single cardio session data (for non-set cardio)
  PerformedCardio? singleCardioSession;

  ActiveExercise({
    required this.id,
    required this.name,
    required this.muscle,
    this.executionType,
    required this.measurementType,
    required this.sets,
    required this.reps,
    required this.rest,
    required this.weight,
    required this.setsState,
    required this.performedCardios,
    required this.failureReport,
    List<int?>? failureReps,
    this.weightsPerSet,
    this.repsPerSet,
    this.isCardio = false,
    this.allowCardioSets = false,
    this.isStationary = false,
    this.singleCardioSession,
  }) : failureReps = failureReps ?? List<int?>.filled(sets, null);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscle': muscle,
    'executionType': executionType,
    'measurementType': measurementTypeToString(measurementType),
    'sets': sets,
    'reps': reps,
    'rest': rest,
    'weight': weight,
    'weightsPerSet': weightsPerSet,
    'repsPerSet': repsPerSet,
    'setsState': setsState,
    'performedCardios': performedCardios.map((c) => c?.toJson()).toList(),
    'failureReport': failureReport,
    'failureReps': failureReps,
    'isCardio': isCardio,
    'allowCardioSets': allowCardioSets,
    'isStationary': isStationary,
    'singleCardioSession': singleCardioSession?.toJson(),
  };

  factory ActiveExercise.fromJson(Map<String, dynamic> json) {
    var setsVal = (json['sets'] as num?)?.toInt() ?? 3;
    return ActiveExercise(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      muscle: json['muscle'] ?? 'Geral',
      executionType: json['executionType'],
      measurementType: measurementTypeFromString(json['measurementType'] ?? 'reps'),
      sets: setsVal,
      reps: (json['reps'] as num?)?.toInt() ?? 10,
      rest: (json['rest'] as num?)?.toInt() ?? 60,
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      weightsPerSet: json['weightsPerSet'] != null
          ? (json['weightsPerSet'] as List).map<double>((w) => (w as num).toDouble()).toList()
          : null,
      repsPerSet: json['repsPerSet'] != null
          ? (json['repsPerSet'] as List).map<int>((r) => (r as num).toInt()).toList()
          : null,
      setsState: List<bool>.from(json['setsState'] ?? List.filled(setsVal, false)),
      performedCardios: json['performedCardios'] != null
          ? (json['performedCardios'] as List).map((c) => c == null ? null : PerformedCardio.fromJson(c)).toList()
          : List.filled(setsVal, null),
      failureReport: List<bool>.from(json['failureReport'] ?? List.filled(setsVal, false)),
      failureReps: json['failureReps'] != null
          ? List<int?>.from(json['failureReps'])
          : List<int?>.filled(setsVal, null),
      isCardio: (json['isCardio'] ?? false) &&
          measurementTypeFromString(json['measurementType'] ?? 'reps') != MeasurementType.time,
      allowCardioSets: json['allowCardioSets'] ?? false,
      isStationary: json['isStationary'] ?? false,
      singleCardioSession: json['singleCardioSession'] != null
          ? PerformedCardio.fromJson(json['singleCardioSession'])
          : null,
    );
  }
}
