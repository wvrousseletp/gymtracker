import re

with open('lib/screens/planner_screen.dart', 'r') as f:
    content = f.read()

# Fix imports
if "import '../models/routine.dart';" not in content:
    content = content.replace("import '../models/planner_state.dart';", "import '../models/planner_state.dart';\nimport '../models/routine.dart';\nimport '../providers/workout_provider.dart';\nimport '../utils/workout_starter.dart';")

# Remove unused imports if any
content = content.replace("import 'exercise_hub_screen.dart';", "")

# Fix _buildBlockItemRow start
content = content.replace(
    "onStart: () {\n        provider.startRoutineWorkout(context, selectedRoutine!);\n      },",
    """onStart: () {
        final wp = Provider.of<WorkoutProvider>(context, listen: false);
        WorkoutStarter.startWithCountdown(
          context,
          wp,
          selectedRoutine!,
          WorkoutRecovery(sleepOk: SleepQuality.okay, pain: [], warmUpDone: false),
          false,
        );
      },"""
)

# Fix _buildPlannerItemRow start
content = content.replace(
    "onStart: routineToStart != null ? () => provider.startRoutineWorkout(context, routineToStart!) : null,",
    """onStart: routineToStart != null ? () {
        final wp = Provider.of<WorkoutProvider>(context, listen: false);
        WorkoutStarter.startWithCountdown(
          context,
          wp,
          routineToStart!,
          WorkoutRecovery(sleepOk: SleepQuality.okay, pain: [], warmUpDone: false),
          false,
        );
      } : null,"""
)

with open('lib/screens/planner_screen.dart', 'w') as f:
    f.write(content)
