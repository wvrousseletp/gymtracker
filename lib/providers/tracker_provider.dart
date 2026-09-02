import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../services/analytics_service.dart';
import '../utils/food_presets_data.dart';
import '../utils/default_exercises_data.dart';
export '../utils/date_utils.dart';
import 'profile_provider.dart';
import 'workout_provider.dart';
import 'diet_provider.dart';

class TrackerProvider extends ChangeNotifier with WidgetsBindingObserver {
  final StatePersistenceService _persistence = StatePersistenceService();
  final FirebaseSyncService _firebaseSync = FirebaseSyncService();

  ProfileProvider? _profileProvider;
  WorkoutProvider? _workoutProvider;
  WorkoutProvider? get workoutProvider => _workoutProvider;
  DietProvider? _dietProvider;

  bool _isLoading = true;

  int _todaySteps = 0;
  int _todayBurnedCalories = 0;
  int _currentHeartRate = 0;
  bool _healthAuthorized = false;

  Timer? _saveDebounceTimer;
  Timer? _dailyResetTimer;
  String _lastCheckedDay = '';

  int get todaySteps => _todaySteps;
  int get todayBurnedCalories => _todayBurnedCalories;
  int get currentHeartRate => _currentHeartRate;
  bool get healthAuthorized => _healthAuthorized;

  bool get isLoading => _isLoading;
  List<ActiveWorkoutState> get postponedWorkouts =>
      _workoutProvider?.postponedWorkouts ?? [];

  // Facade delegations
  List<Profile> get profiles => _profileProvider?.profiles ?? [];
  String get currentUserId => _profileProvider?.currentUserId ?? '';
  Profile get currentProfile =>
      _profileProvider?.currentProfile ??
      Profile(
        id: currentUserId,
        name: 'Usuário',
        avatar: '🏋️',
        colorAccent: 'Branco',
      );

  PlannerState? get state {
    if (_profileProvider == null ||
        _workoutProvider == null ||
        _dietProvider == null) return null;
    return PlannerState(
      library: _workoutProvider!.library,
      routines: _workoutProvider!.routines,
      planner: _workoutProvider!.planner,
      continuousBlocks: _workoutProvider!.continuousBlocks,
      history: _workoutProvider!.history,
      prs: _workoutProvider!.prs,
      exerciseNotes: _workoutProvider!.exerciseNotes,
      medidas: _workoutProvider!.medidas,
      settings: _workoutProvider!.settings,
      activeWorkout: _workoutProvider!.activeWorkout,
      postponedWorkouts: _workoutProvider!.postponedWorkouts,
      diet: _dietProvider!.diet,
      dietHistory: _dietProvider!.dietHistory,
      streak: _workoutProvider!.streak,
      deletedHealthWorkoutIds: _workoutProvider!.deletedHealthWorkoutIds,
      unlockedBadgeIds: _workoutProvider!.unlockedBadgeIds,
    );
  }

  TrackerProvider() {
    // Don't init WatchService here - wait for update() to be called
  }

  void update(
      ProfileProvider profile, WorkoutProvider workout, DietProvider diet) {
    _profileProvider = profile;
    _workoutProvider = workout;
    _dietProvider = diet;

    // Set callback to save state whenever sub-providers update with debouncing
    _workoutProvider?.onStateChanged = () => _debouncedSaveState();
    _dietProvider?.onStateChanged = () => _debouncedSaveState();

    // Set callback to sync water data to watch when water intake changes
    _dietProvider?.onWaterChanged = (int waterIntake) {
      WatchService.instance
          .sendWaterData(waterIntake, _dietProvider!.diet.waterGoalMl);
    };

    // Init WatchService after providers are set up
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _firebaseSync.dispose();
    _dailyResetTimer?.cancel();
    _saveDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    WidgetsBinding.instance.addObserver(this);
    WatchService.instance.init(this);
    _startDailyResetTimer();
  }

