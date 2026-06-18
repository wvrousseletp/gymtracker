class LibraryExercise {
  final String id;
  final String name;
  final String muscle;
  final String measurementType; // 'reps' ou 'time'
  final String? executionType;  // 'isometric' ou null
  final String? notes;

  LibraryExercise({
    required this.id,
    required this.name,
    required this.muscle,
    required this.measurementType,
    this.executionType,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscle': muscle,
    'measurementType': measurementType,
    'executionType': executionType ?? 'Livre',
    'notes': notes,
  };

  factory LibraryExercise.fromJson(Map<String, dynamic> json) => LibraryExercise(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    muscle: json['muscle'] ?? 'Geral',
    measurementType: json['measurementType'] ?? 'reps',
    executionType: json['executionType'] ?? 'Livre',
    notes: json['notes'],
  );
}

class RoutineExercise {
  final String id;
  final String exerciseId;
  final int sets;
  final int reps; // Segundos para isometria/tempo, ou contagem de repetições
  final int rest; // Descanso em segundos
  final double weight;

  RoutineExercise({
    required this.id,
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.rest,
    required this.weight,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'sets': sets,
    'reps': reps,
    'rest': rest,
    'weight': weight,
  };

  factory RoutineExercise.fromJson(Map<String, dynamic> json) {
    return RoutineExercise(
      id: json['id'] ?? '',
      exerciseId: json['exerciseId'] ?? '',
      sets: json['sets'] is int ? json['sets'] : (json['sets'] as num?)?.toInt() ?? 3,
      reps: json['reps'] is int ? json['reps'] : (json['reps'] as num?)?.toInt() ?? 10,
      rest: json['rest'] is int ? json['rest'] : (json['rest'] as num?)?.toInt() ?? 60,
      weight: json['weight'] is double ? json['weight'] : (json['weight'] as num?)?.toDouble() ?? 0.0,
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
  final String measurementType;
  final int sets;
  final int reps;
  final int rest;
  final double weight;
  final List<bool> setsState;
  final List<PerformedCardio?> performedCardios;
  final List<bool> failureReport;

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
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscle': muscle,
    'executionType': executionType,
    'measurementType': measurementType,
    'sets': sets,
    'reps': reps,
    'rest': rest,
    'weight': weight,
    'setsState': setsState,
    'performedCardios': performedCardios.map((c) => c?.toJson()).toList(),
    'failureReport': failureReport,
  };

  factory ActiveExercise.fromJson(Map<String, dynamic> json) {
    var setsVal = (json['sets'] as num?)?.toInt() ?? 3;
    return ActiveExercise(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      muscle: json['muscle'] ?? 'Geral',
      executionType: json['executionType'],
      measurementType: json['measurementType'] ?? 'reps',
      sets: setsVal,
      reps: (json['reps'] as num?)?.toInt() ?? 10,
      rest: (json['rest'] as num?)?.toInt() ?? 60,
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      setsState: List<bool>.from(json['setsState'] ?? List.filled(setsVal, false)),
      performedCardios: json['performedCardios'] != null
          ? (json['performedCardios'] as List).map((c) => c == null ? null : PerformedCardio.fromJson(c)).toList()
          : List.filled(setsVal, null),
      failureReport: List<bool>.from(json['failureReport'] ?? List.filled(setsVal, false)),
    );
  }
}
