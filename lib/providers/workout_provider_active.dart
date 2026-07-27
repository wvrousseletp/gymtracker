part of 'workout_provider.dart';

// part of WorkoutProvider

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

      // Determine if this is cardio based on measurementType or existing flags
      final isCardio = ex.isCardio ||
          ref.measurementType == MeasurementType.cardio ||
          ref.measurementType == MeasurementType.distance ||
          ref.measurementType == MeasurementType.time;

      // For cardio exercises without sets, use 1 set for UI consistency
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
    WatchService.instance.prepareWatchApp();
    WatchService.instance.sendActiveWorkout(activeWorkout!, force: true);
  }



  void startSingleExercise(LibraryExercise exercise) {
    // Determine if this is a cardio exercise based on measurement type
    final isCardio = exercise.measurementType == MeasurementType.cardio ||
        exercise.measurementType == MeasurementType.distance ||
        exercise.measurementType == MeasurementType.time;

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
          setsState: List<bool>.filled(1, true), // Mark as completed
          performedCardios: List<PerformedCardio?>.filled(1, null),
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

    if (isTransitionToDone) {
      if (setIndex < ex.sets - 1) {
        final endTime =
            DateTime.now().millisecondsSinceEpoch + (ex.rest * 1000);
        computedRestTimer = WatchRestTimer(
          endTime: endTime,
          totalSeconds: ex.rest,
          nextExerciseName: ex.name,
          nextSetNum: setIndex + 2,
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



  void startRestTimer(
      int seconds, String nextExName, int nextSetNum, bool isPrep) {
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
        elapsedSeconds:
            (watchData['elapsedSeconds'] as num?)?.toInt() ??
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

      if (isCardio) {
        // For single cardio sessions, use singleCardioSession
        if (!ex.allowCardioSets && ex.singleCardioSession != null) {
          finalWeight = ex.singleCardioSession!.distanceKm;
          finalReps = ex.singleCardioSession!.durationSeconds ~/ 60;
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
    _updatePersonalRecordsForLog(log, prExerciseNames);

    if (prExerciseNames.isNotEmpty) {
      WatchService.instance.sendPrCelebration(prExerciseNames);
    }

    activeWorkout = null;
    _updateStreak();
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
