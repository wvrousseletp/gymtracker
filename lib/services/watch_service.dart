import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/routine.dart';
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
        
        final active = _provider!.state?.activeWorkout;
        if (active != null && exerciseIndex < active.exercises.length) {
          final ex = active.exercises[exerciseIndex];
          if (setIndex < ex.setsState.length) {
            final isDone = !ex.setsState[setIndex];
            _provider!.completeSet(exerciseIndex, setIndex, isDone);
            
            // Envia de volta o estado atualizado do treino ativo
            if (_provider!.state?.activeWorkout != null) {
              sendActiveWorkout(_provider!.state!.activeWorkout!);
            }
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
