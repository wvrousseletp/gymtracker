import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker_flutter/models/planner_state.dart';
import 'package:gym_tracker_flutter/models/diet.dart';
import 'package:gym_tracker_flutter/models/workout_log.dart';

PlannerState _emptyState({ActiveWorkoutState? activeWorkout}) {
  return PlannerState(
    library: const [],
    routines: const [],
    planner: const {},
    history: const [],
    prs: const {},
    medidas: const [],
    settings: SettingsState(sound: true, vibration: true, prepSeconds: 5),
    diet: DietState(
      caloriesGoal: 2000,
      proteinGoal: 150,
      carbsGoal: 200,
      fatGoal: 70,
      waterGoalMl: 2000,
      meals: const [],
      waterIntakeMl: 0,
      fasting: FastingState(history: const []),
      abstinence: const [],
    ),
    activeWorkout: activeWorkout,
  );
}

void main() {
  group('PlannerState.copyWith', () {
    test('preserves unchanged fields', () {
      final original = _emptyState();
      final updated = original.copyWith(
        streak: WorkoutStreak(
          currentWeekCount: 2,
          consecutiveWeeks: 1,
          lastWorkoutDate: '2024-01-01',
        ),
      );

      expect(updated.library, original.library);
      expect(updated.streak.currentWeekCount, 2);
    });

    test('clears active workout', () {
      final withWorkout = _emptyState(
        activeWorkout: ActiveWorkoutState(
          name: 'Treino A',
          startTime: 1,
          exercises: const [],
          currentExerciseIndex: 0,
          elapsedSeconds: 0,
          recovery: WorkoutRecovery(sleepOk: SleepQuality.okay, pain: const [], warmUpDone: false),
          isWarmup: false,
          warmupDurationSeconds: 0,
        ),
      );

      final cleared = withWorkout.copyWith(clearActiveWorkout: true);
      expect(cleared.activeWorkout, isNull);
    });
  });
}
