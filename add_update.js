const fs = require('fs');
let content = fs.readFileSync('lib/providers/workout_provider.dart', 'utf8');

const updateMethod = `
  void updateRoutineInContinuousBlock(String blockId, int index, String newValue) {
    final updatedBlocks = _state.continuousBlocks.map((b) {
      if (b.id == blockId) {
        final newRoutines = List<String>.from(b.routineIds);
        if (index >= 0 && index < newRoutines.length) {
          newRoutines[index] = newValue;
        }
        return b.copyWith(routineIds: newRoutines);
      }
      return b;
    }).toList();
    _state = _state.copyWith(continuousBlocks: updatedBlocks);
    notifyListeners();
    saveData();
  }
`;

content = content.replace('void reorderRoutinesInContinuousBlock', updateMethod + '\n  void reorderRoutinesInContinuousBlock');

fs.writeFileSync('lib/providers/workout_provider.dart', content);
