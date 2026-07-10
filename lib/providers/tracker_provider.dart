import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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
import '../services/analytics_service.dart';
import '../utils/food_presets_data.dart';
export '../utils/date_utils.dart';
import 'profile_provider.dart';
import 'workout_provider.dart';
import 'diet_provider.dart';

class TrackerProvider extends ChangeNotifier with WidgetsBindingObserver {
  final StatePersistenceService _persistence = StatePersistenceService();
  final FirebaseSyncService _firebaseSync = FirebaseSyncService();

  ProfileProvider? _profileProvider;
  WorkoutProvider? _workoutProvider;
  DietProvider? _dietProvider;

  bool _isLoading = true;
  
  int _todaySteps = 0;
  int _todayBurnedCalories = 0;
  int _currentHeartRate = 0;
  bool _healthAuthorized = false;

  int get todaySteps => _todaySteps;
  int get todayBurnedCalories => _todayBurnedCalories;
  int get currentHeartRate => _currentHeartRate;
  bool get healthAuthorized => _healthAuthorized;

  bool get isLoading => _isLoading;

  // Facade delegations
  List<Profile> get profiles => _profileProvider?.profiles ?? [];
  String get currentUserId => _profileProvider?.currentUserId ?? '';
  Profile get currentProfile => _profileProvider?.currentProfile ?? Profile(
        id: currentUserId,
        name: 'Usuário',
        avatar: '🏋️',
        colorAccent: 'Branco',
      );

  PlannerState? get state {
    if (_profileProvider == null || _workoutProvider == null || _dietProvider == null) return null;
    return PlannerState(
      library: _workoutProvider!.library,
      routines: _workoutProvider!.routines,
      planner: _workoutProvider!.planner,
      history: _workoutProvider!.history,
      prs: _workoutProvider!.prs,
      medidas: _workoutProvider!.medidas,
      settings: _workoutProvider!.settings,
      activeWorkout: _workoutProvider!.activeWorkout,
      diet: _dietProvider!.diet,
      dietHistory: _dietProvider!.dietHistory,
      streak: _workoutProvider!.streak,
    );
  }

  TrackerProvider() {
    // Don't init WatchService here - wait for update() to be called
  }

  void update(ProfileProvider profile, WorkoutProvider workout, DietProvider diet) {
    _profileProvider = profile;
    _workoutProvider = workout;
    _dietProvider = diet;

    // Set callback to save state whenever sub-providers update
    _workoutProvider?.onStateChanged = () => saveState();
    _dietProvider?.onStateChanged = () => saveState();
    
    // Set callback to sync water data to watch when water intake changes
    _dietProvider?.onWaterChanged = (int waterIntake) {
      WatchService.instance.sendWaterData(waterIntake, _dietProvider!.diet.waterGoalMl);
    };
    
    // Init WatchService after providers are set up
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
    WatchService.instance.init(this);
  }

