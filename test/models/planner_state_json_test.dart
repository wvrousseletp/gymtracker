import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker_flutter/models/planner_state.dart';
import 'package:gym_tracker_flutter/models/diet.dart';

void main() {
  test('PlannerState serializes and deserializes streak', () {
    final state = PlannerState(
      library: const [],
      routines: const [],
      planner: const {'seg': ['routine:1']},
      history: const [],
      prs: const {},
        exerciseNotes: const {},
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
      streak: WorkoutStreak(
        currentWeekCount: 3,
        consecutiveWeeks: 2,
        lastWorkoutDate: '2024-06-01T00:00:00.000Z',
        weekdaysTrained: const [1, 3, 5],
      ),
    );

    final restored = PlannerState.fromJson(state.toJson());
    expect(restored.streak.currentWeekCount, 3);
    expect(restored.streak.weekdaysTrained, [1, 3, 5]);
    expect(restored.planner['seg'], ['routine:1']);
  });
}
