import 'dart:convert';
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

  void init(TrackerProvider provider) {
    _provider = provider;
    _channel.setMethodCallHandler(_handleMethodCall);
    
    // Envia dados iniciais se houver
    sendRoutines(provider.state?.routines ?? []);
    sendLibrary(provider.state?.library ?? []);
    if (provider.state?.activeWorkout != null) {
      sendActiveWorkout(provider.state!.activeWorkout!);
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (_provider == null) return;

    switch (call.method) {
      case 'startWorkout':
        final String routineId = call.arguments as String;
        final routine = _provider!.state?.routines.firstWhere((r) => r.id == routineId);
        if (routine != null) {
          _provider!.startWorkout(routine, WorkoutRecovery(sleepOk: 'ok', pain: [], warmUpDone: false), false);
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
          _provider!.finishWorkout(duration, 5, 'Treino concluído via Apple Watch');
          _channel.invokeMethod('workoutFinished');
        }
        break;

      case 'cancelWorkout':
        _provider!.discardActiveWorkout();
        _channel.invokeMethod('workoutCancelled');
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
        print("[WatchService] Native session activated, syncing state...");
        if (_provider != null) {
          sendRoutines(_provider!.state?.routines ?? []);
          sendLibrary(_provider!.state?.library ?? []);
          if (_provider!.state?.activeWorkout != null) {
            sendActiveWorkout(_provider!.state!.activeWorkout!);
          } else {
            sendActiveWorkoutCleared();
          }
        }
        break;

      default:
        break;
    }
  }


  Future<void> sendRoutines(List<Routine> routines) async {
    try {
      final List<Map<String, dynamic>> routinesJson = routines.map((r) => r.toJson()).toList();
      await _channel.invokeMethod('updateRoutines', json.encode(routinesJson));
    } on PlatformException catch (e) {
      print("[WatchService] Erro ao enviar rotinas: $e");
    }
  }

  Future<void> sendLibrary(List<LibraryExercise> library) async {
    try {
      final List<Map<String, dynamic>> libraryJson = library.map((e) => e.toJson()).toList();
      await _channel.invokeMethod('updateLibrary', json.encode(libraryJson));
    } on PlatformException catch (e) {
      print("[WatchService] Erro ao enviar biblioteca: $e");
    }
  }

  Future<void> sendActiveWorkout(ActiveWorkoutState activeWorkout) async {
    try {
      await _channel.invokeMethod('updateActiveWorkout', json.encode(activeWorkout.toJson()));
    } on PlatformException catch (e) {
      print("[WatchService] Erro ao enviar treino ativo: $e");
    }
  }

  Future<void> sendActiveWorkoutCleared() async {
    try {
      await _channel.invokeMethod('clearActiveWorkout');
    } on PlatformException catch (e) {
      print("[WatchService] Erro ao limpar treino ativo no watch: $e");
    }
  }
}
