const fs = require('fs');
let content = fs.readFileSync('lib/providers/tracker_provider.dart', 'utf8');

const passThroughs = `
  List<String> get flatContinuousList => _workoutProvider?.flatContinuousList ?? [];

  void addContinuousBlock({String? name}) {
    _workoutProvider?.addContinuousBlock(name: name);
  }

  void renameContinuousBlock(String blockId, String newName) {
    _workoutProvider?.renameContinuousBlock(blockId, newName);
  }

  void removeContinuousBlock(String blockId) {
    _workoutProvider?.removeContinuousBlock(blockId);
  }

  void reorderContinuousBlocks(int oldIndex, int newIndex) {
    _workoutProvider?.reorderContinuousBlocks(oldIndex, newIndex);
  }

  void addRoutineToContinuousBlock(String blockId, String routineId) {
    _workoutProvider?.addRoutineToContinuousBlock(blockId, routineId);
  }

  void updateRoutineInContinuousBlock(String blockId, int index, String newValue) {
    _workoutProvider?.updateRoutineInContinuousBlock(blockId, index, newValue);
  }

  void removeRoutineFromContinuousBlock(String blockId, int index) {
    _workoutProvider?.removeRoutineFromContinuousBlock(blockId, index);
  }

  void reorderRoutinesInContinuousBlock(String blockId, int oldIndex, int newIndex) {
    _workoutProvider?.reorderRoutinesInContinuousBlock(blockId, oldIndex, newIndex);
  }
`;

content = content.replace('void addPlannerItem(String day) {', passThroughs + '\n  void addPlannerItem(String day) {');

fs.writeFileSync('lib/providers/tracker_provider.dart', content);
