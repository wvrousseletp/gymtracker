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
import '../models/profile.dart';
import '../utils/date_utils.dart';
import 'profile_provider.dart';

class WorkoutProvider extends ChangeNotifier {
  final StatePersistenceService _persistence = StatePersistenceService();
  final FirebaseSyncService _firebaseSync = FirebaseSyncService();

  List<LibraryExercise> library = [];
  List<Routine> routines = [];
  Map<String, List<String>> planner = {};
  List<WorkoutLog> history = [];
  Map<String, PersonalRecord> prs = {};
  List<BodyMeasurement> medidas = [];
  SettingsState settings = SettingsState(sound: true, vibration: true, prepSeconds: 5);
  ActiveWorkoutState? activeWorkout;
  WorkoutStreak streak = WorkoutStreak(currentWeekCount: 0, consecutiveWeeks: 0, lastWorkoutDate: '');
  
  bool historyLoaded = false;
  DateTime? _lastHealthMetricsNotify;
  static const Duration _healthMetricsNotifyInterval = Duration(seconds: 5);

  String currentUserId = '';
  Profile? currentProfile;
  VoidCallback? onStateChanged;

  void updateProfile(ProfileProvider profileProvider) {
    currentUserId = profileProvider.currentUserId;
    currentProfile = profileProvider.currentProfile;
  }

  void _save() {
    notifyListeners();
    onStateChanged?.call();
  }

  // --- WORKOUT OPERATIONS ---
  void startWorkout(Routine routine, WorkoutRecovery recovery, bool isWarmup) {
    final workoutExercises = routine.exercises.map((ex) {
      final ref = library.firstWhere(
        (l) => l.id == ex.exerciseId,
        orElse: () => LibraryExercise(
          id: ex.exerciseId,
          name: 'Exercício',
          muscle: 'Geral',
          measurementType: MeasurementType.reps,
        ),
      );

      return ActiveExercise(
        id: ex.id,
        name: ref.name,
        muscle: ref.muscle,
        executionType: ref.executionType,
        measurementType: ref.measurementType,
        sets: ex.sets,
        reps: ex.reps,
        rest: ex.rest,
        weight: ex.weight,
        weightsPerSet: ex.weightsPerSet,
        repsPerSet: ex.repsPerSet,
        setsState: List<bool>.filled(ex.sets, false),
        performedCardios: List<PerformedCardio?>.filled(ex.sets, null),
        failureReport: List<bool>.filled(ex.sets, false),
      );
    }).toList();

    activeWorkout = ActiveWorkoutState(
      name: routine.name,
      startTime: DateTime.now().millisecondsSinceEpoch,
      exercises: workoutExercises,
      currentExerciseIndex: 0,
      elapsedSeconds: 0,
      recovery: recovery,
      isWarmup: isWarmup,
      warmupDurationSeconds: 0,
    );

    _save();
  }

  void startSingleExercise(LibraryExercise exercise) {
    final tempRoutine = Routine(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      name: exercise.name,
      defaultRest: 60,
      isDynamicExercise: true,
      exercises: [
        RoutineExercise(
          id: 'temp_ex_${DateTime.now().millisecondsSinceEpoch}',
          exerciseId: exercise.id,
          sets: 3,
          reps: 10,
          rest: 60,
          weight: 0.0,
        )
      ],
    );
    startWorkout(tempRoutine, WorkoutRecovery(sleepOk: SleepQuality.okay, pain: [], warmUpDone: false), false);
  }

