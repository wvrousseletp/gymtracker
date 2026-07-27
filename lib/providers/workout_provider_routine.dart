part of 'workout_provider.dart';

// part of WorkoutProvider

  void addRoutine(
      String name, int defaultRest, List<RoutineExercise> exercises) {
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
      planner[k] =
          v.where((item) => item != 'routine:$id' && item != id).toList();
    });

    _save();
    unawaited(_firebaseSync.deleteRoutine(currentUserId, id));
  }


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



  void shiftPlannerForward() {
    final List<String> days = ['seg', 'ter', 'qua', 'qui', 'sex', 'sab', 'dom'];
    final Map<String, List<String>> newPlanner = {};
    
    // Shift every day 1 day forward
    for (int i = 0; i < days.length; i++) {
      String currentDay = days[i];
      String nextDay = days[(i + 1) % days.length];
      newPlanner[nextDay] = planner[currentDay] ?? [];
    }
    
    // Save state for undo
    _previousPlanner = Map.from(planner);
    planner = newPlanner;
    
    final restLog = WorkoutLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Dia de Descanso',
      date: DateTime.now().toIso8601String(),
      duration: 0,
      completedSets: 0,
      totalSets: 0,
      totalWeight: 0,
      rpe: 0,
      notes: 'Descanso registrado manualmente.',
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
