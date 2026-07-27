part of 'workout_provider.dart';

extension WorkoutProviderLibrary on WorkoutProvider {

  void addLibraryExercise(String name, String muscle, String measurementType,
      String? notes, String? executionType) {
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



  void updateLibraryExercise(String id, String name, String muscle,
      String measurementType, String? notes, String? executionType) {
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
}
