import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';
import '../models/exercise.dart';
import '../models/routine.dart';
import '../models/workout_log.dart';
import '../models/medidas.dart';
import '../models/diet.dart';
import '../models/planner_state.dart';
import '../services/watch_service.dart';
import '../services/rest_timer_service.dart';
import '../services/state_persistence_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/health_service.dart';
import '../services/food_service.dart';
import '../utils/food_presets_data.dart';
import '../utils/date_utils.dart';

export '../utils/date_utils.dart';

class TrackerProvider extends ChangeNotifier with WidgetsBindingObserver {
  final StatePersistenceService _persistence = StatePersistenceService();
  final FirebaseSyncService _firebaseSync = FirebaseSyncService();

  List<Profile> _profiles = [];
  String _currentUserId = '';
  PlannerState? _state;
  bool _isLoading = true;
  bool _historyLoaded = false;
  DateTime? _lastHealthMetricsNotify;
  
  int _todaySteps = 0;
  int _todayBurnedCalories = 0;
  int _currentHeartRate = 0;
  bool _healthAuthorized = false;

  int get todaySteps => _todaySteps;
  int get todayBurnedCalories => _todayBurnedCalories;
  int get currentHeartRate => _currentHeartRate;
  bool get healthAuthorized => _healthAuthorized;
  static const Duration _healthMetricsNotifyInterval = Duration(seconds: 5);

  List<Profile> get profiles => _profiles;
  String get currentUserId => _currentUserId;
  PlannerState? get state => _state;
  bool get isLoading => _isLoading;

  Profile get currentProfile => _profiles.firstWhere(
        (p) => p.id == _currentUserId,
        orElse: () => Profile(
          id: _currentUserId,
          name: 'Usuário',
          avatar: '🏋️',
          colorAccent: 'Branco',
        ),
      );

