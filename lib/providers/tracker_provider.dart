import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/profile.dart';
import '../models/exercise.dart';
import '../models/routine.dart';
import '../models/workout_log.dart';
import '../models/medidas.dart';
import '../models/diet.dart';
import '../models/planner_state.dart';
import '../services/watch_service.dart';

class TrackerProvider extends ChangeNotifier {
  List<Profile> _profiles = [];
  String _currentUserId = 'vicente';
  PlannerState? _state;
  bool _isLoading = true;

  List<Profile> get profiles => _profiles;
  String get currentUserId => _currentUserId;
  PlannerState? get state => _state;
  bool get isLoading => _isLoading;

  Profile get currentProfile => _profiles.firstWhere(
        (p) => p.id == _currentUserId,
        orElse: () => Profile(
          id: 'vicente',
          name: 'Vicente',
          avatar: '🏋️',
          colorAccent: 'Branco',
          password: '',
          hasPassword: false,
        ),
      );

  TrackerProvider() {
    _init();
  }

  Future<void> _init() async {
    await loadProfiles();
    await loadCurrentState();
    WatchService.instance.init(this);
    _isLoading = false;
    notifyListeners();
  }

  // --- PROFILE MANAGEMENT ---
  Future<void> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesRaw = prefs.getString('los_mooscles_profiles_config');
    
    if (profilesRaw != null) {
      try {
        final parsed = json.decode(profilesRaw);
        if (parsed['profiles'] != null) {
          _profiles = (parsed['profiles'] as List)
              .map((p) => Profile.fromJson(p))
              .toList();
        }
        _currentUserId = parsed['currentUserId'] ?? 'vicente';
      } catch (e) {
        _profiles = _getDefaultProfiles();
        _currentUserId = 'vicente';
      }
    } else {
      _profiles = _getDefaultProfiles();
      _currentUserId = 'vicente';
    }
    