  void _startDailyResetTimer() {
    _dailyResetTimer?.cancel();
    _dailyResetTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkDayChange();
    });
  }

  void _checkDayChange() {
    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (_lastCheckedDay != todayStr) {
      _lastCheckedDay = todayStr;
      checkAndResetDailyDiet();
      checkAndResetPostponedWorkouts();
      debugPrint(
          '[TrackerProvider] Day changed to $todayStr, reset daily data');
    }
  }

  Future<void> _testFirebaseConnection(String uid) async {
    try {
      debugPrint('[FirebaseConnection] Testing Firebase connection...');
      debugPrint('[FirebaseConnection] Project ID: vicente-losmooscles');
      debugPrint('[FirebaseConnection] User ID: $uid');

      // Test Firestore connection by attempting to read user document
      final firestore = FirebaseFirestore.instance;
      final testDoc = await firestore.collection('users').doc(uid).get();

      debugPrint(
          '[FirebaseConnection] Firestore connection test: ${testDoc.exists ? "SUCCESS - Document exists" : "SUCCESS - Document does not exist (new user)"}');
      debugPrint(
          '[FirebaseConnection] Firebase is properly configured and connected!');
    } catch (e) {
      debugPrint('[FirebaseConnection] ERROR - Firebase connection failed: $e');
      debugPrint(
          '[FirebaseConnection] This indicates a configuration or network issue');
    }
  }

  Future<void> initializeUser(String uid) async {
    if (_profileProvider == null ||
        _workoutProvider == null ||
        _dietProvider == null) {
      debugPrint(
          '[TrackerProvider] Sub-providers not initialized yet, deferring user initialization');
      return;
    }

    _isLoading = true;
    notifyListeners();

    // Test Firebase connection
    await _testFirebaseConnection(uid);

    _profileProvider!.setCurrentUserId(uid);
    _workoutProvider!.historyLoaded = false;
    unawaited(AnalyticsService.logLogin(uid));

    final profileRaw = await _persistence.loadProfileJson(uid);
    if (profileRaw != null) {
      try {
        _profileProvider!.setProfiles([_persistence.decodeProfile(profileRaw)]);
      } catch (e) {
        _profileProvider!.setProfiles([_defaultProfile(uid)]);
      }
    } else {
      final cloudProfile = await checkProfileExistsInCloud(uid);
      if (cloudProfile != null) {
        try {
          _profileProvider!.setProfiles([Profile.fromJson(cloudProfile)]);
          await _profileProvider!.saveProfilesConfig();
        } catch (_) {
          _profileProvider!.setProfiles([_defaultProfile(uid)]);
        }
      } else {
        _profileProvider!.setProfiles([_defaultProfile(uid)]);
      }
    }

    await loadCurrentState();

    // Initialize last checked day to today
    final now = DateTime.now();
    _lastCheckedDay =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    checkAndResetDailyDiet();
    checkAndResetPostponedWorkouts();
    await syncWaterFromWidget();
    await syncActiveWorkoutFromWidget();
    await syncHealthMetrics();
    // Auto import recent Apple Health workouts on startup
    await syncAppleWorkouts();

    // Drenar operações offline pendentes após reconexão
    unawaited(_firebaseSync.drainQueue(uid));

    // Migração de estado legado do "vicente" local para o UID do Google
    final compiledState = state;
    if (compiledState == null || compiledState.history.isEmpty) {
      final oldStateRaw = await _persistence.loadLegacyVicenteStateJson();
      if (oldStateRaw != null) {
        try {
          final oldState = _persistence.decodeState(oldStateRaw);
          if (oldState.history.isNotEmpty || oldState.routines.isNotEmpty) {
            _applyStateToSubproviders(oldState);
            await saveState(immediateSync: true);
            debugPrint(
                '[Migration] Dados locais de "vicente" migrados para o Google UID: $uid');
          }
        } catch (e) {
          debugPrint('[Migration] Erro ao migrar dados locais antigos: $e');
        }
      }
    }

    if (_workoutProvider!.activeWorkout == null) {
      RestTimerService.instance.clear();
      WatchService.instance.sendActiveWorkoutCleared();
    }

    // Seed foods in background to avoid blocking startup
    unawaited(_checkAndSeedFoods());

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _checkAndSeedFoods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isSeeded = prefs.getBool('food_db_seeded_v4') ?? false;
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
          await prefs.setBool('food_db_seeded_v4', true);
          debugPrint("[Seeding] 500 alimentos iniciais semeados com sucesso.");
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

    _profileProvider!.setProfiles([]);
    _profileProvider!.setCurrentUserId('');

    // Clear sub-providers
    _workoutProvider!.library = [];
    _workoutProvider!.routines = [];
    _workoutProvider!.planner = {};
    _workoutProvider!.history = [];
    _workoutProvider!.prs = {};
    _workoutProvider!.exerciseNotes = {};
    _workoutProvider!.medidas = [];
    _workoutProvider!.activeWorkout = null;
    _workoutProvider!.historyLoaded = false;
    _workoutProvider!.unlockedBadgeIds = [];

    _dietProvider!.diet = DietState(
      caloriesGoal: 2000,
      proteinGoal: 150.0,
      carbsGoal: 200.0,
      fatGoal: 70.0,
      waterGoalMl: 2000,
      meals: [],
      waterIntakeMl: 0,
      fasting: FastingState(history: []),
      abstinence: [],
    );
    _dietProvider!.dietHistory = {};

    // Limpar fila de sync offline do usuário
    final uid = currentUserId;
    if (uid.isNotEmpty) {
      unawaited(_firebaseSync.clearQueueFor(uid));
    }

    await FirebaseAuth.instance.signOut();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> createCloudProfile(
      String uid, String name, String avatar, String color) async {
    final newProfile = Profile(
      id: uid,
      name: name,
      avatar: avatar,
      colorAccent: color,
    );
    _profileProvider!.setProfiles([newProfile]);
    _profileProvider!.setCurrentUserId(uid);
    await _profileProvider!.saveProfilesConfig();

    final defState = _getDefaultState();
    _applyStateToSubproviders(defState);
    await saveState(immediateSync: true);
  }

  void _applyStateToSubproviders(PlannerState state) {
    _workoutProvider!.library = state.library;
    _workoutProvider!.routines = state.routines;
    _workoutProvider!.planner = state.planner;
    _workoutProvider!.history = state.history;
    _workoutProvider!.prs = state.prs;
    _workoutProvider!.exerciseNotes = state.exerciseNotes;
    _workoutProvider!.medidas = state.medidas;
    _workoutProvider!.settings = state.settings;
    _workoutProvider!.activeWorkout = state.activeWorkout;
    _workoutProvider!.postponedWorkouts =
        List<ActiveWorkoutState>.from(state.postponedWorkouts);
    _workoutProvider!.deletedHealthWorkoutIds =
        List<String>.from(state.deletedHealthWorkoutIds);
    _workoutProvider!.unlockedBadgeIds =
        List<String>.from(state.unlockedBadgeIds);
    _workoutProvider!.streak = state.streak;

    _dietProvider!.diet = state.diet;
    _dietProvider!.dietHistory = state.dietHistory;

    _workoutProvider!.refreshStreak();
  }

  Future<void> loadCurrentState() async {
    final stateRaw = await _persistence.loadStateJson(currentUserId);
    var forceDownload = false;
    PlannerState currentState;

    if (stateRaw != null) {
      try {
        currentState = _persistence.decodeState(stateRaw);
      } catch (e) {
        currentState = _getDefaultState();
        forceDownload = true;
      }
    } else {
      currentState = _getDefaultState();
      forceDownload = true;
    }

    _applyStateToSubproviders(currentState);

    await _workoutProvider!.loadWorkoutHistory();
    // Re-compor após histórico carregado
    final completeState = state!;
    await _syncWithFirebase(completeState, forceDownload: forceDownload);

    _workoutProvider!.checkAndPopulateDefaultLibrary();
  }

  Future<void> saveState({bool immediateSync = false}) async {
    final compiledState = state;
    if (compiledState == null || currentUserId.isEmpty) return;

    await _persistence.saveStateJson(
      currentUserId,
      _persistence.encodeState(compiledState),
    );

    await _persistence.saveWorkoutsHistoryJson(
      currentUserId,
      json.encode(compiledState.history.map((h) => h.toJson()).toList()),
    );

    WatchService.instance.sendRoutines(compiledState.routines);
    WatchService.instance.sendLibrary(compiledState.library);
    WatchService.instance.sendPlanner(compiledState.planner);
    if (compiledState.activeWorkout != null) {
      WatchService.instance.sendActiveWorkout(compiledState.activeWorkout!);
    } else {
      WatchService.instance.sendActiveWorkoutCleared();
    }
    WatchService.instance.syncWidgetData();

    if (immediateSync) {
      await _firebaseSync.flushSync(
        userId: currentUserId,
        state: compiledState,
        profile: currentProfile,
      );
    } else {
      _firebaseSync.scheduleSync(
        userId: currentUserId,
        state: compiledState,
        profile: currentProfile,
      );
    }
    notifyListeners();
  }

  void _debouncedSaveState() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      saveState();
    });
  }

  Future<Map<String, dynamic>?> checkProfileExistsInCloud(String profileId) {
    return _firebaseSync.fetchCloudProfile(profileId);
  }

  Future<void> forceCloudSync() async {
    final s = state;
    if (s != null) {
      await _syncWithFirebase(s, forceDownload: true);
    }
  }

  Future<void> _syncWithFirebase(PlannerState localState,
      {required bool forceDownload}) async {
    if (currentUserId.isEmpty) return;

    final result = await _firebaseSync.sync(
      userId: currentUserId,
      localState: localState,
      profile: currentProfile,
      forceDownload: forceDownload,
      onRemoteApplied: _applyRemoteState,
    );

    if (result != null && result != localState) {
      notifyListeners();
    }
  }

  Future<void> _applyRemoteState(
      PlannerState remoteState, Profile? remoteProfile) async {
    _applyStateToSubproviders(remoteState);
    _workoutProvider!.checkAndPopulateDefaultLibrary();
    await _persistence.saveStateJson(
      currentUserId,
      _persistence.encodeState(remoteState),
    );
    // Persist workout logs history separately to disk so that local cache matches merged cloud data
    await _persistence.saveWorkoutsHistoryJson(
      currentUserId,
      json.encode(remoteState.history.map((h) => h.toJson()).toList()),
    );

    if (remoteProfile != null) {
      final idx = profiles.indexWhere((p) => p.id == remoteProfile.id);
      if (idx != -1) {
        _profileProvider!.profiles[idx] = remoteProfile;
        await _profileProvider!.saveProfilesConfig();
      }
    }
    notifyListeners();
  }

  // --- COMPATIBILITY DELEGATIONS ---
  void startWorkout(Routine routine, WorkoutRecovery recovery, bool isWarmup) {
    if (_workoutProvider == null) return;
    _workoutProvider!.startWorkout(routine, recovery, isWarmup);
  }

  void startSingleExercise(LibraryExercise exercise) {
    if (_workoutProvider == null) return;
    _workoutProvider!.startSingleExercise(exercise);
  }

  void completeSet(int exIndex, int setIndex, bool isDone,
      {double? distance,
      int? duration,
      bool isFailure = false,
      int? failureRep}) {
    if (_workoutProvider == null) return;
    _workoutProvider!.completeSet(exIndex, setIndex, isDone,
        distance: distance,
        duration: duration,
        isFailure: isFailure,
        failureRep: failureRep);
  }

  void startRestTimer(
      int seconds, String nextExName, int nextSetNum, bool isPrep) {
    if (_workoutProvider == null) return;
    _workoutProvider!.startRestTimer(seconds, nextExName, nextSetNum, isPrep);
  }

  void clearRestTimer() {
    if (_workoutProvider == null) return;
    _workoutProvider!.clearRestTimer();
  }

  void adjustRestTimer(int seconds) {
    if (_workoutProvider == null) return;
    _workoutProvider!.adjustRestTimer(seconds);
  }

  void updateExerciseWeightReps(int exIndex, double weight, int reps) {
    if (_workoutProvider == null) return;
    _workoutProvider!.updateExerciseWeightReps(exIndex, weight, reps);
  }

  void updateExerciseNote(String exerciseId, String note) {
    _workoutProvider?.updateExerciseNote(exerciseId, note);
    _debouncedSaveState();
  }


  void updateExerciseSetType(int exIdx, int setIdx, String type) {
    _workoutProvider?.updateExerciseSetType(exIdx, setIdx, type);
  }

  void updateExerciseRir(int exIdx, int setIdx, int? rir) {
    _workoutProvider?.updateExerciseRir(exIdx, setIdx, rir);
  }

  void updateExerciseSetWeightReps(
      int exIndex, int setIdx, double weight, int reps) {
    if (_workoutProvider == null) return;
    _workoutProvider!
        .updateExerciseSetWeightReps(exIndex, setIdx, weight, reps);
  }

  void updateExerciseRpe(int exIndex, int rpe) {
    if (_workoutProvider == null) return;
    _workoutProvider!.updateExerciseRpe(exIndex, rpe);
  }

  void updateWorkoutTimer(int seconds, {bool isWarmupTimer = false}) {
    if (_workoutProvider == null) return;
    _workoutProvider!.updateWorkoutTimer(seconds, isWarmupTimer: isWarmupTimer);
  }

  void setCurrentExerciseIndex(int index) {
    if (_workoutProvider == null) return;
    _workoutProvider!.setCurrentExerciseIndex(index);
  }

  void pauseWorkout(bool isPaused) {
    if (_workoutProvider == null) return;
    _workoutProvider!.pauseWorkout(isPaused);
  }

  void applyActiveWorkoutFromWatch(Map<String, dynamic> watchData) {
    if (_workoutProvider == null) return;
    _workoutProvider!.applyActiveWorkoutFromWatch(watchData);
  }

  void discardActiveWorkout() {
    if (_workoutProvider == null) return;
    _workoutProvider!.discardActiveWorkout();
  }

  void postponeActiveWorkout() {
    if (_workoutProvider == null) return;
    _workoutProvider!.postponeActiveWorkout();
  }

  void resumePostponedWorkout(int index) {
    if (_workoutProvider == null) return;
    _workoutProvider!.resumePostponedWorkout(index);
  }

  void discardPostponedWorkout(int index) {
    if (_workoutProvider == null) return;
    _workoutProvider!.discardPostponedWorkout(index);
  }

  void updateHealthMetrics(int heartRate, int activeCalories) {
    if (_workoutProvider == null) return;
    _workoutProvider!.updateHealthMetrics(heartRate, activeCalories);
  }

  void finishWorkout(int duration, int rpeValue, String notes) {
    if (_workoutProvider == null) return;
    _workoutProvider!.finishWorkout(duration, rpeValue, notes);
  }

  void addManualWorkoutLog(WorkoutLog log) {
    if (_workoutProvider == null) return;
    _workoutProvider!.addManualWorkoutLog(log);
  }

  Future<List<WorkoutLog>> loadWorkoutHistory() {
    if (_workoutProvider == null) return Future.value([]);
    return _workoutProvider!.loadWorkoutHistory();
  }

  void deleteWorkoutLog(String id) {
    if (_workoutProvider == null) return;
    _workoutProvider!.deleteWorkoutLog(id);
  }

  void shiftPlannerForwardWithoutLog() {
    if (_workoutProvider == null) return;
    _workoutProvider!.shiftPlannerForwardWithoutLog();
  }

  void shiftPlannerBackwardWithoutLog() {
    if (_workoutProvider == null) return;
    _workoutProvider!.shiftPlannerBackwardWithoutLog();
  }

  
  List<String> get flatContinuousList => _workoutProvider?.flatContinuousList ?? [];

  void addContinuousBlock({String? name}) {
    _workoutProvider?.addContinuousBlock(name: name);
  }

  void renameContinuousBlock(String blockId, String newName) {
    _workoutProvider?.renameContinuousBlock(blockId, newName);
  }

  void removeContinuousBlock(String blockId) {
    _workoutProvider?.removeContinuousBlock(blockId);
  }

  void reorderContinuousBlocks(int oldIndex, int newIndex) {
    _workoutProvider?.reorderContinuousBlocks(oldIndex, newIndex);
  }

  void addRoutineToContinuousBlock(String blockId, String routineId) {
    _workoutProvider?.addRoutineToContinuousBlock(blockId, routineId);
  }

  void updateRoutineInContinuousBlock(String blockId, int index, String newValue) {
    _workoutProvider?.updateRoutineInContinuousBlock(blockId, index, newValue);
  }

  void removeRoutineFromContinuousBlock(String blockId, int index) {
    _workoutProvider?.removeRoutineFromContinuousBlock(blockId, index);
  }

  void reorderRoutinesInContinuousBlock(String blockId, int oldIndex, int newIndex) {
    _workoutProvider?.reorderRoutinesInContinuousBlock(blockId, oldIndex, newIndex);
  }

  void addPlannerItem(String day) {
    if (_workoutProvider == null) return;
    _workoutProvider!.addPlannerItem(day);
  }

  void updatePlannerItem(String day, int index, String value) {
    if (_workoutProvider == null) return;
    _workoutProvider!.updatePlannerItem(day, index, value);
  }

  void reorderPlannerItem(String day, int index, bool moveUp) {
    if (_workoutProvider == null) return;
    _workoutProvider!.reorderPlannerItem(day, index, moveUp);
  }

  void removePlannerItem(String day, int index) {
    if (_workoutProvider == null) return;
    _workoutProvider!.removePlannerItem(day, index);
  }

  void importFromFixedDay(String sourceDay, String targetKey) {
    if (_workoutProvider == null) return;
    _workoutProvider!.importFromFixedDay(sourceDay, targetKey);
    notifyListeners();
  }

  void importAllFixedDays(String targetKey) {
    if (_workoutProvider == null) return;
    _workoutProvider!.importAllFixedDays(targetKey);
    notifyListeners();
  }

  void deletePersonalRecord(String exerciseId) {
    if (_workoutProvider == null) return;
    _workoutProvider!.deletePersonalRecord(exerciseId);
  }

  void addLibraryExercise(String name, String muscle, String measurementType,
      String? notes, String? executionType,
      {bool isStationary = false, bool isUnilateral = false}) {
    if (_workoutProvider == null) return;
    _workoutProvider!.addLibraryExercise(
        name, muscle, measurementType, notes, executionType,
        isStationary: isStationary, isUnilateral: isUnilateral);
  }

  void updateLibraryExercise(String id, String name, String muscle,
      String measurementType, String? notes, String? executionType,
      {bool isStationary = false, bool isUnilateral = false}) {
    if (_workoutProvider == null) return;
    _workoutProvider!.updateLibraryExercise(
        id, name, muscle, measurementType, notes, executionType,
        isStationary: isStationary, isUnilateral: isUnilateral);
  }

  void deleteLibraryExercise(String id) {
    if (_workoutProvider == null) return;
    _workoutProvider!.deleteLibraryExercise(id);
  }

  void addRoutine(
      String name, int defaultRest, List<RoutineExercise> exercises,
      {RoutineExecutionType executionType = RoutineExecutionType.standard,
      int circuitCycles = 3}) {
    if (_workoutProvider == null) return;
    _workoutProvider!.addRoutine(name, defaultRest, exercises,
        executionType: executionType, circuitCycles: circuitCycles);
  }

  void updateRoutine(Routine r) {
    if (_workoutProvider == null) return;
    _workoutProvider!.updateRoutine(r);
  }

  void deleteRoutine(String id) {
    if (_workoutProvider == null) return;
    _workoutProvider!.deleteRoutine(id);
  }

  void addMeasurement(BodyMeasurement record) {
    if (_workoutProvider == null) return;
    _workoutProvider!.addMeasurement(record);
  }

  void deleteMeasurement(String id) {
    if (_workoutProvider == null) return;
    _workoutProvider!.deleteMeasurement(id);
  }

  void updateMeasurement(BodyMeasurement record) {
    if (_workoutProvider == null) return;
    _workoutProvider!.updateMeasurement(record);
  }

  void updateSettings(bool sound, bool vibration, int prepSeconds) {
    if (_workoutProvider == null) return;
    _workoutProvider!.updateSettings(sound, vibration, prepSeconds);
  }

  void setOrganizationMode(OrganizationMode mode) {
    if (_workoutProvider == null) return;
    _workoutProvider!.setOrganizationMode(mode);
  }

  void updateWaterIntake(int quantityMl) {
    if (_dietProvider == null) return;
    _dietProvider!.updateWaterIntake(quantityMl);
  }

  void addMeal(String name, int cals, double prot, double carbs, double fat,
      String time) {
    if (_dietProvider == null) return;
    _dietProvider!.addMeal(name, cals, prot, carbs, fat, time);
  }

  void deleteMeal(String mealId) {
    if (_dietProvider == null) return;
    _dietProvider!.deleteMeal(mealId);
  }

  void updateDietGoals(int cals, double prot, double carbs, double fat) {
    if (_dietProvider == null) return;
    _dietProvider!.updateDietGoals(cals, prot, carbs, fat);
  }

  void startFasting(double hours) {
    if (_dietProvider == null) return;
    _dietProvider!.startFasting(hours);
  }

  void endFasting() {
    if (_dietProvider == null) return;
    _dietProvider!.endFasting();
  }

  void updateWaterGoal(int goalMl) {
    if (_dietProvider == null) return;
    _dietProvider!.updateWaterGoal(goalMl);
  }

  void addAbstinence(String title, [String? notes]) {
    if (_dietProvider == null) return;
    _dietProvider!.addAbstinence(title, notes);
  }

  void resetAbstinence(String id) {
    if (_dietProvider == null) return;
    _dietProvider!.resetAbstinence(id);
  }

  void deleteAbstinence(String id) {
    if (_dietProvider == null) return;
    _dietProvider!.deleteAbstinence(id);
  }

  void checkAndResetDailyDiet() {
    if (_dietProvider == null) return;
    _dietProvider!.checkAndResetDailyDiet();
  }

  void checkAndResetPostponedWorkouts() {
    if (_workoutProvider == null) return;
    if (_workoutProvider!.postponedWorkouts.isEmpty) return;

    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // Remove any postponed workouts that were created on a previous day
    final beforeCount = _workoutProvider!.postponedWorkouts.length;
    _workoutProvider!.postponedWorkouts.removeWhere((workout) {
      try {
        final workoutDate =
            DateTime.fromMillisecondsSinceEpoch(workout.startTime).toLocal();
        final workoutDateStr =
            "${workoutDate.year}-${workoutDate.month.toString().padLeft(2, '0')}-${workoutDate.day.toString().padLeft(2, '0')}";
        return workoutDateStr != todayStr;
      } catch (_) {
        return true; // Remove if date can't be parsed
      }
    });

    if (_workoutProvider!.postponedWorkouts.length != beforeCount) {
      debugPrint(
          '[TrackerProvider] Limpou ${beforeCount - _workoutProvider!.postponedWorkouts.length} treino(s) adiado(s) de dias anteriores');
      saveState();
    }
  }

  Future<void> updateProfile(
      String id, String name, String avatar, String color) {
    if (_profileProvider == null) return Future.value();
    return _profileProvider!.updateProfile(id, name, avatar, color);
  }

  // --- INITIALIZERS FOR DEFAULT STATE ---
  PlannerState _getDefaultState() {
    return PlannerState(
      library: List.from(defaultLibraryExercises),
      routines: [],
      planner: {
        "seg": [],
        "ter": [],
        "qua": [],
        "qui": [],
        "sex": [],
        "sab": [],
        "dom": []
      },
      continuousBlocks: [],
      history: [],
      prs: {},
      exerciseNotes: {},
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncWaterFromWidget();
      syncActiveWorkoutFromWidget();
      checkAndResetDailyDiet();
      checkAndResetPostponedWorkouts();
      syncHealthMetrics();
      recalculateWorkoutElapsedTime();
    } else if (state == AppLifecycleState.paused) {
      persistActiveWorkoutState();
    }
  }

  void persistActiveWorkoutState() {
    // Save current workout state to SharedPreferences for background recovery
    final active = _workoutProvider?.activeWorkout;
    if (active != null) {
      _persistence.saveActiveWorkoutState(active);
      debugPrint(
          '[TrackerProvider] Persisted active workout state for background recovery');
    }
  }

  void recalculateWorkoutElapsedTime() {
    // Recalculate elapsed time when returning from background
    final active = _workoutProvider?.activeWorkout;
    if (active != null && !active.paused) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final startTime = active.startTime;
      final newElapsed = ((now - startTime) / 1000).round();

      if (newElapsed != active.elapsedSeconds) {
        _workoutProvider?.updateWorkoutElapsedTime(newElapsed);
        debugPrint(
            '[TrackerProvider] Recalculated elapsed time: ${active.elapsedSeconds}s -> ${newElapsed}s');
      }
    }
  }

  Future<void> syncWaterFromWidget() async {
    try {
      final currentWater = await WatchService.instance.getSharedWaterIntake();
      final currentLocal = _dietProvider?.diet.waterIntakeMl;
      if (currentWater != null && currentWater != currentLocal) {
        updateWaterIntake(currentWater);
      }
    } catch (e) {
      debugPrint('[TrackerProvider] Erro ao sincronizar água do widget: $e');
    }
  }

  Future<void> syncActiveWorkoutFromWidget() async {
    if (_isLoading) return;
    try {
      final res = await WatchService.instance.getSharedActiveWorkout();
      if (res == null) return;

      final bool finishPending = res['finishWorkoutPending'] ?? false;
      if (finishPending) {
        final active = _workoutProvider?.activeWorkout;
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

        final current = _workoutProvider?.activeWorkout;
        if (current == null) {
          _workoutProvider!.activeWorkout = fromWidget;
          _workoutProvider!.refreshStreak();
        } else {
          final jsonCurrent = json.encode(current.toJson());
          final jsonWidget = json.encode(fromWidget.toJson());
          if (jsonCurrent != jsonWidget) {
            _workoutProvider!.activeWorkout = fromWidget;

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
            _workoutProvider!.refreshStreak();
          }
        }
      }
    } catch (e) {
      debugPrint('[TrackerProvider] Erro ao sincronizar treino do widget: $e');
    }
  }

  Future<void> syncHealthMetrics() async {
    if (currentUserId.isEmpty) return;
    try {
      final metrics = await HealthService.instance.getDailyMetrics();
      if (metrics != null) {
        _todaySteps = metrics['steps'] ?? 0;
        _todayBurnedCalories = metrics['activeCalories'] ?? 0;
        _currentHeartRate = metrics['heartRate'] ?? 0;
        _healthAuthorized = true;
        notifyListeners();
      }

      // Auto sync recent Apple Health workouts too
      await syncAppleWorkouts();
    } catch (e) {
      debugPrint('[TrackerProvider] Erro ao sincronizar HealthKit: $e');
    }
  }

  Future<void> syncAppleWorkouts() async {
    if (currentUserId.isEmpty || _workoutProvider == null) return;
    try {
      final workouts = await HealthService.instance.getRecentWorkouts();
      if (workouts.isEmpty) return;

      bool addedAny = false;
      for (final w in workouts) {
        final id = w['id'] as String;
        final name = w['name'] as String;
        final duration = w['duration'] as int;
        final calories = w['calories'] as int;
        final date = w['date'] as String;

        // Skip if already imported by ID
        if (_workoutProvider!.history.any((log) => log.id == id)) continue;

        // Skip if it was imported and then deleted by the user
        if (_workoutProvider!.deletedHealthWorkoutIds.contains(id)) continue;

        // Skip if there is a local log registered at the exact same or very close time (±3 minutes)
        try {
          final workoutDateTime = DateTime.parse(date);
          final bool isDuplicateOfLocal = _workoutProvider!.history.any((log) {
            try {
              final logDateTime = DateTime.parse(log.date);
              final diffMinutes =
                  logDateTime.difference(workoutDateTime).inMinutes.abs();
              return diffMinutes <= 3; // Within 3 minutes
            } catch (_) {
              return false;
            }
          });
          if (isDuplicateOfLocal) continue;
        } catch (_) {}

        final newLog = WorkoutLog(
          id: id,
          name: name,
          date: date,
          duration: duration,
          completedSets: 1,
          totalSets: 1,
          totalWeight: 0.0,
          rpe: 8,
          notes: "Importado do Apple Health",
          avgHeartRate: null,
          activeCalories: calories > 0 ? calories : null,
          exercises: [
            LogExercise(
              name: name,
              muscle: "Geral",
              sets: 1,
              completedSets: 1,
              reps: duration ~/ 60,
              weight: 0.0,
              rpe: 8,
              performedCardios: [],
              failureReport: [false],
              failureReps: [null],
            )
          ],
        );

        _workoutProvider!.history.insert(0, newLog);
        unawaited(_firebaseSync.syncWorkoutLog(currentUserId, newLog));
        addedAny = true;
      }

      if (addedAny) {
        // Sort by date descending
        _workoutProvider!.history.sort((a, b) => b.date.compareTo(a.date));
        await saveState();
      }
    } catch (e) {
      debugPrint(
          '[TrackerProvider] Erro ao importar treinos do Apple Health: $e');
    }
  }

  Future<void> requestHealthAuthorization() async {
    final success = await HealthService.instance.requestAuthorization();
    if (success) {
      _healthAuthorized = true;
      await syncHealthMetrics();
    }
  }
  Map<String, int> getRecentMuscleSets([int days = 7]) {
    return _workoutProvider?.getRecentMuscleSets(days) ?? {};
  }
}