  Future<void> initializeUser(String uid) async {
    if (_profileProvider == null || _workoutProvider == null || _dietProvider == null) {
      debugPrint('[TrackerProvider] Sub-providers not initialized yet, deferring user initialization');
      return;
    }

    _isLoading = true;
    notifyListeners();

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
    await syncWaterFromWidget();
    await syncActiveWorkoutFromWidget();
    checkAndResetDailyDiet();
    await syncHealthMetrics();

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
            debugPrint('[Migration] Dados locais de "vicente" migrados para o Google UID: $uid');
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
    _workoutProvider!.medidas = [];
    _workoutProvider!.activeWorkout = null;
    _workoutProvider!.historyLoaded = false;

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

  Future<void> createCloudProfile(String uid, String name, String avatar, String color) async {
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
    _workoutProvider!.medidas = state.medidas;
    _workoutProvider!.settings = state.settings;
    _workoutProvider!.activeWorkout = state.activeWorkout;
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
  }

  Future<void> saveState({bool immediateSync = false}) async {
    final compiledState = state;
    if (compiledState == null || currentUserId.isEmpty) return;

    await _persistence.saveStateJson(
      currentUserId,
      _persistence.encodeState(compiledState),
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
  }

  Future<Map<String, dynamic>?> checkProfileExistsInCloud(String profileId) {
    return _firebaseSync.fetchCloudProfile(profileId);
  }

  Future<void> _syncWithFirebase(PlannerState localState, {required bool forceDownload}) async {
    if (currentUserId.isEmpty) return;

    final result = await _firebaseSync.sync(
      userId: currentUserId,
      localState: localState,
      profile: currentProfile,
      forceDownload: forceDownload,
      onRemoteApplied: _applyRemoteState,
    );

    if (result != null && result != localState) {
      _applyStateToSubproviders(result);
      notifyListeners();
    }
  }

  Future<void> _applyRemoteState(PlannerState remoteState, Profile? remoteProfile) async {
    _applyStateToSubproviders(remoteState);
    await _persistence.saveStateJson(
      currentUserId,
      _persistence.encodeState(remoteState),
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

  void completeSet(int exIndex, int setIndex, bool isDone, {double? distance, int? duration, bool isFailure = false, int? failureRep}) {
    if (_workoutProvider == null) return;
    _workoutProvider!.completeSet(exIndex, setIndex, isDone, distance: distance, duration: duration, isFailure: isFailure, failureRep: failureRep);
  }

  void startRestTimer(int seconds, String nextExName, int nextSetNum, bool isPrep) {
    if (_workoutProvider == null) return;
    _workoutProvider!.startRestTimer(seconds, nextExName, nextSetNum, isPrep);
  }

  void clearRestTimer() {
    if (_workoutProvider == null) return;
    _workoutProvider!.clearRestTimer();
  }

  void updateExerciseWeightReps(int exIndex, double weight, int reps) {
    if (_workoutProvider == null) return;
    _workoutProvider!.updateExerciseWeightReps(exIndex, weight, reps);
  }

  void updateExerciseSetWeightReps(int exIndex, int setIdx, double weight, int reps) {
    if (_workoutProvider == null) return;
    _workoutProvider!.updateExerciseSetWeightReps(exIndex, setIdx, weight, reps);
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

  void resumeActiveWorkout() {
    if (_workoutProvider == null) return;
    _workoutProvider!.resumeActiveWorkout();
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

  void deletePersonalRecord(String exerciseId) {
    if (_workoutProvider == null) return;
    _workoutProvider!.deletePersonalRecord(exerciseId);
  }

  void addLibraryExercise(String name, String muscle, String measurementType, String? notes, String? executionType) {
    if (_workoutProvider == null) return;
    _workoutProvider!.addLibraryExercise(name, muscle, measurementType, notes, executionType);
  }

  void updateLibraryExercise(String id, String name, String muscle, String measurementType, String? notes, String? executionType) {
    if (_workoutProvider == null) return;
    _workoutProvider!.updateLibraryExercise(id, name, muscle, measurementType, notes, executionType);
  }

  void deleteLibraryExercise(String id) {
    if (_workoutProvider == null) return;
    _workoutProvider!.deleteLibraryExercise(id);
  }

  void addRoutine(String name, int defaultRest, List<RoutineExercise> exercises) {
    if (_workoutProvider == null) return;
    _workoutProvider!.addRoutine(name, defaultRest, exercises);
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

  void updateWaterIntake(int quantityMl) {
    if (_dietProvider == null) return;
    _dietProvider!.updateWaterIntake(quantityMl);
  }

  void addMeal(String name, int cals, double prot, double carbs, double fat, String time) {
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

  Future<void> updateProfile(String id, String name, String avatar, String color) {
    if (_profileProvider == null) return Future.value();
    return _profileProvider!.updateProfile(id, name, avatar, color);
  }

  // --- INITIALIZERS FOR DEFAULT STATE ---
  PlannerState _getDefaultState() {
    return PlannerState(
      library: [],
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