    if (_profiles.isEmpty) {
      _profiles = _getDefaultProfiles();
    }
  }

  Future<void> saveProfilesConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final config = {
      'profiles': _profiles.map((p) => p.toJson()).toList(),
      'currentUserId': _currentUserId,
    };
    await prefs.setString('los_mooscles_profiles_config', json.encode(config));
  }

  Future<bool> switchProfile(String profileId, String password) async {
    final target = _profiles.firstWhere((p) => p.id == profileId);
    if (target.hasPassword && target.password != password) {
      return false; // Senha incorreta
    }
    _currentUserId = profileId;
    await saveProfilesConfig();
    _isLoading = true;
    notifyListeners();
    await loadCurrentState();
    _isLoading = false;
    notifyListeners();
    return true;
  }

  String generateProfileId(String name) {
    return name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  Future<void> createProfile(String name, String avatar, String color, String password) async {
    final id = generateProfileId(name);
    final newProfile = Profile(
      id: id,
      name: name,
      avatar: avatar,
      colorAccent: color,
      password: password,
      hasPassword: password.isNotEmpty,
    );
    _profiles.add(newProfile);
    _currentUserId = id;
    await saveProfilesConfig();
    _state = _getDefaultState();
    await saveState(); // This will trigger syncStateWithFirebase which uploads the profile config
    notifyListeners();
  }

  Future<void> updateProfile(String id, String name, String avatar, String color, String password) async {
    final idx = _profiles.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _profiles[idx] = Profile(
        id: id,
        name: name,
        avatar: avatar,
        colorAccent: color,
        password: password,
        hasPassword: password.isNotEmpty,
      );
      await saveProfilesConfig();
      
      // Update in Firebase as well
      try {
        final docRef = FirebaseFirestore.instance.collection('users').doc(id);
        await docRef.update({
          'profile': _profiles[idx].toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('[Firebase] Erro ao atualizar perfil na nuvem: $e');
      }
      notifyListeners();
    }
  }

  Future<void> deleteProfile(String id) async {
    if (_profiles.length <= 1 || _currentUserId == id) return;
    _profiles.removeWhere((p) => p.id == id);
    await saveProfilesConfig();
    
    // Deleta do Firebase se necessário
    try {
      FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .delete();
    } catch (e) {
      // Ignora erro se estiver offline ou sem Firebase
    }
    notifyListeners();
  }

  // --- STATE PERSISTENCE (SHAPED STATE) ---
  Future<void> loadCurrentState() async {
    final prefs = await SharedPreferences.getInstance();
    final stateRaw = prefs.getString('shapeup_tracker_state_$_currentUserId');
    
    if (stateRaw != null) {
      try {
        _state = PlannerState.fromJson(json.decode(stateRaw));
      } catch (e) {
        _state = _getDefaultState();
      }
    } else {
      _state = _getDefaultState();
    }
    
    // Tenta sincronizar com o Firebase
    syncStateWithFirebase();
  }

  Future<void> saveState() async {
    if (_state == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'shapeup_tracker_state_$_currentUserId', 
      json.encode(_state!.toJson())
    );
    
    // Sincroniza com o Apple Watch via Bluetooth
    WatchService.instance.sendRoutines(_state!.routines);
    WatchService.instance.sendLibrary(_state!.library);
    WatchService.instance.sendPlanner(_state!.planner);
    if (_state!.activeWorkout != null) {
      WatchService.instance.sendActiveWorkout(_state!.activeWorkout!);
    } else {
      WatchService.instance.sendActiveWorkoutCleared();
    }
    
    // Sincroniza widgets locais do iOS
    WatchService.instance.syncWidgetData();
    
    // Sincroniza em segundo plano
    syncStateWithFirebase();
  }

  // --- FIREBASE CLOUD MANAGEMENT ---
  Future<Map<String, dynamic>?> checkProfileExistsInCloud(String profileId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(profileId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['profile'] != null) {
          return Map<String, dynamic>.from(data['profile']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> importProfileFromCloud(String profileId, String password) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(profileId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) return false;
      
      final data = docSnap.data();
      if (data == null) return false;
      
      // Checa a senha do perfil remoto
      if (data['profile'] != null) {
        final remoteProfile = Profile.fromJson(data['profile']);
        
        if (remoteProfile.hasPassword && remoteProfile.password != password) {
          return false; // Senha incorreta
        }
        
        // Adiciona à lista local se não existir
        if (!_profiles.any((p) => p.id == remoteProfile.id)) {
          _profiles.add(remoteProfile);
        }
        _currentUserId = remoteProfile.id;
        await saveProfilesConfig();
        
        // Carrega o estado e salva localmente
        if (data['jsonState'] != null) {
          _state = PlannerState.fromJson(json.decode(data['jsonState']));
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'shapeup_tracker_state_$_currentUserId', 
            json.encode(_state!.toJson())
          );
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Firebase] Erro ao importar perfil: $e');
      return false;
    }
  }

  // --- FIREBASE SYNC ---
  Future<void> syncStateWithFirebase() async {
    if (_state == null) return;
    
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(_currentUserId);
      final docSnap = await docRef.get();
      
      if (docSnap.exists) {
        final data = docSnap.data();
        if (data != null && data['jsonState'] != null) {
          final remoteState = PlannerState.fromJson(json.decode(data['jsonState']));
          
          if (_state!.history.length >= remoteState.history.length) {
            await docRef.set({
              'jsonState': json.encode(_state!.toJson()),
              'profile': currentProfile.toJson(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            _state = remoteState;
            notifyListeners();
            // Salva localmente
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              'shapeup_tracker_state_$_currentUserId', 
              json.encode(_state!.toJson())
            );
            
            // Também sincroniza as informações de perfil localmente se vierem da nuvem
            if (data['profile'] != null) {
              final remoteProfile = Profile.fromJson(data['profile']);
              final idx = _profiles.indexWhere((p) => p.id == remoteProfile.id);
              if (idx != -1) {
                _profiles[idx] = remoteProfile;
                await saveProfilesConfig();
              }
            }
          }
        }
      } else {
        // Envia dados locais se não houver dados remotos
        await docRef.set({
          'jsonState': json.encode(_state!.toJson()),
          'profile': currentProfile.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Ignora falhas de conexão de rede ou Firebase não configurado
      debugPrint('[Firebase] Erro de sincronização: $e');
    }
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

    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: activeWorkout,
      diet: _state!.diet,
    );

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

    final updatedWorkout = ActiveWorkoutState(
      name: active.name,
      startTime: active.startTime,
      exercises: exercises,
      currentExerciseIndex: computedExIndex,
      elapsedSeconds: active.elapsedSeconds,
      recovery: active.recovery,
      isWarmup: active.isWarmup,
      warmupDurationSeconds: active.warmupDurationSeconds,
      paused: active.paused,
      restTimer: computedRestTimer,
    );

    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: updatedWorkout,
      diet: _state!.diet,
    );

    saveState();
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

    final updatedWorkout = ActiveWorkoutState(
      name: active.name,
      startTime: active.startTime,
      exercises: active.exercises,
      currentExerciseIndex: active.currentExerciseIndex,
      elapsedSeconds: active.elapsedSeconds,
      recovery: active.recovery,
      isWarmup: active.isWarmup,
      warmupDurationSeconds: active.warmupDurationSeconds,
      paused: active.paused,
      restTimer: restTimer,
    );

    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: updatedWorkout,
      diet: _state!.diet,
    );

    saveState();
    notifyListeners();
  }

  void clearRestTimer() {
    if (_state == null || _state!.activeWorkout == null) return;
    final active = _state!.activeWorkout!;

    final updatedWorkout = ActiveWorkoutState(
      name: active.name,
      startTime: active.startTime,
      exercises: active.exercises,
      currentExerciseIndex: active.currentExerciseIndex,
      elapsedSeconds: active.elapsedSeconds,
      recovery: active.recovery,
      isWarmup: active.isWarmup,
      warmupDurationSeconds: active.warmupDurationSeconds,
      paused: active.paused,
      restTimer: null,
    );

    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: updatedWorkout,
      diet: _state!.diet,
    );

    saveState();
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
      setsState: ex.setsState,
      performedCardios: ex.performedCardios,
      failureReport: ex.failureReport,
    );

    final updatedWorkout = ActiveWorkoutState(
      name: active.name,
      startTime: active.startTime,
      exercises: exercises,
      currentExerciseIndex: active.currentExerciseIndex,
      elapsedSeconds: active.elapsedSeconds,
      recovery: active.recovery,
      isWarmup: active.isWarmup,
      warmupDurationSeconds: active.warmupDurationSeconds,
      paused: active.paused,
      restTimer: active.restTimer,
    );

    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: updatedWorkout,
      diet: _state!.diet,
    );

    saveState();
    notifyListeners();
  }

  void updateWorkoutTimer(int seconds, {bool isWarmupTimer = false}) {
    if (_state == null || _state!.activeWorkout == null) return;
    final active = _state!.activeWorkout!;

    final updatedWorkout = ActiveWorkoutState(
      name: active.name,
      startTime: active.startTime,
      exercises: active.exercises,
      currentExerciseIndex: active.currentExerciseIndex,
      elapsedSeconds: isWarmupTimer ? active.elapsedSeconds : seconds,
      recovery: active.recovery,
      isWarmup: active.isWarmup,
      warmupDurationSeconds: isWarmupTimer ? seconds : active.warmupDurationSeconds,
      paused: active.paused,
    );

    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: updatedWorkout,
      diet: _state!.diet,
    );
    // notifyListeners(); // Otimizado: evita reconstrução de todo o app a cada segundo.

    // Sincroniza com o Apple Watch a cada 5 segundos para manter timer atualizado no relógio
    if (!isWarmupTimer && seconds % 5 == 0) {
      WatchService.instance.sendActiveWorkout(updatedWorkout);
    }
  }

  void setCurrentExerciseIndex(int index) {
    if (_state == null || _state!.activeWorkout == null) return;
    final active = _state!.activeWorkout!;

    final updatedWorkout = ActiveWorkoutState(
      name: active.name,
      startTime: active.startTime,
      exercises: active.exercises,
      currentExerciseIndex: index,
      elapsedSeconds: active.elapsedSeconds,
      recovery: active.recovery,
      isWarmup: active.isWarmup,
      warmupDurationSeconds: active.warmupDurationSeconds,
      paused: active.paused,
    );

    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: updatedWorkout,
      diet: _state!.diet,
    );
    saveState();
    notifyListeners();
  }

  void pauseWorkout(bool isPaused) {
    if (_state == null || _state!.activeWorkout == null) return;
    final active = _state!.activeWorkout!;

    final updatedWorkout = ActiveWorkoutState(
      name: active.name,
      startTime: active.startTime,
      exercises: active.exercises,
      currentExerciseIndex: active.currentExerciseIndex,
      elapsedSeconds: active.elapsedSeconds,
      recovery: active.recovery,
      isWarmup: active.isWarmup,
      warmupDurationSeconds: active.warmupDurationSeconds,
      paused: isPaused,
    );

    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: updatedWorkout,
      diet: _state!.diet,
    );
    // Notifica o Apple Watch imediatamente sobre pausa/retomada
    WatchService.instance.sendActiveWorkout(updatedWorkout);
    saveState();
    notifyListeners();
  }


  void discardActiveWorkout() {
    if (_state == null) return;
    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: null,
      diet: _state!.diet,
    );
    saveState();
    notifyListeners();
  }

  void postponeActiveWorkout() {
    if (_state == null || _state!.activeWorkout == null) return;
    final active = _state!.activeWorkout!;
    final updated = ActiveWorkoutState(
      name: active.name,
      startTime: active.startTime,
      exercises: active.exercises,
      currentExerciseIndex: active.currentExerciseIndex,
      elapsedSeconds: active.elapsedSeconds,
      recovery: active.recovery,
      isWarmup: active.isWarmup,
      warmupDurationSeconds: active.warmupDurationSeconds,
      paused: true,
      restTimer: active.restTimer,
      postponed: true,
    );
    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: updated,
      diet: _state!.diet,
    );
    saveState();
    notifyListeners();
  }

  void resumeActiveWorkout() {
    if (_state == null || _state!.activeWorkout == null) return;
    final active = _state!.activeWorkout!;
    final updated = ActiveWorkoutState(
      name: active.name,
      startTime: DateTime.now().millisecondsSinceEpoch - (active.elapsedSeconds * 1000),
      exercises: active.exercises,
      currentExerciseIndex: active.currentExerciseIndex,
      elapsedSeconds: active.elapsedSeconds,
      recovery: active.recovery,
      isWarmup: active.isWarmup,
      warmupDurationSeconds: active.warmupDurationSeconds,
      paused: false,
      restTimer: active.restTimer,
      postponed: false,
    );
    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: updated,
      diet: _state!.diet,
    );
    saveState();
    notifyListeners();
  }

  void finishWorkout(int duration, int rpeValue, String notes) {
    if (_state == null || _state!.activeWorkout == null) return;

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
    );

    final List<WorkoutLog> newHistory = List.from(_state!.history)..insert(0, log);

    // Atualiza Recordes Pessoais (PRs)
    final Map<String, PersonalRecord> newPrs = Map.from(_state!.prs);
    final List<String> prExerciseNames = [];
    active.exercises.forEach((ex) {
      final done = ex.setsState.where((s) => s).length;
      if (done == 0) return;

      final isCardio = ex.muscle.toLowerCase().contains('cardio');
      double prWeight = ex.weight;
      int prReps = ex.reps;

      if (isCardio) {
        final completedList = ex.performedCardios.where((c) => c != null).toList();
        if (completedList.isNotEmpty) {
          var maxCardio = completedList[0]!;
          completedList.forEach((p) {
            if (p!.distanceKm > maxCardio.distanceKm) {
              maxCardio = p;
            }
          });
          prWeight = maxCardio.distanceKm;
          prReps = maxCardio.durationSeconds ~/ 60;
        } else {
          return; // Sem cardio feito
        }
      }

      // Procura ID correspondente na biblioteca
      final libEx = _state!.library.firstWhere((l) => l.name == ex.name, orElse: () => LibraryExercise(id: '', name: '', muscle: '', measurementType: ''));
      if (libEx.id.isEmpty) return;

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
    });

    // Envia celebração de PR para o Apple Watch
    if (prExerciseNames.isNotEmpty) {
      WatchService.instance.sendPrCelebration(prExerciseNames);
    }

    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: newHistory,
      prs: newPrs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: null,
      diet: _state!.diet,
    );

    _updateStreak();
    saveState();
    notifyListeners();
  }

  void addManualWorkoutLog(WorkoutLog log) {
    if (_state == null) return;
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

    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: newHistory,
      prs: newPrs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: _state!.diet,
    );
    _updateStreak();
    saveState();
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

    // Conta treinos nesta semana
    int currentWeekCount = 0;
    final Set<String> datesThisWeek = {};
    for (final log in history) {
      try {
        final logDate = DateTime.parse(log.date).toLocal();
        if (!logDate.isBefore(thisWeekStart)) {
          final dayKey = '${logDate.year}-${logDate.month}-${logDate.day}';
          datesThisWeek.add(dayKey);
          currentWeekCount++;
        }
      } catch (_) {}
    }

    // Conta semanas consecutivas (incluindo semana atual se houver treino)
    int consecutiveWeeks = 0;
    final Set<String> weeksWithWorkout = {};
    for (final log in history) {
      try {
        final logDate = DateTime.parse(log.date).toLocal();
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

    final lastDate = history.isNotEmpty ? history.first.date : '';
    final newStreak = WorkoutStreak(
      currentWeekCount: currentWeekCount,
      consecutiveWeeks: consecutiveWeeks,
      lastWorkoutDate: lastDate,
    );

    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: _state!.diet,
      streak: newStreak,
    );

    WatchService.instance.sendStreak(newStreak);
  }

  // --- WEEKLY PLANNER ACTIONS ---
  void addPlannerItem(String day) {
    if (_state == null) return;
    final planner = Map<String, List<String>>.from(_state!.planner);
    planner[day] = List<String>.from(planner[day] ?? [])..add("");
    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: _state!.diet,
    );
    saveState();
    notifyListeners();
  }

  void updatePlannerItem(String day, int index, String value) {
    if (_state == null) return;
    final planner = Map<String, List<String>>.from(_state!.planner);
    planner[day] = List<String>.from(planner[day] ?? []);
    planner[day]![index] = value;
    
    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: _state!.diet,
    );
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

    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: _state!.diet,
    );
    saveState();
    notifyListeners();
  }

  void removePlannerItem(String day, int index) {
    if (_state == null) return;
    final planner = Map<String, List<String>>.from(_state!.planner);
    planner[day] = List<String>.from(planner[day] ?? [])..removeAt(index);
    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: _state!.diet,
    );
    saveState();
    notifyListeners();
  }

  void deletePersonalRecord(String exerciseId) {
    if (_state == null) return;
    final Map<String, PersonalRecord> newPrs = Map.from(_state!.prs);
    newPrs.remove(exerciseId);
    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: newPrs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: _state!.diet,
    );
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
    _state = PlannerState(
      library: library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: _state!.diet,
    );
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
      _state = PlannerState(
        library: library,
        routines: _state!.routines,
        planner: _state!.planner,
        history: _state!.history,
        prs: _state!.prs,
        medidas: _state!.medidas,
        settings: _state!.settings,
        activeWorkout: _state!.activeWorkout,
        diet: _state!.diet,
      );
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

    _state = PlannerState(
      library: library,
      routines: routines,
      planner: planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: _state!.diet,
    );
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
    _state = PlannerState(
      library: _state!.library,
      routines: routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: _state!.diet,
    );
    saveState();
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

    _state = PlannerState(
      library: _state!.library,
      routines: routines,
      planner: planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: _state!.diet,
    );
    saveState();
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

    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: list,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: _state!.diet,
    );
    saveState();
    notifyListeners();
  }

  void deleteMeasurement(String id) {
    if (_state == null) return;
    final list = List<BodyMeasurement>.from(_state!.medidas)..removeWhere((m) => m.id == id);
    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: list,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: _state!.diet,
    );
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
    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: newSettings,
      activeWorkout: _state!.activeWorkout,
      diet: _state!.diet,
    );
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

    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: newDiet,
    );
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

    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: newDiet,
    );
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

    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: newDiet,
    );
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

    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: newDiet,
    );
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

    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: newDiet,
    );
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
    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: newDiet,
    );
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
    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: newDiet,
    );
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
    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: newDiet,
    );
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
    _state = PlannerState(
      library: _state!.library,
      routines: _state!.routines,
      planner: _state!.planner,
      history: _state!.history,
      prs: _state!.prs,
      medidas: _state!.medidas,
      settings: _state!.settings,
      activeWorkout: _state!.activeWorkout,
      diet: newDiet,
    );
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

  List<Profile> _getDefaultProfiles() {
    return [
      Profile(id: "vicente", name: "Vicente", password: "", colorAccent: "Branco", avatar: "🏋️", hasPassword: false),
      Profile(id: "davi", name: "Davi", password: "", colorAccent: "Azul", avatar: "⚡", hasPassword: false),
      Profile(id: "ana", name: "Ana", password: "", colorAccent: "Vermelho", avatar: "✨", hasPassword: false),
    ];
  }
}
