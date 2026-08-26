import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/exercise.dart';
import '../models/routine.dart';
import '../models/workout_log.dart';
import '../models/medidas.dart';
import '../models/planner_state.dart';
import '../services/watch_service.dart';
import '../services/rest_timer_service.dart';
import '../services/state_persistence_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/health_service.dart';
import '../models/profile.dart';
import '../utils/date_utils.dart';
import '../utils/default_exercises_data.dart';
import 'profile_provider.dart';
import '../services/badges_service.dart';

class WorkoutProvider extends ChangeNotifier {
  final StatePersistenceService _persistence = StatePersistenceService();
  final FirebaseSyncService _firebaseSync = FirebaseSyncService();

  List<LibraryExercise> library = [];
  List<Routine> routines = [];
  Map<String, List<String>> planner = {};
  Map<String, List<String>>? _previousPlanner;
  String? _lastRestLogId;
  List<WorkoutLog> history = [];
  Map<String, PersonalRecord> prs = {};
  Map<String, String> exerciseNotes = {};
  List<BodyMeasurement> medidas = [];
  SettingsState settings =
      SettingsState(sound: true, vibration: true, prepSeconds: 5);
  ActiveWorkoutState? _activeWorkout;

  ActiveWorkoutState? get activeWorkout {
    if (_activeWorkout != null && !_activeWorkout!.paused) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final newElapsed = ((now - _activeWorkout!.startTime) / 1000).round();
      if (newElapsed != _activeWorkout!.elapsedSeconds) {
        _activeWorkout = _activeWorkout!.copyWith(elapsedSeconds: newElapsed);
      }
    }
    return _activeWorkout;
  }

  List<String> get todayPlannedItems {
    final mode = settings.organizationMode;

    if (mode == OrganizationMode.continuousList) {
      final list = planner['continuous'] ?? [];
      if (list.isEmpty) return [];
      final idx = settings.continuousListCurrentIndex % list.length;
      return [list[idx]];
    } else if (mode == OrganizationMode.weeklyGoals) {
      final list = planner['weekly'] ?? [];
      final completed = streak.completedThisWeekRoutines;
      final remaining = list.where((id) {
        final actualId = id.startsWith('routine:') ? id.substring(8) : id;
        final routine = routines.firstWhere((r) => r.id == actualId,
            orElse: () =>
                Routine(id: '', name: '', defaultRest: 0, exercises: []));
        if (routine.id.isEmpty) return false;
        return !completed.contains(routine.name);
      }).toList();
      if (remaining.isEmpty) return [];
      return [remaining.first];
    }

    // Default: fixedDays
    final weekday = DateTime.now().weekday;
    String todayKey;
    switch (weekday) {
      case 1:
        todayKey = 'seg';
        break;
      case 2:
        todayKey = 'ter';
        break;
      case 3:
        todayKey = 'qua';
        break;
      case 4:
        todayKey = 'qui';
        break;
      case 5:
        todayKey = 'sex';
        break;
      case 6:
        todayKey = 'sab';
        break;
      case 7:
        todayKey = 'dom';
        break;
      default:
        todayKey = 'seg';
    }
    return planner[todayKey] ?? [];
  }

  set activeWorkout(ActiveWorkoutState? value) {
    _activeWorkout = value;
  }

  List<ActiveWorkoutState> postponedWorkouts = [];
  List<String> deletedHealthWorkoutIds = [];
  List<String> unlockedBadgeIds = [];
  WorkoutStreak streak = WorkoutStreak(
      currentWeekCount: 0, consecutiveWeeks: 0, lastWorkoutDate: '');

  bool historyLoaded = false;
  DateTime? _lastHealthMetricsNotify;
  static const Duration _healthMetricsNotifyInterval = Duration(seconds: 5);

  String currentUserId = '';
  Profile? currentProfile;
  VoidCallback? onStateChanged;

  // Cache para a biblioteca de exercícios agrupada por músculo
  Map<String, List<LibraryExercise>>? _muscleGroupedCache;

  // Cache para rotinas agrupadas por músculo
  Map<String, List<Routine>>? _muscleRoutinesCache;

  // Cache para histórico filtrado por data
  Map<String, List<WorkoutLog>>? _historyByDateCache;

  // Track which properties changed for selective notifications
  final Set<String> _changedProperties = {};

  Map<String, List<LibraryExercise>> get muscleGroupedExercises {
    if (_muscleGroupedCache != null) return _muscleGroupedCache!;
    final grouped = <String, List<LibraryExercise>>{};
    for (final ex in library) {
      grouped.putIfAbsent(ex.muscle, () => []).add(ex);
    }
    _muscleGroupedCache = grouped;
    return grouped;
  }

  Map<String, List<Routine>> get muscleGroupedRoutines {
    if (_muscleRoutinesCache != null) return _muscleRoutinesCache!;
    final grouped = <String, List<Routine>>{};
    for (final routine in routines) {
      for (final ex in routine.exercises) {
        final ref = library.firstWhere(
          (l) => l.id == ex.exerciseId,
          orElse: () => LibraryExercise(
            id: ex.exerciseId,
            name: 'Exercício',
            muscle: 'Geral',
            measurementType: MeasurementType.reps,
          ),
        );
        grouped.putIfAbsent(ref.muscle, () => []).add(routine);
      }
    }
    _muscleRoutinesCache = grouped;
    return grouped;
  }

  List<WorkoutLog> getHistoryByDateRange(DateTime start, DateTime end) {
    final cacheKey = '${start.toIso8601String()}-${end.toIso8601String()}';
    if (_historyByDateCache != null &&
        _historyByDateCache!.containsKey(cacheKey)) {
      return _historyByDateCache![cacheKey]!;
    }

    final filtered = history.where((log) {
      final logDate = DateTime.parse(log.date);
      return logDate.isAfter(start.subtract(const Duration(days: 1))) &&
          logDate.isBefore(end.add(const Duration(days: 1)));
    }).toList();

    _historyByDateCache ??= {};
    _historyByDateCache![cacheKey] = filtered;
    return filtered;
  }

  // Estados de erro/loading granular específicos por operação
  bool isSavingWorkout = false;
  bool isAddingExercise = false;
  bool isDeletingPR = false;

  void updateProfile(ProfileProvider profileProvider) {
    currentUserId = profileProvider.currentUserId;
    currentProfile = profileProvider.currentProfile;
  }

  void _save({Set<String>? changedProperties}) {
    _muscleGroupedCache = null; // Invalida o cache
    _muscleRoutinesCache = null; // Invalida o cache de rotinas
    _historyByDateCache = null; // Invalida o cache de histórico
    if (changedProperties != null) {
      _changedProperties.addAll(changedProperties);
    }
    notifyListeners();
    onStateChanged?.call();
    _changedProperties.clear();
  }

  // Check if specific property changed
  bool didPropertyChange(String property) {
    return _changedProperties.contains(property);
  }

  // --- WORKOUT OPERATIONS ---
  void startWorkout(Routine routine, WorkoutRecovery recovery, bool isWarmup) {
    List<ActiveExercise> workoutExercises = [];

    if (routine.executionType == RoutineExecutionType.circuit) {
      final cycles = routine.circuitCycles > 0 ? routine.circuitCycles : 1;
      for (int cycle = 0; cycle < cycles; cycle++) {
        for (int i = 0; i < routine.exercises.length; i++) {
          final ex = routine.exercises[i];
          final ref = library.firstWhere(
            (l) => l.id == ex.exerciseId,
            orElse: () => LibraryExercise(
              id: ex.exerciseId,
              name: 'Exercício',
              muscle: 'Geral',
              measurementType: MeasurementType.reps,
            ),
          );

          final isCardio = (ex.isCardio ||
                  ref.measurementType == MeasurementType.cardio ||
                  ref.measurementType == MeasurementType.distance) &&
              ref.measurementType != MeasurementType.time;

          const effectiveSets = 1;

          // Se por acaso havia configurações de peso/rep por set antes de virar ciclo,
          // tentamos resgatar para a iteração (cycle) correspondente, senão usamos o padrão.
          final cycleWeight =
              (ex.weightsPerSet != null && ex.weightsPerSet!.length > cycle)
                  ? ex.weightsPerSet![cycle]
                  : ex.weight;
          final cycleReps =
              (ex.repsPerSet != null && ex.repsPerSet!.length > cycle)
                  ? ex.repsPerSet![cycle]
                  : ex.reps;

          workoutExercises.add(ActiveExercise(
            id: '${ex.id}_cycle_$cycle',
            name: ref.name,
            muscle: ref.muscle,
            executionType: ref.executionType,
            measurementType: ref.measurementType,
            sets: effectiveSets,
            reps: cycleReps,
            rest: ex.rest,
            weight: cycleWeight,
            weightsPerSet: null, // Achado, então usa o global
            repsPerSet: null, // Achatado
            setsState: List<bool>.filled(effectiveSets, false),
            performedCardios:
                List<PerformedCardio?>.filled(effectiveSets, null),
            failureReport: List<bool>.filled(effectiveSets, false),
            isCardio: isCardio,
            allowCardioSets: false,
          ));
        }
      }
    } else {
      workoutExercises = routine.exercises.map((ex) {
        final ref = library.firstWhere(
          (l) => l.id == ex.exerciseId,
          orElse: () => LibraryExercise(
            id: ex.exerciseId,
            name: 'Exercício',
            muscle: 'Geral',
            measurementType: MeasurementType.reps,
          ),
        );

        final isCardio = (ex.isCardio ||
                ref.measurementType == MeasurementType.cardio ||
                ref.measurementType == MeasurementType.distance) &&
            ref.measurementType != MeasurementType.time;

        final effectiveSets = (isCardio && !ex.allowCardioSets) ? 1 : ex.sets;

        return ActiveExercise(
          id: ex.id,
          name: ref.name,
          muscle: ref.muscle,
          executionType: ref.executionType,
          measurementType: ref.measurementType,
          sets: effectiveSets,
          reps: ex.reps,
          rest: ex.rest,
          weight: ex.weight,
          weightsPerSet: ex.weightsPerSet,
          repsPerSet: ex.repsPerSet,
          setsState: List<bool>.filled(effectiveSets, false),
          performedCardios: List<PerformedCardio?>.filled(effectiveSets, null),
          failureReport: List<bool>.filled(effectiveSets, false),
          isCardio: isCardio,
          allowCardioSets: ex.allowCardioSets,
        );
      }).toList();
    }

    activeWorkout = ActiveWorkoutState(
      name: routine.name,
      startTime: DateTime.now().millisecondsSinceEpoch,
      exercises: workoutExercises,
      currentExerciseIndex: 0,
      elapsedSeconds: 0,
      recovery: recovery,
      isWarmup: isWarmup,
      warmupDurationSeconds: 0,
      executionType: routine.executionType,
      circuitCycles: routine.circuitCycles,
    );

    _save();
    WatchService.instance.prepareWatchApp();
    WatchService.instance.sendActiveWorkout(activeWorkout!, force: true);
  }

  void startSingleExercise(LibraryExercise exercise) {
    // Determine if this is a cardio exercise based on measurement type
    final isCardio = (exercise.measurementType == MeasurementType.cardio ||
            exercise.measurementType == MeasurementType.distance) &&
        exercise.measurementType != MeasurementType.time;

    final tempRoutine = Routine(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      name: exercise.name,
      defaultRest: 60,
      isDynamicExercise: true,
      exercises: [
        RoutineExercise(
          id: 'temp_ex_${DateTime.now().millisecondsSinceEpoch}',
          exerciseId: exercise.id,
          sets: isCardio ? 1 : 3, // Cardio uses 1 set by default
          reps: isCardio ? 0 : 10, // Cardio doesn't use reps
          rest: 60,
          weight: 0.0,
          isCardio: isCardio,
          allowCardioSets: false, // Single exercise defaults to no sets
        )
      ],
    );
    startWorkout(
        tempRoutine,
        WorkoutRecovery(
            sleepOk: SleepQuality.okay, pain: [], warmUpDone: false),
        false);
  }

  void completeSet(int exIndex, int setIndex, bool isDone,
      {double? distance,
      int? duration,
      bool isFailure = false,
      int? failureRep}) {
    if (activeWorkout == null) return;

    HapticFeedback.lightImpact();

    final active = activeWorkout!;
    final exercises = List<ActiveExercise>.from(active.exercises);
    final ex = exercises[exIndex];

    // For cardio exercises without sets, store in singleCardioSession instead
    if (ex.isCardio && !ex.allowCardioSets) {
      if (distance != null && duration != null) {
        exercises[exIndex] = ActiveExercise(
          id: ex.id,
          name: ex.name,
          muscle: ex.muscle,
          executionType: ex.executionType,
          measurementType: ex.measurementType,
          sets: ex.sets,
          reps: ex.reps,
          rest: ex.rest,
          weight: ex.weight,
          weightsPerSet: ex.weightsPerSet,
          repsPerSet: ex.repsPerSet,
          setsState: List<bool>.filled(1, isDone), // Mark as completed
          performedCardios: [
            PerformedCardio(distanceKm: distance, durationSeconds: duration)
          ],
          failureReport: List<bool>.filled(1, false),
          failureReps: List<int?>.filled(1, null),
          isCardio: ex.isCardio,
          allowCardioSets: ex.allowCardioSets,
          singleCardioSession:
              PerformedCardio(distanceKm: distance, durationSeconds: duration),
        );
        activeWorkout = active.copyWith(exercises: exercises);
        _save();
        return;
      }
    }

    final newSetsState = List<bool>.from(ex.setsState);
    newSetsState[setIndex] = isDone;

    final newCardios = List<PerformedCardio?>.from(ex.performedCardios);
    if (distance != null && duration != null) {
      newCardios[setIndex] =
          PerformedCardio(distanceKm: distance, durationSeconds: duration);
    }

    final newFailure = List<bool>.from(ex.failureReport);
    newFailure[setIndex] = isFailure;

    final newFailureReps = List<int?>.from(ex.failureReps);
    newFailureReps[setIndex] = isFailure ? failureRep : null;

    exercises[exIndex] = ActiveExercise(
      id: ex.id,
      name: ex.name,
      muscle: ex.muscle,
      executionType: ex.executionType,
      measurementType: ex.measurementType,
      sets: ex.sets,
      reps: ex.reps,
      rest: ex.rest,
      weight: ex.weight,
      weightsPerSet: ex.weightsPerSet,
      repsPerSet: ex.repsPerSet,
      setsState: newSetsState,
      performedCardios: newCardios,
      failureReport: newFailure,
      failureReps: newFailureReps,
      isCardio: ex.isCardio,
      allowCardioSets: ex.allowCardioSets,
      singleCardioSession: ex.singleCardioSession,
    );

    WatchRestTimer? computedRestTimer = active.restTimer;
    int computedExIndex = active.currentExerciseIndex;

    final bool wasDone =
        setIndex < ex.setsState.length ? ex.setsState[setIndex] : false;
    final bool isTransitionToDone = !wasDone && isDone;
    final bool isStateChanged = wasDone != isDone;

    bool shouldRest = ex.rest > 0;
    if (shouldRest && active.executionType == RoutineExecutionType.circuit && active.circuitCycles > 0) {
      final exercisesPerCycle = exercises.length ~/ active.circuitCycles;
      if (exercisesPerCycle > 0) {
        final isCycleEnd = (exIndex + 1) % exercisesPerCycle == 0;
        if (!isCycleEnd) {
          shouldRest = false;
        }
      }
    }

    if (isTransitionToDone && shouldRest) {
      if (setIndex < ex.sets - 1) {
        final endTime =
            DateTime.now().millisecondsSinceEpoch + (ex.rest * 1000);
        computedRestTimer = WatchRestTimer(
          endTime: endTime,
          totalSeconds: ex.rest,
          nextExerciseName: ex.name,
          nextSetNum: setIndex + 2,
          nextTargetReps: ex.repsPerSet?[setIndex + 1] ?? ex.reps,
          nextTargetWeight: ex.weightsPerSet?[setIndex + 1] ?? ex.weight,
          isPrep: false,
        );
      } else if (exIndex < exercises.length - 1) {
        final nextEx = exercises[exIndex + 1];
        final endTime =
            DateTime.now().millisecondsSinceEpoch + (ex.rest * 1000);
        computedRestTimer = WatchRestTimer(
          endTime: endTime,
          totalSeconds: ex.rest,
          nextExerciseName: nextEx.name,
          nextSetNum: 1,
          nextTargetReps: nextEx.repsPerSet?[0] ?? nextEx.reps,
          nextTargetWeight: nextEx.weightsPerSet?[0] ?? nextEx.weight,
          isPrep: false,
        );
        computedExIndex = exIndex + 1;
      } else {
        computedRestTimer = null;
      }
    } else {
      computedRestTimer = null;
      if (isTransitionToDone && setIndex >= ex.sets - 1 && exIndex < exercises.length - 1) {
         computedExIndex = exIndex + 1;
      }
    }

    activeWorkout = active.copyWith(
      exercises: exercises,
      currentExerciseIndex: computedExIndex,
      restTimer: computedRestTimer,
    );

    _save();

    if (isStateChanged) {
      if (computedRestTimer != null) {
        RestTimerService.instance.start(
          endTimeMs: computedRestTimer.endTime,
          seconds: computedRestTimer.totalSeconds,
          prep: computedRestTimer.isPrep,
          exName: computedRestTimer.nextExerciseName,
          setNum: computedRestTimer.nextSetNum,
          targetReps: computedRestTimer.nextTargetReps,
          targetWeight: computedRestTimer.nextTargetWeight,
        );
      } else {
        RestTimerService.instance.clear();
      }
    }
  }

  void startRestTimer(
      int seconds, String nextExName, int nextSetNum, bool isPrep) {
    if (activeWorkout == null) return;
    final active = activeWorkout!;

    int? targetReps;
    double? targetWeight;
    final exIndex = active.exercises.indexWhere((e) => e.name == nextExName);
    if (exIndex != -1) {
      final nextEx = active.exercises[exIndex];
      final setIdx = (nextSetNum - 1).clamp(0, nextEx.sets - 1);
      targetReps = nextEx.repsPerSet?[setIdx] ?? nextEx.reps;
      targetWeight = nextEx.weightsPerSet?[setIdx] ?? nextEx.weight;
    }

    final endTime = DateTime.now().millisecondsSinceEpoch + (seconds * 1000);
    final restTimer = WatchRestTimer(
      endTime: endTime,
      totalSeconds: seconds,
      nextExerciseName: nextExName,
      nextSetNum: nextSetNum,
      nextTargetReps: targetReps,
      nextTargetWeight: targetWeight,
      isPrep: isPrep,
    );

    activeWorkout = active.copyWith(
      restTimer: restTimer,
    );

    _save();

    RestTimerService.instance.start(
      endTimeMs: endTime,
      seconds: seconds,
      prep: isPrep,
      exName: nextExName,
      setNum: nextSetNum,
      targetReps: targetReps,
      targetWeight: targetWeight,
    );
  }

  void clearRestTimer() {
    if (activeWorkout == null) return;
    final active = activeWorkout!;

    activeWorkout = active.copyWith(
      restTimer: null,
    );

    _save();
    RestTimerService.instance.clear();
  }

  void updateExerciseWeightReps(int exIndex, double weight, int reps) {
    if (activeWorkout == null) return;
    final active = activeWorkout!;
    final exercises = List<ActiveExercise>.from(active.exercises);
    if (exIndex >= exercises.length) return;

    final ex = exercises[exIndex];
    exercises[exIndex] = ActiveExercise(
      id: ex.id,
      name: ex.name,
      muscle: ex.muscle,
      executionType: ex.executionType,
      measurementType: ex.measurementType,
      sets: ex.sets,
      reps: reps,
      rest: ex.rest,
      weight: weight,
      weightsPerSet: ex.weightsPerSet,
      repsPerSet: ex.repsPerSet,
      setsState: ex.setsState,
      performedCardios: ex.performedCardios,
      failureReport: ex.failureReport,
      failureReps: ex.failureReps,
    );

    activeWorkout = active.copyWith(
      exercises: exercises,
    );

    _save();
  }


  void updateExerciseSetType(int exIdx, int setIdx, String type) {
    if (_activeWorkout == null) return;
    final ex = _activeWorkout!.exercises[exIdx];
    final types = ex.setTypes != null ? List<String>.from(ex.setTypes!) : List<String>.filled(ex.sets, 'N');
    if (setIdx < types.length) {
      types[setIdx] = type;
      _activeWorkout!.exercises[exIdx] = ActiveExercise(
        id: ex.id,
        name: ex.name,
        muscle: ex.muscle,
        executionType: ex.executionType,
        measurementType: ex.measurementType,
        sets: ex.sets,
        reps: ex.reps,
        rest: ex.rest,
        weight: ex.weight,
        setsState: ex.setsState,
        performedCardios: ex.performedCardios,
        failureReport: ex.failureReport,
        failureReps: ex.failureReps,
        weightsPerSet: ex.weightsPerSet,
        repsPerSet: ex.repsPerSet,
        setTypes: types,
        rirPerSet: ex.rirPerSet,
        isCardio: ex.isCardio,
        allowCardioSets: ex.allowCardioSets,
        isStationary: ex.isStationary,
        singleCardioSession: ex.singleCardioSession,
        
      );
      _save();
    }
  }

  void updateExerciseRir(int exIdx, int setIdx, int? rir) {
    if (_activeWorkout == null) return;
    final ex = _activeWorkout!.exercises[exIdx];
    final rirs = ex.rirPerSet != null ? List<int?>.from(ex.rirPerSet!) : List<int?>.filled(ex.sets, null);
    if (setIdx < rirs.length) {
      rirs[setIdx] = rir;
      _activeWorkout!.exercises[exIdx] = ActiveExercise(
        id: ex.id,
        name: ex.name,
        muscle: ex.muscle,
        executionType: ex.executionType,
        measurementType: ex.measurementType,
        sets: ex.sets,
        reps: ex.reps,
        rest: ex.rest,
        weight: ex.weight,
        setsState: ex.setsState,
        performedCardios: ex.performedCardios,
        failureReport: ex.failureReport,
        failureReps: ex.failureReps,
        weightsPerSet: ex.weightsPerSet,
        repsPerSet: ex.repsPerSet,
        setTypes: ex.setTypes,
        rirPerSet: rirs,
        isCardio: ex.isCardio,
        allowCardioSets: ex.allowCardioSets,
        isStationary: ex.isStationary,
        singleCardioSession: ex.singleCardioSession,
        
      );
      _save();
    }
  }

  void updateExerciseSetWeightReps(
      int exIndex, int setIdx, double weight, int reps) {
    if (activeWorkout == null) return;
    final active = activeWorkout!;
    final exercises = List<ActiveExercise>.from(active.exercises);
    if (exIndex >= exercises.length) return;

    final ex = exercises[exIndex];

    final List<double> newWeights = ex.weightsPerSet != null
        ? List<double>.from(ex.weightsPerSet!)
        : List<double>.filled(ex.sets, ex.weight);

    final List<int> newReps = ex.repsPerSet != null
        ? List<int>.from(ex.repsPerSet!)
        : List<int>.filled(ex.sets, ex.reps);

    if (setIdx >= 0 && setIdx < newWeights.length) {
      newWeights[setIdx] = weight;
    }
    if (setIdx >= 0 && setIdx < newReps.length) {
      newReps[setIdx] = reps;
    }

    double mainWeight = ex.weight;
    int mainReps = ex.reps;
    if (setIdx == 0) {
      mainWeight = weight;
      mainReps = reps;
    }

    exercises[exIndex] = ActiveExercise(
      id: ex.id,
      name: ex.name,
      muscle: ex.muscle,
      executionType: ex.executionType,
      measurementType: ex.measurementType,
      sets: ex.sets,
      reps: mainReps,
      rest: ex.rest,
      weight: mainWeight,
      weightsPerSet: newWeights,
      repsPerSet: newReps,
      setsState: ex.setsState,
      performedCardios: ex.performedCardios,
      failureReport: ex.failureReport,
      failureReps: ex.failureReps,
    );

    activeWorkout = active.copyWith(
      exercises: exercises,
    );
    WatchService.instance.sendActiveWorkout(activeWorkout!);
    _save();
  }

  void updateExerciseRpe(int exIndex, int rpe) {
    if (activeWorkout == null) return;
    final active = activeWorkout!;
    final exercises = List<ActiveExercise>.from(active.exercises);
    final ex = exercises[exIndex];
    exercises[exIndex] = ex.copyWith(rpe: rpe);
    activeWorkout = active.copyWith(exercises: exercises);
    WatchService.instance.sendActiveWorkout(activeWorkout!);
    _save();
    notifyListeners();
  }


  void updateExerciseNote(String exerciseId, String note) {
    if (note.trim().isEmpty) {
      exerciseNotes.remove(exerciseId);
    } else {
      exerciseNotes[exerciseId] = note.trim();
    }
    _save();
  }

  void updateWorkoutTimer(int seconds, {bool isWarmupTimer = false}) {
    if (activeWorkout == null) return;
    final active = activeWorkout!;

    activeWorkout = active.copyWith(
      elapsedSeconds: isWarmupTimer ? active.elapsedSeconds : seconds,
      warmupDurationSeconds:
          isWarmupTimer ? seconds : active.warmupDurationSeconds,
    );

    onStateChanged?.call(); // Salva sem chamar rebuild geral

    if (!isWarmupTimer && seconds % 5 == 0) {
      WatchService.instance.sendActiveWorkout(activeWorkout!);
    }
  }

  void setCurrentExerciseIndex(int index) {
    if (activeWorkout == null) return;
    final active = activeWorkout!;

    activeWorkout = active.copyWith(
      currentExerciseIndex: index,
    );

    _save();
  }

  void pauseWorkout(bool isPaused) {
    if (activeWorkout == null) return;
    final active = activeWorkout!;

    if (isPaused) {
      activeWorkout = active.copyWith(paused: true);
    } else {
      activeWorkout = active.copyWith(
        paused: false,
        startTime: DateTime.now().millisecondsSinceEpoch -
            (active.elapsedSeconds * 1000),
      );
    }

    WatchService.instance.sendActiveWorkout(activeWorkout!);
    _save();
  }

  void applyActiveWorkoutFromWatch(Map<String, dynamic> watchData) {
    final current = activeWorkout;

    if (current == null) {
      try {
        final fromWatch = ActiveWorkoutState.fromJson(watchData);
        activeWorkout = fromWatch;
        debugPrint(
            '[WorkoutProvider] applyActiveWorkoutFromWatch: created new active workout from Watch state (${fromWatch.name})');
        _save();
      } catch (e) {
        debugPrint(
            '[WorkoutProvider] applyActiveWorkoutFromWatch: failed to parse Watch state — $e');
      }
      return;
    }

    try {
      final watchExercises = watchData['exercises'] as List?;
      if (watchExercises == null ||
          watchExercises.length != current.exercises.length) return;

      final merged = List<ActiveExercise>.from(current.exercises);
      for (int i = 0; i < merged.length; i++) {
        final wEx = Map<String, dynamic>.from(watchExercises[i] as Map);
        final ios = merged[i];

        final wSets =
            (wEx['setsState'] as List?)?.map((e) => e as bool).toList() ??
                ios.setsState;
        final mergedSets = List<bool>.generate(
          ios.setsState.length,
          (j) => (j < wSets.length ? wSets[j] : false) || ios.setsState[j],
        );

        final wCardios = wEx['performedCardios'] as List?;
        final mergedCardios = List<PerformedCardio?>.from(ios.performedCardios);
        if (wCardios != null) {
          for (int j = 0;
              j < mergedCardios.length && j < wCardios.length;
              j++) {
            if (mergedCardios[j] == null && wCardios[j] != null) {
              mergedCardios[j] = PerformedCardio.fromJson(
                  Map<String, dynamic>.from(wCardios[j] as Map));
            }
          }
        }

        merged[i] = ActiveExercise(
          id: ios.id,
          name: ios.name,
          muscle: ios.muscle,
          executionType: ios.executionType,
          measurementType: ios.measurementType,
          sets: ios.sets,
          reps: ios.reps,
          rest: ios.rest,
          weight: ios.weight,
          weightsPerSet: ios.weightsPerSet,
          repsPerSet: ios.repsPerSet,
          setsState: mergedSets,
          performedCardios: mergedCardios,
          failureReport: ios.failureReport,
          failureReps: ios.failureReps,
        );
      }

      activeWorkout = current.copyWith(
        exercises: merged,
        currentExerciseIndex:
            (watchData['currentExerciseIndex'] as num?)?.toInt() ??
                current.currentExerciseIndex,
        paused: watchData['paused'] as bool? ?? current.paused,
        elapsedSeconds: (watchData['elapsedSeconds'] as num?)?.toInt() ??
            current.elapsedSeconds,
        restTimer: watchData['restTimer'] != null
            ? WatchRestTimer.fromJson(
                Map<String, dynamic>.from(watchData['restTimer'] as Map))
            : current.restTimer,
      );
      debugPrint(
          '[WorkoutProvider] applyActiveWorkoutFromWatch: merged Watch sets into iOS state');
      _save();
    } catch (e) {
      debugPrint(
          '[WorkoutProvider] applyActiveWorkoutFromWatch: merge failed — $e');
    }
  }

  void discardActiveWorkout() {
    RestTimerService.instance.clear();
    activeWorkout = null;
    _save();
  }
  void reorderActiveExercises(List<ActiveExercise> reorderedList) {
    if (activeWorkout != null) {
      activeWorkout = activeWorkout!.copyWith(exercises: reorderedList);
      _save();
      notifyListeners();
    }
  }

  void postponeActiveWorkout() {
    if (activeWorkout == null) return;
    RestTimerService.instance.clear();
    final active = activeWorkout!;
    postponedWorkouts.add(active.copyWith(
      paused: true,
      postponed: true,
    ));
    activeWorkout = null;
    _save();
  }

  void resumePostponedWorkout(int index) {
    if (index < 0 || index >= postponedWorkouts.length) return;
    if (activeWorkout != null) {
      return; // Can't resume if there's already an active one
    }

    final workout = postponedWorkouts[index];
    postponedWorkouts.removeAt(index);
    activeWorkout = workout.copyWith(
      startTime: DateTime.now().millisecondsSinceEpoch -
          (workout.elapsedSeconds * 1000),
      paused: false,
      postponed: false,
    );
    _save();
  }

  void discardPostponedWorkout(int index) {
    if (index < 0 || index >= postponedWorkouts.length) return;
    postponedWorkouts.removeAt(index);
    _save();
  }

  void clearAllPostponedWorkouts() {
    if (postponedWorkouts.isEmpty) return;
    postponedWorkouts.clear();
    _save();
  }

  void updateHealthMetrics(int heartRate, int activeCalories) {
    if (activeWorkout == null) return;
    final active = activeWorkout!;

    activeWorkout = active.copyWith(
      heartRate: heartRate,
      activeCalories: activeCalories,
    );

    final now = DateTime.now();
    if (_lastHealthMetricsNotify == null ||
        now.difference(_lastHealthMetricsNotify!) >=
            _healthMetricsNotifyInterval) {
      _lastHealthMetricsNotify = now;
      notifyListeners();
    }
  }

  void finishWorkout(int duration, int rpeValue, String notes) {
    if (activeWorkout == null) return;
    RestTimerService.instance.clear();

    final active = activeWorkout!;
    int totalSets = 0;
    int completedSets = 0;
    double totalWeightVolume = 0.0;

    final List<LogExercise> exercisesSummary = active.exercises.map((ex) {
      final done = ex.setsState.where((s) => s).length;
      totalSets += ex.sets;
      completedSets += done;

      double finalWeight = ex.weight;
      int finalReps = ex.reps;
      final isCardio = ex.isCardio;

      List<PerformedCardio?>? logCardios = ex.performedCardios;

      if (isCardio) {
        // For single cardio sessions, use singleCardioSession
        if (!ex.allowCardioSets && ex.singleCardioSession != null) {
          finalWeight = ex.singleCardioSession!.distanceKm;
          finalReps = ex.singleCardioSession!.durationSeconds ~/ 60;
          logCardios = [ex.singleCardioSession!];
        } else {
          // For cardio with sets (HIIT), use performedCardios
          final completedList =
              ex.performedCardios.where((c) => c != null).toList();
          if (completedList.isNotEmpty) {
            final totalDist =
                completedList.fold<double>(0, (sum, c) => sum + c!.distanceKm);
            final totalDurMin = completedList.fold<int>(
                0, (sum, c) => sum + (c!.durationSeconds ~/ 60));
            finalWeight = totalDist / completedList.length;
            finalReps = totalDurMin ~/ completedList.length;
            logCardios = completedList;
          }
        }
      } else {
        for (int i = 0; i < ex.sets; i++) {
          if (ex.setsState[i]) {
            totalWeightVolume += ex.weight * ex.reps;
          }
        }
      }

      return LogExercise(
        name: ex.name,
        muscle: ex.muscle,
        sets: ex.sets,
        completedSets: done,
        reps: finalReps,
        weight: finalWeight,
        performedCardios: logCardios,
        rpe: ex.rpe ?? rpeValue,
        failureReport: ex.failureReport,
        failureReps: ex.failureReps,
        executionType: ex.executionType,
      );
    }).toList();

    final exercisesWithRpe =
        active.exercises.where((e) => e.rpe != null && e.rpe! > 0).toList();
    final calculatedRpe = exercisesWithRpe.isNotEmpty
        ? (exercisesWithRpe.map((e) => e.rpe!).reduce((a, b) => a + b) /
                exercisesWithRpe.length)
            .round()
        : rpeValue;

    final log = WorkoutLog(
      id: "log-${DateTime.now().millisecondsSinceEpoch}",
      name: active.name,
      date: DateTime.now().toUtc().toIso8601String(),
      duration: duration,
      completedSets: completedSets,
      totalSets: totalSets,
      totalWeight: totalWeightVolume,
      rpe: calculatedRpe,
      notes: notes,
      recovery: active.recovery,
      exercises: exercisesSummary,
      warmupDurationSeconds: active.warmupDurationSeconds,
      avgHeartRate: active.heartRate > 0 ? active.heartRate : null,
      activeCalories: active.activeCalories > 0 ? active.activeCalories : null,
    );

    history = List.from(history)..insert(0, log);

    // Update PRs
    final List<String> prExerciseNames = [];
    _updatePersonalRecordsForLog(log, prExerciseNames);

    if (prExerciseNames.isNotEmpty) {
      WatchService.instance.sendPrCelebration(prExerciseNames);
    }

    activeWorkout = null;
    _updateStreak();

    // Advance continuous list if needed
    if (settings.organizationMode == OrganizationMode.continuousList) {
      final continuousList = planner['continuous'] ?? [];
      if (continuousList.isNotEmpty) {
        setContinuousListIndex(
            (settings.continuousListCurrentIndex + 1) % continuousList.length);
      }
    }

    // Evaluate new badges
    final newlyUnlocked = BadgesService.evaluateNewBadges(
      history: history,
      currentUnlocked: unlockedBadgeIds,
      streak: streak,
      library: library,
    );
    if (newlyUnlocked.isNotEmpty) {
      unlockedBadgeIds = List.from(unlockedBadgeIds)..addAll(newlyUnlocked);
      // Optional: trigger some UI alert / snackbar from the UI layer by listening to a new event or state
    }

    _save();

    unawaited(_firebaseSync.syncWorkoutLog(currentUserId, log));

    // Save to HealthKit
    unawaited(HealthService.instance.saveWorkoutToHealthKit(
      name: log.name,
      duration: log.duration,
      date: log.date,
      calories: log.activeCalories,
    ));
  }

  void addManualWorkoutLog(WorkoutLog log) {
    if (history.any((l) => l.id == log.id)) return;
    history = List.from(history)..insert(0, log);

    // Update PRs
    _updatePersonalRecordsForLog(log, null);

    _updateStreak();

    // Evaluate new badges
    final newlyUnlocked = BadgesService.evaluateNewBadges(
      history: history,
      currentUnlocked: unlockedBadgeIds,
      streak: streak,
      library: library,
    );
    if (newlyUnlocked.isNotEmpty) {
      unlockedBadgeIds = List.from(unlockedBadgeIds)..addAll(newlyUnlocked);
    }

    _save();
    notifyListeners();
    unawaited(_firebaseSync.syncWorkoutLog(currentUserId, log));

    // Save to HealthKit (skip if it's already from HealthKit)
    if (!log.id.startsWith("healthkit-")) {
      unawaited(HealthService.instance.saveWorkoutToHealthKit(
        name: log.name,
        duration: log.duration,
        date: log.date,
        calories: log.activeCalories,
      ));
    }
  }

  Future<List<WorkoutLog>> loadWorkoutHistory() async {
    if (currentUserId.isEmpty) return [];
    if (historyLoaded) return history;

    final rawHistory =
        await _persistence.loadWorkoutsHistoryJson(currentUserId);
    if (rawHistory != null) {
      try {
        final List decoded = json.decode(rawHistory);
        final loadedHistory =
            decoded.map((h) => WorkoutLog.fromJson(h)).toList();
        history.clear();
        history.addAll(loadedHistory);
      } catch (e) {
        debugPrint('[WorkoutProvider] Error loading workouts history: $e');
      }
    }
    historyLoaded = true;

    // Sync HealthKit workouts after loading local history
    await _syncHealthKitWorkouts();

    notifyListeners();
    return history;
  }

  Future<void> _syncHealthKitWorkouts() async {
    try {
      final healthWorkouts = await HealthService.instance.getRecentWorkouts();
      debugPrint(
          '[WorkoutProvider] Found ${healthWorkouts.length} workouts from HealthKit');

      for (final hw in healthWorkouts) {
        final id = hw['id'] as String;
        final name = hw['name'] as String;
        final duration = hw['duration'] as int;
        final calories = hw['calories'] as int?;
        final dateStr = hw['date'] as String;

        // Skip if already in history or deleted
        if (history.any((h) => h.id == id)) {
          debugPrint(
              '[WorkoutProvider] Skipping duplicate HealthKit workout: $id');
          continue;
        }
        if (deletedHealthWorkoutIds.contains(id)) {
          debugPrint(
              '[WorkoutProvider] Skipping deleted HealthKit workout: $id');
          continue;
        }

        // Create WorkoutLog from HealthKit data
        final healthLog = WorkoutLog(
          id: id,
          name: name,
          date: dateStr,
          duration: duration,
          completedSets: 0, // HealthKit workouts don't have sets
          totalSets: 0,
          totalWeight: 0,
          rpe: 0,
          notes: '',
          exercises: [], // HealthKit workouts don't have exercise details
          activeCalories: calories,
        );

        history.insert(0, healthLog);
        debugPrint(
            '[WorkoutProvider] Added HealthKit workout to history: $name');
      }

      if (healthWorkouts.isNotEmpty) {
        _updateStreak();
        _save();
      }
    } catch (e) {
      debugPrint('[WorkoutProvider] Error syncing HealthKit workouts: $e');
    }
  }

  Future<void> syncHealthKitWorkoutsManually() async {
    await _syncHealthKitWorkouts();
    notifyListeners();
  }

  void deleteWorkoutLog(String id) {
    final logToDelete = history.firstWhere((h) => h.id == id,
        orElse: () => WorkoutLog(
            id: '',
            name: '',
            date: '',
            duration: 0,
            completedSets: 0,
            totalSets: 0,
            totalWeight: 0,
            rpe: 0,
            exercises: [],
            notes: ''));
    // Add to deletedHealthWorkoutIds if it's a HealthKit workout (starts with "healthkit-")
    if (logToDelete.id.isNotEmpty && logToDelete.id.startsWith("healthkit-")) {
      if (!deletedHealthWorkoutIds.contains(id)) {
        deletedHealthWorkoutIds.add(id);
      }
    }

    history.removeWhere((h) => h.id == id);

    // Recalculate PRs completely from the remaining logs in history
    prs.clear();
    // Process from oldest to newest log to properly calculate the best records
    final reversedHistory = history.reversed.toList();
    for (final log in reversedHistory) {
      _updatePersonalRecordsForLog(log, null);
    }

    _updateStreak();
    _save();
    notifyListeners();
    unawaited(_firebaseSync.deleteWorkoutLog(currentUserId, id));
  }

  // --- PERSONAL RECORDS HELPER ---
  void _updatePersonalRecordsForLog(
      WorkoutLog log, List<String>? prExerciseNamesToNotify) {
    for (final ex in log.exercises) {
      if (ex.completedSets == 0) continue;

      final libEx = library.firstWhere((l) => l.name == ex.name,
          orElse: () => LibraryExercise(
              id: '',
              name: '',
              muscle: '',
              measurementType: MeasurementType.reps));
      if (libEx.id.isEmpty) continue;

      final isCardio = libEx.measurementType == MeasurementType.cardio ||
          libEx.measurementType == MeasurementType.distance ||
          libEx.measurementType == MeasurementType.time;

      if (isCardio) {
        if (ex.performedCardios != null &&
            ex.performedCardios!.any((c) => c != null)) {
          final completedList =
              ex.performedCardios!.where((c) => c != null).toList();
          if (completedList.isNotEmpty) {
            var maxDistanceCardio = completedList[0]!;
            var bestPaceCardio = completedList[0]!;

            for (var p in completedList) {
              if (p!.distanceKm > maxDistanceCardio.distanceKm) {
                maxDistanceCardio = p;
              }
              if (p.distanceKm > 0 && p.durationSeconds > 0) {
                double speed = p.distanceKm / (p.durationSeconds / 3600);
                double currentBest = bestPaceCardio.distanceKm == 0 ||
                        bestPaceCardio.durationSeconds == 0
                    ? 0
                    : (bestPaceCardio.distanceKm /
                        (bestPaceCardio.durationSeconds / 3600));

                if (speed > currentBest || bestPaceCardio.distanceKm == 0) {
                  bestPaceCardio = p;
                }
              }
            }

            // Maior Distancia PR
            double prWeight = maxDistanceCardio.distanceKm;
            int prReps = maxDistanceCardio.durationSeconds ~/ 60;
            final currentPr = prs[libEx.id];
            if (currentPr == null ||
                prWeight > currentPr.weight ||
                (prWeight == currentPr.weight && prReps > currentPr.reps)) {
              prs[libEx.id] = PersonalRecord(
                  weight: prWeight,
                  reps: prReps,
                  date: log.date,
                  routineName: log.name);
              prExerciseNamesToNotify?.add(ex.name);
            }

            // Melhor Pace/Velocidade PR (Usando o ID com sufixo -pace)
            double prSpeed = 0.0;
            if (bestPaceCardio.distanceKm > 0 &&
                bestPaceCardio.durationSeconds > 0) {
              prSpeed = bestPaceCardio.distanceKm /
                  (bestPaceCardio.durationSeconds / 3600);
            }
            if (prSpeed > 0) {
              final pacePrKey = '${libEx.id}-pace';
              final currentPacePr = prs[pacePrKey];
              if (currentPacePr == null || prSpeed > currentPacePr.weight) {
                prs[pacePrKey] = PersonalRecord(
                    weight: prSpeed,
                    reps: bestPaceCardio.distanceKm.toInt(),
                    date: log.date,
                    routineName: log.name);
              }
            }
          }
        }
      } else {
        // Strength PR
        double prWeight = ex.weight;
        int prReps = ex.reps;
        final currentPr = prs[libEx.id];
        if (currentPr == null ||
            prWeight > currentPr.weight ||
            (prWeight == currentPr.weight && prReps > currentPr.reps)) {
          prs[libEx.id] = PersonalRecord(
              weight: prWeight,
              reps: prReps,
              date: log.date,
              routineName: log.name);
          prExerciseNamesToNotify?.add(ex.name);
        }
      }
    }
  }

  // --- STREAK TRACKING ---
  void _updateStreak() {
    final now = DateTime.now();

    DateTime startOfWeek(DateTime d) {
      final weekday = d.weekday;
      return DateTime(d.year, d.month, d.day - (weekday - 1));
    }

    final thisWeekStart = startOfWeek(now);

    final Set<int> weekdaysTrainedSet = {};
    for (final log in history) {
      try {
        final logDate = parseUtcDate(log.date);
        if (!logDate.isBefore(thisWeekStart)) {
          weekdaysTrainedSet.add(logDate.weekday);
        } else {
          break; // Optimization: history is ordered newest to oldest
        }
      } catch (_) {}
    }
    final List<int> weekdaysTrained = weekdaysTrainedSet.toList()..sort();
    int currentWeekCount = weekdaysTrained.length;

    int consecutiveWeeks = 0;
    final Set<String> weeksWithWorkout = {};
    for (final log in history) {
      try {
        final logDate = parseUtcDate(log.date);
        final ws = startOfWeek(logDate);
        final weekKey = '${ws.year}-${ws.month}-${ws.day}';
        weeksWithWorkout.add(weekKey);
      } catch (_) {}
    }

    DateTime checkWeek = thisWeekStart;
    while (true) {
      final key = '${checkWeek.year}-${checkWeek.month}-${checkWeek.day}';
      if (weeksWithWorkout.contains(key)) {
        consecutiveWeeks++;
        checkWeek = checkWeek.subtract(const Duration(days: 7));
      } else {
        break;
      }
    }

    final Set<String> completedTodayRoutinesSet = {};
    final Set<String> completedThisWeekRoutinesSet = {};
    final nowLocal = DateTime.now();
    for (final log in history) {
      try {
        final logDate = parseUtcDate(log.date);

        // This Week routines
        if (!logDate.isBefore(thisWeekStart)) {
          if (log.name.isNotEmpty) {
            completedThisWeekRoutinesSet.add(log.name);
          }
        } else {
           break; // Optimization: history is ordered newest to oldest
        }

        // Today routines
        if (logDate.year == nowLocal.year &&
            logDate.month == nowLocal.month &&
            logDate.day == nowLocal.day) {
          if (log.name.isNotEmpty) {
            completedTodayRoutinesSet.add(log.name);
          }
        }
      } catch (_) {}
    }
    final List<String> completedTodayRoutines =
        completedTodayRoutinesSet.toList();
    final List<String> completedThisWeekRoutines =
        completedThisWeekRoutinesSet.toList();

    final lastDate = history.isNotEmpty ? history.first.date : '';
    streak = WorkoutStreak(
      currentWeekCount: currentWeekCount,
      consecutiveWeeks: consecutiveWeeks,
      lastWorkoutDate: lastDate,
      weekdaysTrained: weekdaysTrained,
      completedTodayRoutines: completedTodayRoutines,
      completedThisWeekRoutines: completedThisWeekRoutines,
    );

    WatchService.instance.sendStreak(streak);
  }

  // --- WEEKLY PLANNER ACTIONS ---
  void addPlannerItem(String day) {
    planner[day] = List<String>.from(planner[day] ?? [])..add("");
    _save();
  }

  void updatePlannerItem(String day, int index, String value) {
    planner[day] = List<String>.from(planner[day] ?? []);
    planner[day]![index] = value;
    _save();
  }

  void reorderPlannerItem(String day, int index, bool moveUp) {
    planner[day] = List<String>.from(planner[day] ?? []);
    final targetIndex = moveUp ? index - 1 : index + 1;

    if (targetIndex < 0 || targetIndex >= planner[day]!.length) return;

    final temp = planner[day]![index];
    planner[day]![index] = planner[day]![targetIndex];
    planner[day]![targetIndex] = temp;

    _save();
  }

  void removePlannerItem(String day, int index) {
    planner[day] = List<String>.from(planner[day] ?? [])..removeAt(index);
    _save();
  }


  void importFromFixedDay(String sourceDay, String targetKey) {
    final sourceItems = List<String>.from(planner[sourceDay] ?? []);
    final validItems = sourceItems.where((item) => item.isNotEmpty).toList();
    if (validItems.isEmpty) return;
    
    // Simplificado para copiar apenas os modelos originais, sem criar novas rotinas (conforme pedido)
    planner[targetKey] = List<String>.from(planner[targetKey] ?? [])..addAll(validItems);
    _save();
  }

  void importAllFixedDays(String targetKey) {
    final days = ['seg', 'ter', 'qua', 'qui', 'sex', 'sab', 'dom'];
    final List<String> newPlannerEntries = [];

    for (final day in days) {
      final sourceItems = List<String>.from(planner[day] ?? []);
      final validItems = sourceItems.where((item) => item.isNotEmpty).toList();
      if (validItems.isEmpty) continue;

      // Adiciona os modelos originais daquele dia
      newPlannerEntries.addAll(validItems);
    }

    if (newPlannerEntries.isEmpty) return;

    planner[targetKey] = List<String>.from(planner[targetKey] ?? [])
      ..addAll(newPlannerEntries);
    _save();
  }

  void deletePersonalRecord(String exerciseId) {
    prs.remove(exerciseId);
    _save();
  }

  // --- LIBRARY OPERATIONS ---
  void addLibraryExercise(String name, String muscle, String measurementType,
      String? notes, String? executionType,
      {bool isStationary = false}) {
    final newEx = LibraryExercise(
      id: "lib-${DateTime.now().millisecondsSinceEpoch}",
      name: name,
      muscle: muscle,
      measurementType: measurementTypeFromString(measurementType),
      notes: notes,
      executionType: executionType,
      isStationary: isStationary,
    );
    library = List<LibraryExercise>.from(library)..add(newEx);
    _save();
  }

  void updateLibraryExercise(String id, String name, String muscle,
      String measurementType, String? notes, String? executionType,
      {bool isStationary = false}) {
    final idx = library.indexWhere((e) => e.id == id);
    if (idx != -1) {
      library[idx] = LibraryExercise(
        id: id,
        name: name,
        muscle: muscle,
        measurementType: measurementTypeFromString(measurementType),
        notes: notes,
        executionType: executionType,
        isStationary: isStationary,
      );
      _save();
    }
  }

  void deleteLibraryExercise(String id) {
    library = List<LibraryExercise>.from(library)
      ..removeWhere((e) => e.id == id);

    planner.forEach((k, v) {
      planner[k] = v.where((item) => !item.contains('exercise:$id')).toList();
    });

    routines = routines.map((r) {
      return Routine(
        id: r.id,
        name: r.name,
        defaultRest: r.defaultRest,
        exercises: r.exercises.where((ex) => ex.exerciseId != id).toList(),
      );
    }).toList();

    _save();
    unawaited(_firebaseSync.deleteLibraryExercise(currentUserId, id));
  }

  // --- ROUTINE OPERATIONS ---
  void addRoutine(String name, int defaultRest, List<RoutineExercise> exercises,
      {RoutineExecutionType executionType = RoutineExecutionType.standard,
      int circuitCycles = 3}) {
    final r = Routine(
      id: "routine-${DateTime.now().millisecondsSinceEpoch}",
      name: name,
      defaultRest: defaultRest,
      exercises: exercises,
      executionType: executionType,
      circuitCycles: circuitCycles,
    );
    routines = List<Routine>.from(routines)..add(r);
    _save();
    unawaited(_firebaseSync.syncRoutine(currentUserId, r));
  }

  void updateRoutine(Routine r) {
    final idx = routines.indexWhere((item) => item.id == r.id);
    if (idx != -1) {
      routines = List<Routine>.from(routines);
      routines[idx] = r;
      _save();
      unawaited(_firebaseSync.syncRoutine(currentUserId, r));
    }
  }

  void updateRoutineExerciseSettings(String routineId, String exerciseId,
      {double? weight, int? reps, int? sets, int? rest}) {
    final rIdx = routines.indexWhere((r) => r.id == routineId);
    if (rIdx != -1) {
      final routine = routines[rIdx];
      final newExercises = routine.exercises.map((ex) {
        if (ex.exerciseId == exerciseId) {
          final s = sets ?? ex.sets;

          // Re-initialize weightsPerSet and repsPerSet arrays if they exist or sets count changed
          List<double>? newWeights = ex.weightsPerSet;
          if (newWeights != null || weight != null) {
            final oldWeights =
                newWeights ?? List<double>.filled(ex.sets, ex.weight);
            final targetWeight = weight ?? ex.weight;
            newWeights = List<double>.filled(s, targetWeight);
            for (int i = 0; i < s && i < oldWeights.length; i++) {
              newWeights[i] = oldWeights[i];
            }
            if (weight != null) {
              // If weight is specifically updated, overwrite all sets
              newWeights = List<double>.filled(s, weight);
            }
          }

          List<int>? newRepsList = ex.repsPerSet;
          if (newRepsList != null || reps != null) {
            final oldReps = newRepsList ?? List<int>.filled(ex.sets, ex.reps);
            final targetReps = reps ?? ex.reps;
            newRepsList = List<int>.filled(s, targetReps);
            for (int i = 0; i < s && i < oldReps.length; i++) {
              newRepsList[i] = oldReps[i];
            }
            if (reps != null) {
              // If reps are specifically updated, overwrite all sets
              newRepsList = List<int>.filled(s, reps);
            }
          }

          return RoutineExercise(
            id: ex.id,
            exerciseId: ex.exerciseId,
            sets: s,
            reps: reps ?? ex.reps,
            rest: rest ?? ex.rest,
            weight: weight ?? ex.weight,
            weightsPerSet: newWeights,
            repsPerSet: newRepsList,
            isCardio: ex.isCardio,
            allowCardioSets: ex.allowCardioSets,
          );
        }
        return ex;
      }).toList();

      updateRoutine(Routine(
        id: routine.id,
        name: routine.name,
        defaultRest: routine.defaultRest,
        exercises: newExercises,
        isDynamicExercise: routine.isDynamicExercise,
      ));
    }
  }

  void deleteRoutine(String id) {
    routines = List<Routine>.from(routines)..removeWhere((r) => r.id == id);

    planner.forEach((k, v) {
      planner[k] =
          v.where((item) => item != 'routine:$id' && item != id).toList();
    });

    _save();
    unawaited(_firebaseSync.deleteRoutine(currentUserId, id));
  }

  // --- MEASUREMENT OPERATIONS ---
  void addMeasurement(BodyMeasurement record) {
    final index = medidas.indexWhere((m) => m.date == record.date);
    final List<BodyMeasurement> list = List.from(medidas);

    if (index != -1) {
      list[index] = record;
    } else {
      list.add(record);
    }

    medidas = list;
    _save();
  }

  void deleteMeasurement(String id) {
    medidas = List<BodyMeasurement>.from(medidas)
      ..removeWhere((m) => m.id == id);
    _save();
  }

  void updateMeasurement(BodyMeasurement record) {
    final index = medidas.indexWhere((m) => m.id == record.id);
    if (index == -1) return;
    final List<BodyMeasurement> list = List.from(medidas);
    list[index] = record;
    medidas = list;
    _save();
  }

  // --- SETTINGS OPERATIONS ---
  void updateWorkoutElapsedTime(int newElapsedSeconds) {
    if (activeWorkout != null) {
      activeWorkout = ActiveWorkoutState(
        name: activeWorkout!.name,
        startTime: activeWorkout!.startTime,
        exercises: activeWorkout!.exercises,
        currentExerciseIndex: activeWorkout!.currentExerciseIndex,
        elapsedSeconds: newElapsedSeconds,
        paused: activeWorkout!.paused,
        restTimer: activeWorkout!.restTimer,
        warmupDurationSeconds: activeWorkout!.warmupDurationSeconds,
        heartRate: activeWorkout!.heartRate,
        activeCalories: activeWorkout!.activeCalories,
        postponed: activeWorkout!.postponed,
        recovery: activeWorkout!.recovery,
        isWarmup: activeWorkout!.isWarmup,
      );
      _save();
    }
  }

  void updateSettings(bool sound, bool vibration, int prepSeconds) {
    settings = SettingsState(
      sound: sound,
      vibration: vibration,
      prepSeconds: prepSeconds,
      organizationMode: settings.organizationMode,
      continuousListCurrentIndex: settings.continuousListCurrentIndex,
    );
    _save();
  }

  void setOrganizationMode(OrganizationMode mode) {
    if (settings.organizationMode != mode) {
      settings = SettingsState(
        sound: settings.sound,
        vibration: settings.vibration,
        prepSeconds: settings.prepSeconds,
        organizationMode: mode,
        continuousListCurrentIndex: settings.continuousListCurrentIndex,
      );
      _save();
      WatchService.instance
          .sendTodayRoutines(settings, planner, routines, streak);
      WatchService.instance.syncWidgetData();
    }
  }

  void setContinuousListIndex(int index) {
    settings = SettingsState(
      sound: settings.sound,
      vibration: settings.vibration,
      prepSeconds: settings.prepSeconds,
      organizationMode: settings.organizationMode,
      continuousListCurrentIndex: index,
    );
    _save();
    WatchService.instance
        .sendTodayRoutines(settings, planner, routines, streak);
    WatchService.instance.syncWidgetData();
  }

  void checkAndPopulateDefaultLibrary() {
    bool changed = false;
    if (library.isEmpty) {
      library = List<LibraryExercise>.from(defaultLibraryExercises);
      changed = true;
    } else {
      for (final defEx in defaultLibraryExercises) {
        if (!library.any((l) => l.id == defEx.id)) {
          library.add(defEx);
          changed = true;
        }
      }
    }
    if (changed) {
      _save();
    }
  }

  void refreshStreak() {
    _updateStreak();
    notifyListeners();
  }

  void shiftPlannerForward([String? reason]) {
    final List<String> days = ['seg', 'ter', 'qua', 'qui', 'sex', 'sab', 'dom'];
    final Map<String, List<String>> newPlanner = {};

    // Shift every day 1 day backward
    for (int i = 0; i < days.length; i++) {
      String currentDay = days[i];
      String nextDay = days[(i - 1 + days.length) % days.length];
      newPlanner[nextDay] = planner[currentDay] ?? [];
    }

    // Save state for undo
    _previousPlanner = Map.from(planner);
    planner = newPlanner;

    final restLog = WorkoutLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: reason != null ? 'Descanso: $reason' : 'Dia de Descanso',
      date: DateTime.now().toIso8601String(),
      duration: 0,
      completedSets: 0,
      totalSets: 0,
      totalWeight: 0,
      rpe: 0,
      notes: reason != null ? 'Motivo: $reason' : 'Descanso registrado manualmente.',
      exercises: [],
    );
    _lastRestLogId = restLog.id;
    addManualWorkoutLog(restLog);
  }

  void undoShiftPlannerForward() {
    if (_previousPlanner != null) {
      planner = _previousPlanner!;
      _previousPlanner = null;
    }
    if (_lastRestLogId != null) {
      deleteWorkoutLog(_lastRestLogId!);
      _lastRestLogId = null;
    } else {
      _save();
      notifyListeners();
    }
  }

  void shiftPlannerForwardWithoutLog() {
    final List<String> days = ['seg', 'ter', 'qua', 'qui', 'sex', 'sab', 'dom'];
    final Map<String, List<String>> newPlanner = {};

    // Shift every day 1 day backward
    for (int i = 0; i < days.length; i++) {
      String currentDay = days[i];
      String nextDay = days[(i - 1 + days.length) % days.length];
      newPlanner[nextDay] = planner[currentDay] ?? [];
    }

    // Save state for undo
    _previousPlanner = Map.from(planner);
    planner = newPlanner;

    _save();
    notifyListeners();
  }

  void shiftPlannerBackwardWithoutLog() {
    final List<String> days = ['seg', 'ter', 'qua', 'qui', 'sex', 'sab', 'dom'];
    final Map<String, List<String>> newPlanner = {};

    // Shift every day 1 day forward (meaning Monday goes to Sunday instead of Tuesday)
    for (int i = 0; i < days.length; i++) {
      String currentDay = days[i];
      String nextDay = days[(i + 1) % days.length];
      newPlanner[nextDay] = planner[currentDay] ?? [];
    }

    // Save state for undo
    _previousPlanner = Map.from(planner);
    planner = newPlanner;

    _save();
    notifyListeners();
  }

  Map<String, double>? fetchLastPerformance(String exerciseName) {
    for (final log in history) {
      for (final ex in log.exercises) {
        if (ex.name == exerciseName && ex.completedSets > 0) {
          if (ex.weight > 0) {
            return {'weight': ex.weight, 'reps': ex.reps.toDouble()};
          }
        }
      }
    }
    return null;
  }

  Map<String, int> getRecentMuscleSets([int days = 7]) {
    final Map<String, int> muscleSets = {};
    try {
      final now = DateTime.now();
      DateTime startDate;
      if (days == 0) {
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
      } else {
        startDate = now.subtract(Duration(days: days));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
      }
      
      for (final workout in history) {
        final workoutDate = DateTime.tryParse(workout.date);
        if (workoutDate != null) {
          if (workoutDate.isBefore(startDate)) {
            // History is ordered newest to oldest, so we can stop searching.
            break;
          }
          for (final ex in workout.exercises) {
            final count = ex.completedSets;
            if (count > 0 && ex.muscle.isNotEmpty) {
              muscleSets[ex.muscle] = (muscleSets[ex.muscle] ?? 0) + count;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error calculating recent muscle sets: $e");
    }
    return muscleSets;
  }

  WorkoutLog? getLastRoutineExecution(String routineName) {
    for (final log in history) {
      if (log.name.trim().toLowerCase() == routineName.trim().toLowerCase()) {
        return log;
      }
    }
    return null;
  }

  int estimateRoutineDurationMinutes(Routine routine) {
    int totalRestSeconds = 0;
    int totalSets = 0;

    for (final ex in routine.exercises) {
      totalSets += ex.sets;
      totalRestSeconds += ex.sets * (ex.rest > 0 ? ex.rest : routine.defaultRest);
    }

    int totalSeconds = (totalSets * 45) + totalRestSeconds;
    int minutes = (totalSeconds / 60).round();
    return minutes > 0 ? minutes : 15;
  }

  List<String> getRoutineMuscleTags(Routine routine) {
    final Set<String> muscles = {};
    for (final ex in routine.exercises) {
      final match = library.where((l) => l.id == ex.exerciseId).firstOrNull;
      if (match != null && match.muscle.isNotEmpty) {
        muscles.add(match.muscle);
      }
    }
    return muscles.toList();
  }
}
