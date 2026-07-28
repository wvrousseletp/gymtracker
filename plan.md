1. **Model Updates**:
- `lib/models/planner_state.dart`: Add `nextTargetReps` (int?), `nextTargetWeight` (double?) to `WatchRestTimer`.
- `ios/WatchApp Watch App/WatchModels.swift`: Add `nextTargetReps` and `nextTargetWeight` to `WatchRestTimer`.

2. **Service Updates**:
- `lib/services/rest_timer_service.dart`: Add ValueNotifiers for `nextTargetReps` and `nextTargetWeight`. Update `start()` method.

3. **Provider Updates**:
- `lib/providers/workout_provider.dart`: Update `WatchRestTimer` creation. In `startRestTimer()`, look up the target reps/weight and pass them.

4. **UI Updates (Flutter)**:
- `lib/screens/workout_screen.dart`: Update `-` and `+` buttons to show `-15s` and `+15s`. Read `nextTargetReps` and `nextTargetWeight` from `RestTimerService.instance` and display them in the next exercise card.

5. **UI Updates (WatchOS)**:
- `ios/WatchApp Watch App/RestTimerView.swift`: Read `nextTargetReps` and `nextTargetWeight` from `restTimer` and display them.
