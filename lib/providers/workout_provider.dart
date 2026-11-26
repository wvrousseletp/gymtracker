import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
import '../models/engagement.dart';
import '../utils/date_utils.dart';
import '../utils/default_exercises_data.dart';
import 'profile_provider.dart';
import '../services/badges_service.dart';

class WorkoutProvider extends ChangeNotifier {
  final StatePersistenceService _persistence = StatePersistenceService();
  FirebaseSyncService? _firebaseSyncInstance;
  FirebaseSyncService get _firebaseSync =>
      _firebaseSyncInstance ??= FirebaseSyncService();

  List<LibraryExercise> library = [];
  List<Routine> routines = [];
  Map<String, List<String>> planner = {};
  Map<String, WeekTemplate> weekTemplates = {};
  List<WorkoutBlock> continuousBlocks = [];
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

  
  List<String> get flatContinuousList {
    return continuousBlocks.map((b) => b.routineIds).expand((x) => x).toList();
  }

  int _blockIdSeq = 0;

  void addContinuousBlock({String? name}) {
    final newId =
        '${DateTime.now().microsecondsSinceEpoch}_${_blockIdSeq++}';
    final newName = name ?? 'Bloco ${continuousBlocks.length + 1}';
    final newBlock = WorkoutBlock(id: newId, name: newName, routineIds: []);
    continuousBlocks = List<WorkoutBlock>.from(continuousBlocks)..add(newBlock);
    _save();
  }

  void renameContinuousBlock(String blockId, String newName) {
    continuousBlocks = continuousBlocks.map((b) {
      if (b.id == blockId) return b.copyWith(name: newName);
      return b;
    }).toList();
    _save();
  }

  void removeContinuousBlock(String blockId) {
    continuousBlocks = List<WorkoutBlock>.from(continuousBlocks)..removeWhere((b) => b.id == blockId);
    
    // adjust index
    final flattened = continuousBlocks.map((b) => b.routineIds).expand((x) => x).toList();
    int newIndex = settings.continuousListCurrentIndex;
    if (flattened.isNotEmpty) {
      newIndex = newIndex % flattened.length;
    } else {
      newIndex = 0;
    }
    settings = settings.copyWith(continuousListCurrentIndex: newIndex);
    _save();
  }

  void reorderContinuousBlocks(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final updatedBlocks = List<WorkoutBlock>.from(continuousBlocks);
    final item = updatedBlocks.removeAt(oldIndex);
    updatedBlocks.insert(newIndex, item);
    continuousBlocks = updatedBlocks;
    _save();
  }

  void addRoutineToContinuousBlock(String blockId, String routineId) {
    continuousBlocks = continuousBlocks.map((b) {
      if (b.id == blockId) {
        return b.copyWith(routineIds: List.from(b.routineIds)..add(routineId));
      }
      return b;
    }).toList();
    _save();
  }

  void updateRoutineInContinuousBlock(String blockId, int index, String newValue) {
    continuousBlocks = continuousBlocks.map((b) {
      if (b.id == blockId) {
        final newRoutines = List<String>.from(b.routineIds);
        if (index >= 0 && index < newRoutines.length) {
          newRoutines[index] = newValue;
        }
        return b.copyWith(routineIds: newRoutines);
      }
      return b;
    }).toList();
    _save();
  }

  void removeRoutineFromContinuousBlock(String blockId, int index) {
    continuousBlocks = continuousBlocks.map((b) {
      if (b.id == blockId) {
        final newRoutines = List<String>.from(b.routineIds);
        if (index >= 0 && index < newRoutines.length) {
          newRoutines.removeAt(index);
        }
        return b.copyWith(routineIds: newRoutines);
      }
      return b;
    }).toList();
    
    // adjust index
    final flattened = continuousBlocks.map((b) => b.routineIds).expand((x) => x).toList();
    int newIndex = settings.continuousListCurrentIndex;
    if (flattened.isNotEmpty) {
      newIndex = newIndex % flattened.length;
    } else {
      newIndex = 0;
    }
    settings = settings.copyWith(continuousListCurrentIndex: newIndex);
    _save();
  }

  void reorderRoutinesInContinuousBlock(String blockId, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    continuousBlocks = continuousBlocks.map((b) {
      if (b.id == blockId) {
        final newRoutines = List<String>.from(b.routineIds);
        final item = newRoutines.removeAt(oldIndex);
        newRoutines.insert(newIndex, item);
        return b.copyWith(routineIds: newRoutines);
      }
      return b;
    }).toList();
    _save();
  }

  void copyDayToContinuousBlock(String fromDay) {
    final sourceList = planner[fromDay] ?? [];
    final validItems = sourceList.where((item) => item.isNotEmpty).toList();
    if (validItems.isEmpty) return;
    
    final dayNameMap = {
      'seg': 'Segunda',
      'ter': 'Terça',
      'qua': 'Quarta',
      'qui': 'Quinta',
      'sex': 'Sexta',
      'sab': 'Sábado',
      'dom': 'Domingo'
    };
    final suffix = dayNameMap[fromDay] ?? fromDay;
    
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newBlock = WorkoutBlock(
      id: newId, 
      name: 'Treinos de $suffix', 
      routineIds: List.from(validItems)
    );
    
    continuousBlocks = List<WorkoutBlock>.from(continuousBlocks)..add(newBlock);
    _save();
  }

