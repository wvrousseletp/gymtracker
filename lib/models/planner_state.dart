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
  final List<String> completedThisWeekRoutines; // IDs das rotinas concluídas nesta semana (usado para Metas Semanais)

  WorkoutStreak({
    required this.currentWeekCount,
    required this.consecutiveWeeks,
    required this.lastWorkoutDate,
    this.weekdaysTrained = const [],
    this.completedTodayRoutines = const [],
    this.completedThisWeekRoutines = const [],
  });

  Map<String, dynamic> toJson() => {
    'currentWeekCount': currentWeekCount,
    'consecutiveWeeks': consecutiveWeeks,
    'lastWorkoutDate': lastWorkoutDate,
    'weekdaysTrained': weekdaysTrained,
    'completedTodayRoutines': completedTodayRoutines,
    'completedThisWeekRoutines': completedThisWeekRoutines,
  };

  factory WorkoutStreak.fromJson(Map<String, dynamic> json) => WorkoutStreak(
    currentWeekCount: (json['currentWeekCount'] as num?)?.toInt() ?? 0,
    consecutiveWeeks: (json['consecutiveWeeks'] as num?)?.toInt() ?? 0,
    lastWorkoutDate: json['lastWorkoutDate'] ?? '',
    weekdaysTrained: (json['weekdaysTrained'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [],
    completedTodayRoutines: (json['completedTodayRoutines'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    completedThisWeekRoutines: (json['completedThisWeekRoutines'] as List?)?.map((e) => e.toString()).toList() ?? const [],
  );
}

class SettingsState {
  final bool sound;
  final bool vibration;
  final int prepSeconds;
  final OrganizationMode organizationMode;
  final int continuousListCurrentIndex;

  SettingsState({
    required this.sound,
    required this.vibration,
    required this.prepSeconds,
    this.organizationMode = OrganizationMode.fixedDays,
    this.continuousListCurrentIndex = 0,
  });

  Map<String, dynamic> toJson() => {
    'sound': sound,
    'vibration': vibration,
    'prepSeconds': prepSeconds,
    'organizationMode': organizationModeToString(organizationMode),
    'continuousListCurrentIndex': continuousListCurrentIndex,
  };

  factory SettingsState.fromJson(Map<String, dynamic> json) => SettingsState(
    sound: json['sound'] ?? true,
    vibration: json['vibration'] ?? true,
    prepSeconds: (json['prepSeconds'] as num?)?.toInt() ?? 5,
    organizationMode: json['organizationMode'] != null ? organizationModeFromString(json['organizationMode']) : OrganizationMode.fixedDays,
    continuousListCurrentIndex: (json['continuousListCurrentIndex'] as num?)?.toInt() ?? 0,
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
  final int? nextTargetReps;
  final double? nextTargetWeight;
  final bool isPrep;

  WatchRestTimer({
    required this.endTime,
    required this.totalSeconds,
    required this.nextExerciseName,
    required this.nextSetNum,
    this.nextTargetReps,
    this.nextTargetWeight,
    required this.isPrep,
  });

  Map<String, dynamic> toJson() => {
    'endTime': endTime,
    'totalSeconds': totalSeconds,
    'nextExerciseName': nextExerciseName,
    'nextSetNum': nextSetNum,
    'nextTargetReps': nextTargetReps,
    'nextTargetWeight': nextTargetWeight,
    'isPrep': isPrep,
  };

  factory WatchRestTimer.fromJson(Map<String, dynamic> json) => WatchRestTimer(
    endTime: (json['endTime'] as num?)?.toInt() ?? 0,
    totalSeconds: (json['totalSeconds'] as num?)?.toInt() ?? 0,
    nextExerciseName: json['nextExerciseName'] ?? '',
    nextSetNum: (json['nextSetNum'] as num?)?.toInt() ?? 0,
    nextTargetReps: (json['nextTargetReps'] as num?)?.toInt(),
    nextTargetWeight: (json['nextTargetWeight'] as num?)?.toDouble(),
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
  final RoutineExecutionType executionType;
  final int circuitCycles;

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
    this.executionType = RoutineExecutionType.standard,
    this.circuitCycles = 1,
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
    RoutineExecutionType? executionType,
    int? circuitCycles,
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
      executionType: executionType ?? this.executionType,
      circuitCycles: circuitCycles ?? this.circuitCycles,
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
    'executionType': routineExecutionTypeToString(executionType),
    'circuitCycles': circuitCycles,
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
        : WorkoutRecovery(sleepOk: SleepQuality.okay, pain: [], warmUpDone: false),
    isWarmup: json['isWarmup'] ?? false,
    warmupDurationSeconds: (json['warmupDurationSeconds'] as num?)?.toInt() ?? 0,
    paused: json['paused'] ?? false,
    restTimer: json['restTimer'] != null ? WatchRestTimer.fromJson(json['restTimer']) : null,
    postponed: json['postponed'] ?? false,
    heartRate: (json['heartRate'] as num?)?.toInt() ?? 0,
    activeCalories: (json['activeCalories'] as num?)?.toInt() ?? 0,
    executionType: routineExecutionTypeFromString(json['executionType']),
    circuitCycles: (json['circuitCycles'] as num?)?.toInt() ?? 1,
  );
}

class PlannerState {
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
  final Map<String, DietHistoryDay> dietHistory;
  final List<String> deletedHealthWorkoutIds;
  final List<String> unlockedBadgeIds;
  final List<ActiveWorkoutState> postponedWorkouts;

  PlannerState({
    required this.library,
    required this.routines,
    required this.planner,
    required this.history,
    required this.prs,
    required this.medidas,
    required this.settings,
    this.activeWorkout,
    List<ActiveWorkoutState>? postponedWorkouts,
    required this.diet,
    Map<String, DietHistoryDay>? dietHistory,
    WorkoutStreak? streak,
    List<String>? deletedHealthWorkoutIds,
    List<String>? unlockedBadgeIds,
  }) : dietHistory = dietHistory ?? {},
       deletedHealthWorkoutIds = deletedHealthWorkoutIds ?? [],
       unlockedBadgeIds = unlockedBadgeIds ?? [],
       postponedWorkouts = postponedWorkouts ?? [],
       streak = streak ??
            WorkoutStreak(
              currentWeekCount: 0,
              consecutiveWeeks: 0,
              lastWorkoutDate: '',
            );

  PlannerState copyWith({
    List<LibraryExercise>? library,
    List<Routine>? routines,
    Map<String, List<String>>? planner,
    List<WorkoutLog>? history,
    Map<String, PersonalRecord>? prs,
    List<BodyMeasurement>? medidas,
    SettingsState? settings,
    ActiveWorkoutState? activeWorkout,
    List<ActiveWorkoutState>? postponedWorkouts,
    bool clearActiveWorkout = false,
    DietState? diet,
    WorkoutStreak? streak,
    Map<String, DietHistoryDay>? dietHistory,
    List<String>? deletedHealthWorkoutIds,
    List<String>? unlockedBadgeIds,
  }) {
    return PlannerState(
      library: library ?? this.library,
      routines: routines ?? this.routines,
      planner: planner ?? this.planner,
      history: history ?? this.history,
      prs: prs ?? this.prs,
      medidas: medidas ?? this.medidas,
      settings: settings ?? this.settings,
      activeWorkout: clearActiveWorkout ? null : (activeWorkout ?? this.activeWorkout),
      postponedWorkouts: postponedWorkouts ?? this.postponedWorkouts,
      diet: diet ?? this.diet,
      streak: streak ?? this.streak,
      dietHistory: dietHistory ?? this.dietHistory,
      deletedHealthWorkoutIds: deletedHealthWorkoutIds ?? this.deletedHealthWorkoutIds,
      unlockedBadgeIds: unlockedBadgeIds ?? this.unlockedBadgeIds,
    );
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
    'postponedWorkouts': postponedWorkouts.map((w) => w.toJson()).toList(),
    'diet': diet.toJson(),
    'streak': streak.toJson(),
    'dietHistory': dietHistory.map((k, v) => MapEntry(k, v.toJson())),
    'deletedHealthWorkoutIds': deletedHealthWorkoutIds,
    'unlockedBadgeIds': unlockedBadgeIds,
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

    Map<String, DietHistoryDay> dietHistoryMap = {};
    if (json['dietHistory'] != null) {
      (json['dietHistory'] as Map).forEach((k, v) {
        dietHistoryMap[k.toString()] = DietHistoryDay.fromJson(Map<String, dynamic>.from(v));
      });
    }

    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

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
      postponedWorkouts: json['postponedWorkouts'] != null
          ? (json['postponedWorkouts'] as List).map((w) => ActiveWorkoutState.fromJson(w)).toList()
          : (json['postponedWorkout'] != null 
              ? [ActiveWorkoutState.fromJson(json['postponedWorkout'])]
              : []),
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
              lastDietDate: todayStr,
            ),
      streak: json['streak'] != null
          ? WorkoutStreak.fromJson(Map<String, dynamic>.from(json['streak']))
          : WorkoutStreak(currentWeekCount: 0, consecutiveWeeks: 0, lastWorkoutDate: ''),
      dietHistory: dietHistoryMap,
      deletedHealthWorkoutIds: json['deletedHealthWorkoutIds'] != null 
          ? List<String>.from(json['deletedHealthWorkoutIds'])
          : [],
      unlockedBadgeIds: json['unlockedBadgeIds'] != null
          ? List<String>.from(json['unlockedBadgeIds'])
          : [],
    );
  }
}