  void completeSet(int exIndex, int setIndex, bool isDone, {double? distance, int? duration, bool isFailure = false, int? failureRep}) {
    if (activeWorkout == null) return;
    
    HapticFeedback.lightImpact();

    final active = activeWorkout!;
    final exercises = List<ActiveExercise>.from(active.exercises);
    final ex = exercises[exIndex];

    final newSetsState = List<bool>.from(ex.setsState);
    newSetsState[setIndex] = isDone;

    final newCardios = List<PerformedCardio?>.from(ex.performedCardios);
    if (distance != null && duration != null) {
      newCardios[setIndex] = PerformedCardio(distanceKm: distance, durationSeconds: duration);
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
    );

    WatchRestTimer? computedRestTimer = active.restTimer;
    int computedExIndex = active.currentExerciseIndex;
    
    final bool wasDone = setIndex < ex.setsState.length ? ex.setsState[setIndex] : false;
    final bool isTransitionToDone = !wasDone && isDone;
    final bool isStateChanged = wasDone != isDone;

    if (isTransitionToDone) {
      if (setIndex < ex.sets - 1) {
        final endTime = DateTime.now().millisecondsSinceEpoch + (ex.rest * 1000);
        computedRestTimer = WatchRestTimer(
          endTime: endTime,
          totalSeconds: ex.rest,
          nextExerciseName: ex.name,
          nextSetNum: setIndex + 2,
          isPrep: false,
        );
      } else if (exIndex < exercises.length - 1) {
        final nextEx = exercises[exIndex + 1];
        final endTime = DateTime.now().millisecondsSinceEpoch + (ex.rest * 1000);
        computedRestTimer = WatchRestTimer(
          endTime: endTime,
          totalSeconds: ex.rest,
          nextExerciseName: nextEx.name,
          nextSetNum: 1,
          isPrep: false,
        );
        computedExIndex = exIndex + 1;
      } else {
        computedRestTimer = null;
      }
    } else if (!isDone) {
      computedRestTimer = null;
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
        );
      } else {
        RestTimerService.instance.clear();
      }
    }
  }

  void startRestTimer(int seconds, String nextExName, int nextSetNum, bool isPrep) {
    if (activeWorkout == null) return;
    final active = activeWorkout!;

    final endTime = DateTime.now().millisecondsSinceEpoch + (seconds * 1000);
    final restTimer = WatchRestTimer(
      endTime: endTime,
      totalSeconds: seconds,
      nextExerciseName: nextExName,
      nextSetNum: nextSetNum,
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

  void updateExerciseSetWeightReps(int exIndex, int setIdx, double weight, int reps) {
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

  void updateWorkoutTimer(int seconds, {bool isWarmupTimer = false}) {
    if (activeWorkout == null) return;
    final active = activeWorkout!;

    activeWorkout = active.copyWith(
      elapsedSeconds: isWarmupTimer ? active.elapsedSeconds : seconds,
      warmupDurationSeconds: isWarmupTimer ? seconds : active.warmupDurationSeconds,
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

    activeWorkout = active.copyWith(
      paused: isPaused,
    );

    WatchService.instance.sendActiveWorkout(activeWorkout!);
    _save();
  }

  void applyActiveWorkoutFromWatch(Map<String, dynamic> watchData) {
    final current = activeWorkout;

    if (current == null) {
      try {
        final fromWatch = ActiveWorkoutState.fromJson(watchData);
        activeWorkout = fromWatch;
        debugPrint('[WorkoutProvider] applyActiveWorkoutFromWatch: created new active workout from Watch state (${fromWatch.name})');
        _save();
      } catch (e) {
        debugPrint('[WorkoutProvider] applyActiveWorkoutFromWatch: failed to parse Watch state — $e');
      }
      return;
    }

    try {
      final watchExercises = watchData['exercises'] as List?;
      if (watchExercises == null || watchExercises.length != current.exercises.length) return;

      final merged = List<ActiveExercise>.from(current.exercises);
      for (int i = 0; i < merged.length; i++) {
        final wEx = Map<String, dynamic>.from(watchExercises[i] as Map);
        final ios = merged[i];

        final wSets = (wEx['setsState'] as List?)?.map((e) => e as bool).toList() ?? ios.setsState;
        final mergedSets = List<bool>.generate(
          ios.setsState.length,
          (j) => (j < wSets.length ? wSets[j] : false) || ios.setsState[j],
        );

        final wCardios = wEx['performedCardios'] as List?;
        final mergedCardios = List<PerformedCardio?>.from(ios.performedCardios);
        if (wCardios != null) {
          for (int j = 0; j < mergedCardios.length && j < wCardios.length; j++) {
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

      activeWorkout = current.copyWith(exercises: merged);
      debugPrint('[WorkoutProvider] applyActiveWorkoutFromWatch: merged Watch sets into iOS state');
      _save();
    } catch (e) {
      debugPrint('[WorkoutProvider] applyActiveWorkoutFromWatch: merge failed — $e');
    }
  }

  void discardActiveWorkout() {
    RestTimerService.instance.clear();
    activeWorkout = null;
    _save();
  }

  void postponeActiveWorkout() {
    if (activeWorkout == null) return;
    RestTimerService.instance.clear();
    final active = activeWorkout!;
    activeWorkout = active.copyWith(
      paused: true,
      postponed: true,
    );
    _save();
  }

  void resumeActiveWorkout() {
    if (activeWorkout == null) return;
    final active = activeWorkout!;
    activeWorkout = active.copyWith(
      startTime: DateTime.now().millisecondsSinceEpoch - (active.elapsedSeconds * 1000),
      paused: false,
      postponed: false,
    );
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
        now.difference(_lastHealthMetricsNotify!) >= _healthMetricsNotifyInterval) {
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
      final isCardio = ex.name.toLowerCase().contains('cardio') || ex.muscle.toLowerCase().contains('cardio');

      if (isCardio) {
        final completedList = ex.performedCardios.where((c) => c != null).toList();
        if (completedList.isNotEmpty) {
          final totalDist = completedList.fold<double>(0, (sum, c) => sum + c!.distanceKm);
          final totalDurMin = completedList.fold<int>(0, (sum, c) => sum + (c!.durationSeconds ~/ 60));
          finalWeight = totalDist / completedList.length;
          finalReps = totalDurMin ~/ completedList.length;
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
        performedCardios: ex.performedCardios,
        rpe: rpeValue,
        failureReport: ex.failureReport,
        failureReps: ex.failureReps,
        executionType: ex.executionType,
      );
    }).toList();

    final log = WorkoutLog(
      id: "log-${DateTime.now().millisecondsSinceEpoch}",
      name: active.name,
      date: DateTime.now().toUtc().toIso8601String(),
      duration: duration,
      completedSets: completedSets,
      totalSets: totalSets,
      totalWeight: totalWeightVolume,
      rpe: rpeValue,
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
    for (var ex in active.exercises) {
      final done = ex.setsState.where((s) => s).length;
      if (done == 0) continue;

      final isCardio = ex.name.toLowerCase().contains('cardio') || ex.muscle.toLowerCase().contains('cardio');
      double prWeight = ex.weight;
      int prReps = ex.reps;

      if (isCardio) {
        final completedList = ex.performedCardios.where((c) => c != null).toList();
        if (completedList.isNotEmpty) {
          var maxCardio = completedList[0]!;
          for (var p in completedList) {
            if (p!.distanceKm > maxCardio.distanceKm) {
              maxCardio = p;
            }
          }
          prWeight = maxCardio.distanceKm;
          prReps = maxCardio.durationSeconds ~/ 60;
        } else {
          continue;
        }
      }

      final libEx = library.firstWhere((l) => l.name == ex.name, orElse: () => LibraryExercise(id: '', name: '', muscle: '', measurementType: MeasurementType.reps));
      if (libEx.id.isEmpty) continue;

      final currentPr = prs[libEx.id];
      if (currentPr == null || prWeight > currentPr.weight || (prWeight == currentPr.weight && prReps > currentPr.reps)) {
        prs[libEx.id] = PersonalRecord(
          weight: prWeight,
          reps: prReps,
          date: DateTime.now().toUtc().toIso8601String(),
          routineName: active.name,
        );
        prExerciseNames.add(ex.name);
      }
    }

    if (prExerciseNames.isNotEmpty) {
      WatchService.instance.sendPrCelebration(prExerciseNames);
    }

    activeWorkout = null;
    _updateStreak();
    _save();

    unawaited(_firebaseSync.syncWorkoutLog(currentUserId, log));
  }

  void addManualWorkoutLog(WorkoutLog log) {
    if (history.any((l) => l.id == log.id)) return;
    history = List.from(history)..insert(0, log);

    // Update PRs
    for (var ex in log.exercises) {
      if (ex.completedSets == 0) continue;

      final isCardio = ex.name.toLowerCase().contains('cardio') || ex.muscle.toLowerCase().contains('cardio');
      double prWeight = ex.weight;
      int prReps = ex.reps;

      if (isCardio) {
        if (ex.performedCardios != null && ex.performedCardios!.isNotEmpty) {
          final completedList = ex.performedCardios!.where((c) => c != null).toList();
          if (completedList.isNotEmpty) {
            var maxCardio = completedList[0]!;
            for (var p in completedList) {
              if (p!.distanceKm > maxCardio.distanceKm) {
                maxCardio = p;
              }
            }
            prWeight = maxCardio.distanceKm;
            prReps = maxCardio.durationSeconds ~/ 60;
          } else {
            continue;
          }
        } else {
          continue;
        }
      }

      final libEx = library.firstWhere((l) => l.name == ex.name, orElse: () => LibraryExercise(id: '', name: '', muscle: '', measurementType: MeasurementType.reps));
      if (libEx.id.isEmpty) continue;

      final currentPr = prs[libEx.id];
      if (currentPr == null || prWeight > currentPr.weight || (prWeight == currentPr.weight && prReps > currentPr.reps)) {
        prs[libEx.id] = PersonalRecord(
          weight: prWeight,
          reps: prReps,
          date: log.date,
          routineName: log.name,
        );
      }
    }

    _updateStreak();
    _save();
    unawaited(_firebaseSync.syncWorkoutLog(currentUserId, log));
  }

  Future<List<WorkoutLog>> loadWorkoutHistory() async {
    if (currentUserId.isEmpty) return [];
    if (historyLoaded) return history;
    
    final rawHistory = await _persistence.loadWorkoutsHistoryJson(currentUserId);
    if (rawHistory != null) {
      try {
        final List decoded = json.decode(rawHistory);
        final loadedHistory = decoded.map((h) => WorkoutLog.fromJson(h)).toList();
        history.clear();
        history.addAll(loadedHistory);
      } catch (e) {
        debugPrint('[WorkoutProvider] Error loading workouts history: $e');
      }
    }
    historyLoaded = true;
    notifyListeners();
    return history;
  }

  void deleteWorkoutLog(String id) {
    history.removeWhere((h) => h.id == id);
    _updateStreak();
    _save();
    unawaited(_firebaseSync.deleteWorkoutLog(currentUserId, id));
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
    final nowLocal = DateTime.now();
    for (final log in history) {
      try {
        final logDate = parseUtcDate(log.date);
        if (logDate.year == nowLocal.year &&
            logDate.month == nowLocal.month &&
            logDate.day == nowLocal.day) {
          if (log.name.isNotEmpty) {
            completedTodayRoutinesSet.add(log.name);
          }
        }
      } catch (_) {}
    }
    final List<String> completedTodayRoutines = completedTodayRoutinesSet.toList();

    final lastDate = history.isNotEmpty ? history.first.date : '';
    streak = WorkoutStreak(
      currentWeekCount: currentWeekCount,
      consecutiveWeeks: consecutiveWeeks,
      lastWorkoutDate: lastDate,
      weekdaysTrained: weekdaysTrained,
      completedTodayRoutines: completedTodayRoutines,
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

  void deletePersonalRecord(String exerciseId) {
    prs.remove(exerciseId);
    _save();
  }

  // --- LIBRARY OPERATIONS ---
  void addLibraryExercise(String name, String muscle, String measurementType, String? notes, String? executionType) {
    final newEx = LibraryExercise(
      id: "lib-${DateTime.now().millisecondsSinceEpoch}",
      name: name,
      muscle: muscle,
      measurementType: measurementTypeFromString(measurementType),
      notes: notes,
      executionType: executionType,
    );
    library = List<LibraryExercise>.from(library)..add(newEx);
    _save();
  }

  void updateLibraryExercise(String id, String name, String muscle, String measurementType, String? notes, String? executionType) {
    final idx = library.indexWhere((e) => e.id == id);
    if (idx != -1) {
      library[idx] = LibraryExercise(
        id: id,
        name: name,
        muscle: muscle,
        measurementType: measurementTypeFromString(measurementType),
        notes: notes,
        executionType: executionType,
      );
      _save();
    }
  }

  void deleteLibraryExercise(String id) {
    library = List<LibraryExercise>.from(library)..removeWhere((e) => e.id == id);
    
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
  }

  // --- ROUTINE OPERATIONS ---
  void addRoutine(String name, int defaultRest, List<RoutineExercise> exercises) {
    final r = Routine(
      id: "routine-${DateTime.now().millisecondsSinceEpoch}",
      name: name,
      defaultRest: defaultRest,
      exercises: exercises,
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

  void deleteRoutine(String id) {
    routines = List<Routine>.from(routines)..removeWhere((r) => r.id == id);
    
    planner.forEach((k, v) {
      planner[k] = v.where((item) => item != 'routine:$id' && item != id).toList();
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
    medidas = List<BodyMeasurement>.from(medidas)..removeWhere((m) => m.id == id);
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
  void updateSettings(bool sound, bool vibration, int prepSeconds) {
    settings = SettingsState(
      sound: sound,
      vibration: vibration,
      prepSeconds: prepSeconds,
    );
    _save();
  }

  void refreshStreak() {
    _updateStreak();
    notifyListeners();
  }
}