  List<String> get todayPlannedItems {
    final mode = settings.organizationMode;

    if (mode == OrganizationMode.continuousList) {
      final list = flatContinuousList;
      if (list.isEmpty) return [];
      if (settings.continuousListRestDate == _todayDateKey()) return [];
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
  void _applyHistoryToExercises(List<ActiveExercise> exercises) {
    if (history.isEmpty) return;
    for (int i = 0; i < exercises.length; i++) {
      final ex = exercises[i];
      for (final log in history) {
        final previousEx = log.exercises.where((le) => le.name == ex.name).firstOrNull;
        if (previousEx != null) {
          if (previousEx.weight > 0 && ex.weight == 0) {
            exercises[i] = ex.copyWith(
              weight: previousEx.weight,
              reps: ex.reps == 10 && previousEx.reps > 0
                  ? previousEx.reps
                  : ex.reps,
            );
          } else if (ex.weight == 0 && ex.reps == 10 && previousEx.reps > 0) {
            exercises[i] = ex.copyWith(reps: previousEx.reps);
          }
          break;
        }
      }
    }
  }

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

          final cycleSetType =
              (ex.setTypes != null && ex.setTypes!.length > cycle)
                  ? [ex.setTypes![cycle]]
                  : null;
          final cycleRir =
              (ex.rirPerSet != null && ex.rirPerSet!.length > cycle)
                  ? [ex.rirPerSet![cycle]]
                  : null;

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
            weightsPerSet: null, // Achatado, então usa o global
            repsPerSet: null, // Achatado
            setTypes: cycleSetType,
            rirPerSet: cycleRir,
            setsState: List<bool>.filled(effectiveSets, false),
            performedCardios:
                List<PerformedCardio?>.filled(effectiveSets, null),
            failureReport: List<bool>.filled(effectiveSets, false),
            isCardio: isCardio,
            allowCardioSets: false,
            isStationary: ref.isStationary,
            isUnilateral: ex.isUnilateral || ref.isUnilateral,
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
          weightsPerSet: ex.weightsPerSet != null
              ? List<double>.from(ex.weightsPerSet!)
              : null,
          repsPerSet:
              ex.repsPerSet != null ? List<int>.from(ex.repsPerSet!) : null,
          setTypes:
              ex.setTypes != null ? List<String>.from(ex.setTypes!) : null,
          rirPerSet:
              ex.rirPerSet != null ? List<int?>.from(ex.rirPerSet!) : null,
          setsState: List<bool>.filled(effectiveSets, false),
          performedCardios: List<PerformedCardio?>.filled(effectiveSets, null),
          failureReport: List<bool>.filled(effectiveSets, false),
          isCardio: isCardio,
          allowCardioSets: ex.allowCardioSets,
          supersetId: ex.supersetId,
          isStationary: ref.isStationary,
          isUnilateral: ex.isUnilateral || ref.isUnilateral,
        );
      }).toList();
    }

    _applyHistoryToExercises(workoutExercises);

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
          isUnilateral: exercise.isUnilateral,
        )
      ],
    );
    startWorkout(
        tempRoutine,
        WorkoutRecovery(
            sleepOk: SleepQuality.okay, pain: [], warmUpDone: false),
        false);
  }

  void addDropSet(
      int exIdx, int sourceSetIdx, double dropWeight, int dropReps) {
    if (activeWorkout == null) return;
    final active = activeWorkout!;
    if (exIdx < 0 || exIdx >= active.exercises.length) return;
    final exercises = List<ActiveExercise>.from(active.exercises);
    final ex = exercises[exIdx];
    final insertAt = (sourceSetIdx + 1).clamp(0, ex.sets);

    final newSetsState = List<bool>.from(ex.setsState)
      ..insert(insertAt, false);
    final newWeights = ex.weightsPerSet != null
        ? (List<double>.from(ex.weightsPerSet!)..insert(insertAt, dropWeight))
        : (List<double>.filled(ex.sets, ex.weight, growable: true)
          ..insert(insertAt, dropWeight));
    final newReps = ex.repsPerSet != null
        ? (List<int>.from(ex.repsPerSet!)..insert(insertAt, dropReps))
        : (List<int>.filled(ex.sets, ex.reps, growable: true)
          ..insert(insertAt, dropReps));
    final newFailure = List<bool>.from(ex.failureReport);
    while (newFailure.length < ex.sets) {
      newFailure.add(false);
    }
    newFailure.insert(insertAt, false);

    final newFailureReps = List<int?>.from(ex.failureReps);
    while (newFailureReps.length < ex.sets) {
      newFailureReps.add(null);
    }
    newFailureReps.insert(insertAt, null);

    final newCardios = List<PerformedCardio?>.from(ex.performedCardios);
    while (newCardios.length < ex.sets) {
      newCardios.add(null);
    }
    newCardios.insert(insertAt, null);

    final newSetTypes = ex.setTypes != null
        ? (List<String>.from(ex.setTypes!)..insert(insertAt, 'D'))
        : (List<String>.filled(ex.sets, 'N', growable: true)
          ..insert(insertAt, 'D'));

    final newRirs = ex.rirPerSet != null
        ? (List<int?>.from(ex.rirPerSet!)..insert(insertAt, null))
        : null;

    exercises[exIdx] = ex.copyWith(
      sets: ex.sets + 1,
      setsState: newSetsState,
      weightsPerSet: newWeights,
      repsPerSet: newReps,
      failureReport: newFailure,
      failureReps: newFailureReps,
      performedCardios: newCardios,
      setTypes: newSetTypes,
      rirPerSet: newRirs,
    );

    activeWorkout = active.copyWith(exercises: exercises);
    _save();
  }

  /// Calcula o tempo de descanso adaptativo considerando tipo de série (Aquecimento 'W'),
  /// falha concêntrica, RIR 0 e RPE máximo.
  int computeAdaptiveRestSeconds(
    ActiveExercise ex,
    int setIndex, {
    required bool isFailure,
  }) {
    int base = ex.rest;
    if (base <= 0) return 0;

    final setType = (ex.setTypes != null && setIndex < ex.setTypes!.length)
        ? ex.setTypes![setIndex].toUpperCase()
        : 'N';
    final setRir = (ex.rirPerSet != null && setIndex < ex.rirPerSet!.length)
        ? ex.rirPerSet![setIndex]
        : null;

    if (setType == 'W') {
      // Aquecimento: metade do descanso padrão (mínimo 15s)
      return (base * 0.5).round().clamp(15, base);
    }
    if (isFailure || setRir == 0 || (ex.rpe != null && ex.rpe! >= 10)) {
      // Falha ou esforço máximo: +30s de recuperação neural/ATP
      return base + 30;
    }
    return base;
  }

  /// Retorna os índices contíguos que pertencem ao mesmo Bi-set / Superset de [exIndex].
  List<int> _getSupersetGroupIndices(
      List<ActiveExercise> exercises, int exIndex) {
    if (exIndex < 0 || exIndex >= exercises.length) return [exIndex];
    final supId = exercises[exIndex].supersetId;
    if (supId == null || supId.isEmpty) return [exIndex];

    int start = exIndex;
    while (start > 0 && exercises[start - 1].supersetId == supId) {
      start--;
    }
    int end = exIndex;
    while (
        end + 1 < exercises.length && exercises[end + 1].supersetId == supId) {
      end++;
    }
    return [for (int i = start; i <= end; i++) i];
  }

  int _findNextUncompletedExerciseOutside(
    List<ActiveExercise> exercises,
    int afterIndex, {
    Set<int> exclude = const {},
  }) {
    for (int i = afterIndex + 1; i < exercises.length; i++) {
      if (!exclude.contains(i) && exercises[i].setsState.contains(false)) {
        return i;
      }
    }
    for (int i = 0; i <= afterIndex && i < exercises.length; i++) {
      if (!exclude.contains(i) && exercises[i].setsState.contains(false)) {
        return i;
      }
    }
    return -1;
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
        exercises[exIndex] = ex.copyWith(
          setsState: List<bool>.filled(1, isDone), // Mark as completed
          performedCardios: [
            PerformedCardio(distanceKm: distance, durationSeconds: duration)
          ],
          failureReport: List<bool>.filled(1, false),
          failureReps: List<int?>.filled(1, null),
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

    final updatedEx = ex.copyWith(
      setsState: newSetsState,
      performedCardios: newCardios,
      failureReport: newFailure,
      failureReps: newFailureReps,
    );
    exercises[exIndex] = updatedEx;

    WatchRestTimer? computedRestTimer = active.restTimer;
    int computedExIndex = active.currentExerciseIndex;

    final bool wasDone =
        setIndex < ex.setsState.length ? ex.setsState[setIndex] : false;
    final bool isTransitionToDone = !wasDone && isDone;
    final bool isStateChanged = wasDone != isDone;

    final int effectiveRest =
        computeAdaptiveRestSeconds(updatedEx, setIndex, isFailure: isFailure);
    bool shouldRest = effectiveRest > 0;
    if (shouldRest &&
        active.executionType == RoutineExecutionType.circuit &&
        active.circuitCycles > 0) {
      final exercisesPerCycle = exercises.length ~/ active.circuitCycles;
      if (exercisesPerCycle > 0) {
        final isCycleEnd = (exIndex + 1) % exercisesPerCycle == 0;
        if (!isCycleEnd) {
          shouldRest = false;
        }
      }
    }

    final supersetIndices = active.executionType == RoutineExecutionType.circuit
        ? <int>[exIndex]
        : _getSupersetGroupIndices(exercises, exIndex);
    final bool isInSuperset = supersetIndices.length > 1;

    if (isTransitionToDone && isInSuperset) {
      // 1. Procura próximo exercício parceiro do Bi-set/Superset na mesma rodada (setIndex)
      int partnerIdx = -1;
      for (final idx in supersetIndices) {
        if (idx > exIndex &&
            setIndex < exercises[idx].setsState.length &&
            !exercises[idx].setsState[setIndex]) {
          partnerIdx = idx;
          break;
        }
      }
      if (partnerIdx == -1) {
        for (final idx in supersetIndices) {
          if (idx < exIndex &&
              setIndex < exercises[idx].setsState.length &&
              !exercises[idx].setsState[setIndex]) {
            partnerIdx = idx;
            break;
          }
        }
      }

      if (partnerIdx != -1) {
        // Transição intra-Bi-set: sem descanso, avança direto para o parceiro!
        computedRestTimer = null;
        computedExIndex = partnerIdx;
      } else {
        // Fechou a rodada do Bi-set: verifica se ainda há séries pendentes no grupo
        int nextRoundExIdx = -1;
        for (final idx in supersetIndices) {
          if (exercises[idx].setsState.contains(false)) {
            nextRoundExIdx = idx;
            break;
          }
        }

        if (nextRoundExIdx != -1) {
          final nextEx = exercises[nextRoundExIdx];
          int nextSetIdx = nextEx.setsState.indexWhere((done) => !done);
          if (nextSetIdx == -1) nextSetIdx = 0;
          computedExIndex = nextRoundExIdx;
          if (shouldRest) {
            final endTime =
                DateTime.now().millisecondsSinceEpoch + (effectiveRest * 1000);
            computedRestTimer = WatchRestTimer(
              endTime: endTime,
              totalSeconds: effectiveRest,
              nextExerciseName: nextEx.name,
              nextSetNum: nextSetIdx + 1,
              nextTargetReps: nextEx.repsPerSet != null &&
                      nextSetIdx < nextEx.repsPerSet!.length
                  ? nextEx.repsPerSet![nextSetIdx]
                  : nextEx.reps,
              nextTargetWeight: nextEx.weightsPerSet != null &&
                      nextSetIdx < nextEx.weightsPerSet!.length
                  ? nextEx.weightsPerSet![nextSetIdx]
                  : nextEx.weight,
              isPrep: false,
            );
          } else {
            computedRestTimer = null;
          }
        } else {
          // Todo o Bi-set foi concluído -> avança para o próximo exercício fora do grupo
          final nextExIndex = _findNextUncompletedExerciseOutside(
            exercises,
            supersetIndices.last,
            exclude: supersetIndices.toSet(),
          );
          if (nextExIndex != -1) {
            final nextEx = exercises[nextExIndex];
            int nextSetIdx = nextEx.setsState.indexWhere((done) => !done);
            if (nextSetIdx == -1) nextSetIdx = 0;
            computedExIndex = nextExIndex;
            if (shouldRest) {
              final endTime = DateTime.now().millisecondsSinceEpoch +
                  (effectiveRest * 1000);
              computedRestTimer = WatchRestTimer(
                endTime: endTime,
                totalSeconds: effectiveRest,
                nextExerciseName: nextEx.name,
                nextSetNum: nextSetIdx + 1,
                nextTargetReps: nextEx.repsPerSet != null &&
                        nextSetIdx < nextEx.repsPerSet!.length
                    ? nextEx.repsPerSet![nextSetIdx]
                    : nextEx.reps,
                nextTargetWeight: nextEx.weightsPerSet != null &&
                        nextSetIdx < nextEx.weightsPerSet!.length
                    ? nextEx.weightsPerSet![nextSetIdx]
                    : nextEx.weight,
                isPrep: false,
              );
            } else {
              computedRestTimer = null;
            }
          } else {
            computedRestTimer = null;
          }
        }
      }
    } else if (isTransitionToDone && shouldRest) {
      if (setIndex < ex.sets - 1) {
        final nextSetIdx = setIndex + 1;
        final endTime =
            DateTime.now().millisecondsSinceEpoch + (effectiveRest * 1000);
        computedRestTimer = WatchRestTimer(
          endTime: endTime,
          totalSeconds: effectiveRest,
          nextExerciseName: ex.name,
          nextSetNum: setIndex + 2,
          nextTargetReps:
              ex.repsPerSet != null && nextSetIdx < ex.repsPerSet!.length
                  ? ex.repsPerSet![nextSetIdx]
                  : ex.reps,
          nextTargetWeight:
              ex.weightsPerSet != null && nextSetIdx < ex.weightsPerSet!.length
                  ? ex.weightsPerSet![nextSetIdx]
                  : ex.weight,
          isPrep: false,
        );
      } else {
        // Find next uncompleted exercise (wrapping around if needed)
        final nextExIndex = _findNextUncompletedExerciseOutside(
          exercises,
          exIndex,
          exclude: {exIndex},
        );

        if (nextExIndex != -1) {
          final nextEx = exercises[nextExIndex];
          int nextSetIndex = nextEx.setsState.indexWhere((done) => !done);
          if (nextSetIndex == -1) nextSetIndex = 0;

          final endTime =
              DateTime.now().millisecondsSinceEpoch + (effectiveRest * 1000);
          computedRestTimer = WatchRestTimer(
            endTime: endTime,
            totalSeconds: effectiveRest,
            nextExerciseName: nextEx.name,
            nextSetNum: nextSetIndex + 1,
            nextTargetReps: nextEx.repsPerSet != null &&
                    nextSetIndex < nextEx.repsPerSet!.length
                ? nextEx.repsPerSet![nextSetIndex]
                : nextEx.reps,
            nextTargetWeight: nextEx.weightsPerSet != null &&
                    nextSetIndex < nextEx.weightsPerSet!.length
                ? nextEx.weightsPerSet![nextSetIndex]
                : nextEx.weight,
            isPrep: false,
          );
          computedExIndex = nextExIndex;
        } else {
          computedRestTimer = null;
        }
      }
    } else {
      computedRestTimer = null;
      if (isTransitionToDone && setIndex >= ex.sets - 1) {
        final nextExIndex = _findNextUncompletedExerciseOutside(
          exercises,
          exIndex,
          exclude: {exIndex},
        );

        if (nextExIndex != -1) {
          computedExIndex = nextExIndex;
        } else if (exIndex < exercises.length - 1) {
          computedExIndex = exIndex + 1;
        }
      }
    }

    activeWorkout = active.copyWith(
      exercises: exercises,
      currentExerciseIndex: computedExIndex,
      restTimer: computedRestTimer,
      clearRestTimer: computedRestTimer == null,
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
          onCompleted: clearRestTimer,
        );
      } else {
        RestTimerService.instance.clear();
      }
    }
  }

  void replaceActiveExercise(String oldExerciseId, LibraryExercise newLibExercise) {
    if (activeWorkout == null) return;
    
    final exercises = List<ActiveExercise>.from(activeWorkout!.exercises);
    final index = exercises.indexWhere((e) => e.id == oldExerciseId);
    if (index == -1) return;

    final oldEx = exercises[index];
    final isCardio = (newLibExercise.measurementType == MeasurementType.cardio ||
            newLibExercise.measurementType == MeasurementType.distance) &&
        newLibExercise.measurementType != MeasurementType.time;

    final newEx = ActiveExercise(
      id: oldEx.id,
      name: newLibExercise.name,
      muscle: newLibExercise.muscle,
      executionType: newLibExercise.executionType,
      measurementType: newLibExercise.measurementType,
      sets: isCardio ? 1 : 3,
      reps: isCardio ? 0 : 10,
      rest: oldEx.rest,
      weight: 0.0,
      setsState: List<bool>.filled(isCardio ? 1 : 3, false),
      performedCardios: List<PerformedCardio?>.filled(isCardio ? 1 : 3, null),
      failureReport: List<bool>.filled(isCardio ? 1 : 3, false),
      isCardio: isCardio,
      allowCardioSets: false,
    );

    exercises[index] = newEx;
    
    // Auto-fill the newly replaced exercise
    _applyHistoryToExercises([exercises[index]]);

    activeWorkout = ActiveWorkoutState(
      name: activeWorkout!.name,
      startTime: activeWorkout!.startTime,
      exercises: exercises,
      currentExerciseIndex: activeWorkout!.currentExerciseIndex,
      elapsedSeconds: activeWorkout!.elapsedSeconds,
      paused: activeWorkout!.paused,
      restTimer: activeWorkout!.restTimer,
      warmupDurationSeconds: activeWorkout!.warmupDurationSeconds,
      heartRate: activeWorkout!.heartRate,
      activeCalories: activeWorkout!.activeCalories,
      postponed: activeWorkout!.postponed,
      recovery: activeWorkout!.recovery,
      isWarmup: activeWorkout!.isWarmup,
      executionType: activeWorkout!.executionType,
      circuitCycles: activeWorkout!.circuitCycles,
    );
    _save();
    WatchService.instance.sendActiveWorkout(activeWorkout!, force: true);
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
      onCompleted: clearRestTimer,
    );
  }

  void clearRestTimer() {
    if (activeWorkout == null) return;
    final active = activeWorkout!;

    activeWorkout = active.copyWith(
      clearRestTimer: true,
    );

    _save();
    RestTimerService.instance.clear();
  }

  void adjustRestTimer(int seconds) {
    if (activeWorkout == null) return;
    final active = activeWorkout!;
    if (active.restTimer == null) return;

    final timer = active.restTimer!;
    final newEndTime = timer.endTime + (seconds * 1000);
    final newTotalSeconds = (timer.totalSeconds + seconds) > 0 ? (timer.totalSeconds + seconds) : 1;

    final newTimer = WatchRestTimer(
      endTime: newEndTime,
      totalSeconds: newTotalSeconds,
      nextExerciseName: timer.nextExerciseName,
      nextSetNum: timer.nextSetNum,
      nextTargetReps: timer.nextTargetReps,
      nextTargetWeight: timer.nextTargetWeight,
      isPrep: timer.isPrep,
    );

    activeWorkout = active.copyWith(
      restTimer: newTimer,
    );

    _save();
    RestTimerService.instance.start(
      endTimeMs: newTimer.endTime,
      seconds: newTimer.totalSeconds,
      prep: newTimer.isPrep,
      exName: newTimer.nextExerciseName,
      setNum: newTimer.nextSetNum,
      targetReps: newTimer.nextTargetReps,
      targetWeight: newTimer.nextTargetWeight,
      onCompleted: clearRestTimer,
    );
  }

  void updateExerciseWeightReps(int exIndex, double weight, int reps) {
    if (activeWorkout == null) return;
    final active = activeWorkout!;
    final exercises = List<ActiveExercise>.from(active.exercises);
    if (exIndex >= exercises.length) return;

    final ex = exercises[exIndex];
    exercises[exIndex] = ex.copyWith(
      reps: reps,
      weight: weight,
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
      _activeWorkout!.exercises[exIdx] = ex.copyWith(
        setTypes: types,
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
      _activeWorkout!.exercises[exIdx] = ex.copyWith(
        rirPerSet: rirs,
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

    exercises[exIndex] = ex.copyWith(
      reps: mainReps,
      weight: mainWeight,
      weightsPerSet: newWeights,
      repsPerSet: newReps,
    );

    activeWorkout = active.copyWith(
      exercises: exercises,
    );
    WatchService.instance.sendActiveWorkout(activeWorkout!);
    _save();
  }

  /// Localiza a rotina de origem de um exercício do treino ativo,
  /// casando o id do exercício ativo com o RoutineExercise.id.
  /// Retorna null para exercícios avulsos/dinâmicos.
  ({Routine routine, int exerciseIndex})? findActiveExerciseSourceRoutine(
      int exIndex) {
    final active = _activeWorkout;
    if (active == null ||
        exIndex < 0 ||
        exIndex >= active.exercises.length) {
      return null;
    }
    var exId = active.exercises[exIndex].id;
    final cycleSep = exId.indexOf('_cycle_');
    if (cycleSep >= 0) exId = exId.substring(0, cycleSep);
    for (final r in routines) {
      final idx = r.exercises.indexWhere((e) => e.id == exId);
      if (idx >= 0) return (routine: r, exerciseIndex: idx);
    }
    return null;
  }

  /// Retorna os índices dos exercícios do treino ativo cujas cargas, repetições
  /// ou séries foram alteradas em relação à rotina original.
  List<int> getModifiedRoutineExerciseIndices() {
    final active = _activeWorkout;
    if (active == null ||
        active.executionType == RoutineExecutionType.circuit) {
      return [];
    }
    final modified = <int>[];
    for (int i = 0; i < active.exercises.length; i++) {
      final ex = active.exercises[i];
      if (ex.isCardio) continue;
      final found = findActiveExerciseSourceRoutine(i);
      if (found == null || found.routine.isDynamicExercise) continue;
      final re = found.routine.exercises[found.exerciseIndex];

      bool changed = ex.sets != re.sets ||
          (ex.weight - re.weight).abs() > 0.001 ||
          ex.reps != re.reps;

      if (!changed && (ex.weightsPerSet != null || re.weightsPerSet != null)) {
        final aWeights =
            ex.weightsPerSet ?? List<double>.filled(ex.sets, ex.weight);
        final rWeights =
            re.weightsPerSet ?? List<double>.filled(re.sets, re.weight);
        if (aWeights.length != rWeights.length) {
          changed = true;
        } else {
          for (int k = 0; k < aWeights.length; k++) {
            if ((aWeights[k] - rWeights[k]).abs() > 0.001) {
              changed = true;
              break;
            }
          }
        }
      }

      if (!changed && (ex.repsPerSet != null || re.repsPerSet != null)) {
        final aReps = ex.repsPerSet ?? List<int>.filled(ex.sets, ex.reps);
        final rReps = re.repsPerSet ?? List<int>.filled(re.sets, re.reps);
        if (!listEquals(aReps, rReps)) {
          changed = true;
        }
      }

      if (changed) {
        modified.add(i);
      }
    }
    return modified;
  }

  /// Aplica em lote todas as progressões de carga/reps/séries do treino ativo
  /// de volta às rotinas originais e sincroniza com o Firebase.
  int applyAllModifiedExercisesToRoutine() {
    final indices = getModifiedRoutineExerciseIndices();
    int count = 0;
    final touchedRoutineIds = <String>{};
    for (final idx in indices) {
      final found = findActiveExerciseSourceRoutine(idx);
      if (applyActiveExerciseToRoutine(idx)) {
        count++;
        if (found != null) touchedRoutineIds.add(found.routine.id);
      }
    }
    for (final rId in touchedRoutineIds) {
      final updated = routines.where((r) => r.id == rId).firstOrNull;
      if (updated != null && currentUserId.isNotEmpty) {
        unawaited(_firebaseSync.syncRoutine(currentUserId, updated));
      }
    }
    return count;
  }

  /// Copia peso/reps/séries atuais do exercício ativo de volta para a
  /// rotina que o originou. Retorna false se não houver rotina de origem.
  bool applyActiveExerciseToRoutine(int exIndex) {
    final active = _activeWorkout;
    if (active == null) return false;
    final found = findActiveExerciseSourceRoutine(exIndex);
    if (found == null) return false;

    final activeEx = active.exercises[exIndex];
    final re = found.routine.exercises[found.exerciseIndex];

    final updatedRe = RoutineExercise(
      id: re.id,
      exerciseId: re.exerciseId,
      sets: activeEx.isCardio ? re.sets : activeEx.sets,
      reps: activeEx.reps,
      rest: re.rest,
      weight: activeEx.weight,
      weightsPerSet: activeEx.weightsPerSet,
      repsPerSet: activeEx.repsPerSet,
      setTypes: activeEx.setTypes ?? re.setTypes,
      rirPerSet: activeEx.rirPerSet ?? re.rirPerSet,
      isCardio: re.isCardio,
      allowCardioSets: re.allowCardioSets,
      supersetId: re.supersetId,
      isUnilateral: activeEx.isUnilateral,
    );

    final newExercises = List<RoutineExercise>.from(found.routine.exercises);
    newExercises[found.exerciseIndex] = updatedRe;

    routines = routines
        .map((r) => r.id == found.routine.id
            ? r.copyWith(exercises: newExercises)
            : r)
        .toList();
    _save();
    return true;
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

        merged[i] = ios.copyWith(
          setsState: mergedSets,
          performedCardios: mergedCardios,
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
            : null,
        clearRestTimer: watchData['restTimer'] == null,
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
      clearRestTimer: true,
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

  WorkoutLog _buildLogFromActive(ActiveWorkoutState active, int duration,
      int rpeValue, String notes,
      {String? id, DateTime? date}) {
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
      List<double>? loggedWeightsPerSet;
      List<int>? loggedRepsPerSet;

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
        loggedWeightsPerSet = [];
        loggedRepsPerSet = [];
        double bestWorkingWeight = -1;
        int bestWorkingReps = 0;
        double bestWarmupWeight = -1;
        int bestWarmupReps = 0;

        for (int i = 0; i < ex.sets; i++) {
          final bool isSetDone = i < ex.setsState.length && ex.setsState[i];
          final String setType =
              (ex.setTypes != null && i < ex.setTypes!.length)
                  ? ex.setTypes![i].toUpperCase()
                  : 'N';
          final double setWeight =
              (ex.weightsPerSet != null && i < ex.weightsPerSet!.length)
                  ? ex.weightsPerSet![i]
                  : ex.weight;
          final int plannedReps =
              (ex.repsPerSet != null && i < ex.repsPerSet!.length)
                  ? ex.repsPerSet![i]
                  : ex.reps;
          final bool isFail =
              i < ex.failureReport.length && ex.failureReport[i];
          final int? failRepsVal =
              i < ex.failureReps.length ? ex.failureReps[i] : null;
          final int actualReps =
              (isFail && failRepsVal != null && failRepsVal > 0)
                  ? failRepsVal
                  : plannedReps;

          if (isSetDone) {
            loggedWeightsPerSet.add(setWeight);
            loggedRepsPerSet.add(actualReps);
            if (setType != 'W') {
              totalWeightVolume += setWeight * actualReps;
              if (setWeight > bestWorkingWeight ||
                  (setWeight == bestWorkingWeight &&
                      actualReps > bestWorkingReps)) {
                bestWorkingWeight = setWeight;
                bestWorkingReps = actualReps;
              }
            } else {
              if (setWeight > bestWarmupWeight ||
                  (setWeight == bestWarmupWeight &&
                      actualReps > bestWarmupReps)) {
                bestWarmupWeight = setWeight;
                bestWarmupReps = actualReps;
              }
            }
          } else {
            loggedWeightsPerSet.add(0.0);
            loggedRepsPerSet.add(0);
          }
        }

        if (bestWorkingWeight >= 0) {
          finalWeight = bestWorkingWeight;
          finalReps = bestWorkingReps;
        } else if (bestWarmupWeight >= 0) {
          finalWeight = bestWarmupWeight;
          finalReps = bestWarmupReps;
        }
      }

      return LogExercise(
        name: ex.name,
        muscle: ex.muscle,
        sets: ex.sets,
        completedSets: done,
        reps: finalReps,
        weight: finalWeight,
        weightsPerSet: loggedWeightsPerSet,
        repsPerSet: loggedRepsPerSet,
        performedCardios: logCardios,
        rpe: ex.rpe ?? rpeValue,
        failureReport: ex.failureReport,
        failureReps: ex.failureReps,
        executionType: ex.executionType,
        setTypes: ex.setTypes != null ? List<String>.from(ex.setTypes!) : null,
        rirPerSet: ex.rirPerSet != null ? List<int?>.from(ex.rirPerSet!) : null,
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
      id: id ?? "log-${DateTime.now().millisecondsSinceEpoch}",
      name: active.name,
      date: (date ?? DateTime.now()).toUtc().toIso8601String(),
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
    return log;
  }

  void finishWorkout(int duration, int rpeValue, String notes) {
    if (activeWorkout == null) return;
    RestTimerService.instance.clear();

    final active = activeWorkout!;
    final log = _buildLogFromActive(active, duration, rpeValue, notes);

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
      final continuousList = flatContinuousList;
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

    if (currentUserId.isNotEmpty) {
      unawaited(_firebaseSync.syncWorkoutLog(currentUserId, log));
    }

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

    if (!log.isRestDayLog) {
      // Update PRs
      _updatePersonalRecordsForLog(log, null);
    }

    _updateStreak();

    if (!log.isRestDayLog) {
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
    }

    _save();
    notifyListeners();
    if (currentUserId.isNotEmpty) {
      unawaited(_firebaseSync.syncWorkoutLog(currentUserId, log));
    }

    // Save to HealthKit (skip if it's already from HealthKit or a rest day)
    if (!log.id.startsWith("healthkit-") && !log.isRestDayLog) {
      unawaited(HealthService.instance.saveWorkoutToHealthKit(
        name: log.name,
        duration: log.duration,
        date: log.date,
        calories: log.activeCalories,
      ));
    }
  }

  /// Registers a workout completed on the Apple Watch while the iPhone was
  /// unreachable. [workoutData] is the WatchActiveWorkoutState payload and
  /// [workoutId] is the queue id used by the Watch for ack/dedup.
  void addOfflineWatchWorkout(
      Map<String, dynamic> workoutData, String workoutId) {
    final effectiveId = workoutId.isNotEmpty
        ? workoutId
        : "watch-${DateTime.now().millisecondsSinceEpoch}";
    if (history.any((l) => l.id == effectiveId)) return;

    try {
      final active = ActiveWorkoutState.fromJson(workoutData);
      var duration = active.elapsedSeconds;
      if (duration <= 0 && active.startTime > 0) {
        duration = ((DateTime.now().millisecondsSinceEpoch -
                    active.startTime) ~/
                1000)
            .clamp(0, 86400);
      }
      final startDate = active.startTime > 0
          ? DateTime.fromMillisecondsSinceEpoch(active.startTime)
          : DateTime.now();
      final log = _buildLogFromActive(active, duration, 7,
          'Treino concluído offline via Apple Watch',
          id: effectiveId, date: startDate);
      addManualWorkoutLog(log);

      // Advance continuous list like finishWorkout does
      if (settings.organizationMode == OrganizationMode.continuousList) {
        final continuousList = flatContinuousList;
        if (continuousList.isNotEmpty) {
          setContinuousListIndex(
              (settings.continuousListCurrentIndex + 1) %
                  continuousList.length);
        }
      }
    } catch (e) {
      debugPrint('[WorkoutProvider] addOfflineWatchWorkout failed: $e');
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

      int addedCount = 0;
      for (final hw in healthWorkouts) {
        final id = hw['id'] as String;
        final name = hw['name'] as String;
        final duration = hw['duration'] as int;
        final calories = hw['calories'] as int?;
        final dateStr = hw['date'] as String;

        // Skip if already in history or deleted
        if (history.any((h) => h.id == id)) {
          continue;
        }
        if (deletedHealthWorkoutIds.contains(id)) {
          continue;
        }

        // Deduplicate against local Los Mooscles workouts within ±3 minutes
        final hwDate = DateTime.tryParse(dateStr);
        if (hwDate != null) {
          final isDuplicateLocal = history.any((h) {
            if (h.id.startsWith('healthkit-') || h.isRestDayLog) return false;
            final localDate = DateTime.tryParse(h.date);
            if (localDate == null) return false;
            return hwDate.difference(localDate).abs().inMinutes <= 3;
          });
          if (isDuplicateLocal) {
            debugPrint(
                '[WorkoutProvider] Skipping HealthKit workout near local workout: $id');
            continue;
          }
        }

        final durationMin = (duration / 60).round().clamp(1, 1440);
        final healthLog = WorkoutLog(
          id: id,
          name: name,
          date: dateStr,
          duration: duration,
          completedSets: 1,
          totalSets: 1,
          totalWeight: 0,
          rpe: 5,
          notes: 'Sincronizado via Apple Saúde',
          exercises: [
            LogExercise(
              name: name,
              muscle: 'Cardio',
              sets: 1,
              completedSets: 1,
              reps: durationMin,
              weight: 0,
              rpe: 5,
              performedCardios: [
                PerformedCardio(distanceKm: 0, durationSeconds: duration),
              ],
            ),
          ],
          activeCalories: calories,
        );

        history.insert(0, healthLog);
        addedCount++;
        unawaited(_firebaseSync.syncWorkoutLog(currentUserId, healthLog));
        debugPrint(
            '[WorkoutProvider] Added HealthKit workout to history: $name');
      }

      if (addedCount > 0) {
        history.sort((a, b) {
          final da = DateTime.tryParse(a.date) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final db = DateTime.tryParse(b.date) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
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
    if (log.isRestDayLog) return;

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
            if (prWeight > 0) {
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
        // Strength PR (evaluate per-set working sets, skipping 'W' warm-up sets)
        double prWeight = -1;
        int prReps = 0;

        if (ex.weightsPerSet != null && ex.weightsPerSet!.isNotEmpty) {
          for (int i = 0; i < ex.weightsPerSet!.length; i++) {
            final setType =
                (ex.setTypes != null && i < ex.setTypes!.length)
                    ? ex.setTypes![i].toUpperCase()
                    : 'N';
            if (setType == 'W') continue;

            final double w = ex.weightsPerSet![i];
            final int r =
                (ex.repsPerSet != null && i < ex.repsPerSet!.length)
                    ? ex.repsPerSet![i]
                    : ex.reps;
            if (w <= 0 && r <= 0) continue; // uncompleted set

            if (w > prWeight || (w == prWeight && r > prReps)) {
              prWeight = w;
              prReps = r;
            }
          }
          if (prWeight < 0) {
            // Only warm-up or uncompleted sets were logged
            continue;
          }
        } else {
          prWeight = ex.weight;
          prReps = ex.reps;
        }

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
  void updateWeeklyConsistencySettings(int goal, List<int> restDays) {
    streak = WorkoutStreak(
      currentWeekCount: streak.currentWeekCount,
      consecutiveWeeks: streak.consecutiveWeeks,
      lastWorkoutDate: streak.lastWorkoutDate,
      weekdaysTrained: streak.weekdaysTrained,
      completedTodayRoutines: streak.completedTodayRoutines,
      completedThisWeekRoutines: streak.completedThisWeekRoutines,
      weeklyGoal: goal,
      plannedRestDays: restDays,
      availableFreezes: streak.availableFreezes,
      weekdaysData: streak.weekdaysData,
    );
    _updateStreak(); // Recalculate streak/freezes based on new goal
    _save();
    notifyListeners();
  }

  void _updateStreak() {
    final now = DateTime.now();

    DateTime startOfWeek(DateTime d) {
      final weekday = d.weekday;
      return DateTime(d.year, d.month, d.day - (weekday - 1));
    }

    final thisWeekStart = startOfWeek(now);

    // Maintain current preferences
    final int currentWeeklyGoal = streak.weeklyGoal;
    final List<int> currentPlannedRestDays = streak.plannedRestDays;

    final realLogs = history.where((l) => !l.isRestDayLog).toList();

    final Set<int> weekdaysTrainedSet = {};
    final Map<int, Map<String, dynamic>> weekdaysData = {};

    for (final log in realLogs) {
      try {
        final logDate = parseUtcDate(log.date);
        if (!logDate.isBefore(thisWeekStart)) {
          final weekday = logDate.weekday;
          weekdaysTrainedSet.add(weekday);

          final isLogCardio =
              log.name.toLowerCase().contains('cardio') || log.totalWeight == 0;

          if (!weekdaysData.containsKey(weekday)) {
            weekdaysData[weekday] = {
              'name': log.name,
              'duration': log.duration,
              'tonnage': log.totalWeight,
              'activeCalories': log.activeCalories ?? 0,
              'isCardio': isLogCardio,
              'isMixed': false,
              'workoutCount': 1,
            };
          } else {
            // Treino Duplo! Aggregate the values
            final currentData = weekdaysData[weekday]!;
            currentData['duration'] =
                (currentData['duration'] ?? 0) + log.duration;
            currentData['tonnage'] =
                (currentData['tonnage'] ?? 0.0) + log.totalWeight;
            currentData['activeCalories'] =
                (currentData['activeCalories'] ?? 0) +
                    (log.activeCalories ?? 0);
            currentData['workoutCount'] =
                (currentData['workoutCount'] ?? 1) + 1;

            // Check if it's mixed (Cardio + Strength)
            if (currentData['isCardio'] != isLogCardio) {
              currentData['isMixed'] = true;
            }

            // Change name to Treino Duplo
            currentData['name'] = "Treino Duplo";
          }
        } else {
          break; // Optimization: history is ordered newest to oldest
        }
      } catch (_) {}
    }
    final List<int> weekdaysTrained = weekdaysTrainedSet.toList()..sort();
    int currentWeekCount = weekdaysTrained.length;

    // Calculando Streak e Freezes retroativamente
    int consecutiveWeeks = 0;
    int availableFreezes = 1;

    if (realLogs.isNotEmpty) {
      try {
        DateTime oldestWeek = startOfWeek(parseUtcDate(realLogs.last.date));

        Map<String, int> weekCounts = {};
        for (final log in realLogs) {
          final logDate = parseUtcDate(log.date);
          final ws = startOfWeek(logDate);
          final weekKey = '${ws.year}-${ws.month}-${ws.day}';
          weekCounts[weekKey] = (weekCounts[weekKey] ?? 0) + 1;
        }

        DateTime current = oldestWeek;
        while (!current.isAfter(thisWeekStart)) {
          final key = '${current.year}-${current.month}-${current.day}';
          final count = weekCounts[key] ?? 0;

          // Don't penalize the CURRENT week if it's 0 so far, because the week isn't over yet!
          bool isCurrentWeek = current.year == thisWeekStart.year &&
              current.month == thisWeekStart.month &&
              current.day == thisWeekStart.day;

          if (count >= currentWeeklyGoal) {
            // Perfect week! Only award if it's a past week, or if they already hit it this week.
            availableFreezes++;
            consecutiveWeeks++;
          } else if (count > 0) {
            consecutiveWeeks++;
          } else {
            // 0 workouts
            if (isCurrentWeek) {
              // week is not over, so we don't break the streak yet, but it's 0 so far.
            } else {
              if (availableFreezes > 0) {
                availableFreezes--;
                consecutiveWeeks++;
              } else {
                consecutiveWeeks = 0; // Streak broken
              }
            }
          }
          current = current.add(const Duration(days: 7));
        }
      } catch (_) {}
    }

    final Set<String> completedTodayRoutinesSet = {};
    final Set<String> completedThisWeekRoutinesSet = {};
    final nowLocal = DateTime.now();
    for (final log in realLogs) {
      try {
        final logDate = parseUtcDate(log.date);

        // This Week routines
        if (!logDate.isBefore(thisWeekStart)) {
          if (log.name.isNotEmpty) {
            completedThisWeekRoutinesSet.add(log.name);
          }
        } else {
          break; // Optimization
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

    final lastDate = realLogs.isNotEmpty ? realLogs.first.date : '';
    streak = WorkoutStreak(
      currentWeekCount: currentWeekCount,
      consecutiveWeeks: consecutiveWeeks,
      lastWorkoutDate: lastDate,
      weekdaysTrained: weekdaysTrained,
      completedTodayRoutines: completedTodayRoutines,
      completedThisWeekRoutines: completedThisWeekRoutines,
      weeklyGoal: currentWeeklyGoal,
      plannedRestDays: currentPlannedRestDays,
      availableFreezes: availableFreezes,
      weekdaysData: weekdaysData,
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
    if (index < 0 || index >= planner[day]!.length) return;
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

  void movePlannerItem(String day, int oldIndex, int newIndex) {
    // Mesma convenção do ReorderableListView.onReorder:
    // newIndex é a posição de inserção antes da remoção.
    if (newIndex > oldIndex) newIndex -= 1;
    planner[day] = List<String>.from(planner[day] ?? []);
    if (oldIndex < 0 ||
        oldIndex >= planner[day]!.length ||
        newIndex < 0 ||
        newIndex >= planner[day]!.length ||
        oldIndex == newIndex) {
      return;
    }
    final item = planner[day]!.removeAt(oldIndex);
    planner[day]!.insert(newIndex, item);
    _save();
  }

  void removePlannerItem(String day, int index) {
    planner[day] = List<String>.from(planner[day] ?? [])..removeAt(index);
    _save();
  }

  void copyPlannerDay(String fromDay, String toDay) {
    planner[toDay] = List<String>.from(planner[fromDay] ?? []);
    _save();
  }

  // --- WEEK TEMPLATES ---

  static const List<String> weekDays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sab', 'dom'];

  /// Salva a semana atual (seg–dom) como um modelo reutilizável.
  void saveCurrentWeekAsTemplate(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final days = <String, List<String>>{};
    for (final day in weekDays) {
      final items = (planner[day] ?? []).where((i) => i.isNotEmpty).toList();
      if (items.isNotEmpty) days[day] = items;
    }
    if (days.isEmpty) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    weekTemplates = Map<String, WeekTemplate>.from(weekTemplates)
      ..[id] = WeekTemplate(id: id, name: trimmed, days: days);
    _save();
  }

  void renameWeekTemplate(String id, String name) {
    final t = weekTemplates[id];
    if (t == null || name.trim().isEmpty) return;
    weekTemplates = Map<String, WeekTemplate>.from(weekTemplates)
      ..[id] = t.copyWith(name: name.trim());
    _save();
  }

  /// Substitui o cronograma seg–dom pelo modelo informado.
  void applyWeekTemplate(String id) {
    final t = weekTemplates[id];
    if (t == null) return;
    for (final day in weekDays) {
      planner[day] = List<String>.from(t.days[day] ?? []);
    }
    _save();
  }

  void deleteWeekTemplate(String id) {
    if (!weekTemplates.containsKey(id)) return;
    weekTemplates = Map<String, WeekTemplate>.from(weekTemplates)..remove(id);
    _save();
  }


  void importFromFixedDay(String sourceDay, String targetKey) {
    if (targetKey == 'continuous') {
      copyDayToContinuousBlock(sourceDay);
      return;
    }
    final sourceItems = List<String>.from(planner[sourceDay] ?? []);
    final validItems = sourceItems.where((item) => item.isNotEmpty).toList();
    if (validItems.isEmpty) return;
    
    planner[targetKey] = List<String>.from(planner[targetKey] ?? [])..addAll(validItems);
    _save();
  }

  void importAllFixedDays(String targetKey) {
    final days = ['seg', 'ter', 'qua', 'qui', 'sex', 'sab', 'dom'];
    
    if (targetKey == 'continuous') {
      for (final day in days) {
        copyDayToContinuousBlock(day);
      }
      return;
    }

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
  
    LogExercise? getLastPerformance(String exerciseName) {
    if (history.isEmpty) return null;
    for (int i = history.length - 1; i >= 0; i--) {
      final log = history[i];
      for (final ex in log.exercises) {
        if (ex.name == exerciseName) {
          return ex;
        }
      }
    }
    return null;
  }

  void addLibraryExercise(String name, String muscle, String measurementType,
      String? notes, String? executionType,
      {bool isStationary = false, bool isUnilateral = false}) {
    final newEx = LibraryExercise(
      id: "lib-${DateTime.now().millisecondsSinceEpoch}",
      name: name,
      muscle: muscle,
      measurementType: measurementTypeFromString(measurementType),
      notes: notes,
      executionType: executionType,
      isStationary: isStationary,
      isUnilateral: isUnilateral,
    );
    library = List<LibraryExercise>.from(library)..add(newEx);
    _save();
  }

  void updateLibraryExercise(String id, String name, String muscle,
      String measurementType, String? notes, String? executionType,
      {bool isStationary = false, bool isUnilateral = false}) {
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
        isUnilateral: isUnilateral,
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
      return r.copyWith(
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

          List<String>? newSetTypes = ex.setTypes;
          if (newSetTypes != null) {
            final resized = List<String>.filled(s, 'N');
            for (int i = 0; i < s && i < newSetTypes.length; i++) {
              resized[i] = newSetTypes[i];
            }
            newSetTypes = resized;
          }

          List<int?>? newRirs = ex.rirPerSet;
          if (newRirs != null) {
            final resized = List<int?>.filled(s, null);
            for (int i = 0; i < s && i < newRirs.length; i++) {
              resized[i] = newRirs[i];
            }
            newRirs = resized;
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
            setTypes: newSetTypes,
            rirPerSet: newRirs,
            isCardio: ex.isCardio,
            allowCardioSets: ex.allowCardioSets,
            supersetId: ex.supersetId,
            isUnilateral: ex.isUnilateral,
          );
        }
        return ex;
      }).toList();

      updateRoutine(routine.copyWith(
        exercises: newExercises,
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
      activeWorkout =
          activeWorkout!.copyWith(elapsedSeconds: newElapsedSeconds);
      _save();
    }
  }

  void updateSettings(bool sound, bool vibration, int prepSeconds) {
    settings = settings.copyWith(
      sound: sound,
      vibration: vibration,
      prepSeconds: prepSeconds,
    );
    _save();
  }

  void updateThemeMode(String mode) {
    if (settings.themeMode == mode) return;
    settings = settings.copyWith(themeMode: mode);
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
        continuousListRestDate: settings.continuousListRestDate,
        workoutReminderEnabled: settings.workoutReminderEnabled,
        workoutReminderHour: settings.workoutReminderHour,
        workoutReminderMinute: settings.workoutReminderMinute,
      );
      _save();
      WatchService.instance
          .sendTodayRoutines(settings, planner, routines, streak, continuousBlocks);
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
      continuousListRestDate: settings.continuousListRestDate,
      workoutReminderEnabled: settings.workoutReminderEnabled,
      workoutReminderHour: settings.workoutReminderHour,
      workoutReminderMinute: settings.workoutReminderMinute,
    );
    _save();
    WatchService.instance
        .sendTodayRoutines(settings, planner, routines, streak, continuousBlocks);
    WatchService.instance.syncWidgetData();
  }

  bool get isContinuousRestToday =>
      settings.continuousListRestDate == _todayDateKey();

  void setContinuousListRestToday(bool isRest) {
    settings = settings.copyWith(
      continuousListRestDate: isRest ? _todayDateKey() : '',
    );
    _save();
    WatchService.instance
        .sendTodayRoutines(settings, planner, routines, streak, continuousBlocks);
    WatchService.instance.syncWidgetData();
  }

  void updateWorkoutReminder(bool enabled, int hour, int minute) {
    settings = settings.copyWith(
      workoutReminderEnabled: enabled,
      workoutReminderHour: hour,
      workoutReminderMinute: minute,
    );
    _save();
    WatchService.instance
        .sendWorkoutReminder(enabled, hour, minute);
  }

  String _todayDateKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
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

    final cleanReason = reason?.trim();
    final hasReason = cleanReason != null && cleanReason.isNotEmpty;

    final restLog = WorkoutLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: hasReason ? 'Descanso: $cleanReason' : 'Dia de Descanso',
      date: DateTime.now().toUtc().toIso8601String(),
      duration: 0,
      completedSets: 0,
      totalSets: 0,
      totalWeight: 0,
      rpe: 0,
      notes: hasReason
          ? 'Motivo: $cleanReason'
          : 'Descanso registrado manualmente.',
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
      final todayStr = DateTime.now().toLocal().toString().substring(0, 10);
      final todayRestLog = history.where((log) {
        if (!log.isRestDayLog) return false;
        try {
          final logDate = DateTime.parse(log.date).toLocal();
          return logDate.toString().substring(0, 10) == todayStr;
        } catch (_) {
          return false;
        }
      }).firstOrNull;
      if (todayRestLog != null) {
        deleteWorkoutLog(todayRestLog.id);
      } else {
        _save();
        notifyListeners();
      }
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
        if (workout.isRestDayLog) continue;
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
      if (log.isRestDayLog) continue;
      if (log.name.trim().toLowerCase() == routineName.trim().toLowerCase()) {
        return log;
      }
    }
    return null;
  }

  // --- ENGAGEMENT: weekly report & monthly challenges ---

  static bool _inDateRange(String isoDate, DateTime start, DateTime end) {
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return false;
    return !dt.isBefore(start) && dt.isBefore(end);
  }

  /// Relatório da semana atual (últimos 7 dias) comparado com os 7 anteriores.
  WeeklyReportData getWeeklyReportData() {
    final now = DateTime.now();
    final thisWeekStart = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 7));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    int wThis = 0, wLast = 0;
    double vThis = 0, vLast = 0;
    int dThis = 0, dLast = 0;

    for (final log in history) {
      if (log.isRestDayLog) continue;
      if (_inDateRange(log.date, thisWeekStart, now)) {
        wThis++;
        vThis += log.totalWeight;
        dThis += log.duration;
      } else if (_inDateRange(log.date, lastWeekStart, thisWeekStart)) {
        wLast++;
        vLast += log.totalWeight;
        dLast += log.duration;
      }
    }

    return WeeklyReportData(
      workoutsThisWeek: wThis,
      workoutsLastWeek: wLast,
      volumeThisWeek: vThis,
      volumeLastWeek: vLast,
      durationMinutesThisWeek: dThis ~/ 60,
      durationMinutesLastWeek: dLast ~/ 60,
      streakWeeks: streak.consecutiveWeeks,
      weeklyGoal: streak.weeklyGoal,
      workoutsThisWeekGoalProgress: streak.currentWeekCount,
    );
  }

  /// Desafios do mês corrente calculados a partir do histórico.
  List<MonthlyChallenge> getMonthlyChallenges() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final monthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    int workouts = 0;
    double volume = 0;
    int durationMin = 0;

    for (final log in history) {
      if (log.isRestDayLog) continue;
      if (!_inDateRange(log.date, monthStart, monthEnd)) continue;
      workouts++;
      volume += log.totalWeight;
      durationMin += log.duration ~/ 60;
    }

    return [
      MonthlyChallenge(
        id: 'month-workouts',
        title: 'Treinos no mês',
        icon: '🏋️',
        unit: 'treinos',
        target: 16,
        current: workouts.toDouble(),
        monthKey: monthKey,
      ),
      MonthlyChallenge(
        id: 'month-volume',
        title: 'Volume no mês',
        icon: '🏋️‍♂️',
        unit: 'kg',
        target: 50000,
        current: volume,
        monthKey: monthKey,
      ),
      MonthlyChallenge(
        id: 'month-duration',
        title: 'Tempo de treino',
        icon: '⏱️',
        unit: 'min',
        target: 600,
        current: durationMin.toDouble(),
        monthKey: monthKey,
      ),
    ];
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

  /// Retorna o índice (na lista contínua plana) do treino cujos grupos
  /// musculares foram menos trabalhados nos últimos [days] dias.
  /// Retorna null se não houver itens válidos.
  int? suggestContinuousIndexByFatigue([int days = 7]) {
    final flat = flatContinuousList;
    if (flat.isEmpty) return null;
    final recent = getRecentMuscleSets(days);

    int bestIdx = -1;
    int bestScore = 1 << 30;
    for (int i = 0; i < flat.length; i++) {
      final raw = flat[i];
      int score;
      if (raw.startsWith('exercise:')) {
        final parts = raw.split(':');
        if (parts.length < 2) continue;
        final ex =
            library.where((e) => e.id == parts[1]).firstOrNull;
        if (ex == null) continue;
        score = recent[ex.muscle] ?? 0;
      } else {
        final routineId =
            raw.startsWith('routine:') ? raw.substring(8) : raw;
        if (routineId.isEmpty) continue;
        final r = routines.where((x) => x.id == routineId).firstOrNull;
        if (r == null) continue;
        score = getRoutineMuscleTags(r)
            .fold(0, (s, m) => s + (recent[m] ?? 0));
      }
      if (score < bestScore) {
        bestScore = score;
        bestIdx = i;
      }
    }
    return bestIdx >= 0 ? bestIdx : null;
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
