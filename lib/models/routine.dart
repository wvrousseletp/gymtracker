import 'exercise.dart';
import 'enums.dart';

class Routine {
  final String id;
  final String name;
  final int defaultRest;
  final List<RoutineExercise> exercises;
  final bool isDynamicExercise; // Se foi gerado dinamicamente para um exercício avulso
  final RoutineExecutionType executionType;
  final int circuitCycles;

  Routine({
    required this.id,
    required this.name,
    required this.defaultRest,
    required this.exercises,
    this.isDynamicExercise = false,
    this.executionType = RoutineExecutionType.standard,
    this.circuitCycles = 3,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'defaultRest': defaultRest,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'isDynamicExercise': isDynamicExercise,
    'executionType': routineExecutionTypeToString(executionType),
    'circuitCycles': circuitCycles,
  };

  factory Routine.fromJson(Map<String, dynamic> json) => Routine(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    defaultRest: (json['defaultRest'] as num?)?.toInt() ?? 60,
    exercises: json['exercises'] != null
        ? (json['exercises'] as List).map((e) => RoutineExercise.fromJson(e)).toList()
        : [],
    isDynamicExercise: json['isDynamicExercise'] ?? false,
    executionType: routineExecutionTypeFromString(json['executionType']),
    circuitCycles: (json['circuitCycles'] as num?)?.toInt() ?? 3,
  );
}