  TrackerProvider() {
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _firebaseSync.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    WidgetsBinding.instance.addObserver(this);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await initializeUser(user.uid);
    } else {
      _isLoading = false;
      notifyListeners();
    }
    WatchService.instance.init(this);
  }

  Future<void> initializeUser(String uid) async {
    _isLoading = true;
    _currentUserId = uid;
    _historyLoaded = false;
    notifyListeners();

    final profileRaw = await _persistence.loadProfileJson(uid);
    if (profileRaw != null) {
      try {
        _profiles = [_persistence.decodeProfile(profileRaw)];
      } catch (e) {
        _profiles = [_defaultProfile(uid)];
      }
    } else {
      final cloudProfile = await checkProfileExistsInCloud(uid);
      if (cloudProfile != null) {
        try {
          _profiles = [Profile.fromJson(cloudProfile)];
          await saveProfilesConfig();
        } catch (_) {
          _profiles = [_defaultProfile(uid)];
        }
      } else {
        _profiles = [_defaultProfile(uid)];
      }
    }

    await loadCurrentState();
    await syncWaterFromWidget();
    await syncActiveWorkoutFromWidget();
    checkAndResetDailyDiet();
    await syncHealthMetrics();

    if (_state == null || _state!.history.isEmpty) {
      final oldStateRaw = await _persistence.loadLegacyVicenteStateJson();
      if (oldStateRaw != null) {
        try {
          final oldState = _persistence.decodeState(oldStateRaw);
          if (oldState.history.isNotEmpty || oldState.routines.isNotEmpty) {
            _state = oldState;
            await saveState(immediateSync: true);
            debugPrint('[Migration] Dados locais de "vicente" migrados para o Google UID: $uid');
          }
        } catch (e) {
          debugPrint('[Migration] Erro ao migrar dados locais antigos: $e');
        }
      }
    }

    if (_state?.activeWorkout == null) {
      RestTimerService.instance.clear();
      WatchService.instance.sendActiveWorkoutCleared();
    }

    _checkAndSeedFoods();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _checkAndSeedFoods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isSeeded = prefs.getBool('food_db_seeded_v3') ?? false;
      if (!isSeeded) {
        final foodService = FoodService.instance;
        bool allSucceeded = true;
        for (final food in presetFoods100) {
          final success = await foodService.addFood(food);
          if (!success) {
            allSucceeded = false;
          }
        }
        if (allSucceeded && presetFoods100.isNotEmpty) {
          await prefs.setBool('food_db_seeded_v3', true);
          debugPrint("[Seeding] 100 alimentos iniciais semeados com sucesso.");
        }
      }
    } catch (e) {
      debugPrint("[Seeding] Erro ao semear alimentos: $e");
    }
  }

  Profile _defaultProfile(String uid) => Profile(
        id: uid,
        name: FirebaseAuth.instance.currentUser?.displayName ?? 'Usuário',
        avatar: '🏋️',
        colorAccent: 'Branco',
      );

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    _state = null;
    _profiles = [];
    _currentUserId = '';
    _historyLoaded = false;

    await FirebaseAuth.instance.signOut();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveProfilesConfig() async {
    if (_profiles.isEmpty) return;
    final profile = _profiles.firstWhere((p) => p.id == _currentUserId);
    await _persistence.saveProfileJson(
      _currentUserId,
      _persistence.encodeProfile(profile),
    );
  }

  Future<void> createCloudProfile(String uid, String name, String avatar, String color) async {
    final newProfile = Profile(
      id: uid,
      name: name,
      avatar: avatar,
      colorAccent: color,
    );
    _profiles = [newProfile];
    _currentUserId = uid;
    await saveProfilesConfig();
    _state = _getDefaultState();
    await saveState(immediateSync: true);
  }

  Future<void> updateProfile(String id, String name, String avatar, String color) async {
    final idx = _profiles.indexWhere((p) => p.id == id);
    if (idx == -1) return;

    _profiles[idx] = Profile(
      id: id,
      name: name,
      avatar: avatar,
      colorAccent: color,
    );
    await saveProfilesConfig();
    unawaited(_firebaseSync.updateCloudProfile(id, _profiles[idx]));
    notifyListeners();
  }

  Future<void> loadCurrentState() async {
    final stateRaw = await _persistence.loadStateJson(_currentUserId);
    var forceDownload = false;

    if (stateRaw != null) {
      try {
        _state = _persistence.decodeState(stateRaw);
      } catch (e) {
        _state = _getDefaultState();
        forceDownload = true;
      }
    } else {
      _state = _getDefaultState();
      forceDownload = true;
    }

    await _syncWithFirebase(forceDownload: forceDownload);
  }

  Future<void> saveState({bool immediateSync = false}) async {
    if (_state == null || _currentUserId.isEmpty) return;

    await _persistence.saveStateJson(
      _currentUserId,
      _persistence.encodeState(_state!),
    );

    WatchService.instance.sendRoutines(_state!.routines);
    WatchService.instance.sendLibrary(_state!.library);
    WatchService.instance.sendPlanner(_state!.planner);
    if (_state!.activeWorkout != null) {
      WatchService.instance.sendActiveWorkout(_state!.activeWorkout!);
    } else {
      WatchService.instance.sendActiveWorkoutCleared();
    }
    WatchService.instance.syncWidgetData();

    if (immediateSync) {
      await _firebaseSync.flushSync(
        userId: _currentUserId,
        state: _state!,
        profile: currentProfile,
      );
    } else {
      _firebaseSync.scheduleSync(
        userId: _currentUserId,
        state: _state!,
        profile: currentProfile,
      );
    }
  }

  Future<Map<String, dynamic>?> checkProfileExistsInCloud(String profileId) {
    return _firebaseSync.fetchCloudProfile(profileId);
  }

  Future<void> _syncWithFirebase({required bool forceDownload}) async {
    if (_state == null || _currentUserId.isEmpty) return;

    final result = await _firebaseSync.sync(
      userId: _currentUserId,
      localState: _state!,
      profile: currentProfile,
      forceDownload: forceDownload,
      onRemoteApplied: _applyRemoteState,
    );

    if (result != null && result != _state) {
      _state = result;
      notifyListeners();
    }
  }

  Future<void> _applyRemoteState(PlannerState remoteState, Profile? remoteProfile) async {
    _state = remoteState;
    await _persistence.saveStateJson(
      _currentUserId,
      _persistence.encodeState(remoteState),
    );

    if (remoteProfile != null) {
      final idx = _profiles.indexWhere((p) => p.id == remoteProfile.id);
      if (idx != -1) {
        _profiles[idx] = remoteProfile;
        await saveProfilesConfig();
      }
    }
    notifyListeners();
  }

  // --- WORKOUT OPERATIONS ---
  void startWorkout(Routine routine, WorkoutRecovery recovery, bool isWarmup) {
    if (_state == null) return;

    final workoutExercises = routine.exercises.map((ex) {
      final ref = _state!.library.firstWhere(
        (l) => l.id == ex.exerciseId,
        orElse: () => LibraryExercise(
          id: ex.exerciseId,
          name: 'Exercício',
          muscle: 'Geral',
          measurementType: 'reps',
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

    final activeWorkout = ActiveWorkoutState(
      name: routine.name,
      startTime: DateTime.now().millisecondsSinceEpoch,
      exercises: workoutExercises,
      currentExerciseIndex: 0,
      elapsedSeconds: 0,
      recovery: recovery,
      isWarmup: isWarmup,
      warmupDurationSeconds: 0,
    );

    _state = _state!.copyWith(activeWorkout: activeWorkout);

    saveState();
    notifyListeners();
  }

  void startSingleExercise(LibraryExercise exercise) {
    if (_state == null) return;
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
    startWorkout(tempRoutine, WorkoutRecovery(sleepOk: 'ok', pain: [], warmUpDone: false), false);
  }

  void completeSet(int exIndex, int setIndex, bool isDone, {double? distance, int? duration, bool isFailure = false, int? failureRep}) {
    if (_state == null || _state!.activeWorkout == null) return;
    
    // Tactile haptic feedback when completing a set
    HapticFeedback.lightImpact();

    final active = _state!.activeWorkout!;
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

    // Calcular cronômetro de descanso se a série foi completada
    WatchRestTimer? computedRestTimer = active.restTimer;
    int computedExIndex = active.currentExerciseIndex;
    if (isDone) {
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
    } else {
      // Se desmarcou, cancela o timer de descanso ativo
      computedRestTimer = null;
    }

    final updatedWorkout = active.copyWith(
      exercises: exercises,
      currentExerciseIndex: computedExIndex,
      restTimer: computedRestTimer,
    );

    _state = _state!.copyWith(activeWorkout: updatedWorkout);

    saveState();
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
    notifyListeners();
  }

  void startRestTimer(int seconds, String nextExName, int nextSetNum, bool isPrep) {
    if (_state == null || _state!.activeWorkout == null) return;
    final active = _state!.activeWorkout!;

    final endTime = DateTime.now().millisecondsSinceEpoch + (seconds * 1000);
    final restTimer = WatchRestTimer(
      endTime: endTime,
      totalSeconds: seconds,
      nextExerciseName: nextExName,
      nextSetNum: nextSetNum,
      isPrep: isPrep,
    );

    final updatedWorkout = active.copyWith(
      restTimer: restTimer,
    );

    _state = _state!.copyWith(activeWorkout: updatedWorkout);

    saveState();
    // Sync global RestTimerService (survives navigation)
    RestTimerService.instance.start(
      endTimeMs: endTime,
      seconds: seconds,
      prep: isPrep,
      exName: nextExName,
      setNum: nextSetNum,
    );
    notifyListeners();
  }

  void clearRestTimer() {
    if (_state == null || _state!.activeWorkout == null) return;
    final active = _state!.activeWorkout!;

    final updatedWorkout = active.copyWith(
      restTimer: null,
    );

    _state = _state!.copyWith(activeWorkout: updatedWorkout);

    saveState();
    // Sync global RestTimerService
    RestTimerService.instance.clear();
    notifyListeners();
  }

  void updateExerciseWeightReps(int exIndex, double weight, int reps) {
    if (_state == null || _state!.activeWorkout == null) return;
    final active = _state!.activeWorkout!;
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

    final updatedWorkout = active.copyWith(
      exercises: exercises,
    );

    _state = _state!.copyWith(activeWorkout: updatedWorkout);

    saveState();
    notifyListeners();
  }

  void updateExerciseSetWeightReps(int exIndex, int setIdx, double weight, int reps) {
    if (_state == null || _state!.activeWorkout == null) return;
    final active = _state!.activeWorkout!;
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

    final updatedWorkout = active.copyWith(
      exercises: exercises,
    );

    _state = _state!.copyWith(activeWorkout: updatedWorkout);
    WatchService.instance.sendActiveWorkout(updatedWorkout);
    saveState();
    notifyListeners();
  }

  void updateWorkoutTimer(int seconds, {bool isWarmupTimer = false}) {
    if (_state == null || _state!.activeWorkout == null) return;
    final active = _state!.activeWorkout!;

    final updatedWorkout = active.copyWith(
      elapsedSeconds: isWarmupTimer ? active.elapsedSeconds : seconds,
      warmupDurationSeconds: isWarmupTimer ? seconds : active.warmupDurationSeconds,
    );

    _state = _state!.copyWith(activeWorkout: updatedWorkout);
    // notifyListeners(); // Otimizado: evita reconstrução de todo o app a cada segundo.

    // Sincroniza com o Apple Watch a cada 5 segundos para manter timer atualizado no relógio
    if (!isWarmupTimer && seconds % 5 == 0) {
      WatchService.instance.sendActiveWorkout(updatedWorkout);
    }
  }

  void setCurrentExerciseIndex(int index) {
    if (_state == null || _state!.activeWorkout == null) return;
    final active = _state!.activeWorkout!;

    final updatedWorkout = active.copyWith(
      currentExerciseIndex: index,
    );

    _state = _state!.copyWith(activeWorkout: updatedWorkout);
    saveState();
    notifyListeners();
  }

  void pauseWorkout(bool isPaused) {
    if (_state == null || _state!.activeWorkout == null) return;
    final active = _state!.activeWorkout!;

    final updatedWorkout = active.copyWith(
      paused: isPaused,
    );

    _state = _state!.copyWith(activeWorkout: updatedWorkout);
    // Notifica o Apple Watch imediatamente sobre pausa/retomada
    WatchService.instance.sendActiveWorkout(updatedWorkout);
    saveState();
    notifyListeners();
  }

  /// Reconcile iOS state with a workout state pushed from the Apple Watch.
  ///
  /// Called when the Watch transitions from offline (local) to connected mode
  /// and pushes its in-progress [watchData] JSON (WatchActiveWorkoutState schema).
  /// The Watch JSON uses the same field names as [ActiveWorkoutState.toJson] so
  /// we can deserialise it directly.
  void applyActiveWorkoutFromWatch(Map<String, dynamic> watchData) {
    if (_state == null) return;

    final current = _state!.activeWorkout;

    if (current == null) {
      // iOS has no active workout — create one from the Watch state.
      try {
        final fromWatch = ActiveWorkoutState.fromJson(watchData);
        _state = _state!.copyWith(activeWorkout: fromWatch);
        debugPrint('[TrackerProvider] applyActiveWorkoutFromWatch: created new active workout from Watch state (${fromWatch.name})');
        saveState();
        notifyListeners();
      } catch (e) {
        debugPrint('[TrackerProvider] applyActiveWorkoutFromWatch: failed to parse Watch state — $e');
      }
      return;
    }

    // iOS already has an active workout — merge more-advanced sets from the Watch.
    // We take the union of completed sets so neither side loses data.
    try {
      final watchExercises = watchData['exercises'] as List?;
      if (watchExercises == null || watchExercises.length != current.exercises.length) return;

      final merged = List<ActiveExercise>.from(current.exercises);
      for (int i = 0; i < merged.length; i++) {
        final wEx = Map<String, dynamic>.from(watchExercises[i] as Map);
        final ios = merged[i];

        final wSets = (wEx['setsState'] as List?)?.map((e) => e as bool).toList() ?? ios.setsState;
        // Union: a set is done if *either* Watch or iOS marked it done
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

      _state = _state!.copyWith(activeWorkout: current.copyWith(exercises: merged));
      debugPrint('[TrackerProvider] applyActiveWorkoutFromWatch: merged Watch sets into iOS state');
      saveState();
      notifyListeners();
    } catch (e) {
      debugPrint('[TrackerProvider] applyActiveWorkoutFromWatch: merge failed — $e');
    }
  }

  void discardActiveWorkout() {

    if (_state == null) return;
    // Stop any running rest timer immediately before clearing workout state.
    RestTimerService.instance.clear();
    _state = _state!.copyWith(clearActiveWorkout: true);
    saveState();
    notifyListeners();
  }

  void postponeActiveWorkout() {
    if (_state == null || _state!.activeWorkout == null) return;
    // Stop any running rest timer so native side clears the rest-timer widget.
    RestTimerService.instance.clear();
    final active = _state!.activeWorkout!;
    final updated = active.copyWith(
      paused: true,
      postponed: true,
    );
    _state = _state!.copyWith(activeWorkout: updated);
    saveState();
    notifyListeners();
  }

  void resumeActiveWorkout() {
    if (_state == null || _state!.activeWorkout == null) return;
    final active = _state!.activeWorkout!;
    final updated = active.copyWith(
      startTime: DateTime.now().millisecondsSinceEpoch - (active.elapsedSeconds * 1000),
      paused: false,
      postponed: false,
    );
    _state = _state!.copyWith(activeWorkout: updated);
    saveState();
    notifyListeners();
  }

  void updateHealthMetrics(int heartRate, int activeCalories) {
    if (_state == null || _state!.activeWorkout == null) return;
    final active = _state!.activeWorkout!;

    final updatedWorkout = active.copyWith(
      heartRate: heartRate,
      activeCalories: activeCalories,
    );

    _state = _state!.copyWith(activeWorkout: updatedWorkout);

    final now = DateTime.now();
    if (_lastHealthMetricsNotify == null ||
        now.difference(_lastHealthMetricsNotify!) >= _healthMetricsNotifyInterval) {
      _lastHealthMetricsNotify = now;
      notifyListeners();
    }
  }

  void finishWorkout(int duration, int rpeValue, String notes) {
    if (_state == null || _state!.activeWorkout == null) return;
    // Stop any running rest timer before processing the finish.
    RestTimerService.instance.clear();

    final active = _state!.activeWorkout!;
    int totalSets = 0;
    int completedSets = 0;
    double totalWeightVolume = 0.0;

    final List<LogExercise> exercisesSummary = active.exercises.map((ex) {
      final done = ex.setsState.where((s) => s).length;
      totalSets += ex.sets;
      completedSets += done;

      double finalWeight = ex.weight;
      int finalReps = ex.reps;
      final isCardio = ex.muscle.toLowerCase().contains('cardio');

      if (isCardio) {
        final completedList = ex.performedCardios.where((c) => c != null).toList();
        if (completedList.isNotEmpty) {
          final totalDist = completedList.fold<double>(0, (sum, c) => sum + c!.distanceKm);
          final totalDurMin = completedList.fold<int>(0, (sum, c) => sum + (c!.durationSeconds ~/ 60));
          finalWeight = totalDist / completedList.length;
          finalReps = totalDurMin ~/ completedList.length;
        }
      } else {
        // Carga de volume total de musculação
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

    // Cria log de histórico
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

    final List<WorkoutLog> newHistory = List.from(_state!.history)..insert(0, log);

    // Atualiza Recordes Pessoais (PRs)
    final Map<String, PersonalRecord> newPrs = Map.from(_state!.prs);
    final List<String> prExerciseNames = [];
    for (var ex in active.exercises) {
      final done = ex.setsState.where((s) => s).length;
      if (done == 0) continue;

      final isCardio = ex.muscle.toLowerCase().contains('cardio');
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
          continue; // Sem cardio feito
        }
      }

      // Procura ID correspondente na biblioteca
      final libEx = _state!.library.firstWhere((l) => l.name == ex.name, orElse: () => LibraryExercise(id: '', name: '', muscle: '', measurementType: ''));
      if (libEx.id.isEmpty) continue;

      final currentPr = newPrs[libEx.id];
      if (currentPr == null || prWeight > currentPr.weight || (prWeight == currentPr.weight && prReps > currentPr.reps)) {
        newPrs[libEx.id] = PersonalRecord(
          weight: prWeight,
          reps: prReps,
          date: DateTime.now().toUtc().toIso8601String(),
          routineName: active.name,
        );
        prExerciseNames.add(ex.name);
      }
    }

    // Envia celebração de PR para o Apple Watch
    if (prExerciseNames.isNotEmpty) {
      WatchService.instance.sendPrCelebration(prExerciseNames);
    }

    _state = _state!.copyWith(history: newHistory, prs: newPrs, clearActiveWorkout: true);

    _updateStreak();
    saveState(immediateSync: true);
    unawaited(_firebaseSync.syncWorkoutLog(_currentUserId, log));
    notifyListeners();
  }

  void addManualWorkoutLog(WorkoutLog log) {
    if (_state == null) return;
    if (_state!.history.any((l) => l.id == log.id)) {
      return;
    }
    final List<WorkoutLog> newHistory = List.from(_state!.history)..insert(0, log);

    // Atualiza Recordes Pessoais (PRs)
    final Map<String, PersonalRecord> newPrs = Map.from(_state!.prs);
    for (var ex in log.exercises) {
      if (ex.completedSets == 0) continue;

      final isCardio = ex.muscle.toLowerCase().contains('cardio');
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

      final libEx = _state!.library.firstWhere((l) => l.name == ex.name, orElse: () => LibraryExercise(id: '', name: '', muscle: '', measurementType: ''));
      if (libEx.id.isEmpty) continue;

      final currentPr = newPrs[libEx.id];
      if (currentPr == null || prWeight > currentPr.weight || (prWeight == currentPr.weight && prReps > currentPr.reps)) {
        newPrs[libEx.id] = PersonalRecord(
          weight: prWeight,
          reps: prReps,
          date: log.date,
          routineName: log.name,
        );
      }
    }

    _state = _state!.copyWith(history: newHistory, prs: newPrs);
    _updateStreak();
    saveState();
    unawaited(_firebaseSync.syncWorkoutLog(_currentUserId, log));
    notifyListeners();
  }

  Future<List<WorkoutLog>> loadWorkoutHistory() async {
    if (_state == null || _currentUserId.isEmpty) return [];
    if (_historyLoaded) return _state!.history;
    
    final rawHistory = await _persistence.loadWorkoutsHistoryJson(_currentUserId);
    if (rawHistory != null) {
      try {
        final List decoded = json.decode(rawHistory);
        final loadedHistory = decoded.map((h) => WorkoutLog.fromJson(h)).toList();
        _state!.history.clear();
        _state!.history.addAll(loadedHistory);
      } catch (e) {
        debugPrint('[TrackerProvider] Error loading workouts history: $e');
      }
    }
    _historyLoaded = true;
    notifyListeners();
    return _state!.history;
  }

  void deleteWorkoutLog(String id) {
    if (_state == null) return;
    _state!.history.removeWhere((h) => h.id == id);
    saveState();
    unawaited(_firebaseSync.deleteWorkoutLog(_currentUserId, id));
    notifyListeners();
  }

  // --- STREAK TRACKING ---
  void _updateStreak() {
    if (_state == null) return;

    final now = DateTime.now();
    final history = _state!.history;

    // Semana ISO: segunda (1) até domingo (7)
    // Obtém o início da semana atual (segunda-feira)
    DateTime startOfWeek(DateTime d) {
      final weekday = d.weekday; // 1=Mon, 7=Sun
      return DateTime(d.year, d.month, d.day - (weekday - 1));
    }

    final thisWeekStart = startOfWeek(now);

    // Conta dias únicos de treinos nesta semana e identifica os dias exatos
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

    // Conta semanas consecutivas (incluindo semana atual se houver treino)
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

    // Conta semanas consecutivas para trás a partir de agora
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

    // Identifica rotinas concluídas hoje
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
    final newStreak = WorkoutStreak(
      currentWeekCount: currentWeekCount,
      consecutiveWeeks: consecutiveWeeks,
      lastWorkoutDate: lastDate,
      weekdaysTrained: weekdaysTrained,
      completedTodayRoutines: completedTodayRoutines,
    );

    _state = _state!.copyWith(streak: newStreak);

    WatchService.instance.sendStreak(newStreak);
  }

  // --- WEEKLY PLANNER ACTIONS ---
  void addPlannerItem(String day) {
    if (_state == null) return;
    final planner = Map<String, List<String>>.from(_state!.planner);
    planner[day] = List<String>.from(planner[day] ?? [])..add("");
    _state = _state!.copyWith(planner: planner);
    saveState();
    notifyListeners();
  }

  void updatePlannerItem(String day, int index, String value) {
    if (_state == null) return;
    final planner = Map<String, List<String>>.from(_state!.planner);
    planner[day] = List<String>.from(planner[day] ?? []);
    planner[day]![index] = value;
    
    _state = _state!.copyWith(planner: planner);
    saveState();
    notifyListeners();
  }

  void reorderPlannerItem(String day, int index, bool moveUp) {
    if (_state == null) return;
    final planner = Map<String, List<String>>.from(_state!.planner);
    planner[day] = List<String>.from(planner[day] ?? []);
    final targetIndex = moveUp ? index - 1 : index + 1;

    if (targetIndex < 0 || targetIndex >= planner[day]!.length) return;

    final temp = planner[day]![index];
    planner[day]![index] = planner[day]![targetIndex];
    planner[day]![targetIndex] = temp;

    _state = _state!.copyWith(planner: planner);
    saveState();
    notifyListeners();
  }

  void removePlannerItem(String day, int index) {
    if (_state == null) return;
    final planner = Map<String, List<String>>.from(_state!.planner);
    planner[day] = List<String>.from(planner[day] ?? [])..removeAt(index);
    _state = _state!.copyWith(planner: planner);
    saveState();
    notifyListeners();
  }

  void deletePersonalRecord(String exerciseId) {
    if (_state == null) return;
    final Map<String, PersonalRecord> newPrs = Map.from(_state!.prs);
    newPrs.remove(exerciseId);
    _state = _state!.copyWith(prs: newPrs);
    saveState();
    notifyListeners();
  }

  // --- LIBRARY OPERATIONS ---
  void addLibraryExercise(String name, String muscle, String measurementType, String? notes, String? executionType) {
    if (_state == null) return;
    final newEx = LibraryExercise(
      id: "lib-${DateTime.now().millisecondsSinceEpoch}",
      name: name,
      muscle: muscle,
      measurementType: measurementType,
      notes: notes,
      executionType: executionType,
    );
    final library = List<LibraryExercise>.from(_state!.library)..add(newEx);
    _state = _state!.copyWith(library: library);
    saveState();
    notifyListeners();
  }

  void updateLibraryExercise(String id, String name, String muscle, String measurementType, String? notes, String? executionType) {
    if (_state == null) return;
    final library = List<LibraryExercise>.from(_state!.library);
    final idx = library.indexWhere((e) => e.id == id);
    if (idx != -1) {
      library[idx] = LibraryExercise(
        id: id,
        name: name,
        muscle: muscle,
        measurementType: measurementType,
        notes: notes,
        executionType: executionType,
      );
      _state = _state!.copyWith(library: library);
      saveState();
      notifyListeners();
    }
  }

  void deleteLibraryExercise(String id) {
    if (_state == null) return;
    final library = List<LibraryExercise>.from(_state!.library)..removeWhere((e) => e.id == id);
    
    // Remove referências no planejador
    final planner = Map<String, List<String>>.from(_state!.planner);
    planner.forEach((k, v) {
      planner[k] = v.where((item) => !item.contains('exercise:$id')).toList();
    });

    // Remove referências nas rotinas
    final routines = _state!.routines.map((r) {
      return Routine(
        id: r.id,
        name: r.name,
        defaultRest: r.defaultRest,
        exercises: r.exercises.where((ex) => ex.exerciseId != id).toList(),
      );
    }).toList();

    _state = _state!.copyWith(library: library, routines: routines, planner: planner);
    saveState();
    notifyListeners();
  }

  // --- ROUTINE OPERATIONS ---
  void addRoutine(String name, int defaultRest, List<RoutineExercise> exercises) {
    if (_state == null) return;
    final r = Routine(
      id: "routine-${DateTime.now().millisecondsSinceEpoch}",
      name: name,
      defaultRest: defaultRest,
      exercises: exercises,
    );
    final routines = List<Routine>.from(_state!.routines)..add(r);
    _state = _state!.copyWith(routines: routines);
    saveState();
    unawaited(_firebaseSync.syncRoutine(_currentUserId, r));
    notifyListeners();
  }

  void deleteRoutine(String id) {
    if (_state == null) return;
    final routines = List<Routine>.from(_state!.routines)..removeWhere((r) => r.id == id);
    
    // Remove referências no planejador
    final planner = Map<String, List<String>>.from(_state!.planner);
    planner.forEach((k, v) {
      planner[k] = v.where((item) => item != 'routine:$id' && item != id).toList();
    });

    _state = _state!.copyWith(routines: routines, planner: planner);
    saveState();
    unawaited(_firebaseSync.deleteRoutine(_currentUserId, id));
    notifyListeners();
  }

  // --- MEASUREMENT OPERATIONS ---
  void addMeasurement(BodyMeasurement record) {
    if (_state == null) return;
    final index = _state!.medidas.indexWhere((m) => m.date == record.date);
    final List<BodyMeasurement> list = List.from(_state!.medidas);

    if (index != -1) {
      list[index] = record;
    } else {
      list.add(record);
    }

    _state = _state!.copyWith(medidas: list);
    saveState();
    notifyListeners();
  }

  void deleteMeasurement(String id) {
    if (_state == null) return;
    final list = List<BodyMeasurement>.from(_state!.medidas)..removeWhere((m) => m.id == id);
    _state = _state!.copyWith(medidas: list);
    saveState();
    notifyListeners();
  }

  void updateMeasurement(BodyMeasurement record) {
    if (_state == null) return;
    final index = _state!.medidas.indexWhere((m) => m.id == record.id);
    if (index == -1) return;
    final List<BodyMeasurement> list = List.from(_state!.medidas);
    list[index] = record;
    _state = _state!.copyWith(medidas: list);
    saveState();
    notifyListeners();
  }

  // --- SETTINGS OPERATIONS ---
  void updateSettings(bool sound, bool vibration, int prepSeconds) {
    if (_state == null) return;
    final newSettings = SettingsState(
      sound: sound,
      vibration: vibration,
      prepSeconds: prepSeconds,
    );
    _state = _state!.copyWith(settings: newSettings);
    saveState();
    notifyListeners();
  }

  // --- DIET & WATER OPERATIONS ---
  void updateWaterIntake(int quantityMl) {
    if (_state == null) return;
    final currentDiet = _state!.diet;
    final newDiet = DietState(
      caloriesGoal: currentDiet.caloriesGoal,
      proteinGoal: currentDiet.proteinGoal,
      carbsGoal: currentDiet.carbsGoal,
      fatGoal: currentDiet.fatGoal,
      waterGoalMl: currentDiet.waterGoalMl,
      meals: currentDiet.meals,
      waterIntakeMl: quantityMl,
      fasting: currentDiet.fasting,
      abstinence: currentDiet.abstinence,
    );

    _state = _state!.copyWith(diet: newDiet);
    saveState();
    notifyListeners();
  }

  void addMeal(String name, int cals, double prot, double carbs, double fat, String time) {
    if (_state == null) return;
    final currentDiet = _state!.diet;
    final meal = Meal(
      id: "meal-${DateTime.now().millisecondsSinceEpoch}",
      name: name,
      calories: cals,
      protein: prot,
      carbs: carbs,
      fat: fat,
      time: time,
    );
    final meals = List<Meal>.from(currentDiet.meals)..add(meal);
    
    final newDiet = DietState(
      caloriesGoal: currentDiet.caloriesGoal,
      proteinGoal: currentDiet.proteinGoal,
      carbsGoal: currentDiet.carbsGoal,
      fatGoal: currentDiet.fatGoal,
      waterGoalMl: currentDiet.waterGoalMl,
      meals: meals,
      waterIntakeMl: currentDiet.waterIntakeMl,
      fasting: currentDiet.fasting,
      abstinence: currentDiet.abstinence,
    );

    _state = _state!.copyWith(diet: newDiet);
    saveState();
    notifyListeners();
  }

  void deleteMeal(String mealId) {
    if (_state == null) return;
    final currentDiet = _state!.diet;
    final meals = List<Meal>.from(currentDiet.meals)..removeWhere((m) => m.id == mealId);
    
    final newDiet = DietState(
      caloriesGoal: currentDiet.caloriesGoal,
      proteinGoal: currentDiet.proteinGoal,
      carbsGoal: currentDiet.carbsGoal,
      fatGoal: currentDiet.fatGoal,
      waterGoalMl: currentDiet.waterGoalMl,
      meals: meals,
      waterIntakeMl: currentDiet.waterIntakeMl,
      fasting: currentDiet.fasting,
      abstinence: currentDiet.abstinence,
    );

    _state = _state!.copyWith(diet: newDiet);
    saveState();
    notifyListeners();
  }

  // --- FASTING ACTIONS ---
  void startFasting(double hours) {
    if (_state == null) return;
    final currentDiet = _state!.diet;
    
    final newFasting = FastingState(
      history: currentDiet.fasting.history,
      active: ActiveFasting(
        startTime: DateTime.now().toUtc().toIso8601String(),
        goalDurationHours: hours,
      ),
    );

    final newDiet = DietState(
      caloriesGoal: currentDiet.caloriesGoal,
      proteinGoal: currentDiet.proteinGoal,
      carbsGoal: currentDiet.carbsGoal,
      fatGoal: currentDiet.fatGoal,
      waterGoalMl: currentDiet.waterGoalMl,
      meals: currentDiet.meals,
      waterIntakeMl: currentDiet.waterIntakeMl,
      fasting: newFasting,
      abstinence: currentDiet.abstinence,
    );

    _state = _state!.copyWith(diet: newDiet);
    saveState();
    notifyListeners();
  }

  void endFasting() {
    if (_state == null || _state!.diet.fasting.active == null) return;
    final currentDiet = _state!.diet;
    final active = currentDiet.fasting.active!;

    final record = FastingRecord(
      id: "fast-${DateTime.now().millisecondsSinceEpoch}",
      startTime: active.startTime,
      endTime: DateTime.now().toUtc().toIso8601String(),
      goalDurationHours: active.goalDurationHours,
    );

    final history = List<FastingRecord>.from(currentDiet.fasting.history)..insert(0, record);

    final newFasting = FastingState(
      history: history,
      active: null,
    );

    final newDiet = DietState(
      caloriesGoal: currentDiet.caloriesGoal,
      proteinGoal: currentDiet.proteinGoal,
      carbsGoal: currentDiet.carbsGoal,
      fatGoal: currentDiet.fatGoal,
      waterGoalMl: currentDiet.waterGoalMl,
      meals: currentDiet.meals,
      waterIntakeMl: currentDiet.waterIntakeMl,
      fasting: newFasting,
      abstinence: currentDiet.abstinence,
    );

    _state = _state!.copyWith(diet: newDiet);
    saveState();
    notifyListeners();
  }

  void updateWaterGoal(int goalMl) {
    if (_state == null) return;
    final currentDiet = _state!.diet;
    final newDiet = DietState(
      caloriesGoal: currentDiet.caloriesGoal,
      proteinGoal: currentDiet.proteinGoal,
      carbsGoal: currentDiet.carbsGoal,
      fatGoal: currentDiet.fatGoal,
      waterGoalMl: goalMl,
      meals: currentDiet.meals,
      waterIntakeMl: currentDiet.waterIntakeMl,
      fasting: currentDiet.fasting,
      abstinence: currentDiet.abstinence,
    );
    _state = _state!.copyWith(diet: newDiet);
    saveState();
    notifyListeners();
  }

  void addAbstinence(String title, [String? notes]) {
    if (_state == null) return;
    final currentDiet = _state!.diet;
    final newRecord = AbstinenceRecord(
      id: "abst-${DateTime.now().millisecondsSinceEpoch}",
      title: title,
      startTime: DateTime.now().toUtc().toIso8601String(),
      notes: notes,
    );
    final list = List<AbstinenceRecord>.from(currentDiet.abstinence)..add(newRecord);
    final newDiet = DietState(
      caloriesGoal: currentDiet.caloriesGoal,
      proteinGoal: currentDiet.proteinGoal,
      carbsGoal: currentDiet.carbsGoal,
      fatGoal: currentDiet.fatGoal,
      waterGoalMl: currentDiet.waterGoalMl,
      meals: currentDiet.meals,
      waterIntakeMl: currentDiet.waterIntakeMl,
      fasting: currentDiet.fasting,
      abstinence: list,
    );
    _state = _state!.copyWith(diet: newDiet);
    saveState();
    notifyListeners();
  }

  void resetAbstinence(String id) {
    if (_state == null) return;
    final currentDiet = _state!.diet;
    final list = currentDiet.abstinence.map((a) {
      if (a.id == id) {
        return AbstinenceRecord(
          id: a.id,
          title: a.title,
          startTime: DateTime.now().toUtc().toIso8601String(),
          notes: a.notes,
        );
      }
      return a;
    }).toList();
    final newDiet = DietState(
      caloriesGoal: currentDiet.caloriesGoal,
      proteinGoal: currentDiet.proteinGoal,
      carbsGoal: currentDiet.carbsGoal,
      fatGoal: currentDiet.fatGoal,
      waterGoalMl: currentDiet.waterGoalMl,
      meals: currentDiet.meals,
      waterIntakeMl: currentDiet.waterIntakeMl,
      fasting: currentDiet.fasting,
      abstinence: list,
    );
    _state = _state!.copyWith(diet: newDiet);
    saveState();
    notifyListeners();
  }

  void deleteAbstinence(String id) {
    if (_state == null) return;
    final currentDiet = _state!.diet;
    final list = List<AbstinenceRecord>.from(currentDiet.abstinence)..removeWhere((a) => a.id == id);
    final newDiet = DietState(
      caloriesGoal: currentDiet.caloriesGoal,
      proteinGoal: currentDiet.proteinGoal,
      carbsGoal: currentDiet.carbsGoal,
      fatGoal: currentDiet.fatGoal,
      waterGoalMl: currentDiet.waterGoalMl,
      meals: currentDiet.meals,
      waterIntakeMl: currentDiet.waterIntakeMl,
      fasting: currentDiet.fasting,
      abstinence: list,
    );
    _state = _state!.copyWith(diet: newDiet);
    saveState();
    notifyListeners();
  }

  // --- INITIALIZERS FOR DEFAULT STATE ---
  PlannerState _getDefaultState() {
    return PlannerState(
      library: _getDefaultLibrary(),
      routines: _getDefaultRoutines(),
      planner: _getDefaultPlanner(),
      history: [],
      prs: {},
      medidas: [],
      settings: SettingsState(sound: true, vibration: true, prepSeconds: 5),
      diet: DietState(
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
    );
  }

  List<LibraryExercise> _getDefaultLibrary() {
    return [];
  }

  List<Routine> _getDefaultRoutines() {
    return [];
  }

  Map<String, List<String>> _getDefaultPlanner() {
    return {
      "seg": [],
      "ter": [],
      "qua": [],
      "qui": [],
      "sex": [],
      "sab": [],
      "dom": []
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncWaterFromWidget();
      syncActiveWorkoutFromWidget();
      checkAndResetDailyDiet();
      syncHealthMetrics();
    }
  }

  Future<void> syncWaterFromWidget() async {
    if (_state == null) return;
    try {
      final currentWater = await WatchService.instance.getSharedWaterIntake();
      if (currentWater != null && currentWater != _state!.diet.waterIntakeMl) {
        updateWaterIntake(currentWater);
      }
    } catch (e) {
      debugPrint('[TrackerProvider] Erro ao sincronizar água do widget: $e');
    }
  }

  Future<void> syncActiveWorkoutFromWidget() async {
    if (_state == null || _isLoading) return;
    try {
      final res = await WatchService.instance.getSharedActiveWorkout();
      if (res == null) return;

      final bool finishPending = res['finishWorkoutPending'] ?? false;
      if (finishPending) {
        final active = _state!.activeWorkout;
        if (active != null) {
          final elapsed = active.elapsedSeconds;
          finishWorkout(elapsed ~/ 60, 5, 'Finalizado via Dynamic Island');
        }
        return;
      }

      final String? workoutJson = res['workoutJson'];
      if (workoutJson != null) {
        final decodedMap = json.decode(workoutJson) as Map<String, dynamic>;
        final fromWidget = ActiveWorkoutState.fromJson(decodedMap);
        
        final current = _state!.activeWorkout;
        if (current == null) {
          _state = _state!.copyWith(activeWorkout: fromWidget);
          notifyListeners();
        } else {
          final jsonCurrent = json.encode(current.toJson());
          final jsonWidget = json.encode(fromWidget.toJson());
          if (jsonCurrent != jsonWidget) {
            _state = _state!.copyWith(activeWorkout: fromWidget);
            
            final rest = fromWidget.restTimer;
            if (rest != null) {
              RestTimerService.instance.start(
                endTimeMs: rest.endTime,
                seconds: rest.totalSeconds,
                prep: rest.isPrep,
                exName: rest.nextExerciseName,
                setNum: rest.nextSetNum,
              );
            } else {
              RestTimerService.instance.clear();
            }
            
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('[TrackerProvider] Erro ao sincronizar treino do widget: $e');
    }
  }

  void checkAndResetDailyDiet() {
    if (_state == null) return;
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    final currentDiet = _state!.diet;
    if (currentDiet.lastDietDate != todayStr) {
      int totalCals = currentDiet.meals.fold<int>(0, (sum, m) => sum + m.calories);
      double totalProt = currentDiet.meals.fold<double>(0, (sum, m) => sum + m.protein);
      double totalCarbs = currentDiet.meals.fold<double>(0, (sum, m) => sum + m.carbs);
      double totalFat = currentDiet.meals.fold<double>(0, (sum, m) => sum + m.fat);
      
      final historyDay = DietHistoryDay(
        date: currentDiet.lastDietDate,
        caloriesGoal: currentDiet.caloriesGoal,
        caloriesIntake: totalCals,
        proteinGoal: currentDiet.proteinGoal,
        proteinIntake: totalProt,
        carbsGoal: currentDiet.carbsGoal,
        carbsIntake: totalCarbs,
        fatGoal: currentDiet.fatGoal,
        fatIntake: totalFat,
        waterGoalMl: currentDiet.waterGoalMl,
        waterIntakeMl: currentDiet.waterIntakeMl,
      );
      
      final newHistory = Map<String, DietHistoryDay>.from(_state!.dietHistory);
      newHistory[currentDiet.lastDietDate] = historyDay;
      
      final newDiet = DietState(
        caloriesGoal: currentDiet.caloriesGoal,
        proteinGoal: currentDiet.proteinGoal,
        carbsGoal: currentDiet.carbsGoal,
        fatGoal: currentDiet.fatGoal,
        waterGoalMl: currentDiet.waterGoalMl,
        meals: [],
        waterIntakeMl: 0,
        fasting: currentDiet.fasting,
        abstinence: currentDiet.abstinence,
        lastDietDate: todayStr,
      );
      
      _state = _state!.copyWith(
        diet: newDiet,
        dietHistory: newHistory,
      );
      
      saveState();
      notifyListeners();
    }
  }

  Future<void> syncHealthMetrics() async {
    if (_currentUserId.isEmpty) return;
    try {
      final metrics = await HealthService.instance.getDailyMetrics();
      if (metrics != null) {
        _todaySteps = metrics['steps'] ?? 0;
        _todayBurnedCalories = metrics['activeCalories'] ?? 0;
        _currentHeartRate = metrics['heartRate'] ?? 0;
        _healthAuthorized = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[TrackerProvider] Erro ao sincronizar HealthKit: $e');
    }
  }

  Future<void> requestHealthAuthorization() async {
    final success = await HealthService.instance.requestAuthorization();
    if (success) {
      _healthAuthorized = true;
      await syncHealthMetrics();
    }
  }
}
