import 'exercise.dart';

class Routine {
  final String id;
  final String name;
  final int defaultRest;
  final List<RoutineExercise> exercises;
  final bool isDynamicExercise; // Se foi gerado dinamicamente para um exercício avulso

  Routine({
    required this.id,
    required this.name,
    required this.defaultRest,
    required this.exercises,
    this.isDynamicExercise = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'defaultRest': defaultRest,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'isDynamicExercise': isDynamicExercise,
  };

  factory Routine.fromJson(Map<String, dynamic> json) => Routine(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    defaultRest: (json['defaultRest'] as num?)?.toInt() ?? 60,
    exercises: json['exercises'] != null
        ? (json['exercises'] as List).map((e) => RoutineExercise.fromJson(e)).toList()
        : [],
    isDynamicExercise: json['isDynamicExercise'] ?? false,
  );
}
