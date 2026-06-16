class Meal {
  final String id;
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final String time;

  Meal({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'time': time,
  };

  factory Meal.fromJson(Map<String, dynamic> json) => Meal(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    calories: (json['calories'] as num?)?.toInt() ?? 0,
    protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
    carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
    fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
    time: json['time'] ?? '',
  );
}

class FastingRecord {
  final String id;
  final String startTime; // ISO String
  final String? endTime; // ISO String ou null
  final double goalDurationHours;

  FastingRecord({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.goalDurationHours,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'startTime': startTime,
    'endTime': endTime,
    'goalDurationHours': goalDurationHours,
  };

  factory FastingRecord.fromJson(Map<String, dynamic> json) => FastingRecord(
    id: json['id'] ?? '',
    startTime: json['startTime'] ?? '',
    endTime: json['endTime'],
    goalDurationHours: (json['goalDurationHours'] as num?)?.toDouble() ?? 16.0,
  );
}

class ActiveFasting {
  final String startTime; // ISO String
  final double goalDurationHours;

  ActiveFasting({
    required this.startTime,
    required this.goalDurationHours,
  });

  Map<String, dynamic> toJson() => {
    'startTime': startTime,
    'goalDurationHours': goalDurationHours,
  };

  factory ActiveFasting.fromJson(Map<String, dynamic> json) => ActiveFasting(
    startTime: json['startTime'] ?? '',
    goalDurationHours: (json['goalDurationHours'] as num?)?.toDouble() ?? 16.0,
  );
}

class FastingState {
  final List<FastingRecord> history;
  final ActiveFasting? active;

  FastingState({
    required this.history,
    this.active,
  });

  Map<String, dynamic> toJson() => {
    'history': history.map((h) => h.toJson()).toList(),
    'active': active?.toJson(),
  };

  factory FastingState.fromJson(Map<String, dynamic> json) => FastingState(
    history: json['history'] != null
        ? (json['history'] as List).map((h) => FastingRecord.fromJson(h)).toList()
        : [],
    active: json['active'] != null ? ActiveFasting.fromJson(json['active']) : null,
  );
}

class DietState {
  final int caloriesGoal;
  final double proteinGoal;
  final double carbsGoal;
  final double fatGoal;
  final int waterGoalMl;
  final List<Meal> meals;
  final int waterIntakeMl;
  final FastingState fasting;

  DietState({
    required this.caloriesGoal,
    required this.proteinGoal,
    required this.carbsGoal,
    required this.fatGoal,
    required this.waterGoalMl,
    required this.meals,
    required this.waterIntakeMl,
    required this.fasting,
  });

  Map<String, dynamic> toJson() => {
    'caloriesGoal': caloriesGoal,
    'proteinGoal': proteinGoal,
    'carbsGoal': carbsGoal,
    'fatGoal': fatGoal,
    'waterGoalMl': waterGoalMl,
    'meals': meals.map((m) => m.toJson()).toList(),
    'waterIntakeMl': waterIntakeMl,
    'fasting': fasting.toJson(),
  };

  factory DietState.fromJson(Map<String, dynamic> json) => DietState(
    caloriesGoal: (json['caloriesGoal'] as num?)?.toInt() ?? 2000,
    proteinGoal: (json['proteinGoal'] as num?)?.toDouble() ?? 150.0,
    carbsGoal: (json['carbsGoal'] as num?)?.toDouble() ?? 200.0,
    fatGoal: (json['fatGoal'] as num?)?.toDouble() ?? 70.0,
    waterGoalMl: (json['waterGoalMl'] as num?)?.toInt() ?? 2000,
    meals: json['meals'] != null
        ? (json['meals'] as List).map((m) => Meal.fromJson(m)).toList()
        : [],
    waterIntakeMl: (json['waterIntakeMl'] as num?)?.toInt() ?? 0,
    fasting: json['fasting'] != null
        ? FastingState.fromJson(json['fasting'])
        : FastingState(history: []),
  );
}
