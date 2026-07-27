import re
import os

def find_closing_bracket(text, start_index):
    count = 0
    for i in range(start_index, len(text)):
        if text[i] == '{':
            count += 1
        elif text[i] == '}':
            count -= 1
            if count == 0:
                return i
    return -1

def extract_methods(text, method_names):
    extracted = []
    remaining = text
    for name in method_names:
        # Match the signature of the method
        # e.g., void addRoutine(
        pattern = r'(\s*(?:void|Future<void>|List<[\w<>]+>|Map<[\w<>,\s]+>|String|bool|ActiveWorkoutState\??|WorkoutStreak|int|double)\s+' + name + r'\s*\([^)]*\)\s*(?:async\s*)?{)'
        match = re.search(pattern, remaining)
        if match:
            start = match.start(1)
            body_start = match.end(1) - 1 # position of {
            end = find_closing_bracket(remaining, body_start)
            if end != -1:
                method_code = remaining[start:end+1]
                extracted.append(method_code)
                remaining = remaining[:start] + remaining[end+1:]
        else:
            print("Method not found:", name)
    return remaining, "\n\n".join(extracted)

with open('lib/providers/workout_provider.dart', 'r') as f:
    content = f.read()

library_methods = [
    "addLibraryExercise", "updateLibraryExercise", "deleteLibraryExercise", "checkAndPopulateDefaultLibrary"
]

routine_methods = [
    "addRoutine", "updateRoutine", "deleteRoutine",
    "addPlannerItem", "updatePlannerItem", "reorderPlannerItem", "removePlannerItem",
    "shiftPlannerForward", "undoShiftPlannerForward"
]

history_methods = [
    "addMeasurement", "deleteMeasurement", "updateMeasurement",
    "addManualWorkoutLog", "deleteWorkoutLog", "deletePersonalRecord",
    "_updatePersonalRecordsForLog", "_updateStreak", "refreshStreak",
    "loadWorkoutHistory"
]

active_methods = [
    "startWorkout", "startSingleExercise", "completeSet", "startRestTimer", "clearRestTimer",
    "updateExerciseWeightReps", "updateExerciseSetWeightReps", "updateWorkoutTimer", "setCurrentExerciseIndex",
    "pauseWorkout", "applyActiveWorkoutFromWatch", "discardActiveWorkout", "postponeActiveWorkout",
    "resumePostponedWorkout", "discardPostponedWorkout", "clearAllPostponedWorkouts", "updateHealthMetrics",
    "finishWorkout", "updateWorkoutElapsedTime"
]

content, lib_code = extract_methods(content, library_methods)
content, routine_code = extract_methods(content, routine_methods)
content, history_code = extract_methods(content, history_methods)
content, active_code = extract_methods(content, active_methods)

# write part files
def write_part(filename, ext_name, code):
    with open(f'lib/providers/{filename}', 'w') as f:
        f.write("part of 'workout_provider.dart';\n\n")
        f.write(f"extension {ext_name} on WorkoutProvider {{\n")
        f.write(code)
        f.write("\n}\n")

write_part('workout_provider_library.dart', 'WorkoutProviderLibrary', lib_code)
write_part('workout_provider_routine.dart', 'WorkoutProviderRoutine', routine_code)
write_part('workout_provider_history.dart', 'WorkoutProviderHistory', history_code)
write_part('workout_provider_active.dart', 'WorkoutProviderActive', active_code)

# Insert part directives after imports
import_end = content.rfind("import 'profile_provider.dart';")
insert_pos = content.find('\n', import_end) + 1

parts = """
part 'workout_provider_library.dart';
part 'workout_provider_routine.dart';
part 'workout_provider_history.dart';
part 'workout_provider_active.dart';
"""

content = content[:insert_pos] + parts + content[insert_pos:]

with open('lib/providers/workout_provider.dart', 'w') as f:
    f.write(content)
print("done")
