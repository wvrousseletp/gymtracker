import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/routine.dart';
import '../models/exercise.dart';
import '../models/planner_state.dart';
import '../models/workout_log.dart';
import '../providers/tracker_provider.dart';

class WatchService {
  static final WatchService instance = WatchService._internal();
  WatchService._internal();

  final MethodChannel _channel = const MethodChannel('com.vicente.losmooscles/watch');
  TrackerProvider? _provider;

  String? _lastSentRoutinesJson;
  String? _lastSentLibraryJson;
  String? _lastSentPlannerJson;
  String? _lastSentActiveWorkoutJson;

  /// Called when native side sends 'navigateToWorkout' (e.g. user tapped rest timer notification)
  VoidCallback? onNavigateToWorkout;

  void init(TrackerProvider provider) {
    _provider = provider;
    _channel.setMethodCallHandler(_handleMethodCall);
    
    // Envia dados iniciais se houver
    sendRoutines(provider.state?.routines ?? []);
    sendLibrary(provider.state?.library ?? []);
    sendPlanner(provider.state?.planner ?? {});
    if (provider.state?.activeWorkout != null) {
      sendActiveWorkout(provider.state!.activeWorkout!);
    }
    syncWidgetData();
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (_provider == null) return;

    switch (call.method) {
      case 'skipRestTimer':
        _provider!.clearRestTimer();
        break;

      case 'startWorkout':
        String routineId;
        List? customExercisesJson;
        if (call.arguments is Map) {
          routineId = call.arguments['routineId'] as String;
          customExercisesJson = call.arguments['customExercises'] as List?;
        } else {
          routineId = call.arguments as String;
        }

        final baseRoutine = _provider!.state?.routines.firstWhere((r) => r.id == routineId);
        if (baseRoutine != null) {
          Routine routineToStart = baseRoutine;
          if (customExercisesJson != null) {
            final List<RoutineExercise> customExList = [];
            for (var item in customExercisesJson) {
              final String exId = item['exerciseId'] as String;
              final int sets = (item['sets'] as num).toInt();
              final int reps = (item['reps'] as num).toInt();
              final double weight = (item['weight'] as num).toDouble();
              
              final orig = baseRoutine.exercises.firstWhere(
                (e) => e.exerciseId == exId,
                orElse: () => baseRoutine.exercises.first,
              );
              customExList.add(RoutineExercise(
                id: orig.id,
                exerciseId: exId,
                sets: sets,
                reps: reps,
                rest: orig.rest,
                weight: weight,
              ));
            }
            routineToStart = Routine(
              id: baseRoutine.id,
              name: baseRoutine.name,
              defaultRest: baseRoutine.defaultRest,
              exercises: customExList,
              isDynamicExercise: baseRoutine.isDynamicExercise,
            );
          }
          
          _provider!.startWorkout(routineToStart, WorkoutRecovery(sleepOk: 'ok', pain: [], warmUpDone: false), false);
          // Envia de volta o estado atualizado do treino ativo
          if (_provider!.state?.activeWorkout != null) {
            sendActiveWorkout(_provider!.state!.activeWorkout!);
          }
        }
        break;

      case 'toggleSet':
        final int exerciseIndex = call.arguments['exerciseIndex'] as int;
        final int setIndex = call.arguments['setIndex'] as int;
        final bool isDone = call.arguments['isDone'] as bool;
        final bool isFailure = call.arguments['isFailure'] as bool? ?? false;
        final int? failureRep = call.arguments['failureRep'] as int?;
        final double? distance = (call.arguments['distance'] as num?)?.toDouble();
        final int? duration = call.arguments['duration'] as int?;
        
        _provider!.completeSet(
          exerciseIndex,
          setIndex,
          isDone,
          distance: distance,
          duration: duration,
          isFailure: isFailure,
          failureRep: failureRep,
        );
        
        // Envia de volta o estado atualizado do treino ativo
        if (_provider!.state?.activeWorkout != null) {
          sendActiveWorkout(_provider!.state!.activeWorkout!);
        }
        break;

      case 'updateCardio':
        final int exerciseIndex = call.arguments['exerciseIndex'] as int;
        final int setIndex = call.arguments['setIndex'] as int;
        final double distance = (call.arguments['distance'] as num).toDouble();
        final int duration = call.arguments['duration'] as int;
        
        final active = _provider!.state?.activeWorkout;
        if (active != null && exerciseIndex < active.exercises.length) {
          final ex = active.exercises[exerciseIndex];
          if (setIndex < ex.setsState.length) {
            _provider!.completeSet(
              exerciseIndex,
              setIndex,
              ex.setsState[setIndex],
              distance: distance,
              duration: duration,
              isFailure: ex.failureReport[setIndex],
              failureRep: ex.failureReps[setIndex],
            );
            if (_provider!.state?.activeWorkout != null) {
              sendActiveWorkout(_provider!.state!.activeWorkout!);
            }
          }
        }
        break;

      case 'updateFailure':
        final int exerciseIndex = call.arguments['exerciseIndex'] as int;
        final int setIndex = call.arguments['setIndex'] as int;
        final bool isFailure = call.arguments['isFailure'] as bool;
        final int? failureRep = call.arguments['failureRep'] as int?;
        
        final active = _provider!.state?.activeWorkout;
        if (active != null && exerciseIndex < active.exercises.length) {
          final ex = active.exercises[exerciseIndex];
          if (setIndex < ex.setsState.length) {
            final pc = setIndex < ex.performedCardios.length ? ex.performedCardios[setIndex] : null;
            _provider!.completeSet(
              exerciseIndex,
              setIndex,
              ex.setsState[setIndex],
              distance: pc?.distanceKm,
              duration: pc?.durationSeconds,
              isFailure: isFailure,
              failureRep: failureRep,
            );
            if (_provider!.state?.activeWorkout != null) {
              sendActiveWorkout(_provider!.state!.activeWorkout!);
            }
          }
        }
        break;

      case 'skipRest':
        _provider!.clearRestTimer();
        // Envia estado atualizado após pular descanso
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_provider!.state?.activeWorkout != null) {
            sendActiveWorkout(_provider!.state!.activeWorkout!);
          }
        });
        break;

      case 'updateExerciseWeightReps':
        final int exerciseIndex = call.arguments['exerciseIndex'] as int;
        final double weight = (call.arguments['weight'] as num).toDouble();
        final int reps = call.arguments['reps'] as int;
        _provider!.updateExerciseWeightReps(exerciseIndex, weight, reps);
        // Envia estado atualizado após alterar carga/reps
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_provider!.state?.activeWorkout != null) {
            sendActiveWorkout(_provider!.state!.activeWorkout!);
          }
        });
        break;

      case 'startSingleExercise':
        final String exerciseId = call.arguments as String;
        final exercise = _provider!.state?.library.firstWhere((e) => e.id == exerciseId);
        if (exercise != null) {
          _provider!.startSingleExercise(exercise);
          if (_provider!.state?.activeWorkout != null) {
            sendActiveWorkout(_provider!.state!.activeWorkout!);
          }
        }
        break;

      case 'completeWorkout':
        final active = _provider!.state?.activeWorkout;
        if (active != null) {
          final duration = active.elapsedSeconds;
          final args = call.arguments;
          int rpe = 7;
          String notes = 'Treino concluído via Apple Watch';
          if (args is Map) {
            rpe = (args['rpe'] as num?)?.toInt() ?? rpe;
            notes = args['notes'] as String? ?? notes;
          }
          _provider!.finishWorkout(duration, rpe, notes);
          _channel.invokeMethod('workoutFinished');
        }
        break;

      case 'cancelWorkout':
        _provider!.discardActiveWorkout();
        _channel.invokeMethod('workoutCancelled');
        break;

      case 'postponeWorkout':
        _provider!.postponeActiveWorkout();
        _channel.invokeMethod('workoutPostponed');
        break;

      case 'resumeWorkout':
        _provider!.resumeActiveWorkout();
        _channel.invokeMethod('workoutResumed');
        break;

      case 'togglePause':
        final bool isPaused = call.arguments as bool;
        _provider!.pauseWorkout(isPaused);
        // Envia estado atualizado ao watch imediatamente
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_provider!.state?.activeWorkout != null) {
            sendActiveWorkout(_provider!.state!.activeWorkout!);
          }
        });
        break;

      case 'sessionActivated':
        debugPrint("[WatchService] Native session activated, syncing state...");
        if (_provider != null) {
          sendRoutines(_provider!.state?.routines ?? []);
          sendLibrary(_provider!.state?.library ?? []);
          sendPlanner(_provider!.state?.planner ?? {});
          if (_provider!.state?.activeWorkout != null) {
            sendActiveWorkout(_provider!.state!.activeWorkout!);
          } else {
            sendActiveWorkoutCleared();
          }
          
          // Envia dados de água para o Watch
          sendWaterData(
            _provider!.state?.diet.waterIntakeMl ?? 0,
            _provider!.state?.diet.waterGoalMl ?? 2000,
          );
        }
        break;

      case 'syncOfflineWorkout':
        final Map<String, dynamic> workoutData = Map<String, dynamic>.from(call.arguments as Map);
        try {
          final log = WorkoutLog.fromJson(workoutData);
          _provider!.addManualWorkoutLog(log);
          debugPrint("[WatchService] Synced offline workout from watch: ${log.name}");
          final workoutId = workoutData['id'] as String?;
          if (workoutId != null && workoutId.isNotEmpty) {
            await _channel.invokeMethod('ackOfflineWorkout', workoutId);
          }
        } catch (e) {
          debugPrint("[WatchService] Erro ao processar treino offline: $e");
        }
        break;

      case 'updateWaterIntake':
        final int currentWater = call.arguments as int;
        _provider?.updateWaterIntake(currentWater);
        break;

      case 'changeExercise':
        final int exerciseIndex = call.arguments as int;
        _provider!.setCurrentExerciseIndex(exerciseIndex);
        if (_provider!.state?.activeWorkout != null) {
          sendActiveWorkout(_provider!.state!.activeWorkout!);
        }
        break;

      case 'updateHealthMetrics':
        final int heartRate = (call.arguments['heartRate'] as num).toInt();
        final int activeCalories = (call.arguments['activeCalories'] as num).toInt();
        _provider!.updateHealthMetrics(heartRate, activeCalories);
        break;

      case 'navigateToWorkout':
        // Called by native iOS when user taps the rest timer notification
        onNavigateToWorkout?.call();
        break;


      case 'updateActiveWorkoutFromWatch':
        // The Watch pushed its in-progress workout state to iOS.
        // Apply it so the iOS side can mirror/reconcile the workout.
        final String workoutJson = call.arguments as String;
        try {
          final Map<String, dynamic> watchData = Map<String, dynamic>.from(
              json.decode(workoutJson) as Map);
          _provider!.applyActiveWorkoutFromWatch(watchData);
          if (_provider!.state?.activeWorkout != null) {
            sendActiveWorkout(_provider!.state!.activeWorkout!);
          }
        } catch (e) {
          debugPrint('[WatchService] Error applying active workout from Watch: $e');
        }
        break;

      default:
        break;
    }
  }



  Future<void> sendRoutines(List<Routine> routines) async {
    try {
      final List<Map<String, dynamic>> routinesJson = routines.map((r) => r.toJson()).toList();
      final serialized = json.encode(routinesJson);
      if (serialized == _lastSentRoutinesJson) return;
      _lastSentRoutinesJson = serialized;
      await _channel.invokeMethod('updateRoutines', serialized);
    } on PlatformException catch (e) {
      debugPrint("[WatchService] Erro ao enviar rotinas: $e");
    }
  }

  Future<void> sendLibrary(List<LibraryExercise> library) async {
    try {
      final List<Map<String, dynamic>> libraryJson = library.map((e) => e.toJson()).toList();
      final serialized = json.encode(libraryJson);
      if (serialized == _lastSentLibraryJson) return;
      _lastSentLibraryJson = serialized;
      await _channel.invokeMethod('updateLibrary', serialized);
    } on PlatformException catch (e) {
      debugPrint("[WatchService] Erro ao enviar biblioteca: $e");
    }
  }

  Future<void> sendActiveWorkout(ActiveWorkoutState activeWorkout) async {
    try {
      final jsonMap = activeWorkout.toJson();
      final structureMap = Map<String, dynamic>.from(jsonMap)
        ..remove('elapsedSeconds')
        ..remove('warmupDurationSeconds')
        ..remove('heartRate')
        ..remove('activeCalories');
      final serializedStructure = json.encode(structureMap);

      if (serializedStructure == _lastSentActiveWorkoutJson) {
        return; // Skip if identical structure
      }
      _lastSentActiveWorkoutJson = serializedStructure;
      await _channel.invokeMethod('updateActiveWorkout', json.encode(jsonMap));
    } on PlatformException catch (e) {
      debugPrint("[WatchService] Erro ao enviar treino ativo: $e");
    }
  }

  Future<void> sendActiveWorkoutCleared() async {
    try {
      _lastSentActiveWorkoutJson = null;
      await _channel.invokeMethod('clearActiveWorkout');
    } on PlatformException catch (e) {
      debugPrint("[WatchService] Erro ao limpar treino ativo no watch: $e");
    }
  }

  Future<void> sendPlanner(Map<String, List<String>> planner) async {
    try {
      final serialized = json.encode(planner);
      if (serialized == _lastSentPlannerJson) return;
      _lastSentPlannerJson = serialized;
      await _channel.invokeMethod('updatePlanner', serialized);
    } on PlatformException catch (e) {
      debugPrint("[WatchService] Erro ao enviar planner: $e");
    }
  }

  Future<void> syncWidgetData() async {
    try {
      final state = _provider?.state;
      if (state == null) return;
      
      // Calculate today's routine
      final calendar = DateTime.now();
      final weekday = calendar.weekday;
      final String todayKey;
      switch (weekday) {
        case 7: todayKey = "dom"; break;
        case 1: todayKey = "seg"; break;
        case 2: todayKey = "ter"; break;
        case 3: todayKey = "qua"; break;
        case 4: todayKey = "qui"; break;
        case 5: todayKey = "sex"; break;
        case 6: todayKey = "sab"; break;
        default: todayKey = "seg";
      }
      
      final plannedIds = state.planner[todayKey] ?? [];
      final todayRoutines = state.routines.where((r) => plannedIds.contains(r.id) || plannedIds.contains("routine:${r.id}")).toList();
      
      final String todayRoutineName = todayRoutines.isNotEmpty ? todayRoutines.first.name : "Nenhum treino planejado";
      final int todayRoutineExerciseCount = todayRoutines.isNotEmpty ? todayRoutines.first.exercises.length : 0;
      final List<String> todayRoutineExercises = todayRoutines.isNotEmpty 
          ? todayRoutines.first.exercises.map<String>((e) {
              final libEx = state.library.firstWhere(
                (l) => l.id == e.exerciseId,
                orElse: () => LibraryExercise(id: '', name: 'Exercício', muscle: '', measurementType: ''),
              );
              return libEx.name;
            }).toList() 
          : [];
      
      final int waterIntakeCurrent = state.diet.waterIntakeMl;
      final int waterIntakeTarget = state.diet.waterGoalMl;
      
      await _channel.invokeMethod('updateWidgetData', {
        'todayRoutineName': todayRoutineName,
        'todayRoutineExerciseCount': todayRoutineExerciseCount,
        'todayRoutineExercises': todayRoutineExercises,
        'waterIntakeCurrent': waterIntakeCurrent,
        'waterIntakeTarget': waterIntakeTarget,
      });
    } on PlatformException catch (e) {
      debugPrint("[WatchService] Erro ao sincronizar widgets: $e");
    }
  }

  Future<void> sendPrCelebration(List<String> exerciseNames) async {
    try {
      await _channel.invokeMethod('prCelebration', exerciseNames);
    } on PlatformException catch (e) {
      debugPrint("[WatchService] Erro ao enviar celebração de PR: $e");
    }
  }

  Future<void> sendStreak(WorkoutStreak streak) async {
    try {
      await _channel.invokeMethod('updateStreak', streak.toJson());
    } on PlatformException catch (e) {
      debugPrint("[WatchService] Erro ao enviar streak: $e");
    }
  }

  Future<int?> getSharedWaterIntake() async {
    try {
      final int? value = await _channel.invokeMethod<int>('getSharedWaterIntake');
      return value;
    } on PlatformException catch (e) {
      debugPrint("[WatchService] Erro ao buscar ingestão de água compartilhada: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSharedActiveWorkout() async {
    try {
      final Map? res = await _channel.invokeMethod<Map>('getSharedActiveWorkout');
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint("[WatchService] Erro ao buscar treino compartilhado: $e");
      return null;
    }
  }

  Future<void> sendWaterData(int current, int target) async {
    try {
      await _channel.invokeMethod('updateWidgetData', {
        'waterIntakeCurrent': current,
        'waterIntakeTarget': target,
      });
    } on PlatformException catch (e) {
      debugPrint("[WatchService] Erro ao enviar dados de água para o Watch: $e");
    }
  }
}
