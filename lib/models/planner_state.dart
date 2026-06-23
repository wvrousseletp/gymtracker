import 'exercise.dart';
import 'routine.dart';
import 'workout_log.dart';
import 'medidas.dart';
import 'diet.dart';

class WorkoutStreak {
  final int currentWeekCount;   // Treinos feitos na semana atual
  final int consecutiveWeeks;   // Semanas consecutivas com pelo menos 1 treino
  final String lastWorkoutDate; // ISO8601
  final List<int> weekdaysTrained; // Dias da semana treinados (1 = Segunda, 7 = Domingo)
  final List<String> completedTodayRoutines; // Rotinas concluídas hoje

  WorkoutStreak({
    required this.currentWeekCount,
    required this.consecutiveWeeks,
    required this.lastWorkoutDate,
    this.weekdaysTrained = const [],
    this.completedTodayRoutines = const [],
  });

  Map<String, dynamic> toJson() => {
    'currentWeekCount': currentWeekCount,
    'consecutiveWeeks': consecutiveWeeks,
    'lastWorkoutDate': lastWorkoutDate,
    'weekdaysTrained': weekdaysTrained,
    'completedTodayRoutines': completedTodayRoutines,
  };

  factory WorkoutStreak.fromJson(Map<String, dynamic> json) => WorkoutStreak(
    currentWeekCount: (json['currentWeekCount'] as num?)?.toInt() ?? 0,
    consecutiveWeeks: (json['consecutiveWeeks'] as num?)?.toInt() ?? 0,
    lastWorkoutDate: json['lastWorkoutDate'] ?? '',
    weekdaysTrained: (json['weekdaysTrained'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [],
    completedTodayRoutines: (json['completedTodayRoutines'] as List?)?.map((e) => e.toString()).toList() ?? const [],
  );
}

class SettingsState {
  final bool sound;
  final bool vibration;
  final int prepSeconds;

  SettingsState({
    required this.sound,
    required this.vibration,
    required this.prepSeconds,
  });

  Map<String, dynamic> toJson() => {
    'sound': sound,
    'vibration': vibration,
    'prepSeconds': prepSeconds,
  };

  factory SettingsState.fromJson(Map<String, dynamic> json) => SettingsState(
    sound: json['sound'] ?? true,
    vibration: json['vibration'] ?? true,
    prepSeconds: (json['prepSeconds'] as num?)?.toInt() ?? 5,
  );
}

class PersonalRecord {
  final double weight;
  final int reps;
  final String date;
  final String routineName;

  PersonalRecord({
    required this.weight,
    required this.reps,
    required this.date,
    required this.routineName,
  });

  Map<String, dynamic> toJson() => {
    'weight': weight,
    'reps': reps,
    'date': date,
    'routineName': routineName,
  };

  factory PersonalRecord.fromJson(Map<String, dynamic> json) => PersonalRecord(
    weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
    reps: (json['reps'] as num?)?.toInt() ?? 0,
    date: json['date'] ?? '',
    routineName: json['routineName'] ?? '',
  );
}

class WatchRestTimer {
  final int endTime; // Epoch milissegundos
  final int totalSeconds;
  final String nextExerciseName;
  final int nextSetNum;
  final bool isPrep;

  WatchRestTimer({
    required this.endTime,
    required this.totalSeconds,
    required this.nextExerciseName,
    required this.nextSetNum,
    required this.isPrep,
  });

  Map<String, dynamic> toJson() => {
    'endTime': endTime,
    'totalSeconds': totalSeconds,
    'nextExerciseName': nextExerciseName,
    'nextSetNum': nextSetNum,
    'isPrep': isPrep,
  };

  factory WatchRestTimer.fromJson(Map<String, dynamic> json) => WatchRestTimer(
    endTime: (json['endTime'] as num?)?.toInt() ?? 0,
    totalSeconds: (json['totalSeconds'] as num?)?.toInt() ?? 0,
    nextExerciseName: json['nextExerciseName'] ?? '',
    nextSetNum: (json['nextSetNum'] as num?)?.toInt() ?? 0,
    isPrep: json['isPrep'] ?? false,
  );
}

class ActiveWorkoutState {
  final String name;
  final int startTime; // Epoch milissegundos
  final List<ActiveExercise> exercises;
  final int currentExerciseIndex;
  final int elapsedSeconds;
  final WorkoutRecovery recovery;
  final bool isWarmup;
  final int warmupDurationSeconds;
  final bool paused;
  final WatchRestTimer? restTimer;
  final bool postponed;
  final int heartRate;
  final int activeCalories;

  ActiveWorkoutState({
    required this.name,
    required this.startTime,
    required this.exercises,
    required this.currentExerciseIndex,
    required this.elapsedSeconds,
    required this.recovery,
    required this.isWarmup,
    required this.warmupDurationSeconds,
    this.paused = false,
    this.restTimer,
    this.postponed = false,
    this.heartRate = 0,
    this.activeCalories = 0,
  });

  ActiveWorkoutState copyWith({
    String? name,
    int? startTime,
    List<ActiveExercise>? exercises,
    int? currentExerciseIndex,
    int? elapsedSeconds,
    WorkoutRecovery? recovery,
    bool? isWarmup,
    int? warmupDurationSeconds,
    bool? paused,
    WatchRestTimer? restTimer,
    bool? postponed,
    int? heartRate,
    int? activeCalories,
  }) {
    return ActiveWorkoutState(
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      exercises: exercises ?? this.exercises,
      currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      recovery: recovery ?? this.recovery,
      isWarmup: isWarmup ?? this.isWarmup,
      warmupDurationSeconds: warmupDurationSeconds ?? this.warmupDurationSeconds,
      paused: paused ?? this.paused,
      restTimer: restTimer ?? this.restTimer,
      postponed: postponed ?? this.postponed,
      heartRate: heartRate ?? this.heartRate,
      activeCalories: activeCalories ?? this.activeCalories,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'startTime': startTime,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'currentExerciseIndex': currentExerciseIndex,
    'elapsedSeconds': elapsedSeconds,
    'recovery': recovery.toJson(),
    'isWarmup': isWarmup,
    'warmupDurationSeconds': warmupDurationSeconds,
    'paused': paused,
    'restTimer': restTimer?.toJson(),
    'postponed': postponed,
    'heartRate': heartRate,
    'activeCalories': activeCalories,
  };

  factory ActiveWorkoutState.fromJson(Map<String, dynamic> json) => ActiveWorkoutState(
    name: json['name'] ?? '',
    startTime: (json['startTime'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    exercises: json['exercises'] != null
        ? (json['exercises'] as List).map((e) => ActiveExercise.fromJson(e)).toList()
        : [],
    currentExerciseIndex: (json['currentExerciseIndex'] as num?)?.toInt() ?? 0,
    elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
    recovery: json['recovery'] != null
        ? WorkoutRecovery.fromJson(json['recovery'])
        : WorkoutRecovery(sleepOk: 'ok', pain: [], warmUpDone: false),
    isWarmup: json['isWarmup'] ?? false,
    warmupDurationSeconds: (json['warmupDurationSeconds'] as num?)?.toInt() ?? 0,
    paused: json['paused'] ?? false,
    restTimer: json['restTimer'] != null ? WatchRestTimer.fromJson(json['restTimer']) : null,
    postponed: json['postponed'] ?? false,
    heartRate: (json['heartRate'] as num?)?.toInt() ?? 0,
    activeCalories: (json['activeCalories'] as num?)?.toInt() ?? 0,
  );
}

class PlannerState {
  static WorkoutStreak? currentStreak;

  final List<LibraryExercise> library;
  final List<Routine> routines;
  final Map<String, List<String>> planner; // Dia -> lista de strings de ID/Prefixo
  final List<WorkoutLog> history;
  final Map<String, PersonalRecord> prs; // exerciseId -> record
  final List<BodyMeasurement> medidas;
  final SettingsState settings;
  final ActiveWorkoutState? activeWorkout;
  final DietState diet;
  final WorkoutStreak streak;

  PlannerState({
    required this.library,
    required this.routines,
    required this.planner,
    required this.history,
    required this.prs,
    required this.medidas,
    required this.settings,
    this.activeWorkout,
    required this.diet,
    WorkoutStreak? streak,
  }) : streak = streak ?? PlannerState.currentStreak ?? WorkoutStreak(currentWeekCount: 0, consecutiveWeeks: 0, lastWorkoutDate: '') {
    PlannerState.currentStreak = this.streak;
  }

  Map<String, dynamic> toJson() => {
    'library': library.map((e) => e.toJson()).toList(),
    'routines': routines.map((r) => r.toJson()).toList(),
    'planner': planner,
    'history': history.map((h) => h.toJson()).toList(),
    'prs': prs.map((k, v) => MapEntry(k, v.toJson())),
    'medidas': medidas.map((m) => m.toJson()).toList(),
    'settings': settings.toJson(),
    'activeWorkout': activeWorkout?.toJson(),
    'diet': diet.toJson(),
    'streak': streak.toJson(),
  };

  factory PlannerState.fromJson(Map<String, dynamic> json) {
    Map<String, List<String>> plannerMap = {};
    if (json['planner'] != null) {
      (json['planner'] as Map).forEach((k, v) {
        plannerMap[k.toString()] = List<String>.from(v);
      });
    }

    Map<String, PersonalRecord> prsMap = {};
    if (json['prs'] != null) {
      (json['prs'] as Map).forEach((k, v) {
        prsMap[k.toString()] = PersonalRecord.fromJson(Map<String, dynamic>.from(v));
      });
    }

    return PlannerState(
      library: json['library'] != null
          ? (json['library'] as List).map((e) => LibraryExercise.fromJson(e)).toList()
          : [],
      routines: json['routines'] != null
          ? (json['routines'] as List).map((r) => Routine.fromJson(r)).toList()
          : [],
      planner: plannerMap,
      history: json['history'] != null
          ? (json['history'] as List).map((h) => WorkoutLog.fromJson(h)).toList()
          : [],
      prs: prsMap,
      medidas: json['medidas'] != null
          ? (json['medidas'] as List).map((m) => BodyMeasurement.fromJson(m)).toList()
          : [],
      settings: json['settings'] != null
          ? SettingsState.fromJson(json['settings'])
          : SettingsState(sound: true, vibration: true, prepSeconds: 5),
      activeWorkout: json['activeWorkout'] != null
          ? ActiveWorkoutState.fromJson(json['activeWorkout'])
          : null,
      diet: json['diet'] != null
          ? DietState.fromJson(json['diet'])
          : DietState(
              caloriesGoal: 2000,
              proteinGoal: 150.0,
              carbsGoal: 200.0,
              fatGoal: 70.0,
              waterGoalMl: 2000,
              meals: [],
              waterIntakeMl: 0,
              fasting: FastingState(history: []),
              abstinence: [],
            ),
      streak: json['streak'] != null
          ? WorkoutStreak.fromJson(Map<String, dynamic>.from(json['streak']))
          : WorkoutStreak(currentWeekCount: 0, consecutiveWeeks: 0, lastWorkoutDate: ''),
    );
  }
}
