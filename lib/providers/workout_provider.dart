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

part 'workout_provider_library.dart';
part 'workout_provider_routine.dart';
part 'workout_provider_history.dart';
part 'workout_provider_active.dart';

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

  set activeWorkout(ActiveWorkoutState? value) {
    _activeWorkout = value;
  }
  List<ActiveWorkoutState> postponedWorkouts = [];
  List<String> deletedHealthWorkoutIds = [];
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

  // --- PERSONAL RECORDS HELPER ---

  // --- STREAK TRACKING ---

  // --- WEEKLY PLANNER ACTIONS ---

  // --- LIBRARY OPERATIONS ---

  // --- ROUTINE OPERATIONS ---

  // --- MEASUREMENT OPERATIONS ---

  // --- SETTINGS OPERATIONS ---

  void updateSettings(bool sound, bool vibration, int prepSeconds) {
    settings = SettingsState(
      sound: sound,
      vibration: vibration,
      prepSeconds: prepSeconds,
    );
    _save();
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
}
