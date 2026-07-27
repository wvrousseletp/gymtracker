part of 'workout_provider.dart';

// part of WorkoutProvider

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



  void addManualWorkoutLog(WorkoutLog log) {
    if (history.any((l) => l.id == log.id)) return;
    history = List.from(history)..insert(0, log);

    // Update PRs
    _updatePersonalRecordsForLog(log, null);

    _updateStreak();
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



  void deletePersonalRecord(String exerciseId) {
    prs.remove(exerciseId);
    _save();
  }


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
        if (ex.performedCardios != null && ex.performedCardios!.isNotEmpty) {
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
    final List<String> completedTodayRoutines =
        completedTodayRoutinesSet.toList();

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



  void refreshStreak() {
    _updateStreak();
    notifyListeners();
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
