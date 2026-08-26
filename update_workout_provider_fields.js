const fs = require('fs');
let content = fs.readFileSync('lib/providers/workout_provider.dart', 'utf8');

// Add field continuousBlocks
content = content.replace(
  'Map<String, List<String>> planner = {};',
  'Map<String, List<String>> planner = {};\n  List<WorkoutBlock> continuousBlocks = [];'
);

// Add block management methods (add, rename, reorder, etc)
const blockMethods = `
  List<String> get flatContinuousList {
    return continuousBlocks.map((b) => b.routineIds).expand((x) => x).toList();
  }

  void addContinuousBlock({String? name}) {
    final newId = DateTime.now().millisecondsSinceEpoch.toString(); // simpler than Uuid without import
    final newName = name ?? 'Bloco \${continuousBlocks.length + 1}';
    final newBlock = WorkoutBlock(id: newId, name: newName, routineIds: []);
    continuousBlocks = List<WorkoutBlock>.from(continuousBlocks)..add(newBlock);
    _save();
  }

  void renameContinuousBlock(String blockId, String newName) {
    continuousBlocks = continuousBlocks.map((b) {
      if (b.id == blockId) return b.copyWith(name: newName);
      return b;
    }).toList();
    _save();
  }

  void removeContinuousBlock(String blockId) {
    continuousBlocks = List<WorkoutBlock>.from(continuousBlocks)..removeWhere((b) => b.id == blockId);
    
    // adjust index
    final flattened = continuousBlocks.map((b) => b.routineIds).expand((x) => x).toList();
    int newIndex = settings.continuousListCurrentIndex;
    if (flattened.isNotEmpty) {
      newIndex = newIndex % flattened.length;
    } else {
      newIndex = 0;
    }
    settings = settings.copyWith(continuousListCurrentIndex: newIndex);
    _save();
  }

  void reorderContinuousBlocks(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final updatedBlocks = List<WorkoutBlock>.from(continuousBlocks);
    final item = updatedBlocks.removeAt(oldIndex);
    updatedBlocks.insert(newIndex, item);
    continuousBlocks = updatedBlocks;
    _save();
  }

  void addRoutineToContinuousBlock(String blockId, String routineId) {
    continuousBlocks = continuousBlocks.map((b) {
      if (b.id == blockId) {
        return b.copyWith(routineIds: List.from(b.routineIds)..add(routineId));
      }
      return b;
    }).toList();
    _save();
  }

  void updateRoutineInContinuousBlock(String blockId, int index, String newValue) {
    continuousBlocks = continuousBlocks.map((b) {
      if (b.id == blockId) {
        final newRoutines = List<String>.from(b.routineIds);
        if (index >= 0 && index < newRoutines.length) {
          newRoutines[index] = newValue;
        }
        return b.copyWith(routineIds: newRoutines);
      }
      return b;
    }).toList();
    _save();
  }

  void removeRoutineFromContinuousBlock(String blockId, int index) {
    continuousBlocks = continuousBlocks.map((b) {
      if (b.id == blockId) {
        final newRoutines = List<String>.from(b.routineIds);
        if (index >= 0 && index < newRoutines.length) {
          newRoutines.removeAt(index);
        }
        return b.copyWith(routineIds: newRoutines);
      }
      return b;
    }).toList();
    
    // adjust index
    final flattened = continuousBlocks.map((b) => b.routineIds).expand((x) => x).toList();
    int newIndex = settings.continuousListCurrentIndex;
    if (flattened.isNotEmpty) {
      newIndex = newIndex % flattened.length;
    } else {
      newIndex = 0;
    }
    settings = settings.copyWith(continuousListCurrentIndex: newIndex);
    _save();
  }

  void reorderRoutinesInContinuousBlock(String blockId, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    continuousBlocks = continuousBlocks.map((b) {
      if (b.id == blockId) {
        final newRoutines = List<String>.from(b.routineIds);
        final item = newRoutines.removeAt(oldIndex);
        newRoutines.insert(newIndex, item);
        return b.copyWith(routineIds: newRoutines);
      }
      return b;
    }).toList();
    _save();
  }

  void copyDayToContinuousBlock(String fromDay) {
    final sourceList = planner[fromDay] ?? [];
    final validItems = sourceList.where((item) => item.isNotEmpty).toList();
    if (validItems.isEmpty) return;
    
    final dayNameMap = {
      'seg': 'Segunda',
      'ter': 'Terça',
      'qua': 'Quarta',
      'qui': 'Quinta',
      'sex': 'Sexta',
      'sab': 'Sábado',
      'dom': 'Domingo'
    };
    final suffix = dayNameMap[fromDay] ?? fromDay;
    
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newBlock = WorkoutBlock(
      id: newId, 
      name: 'Treinos de $suffix', 
      routineIds: List.from(validItems)
    );
    
    continuousBlocks = List<WorkoutBlock>.from(continuousBlocks)..add(newBlock);
    _save();
  }
`;

content = content.replace('List<String> get todayPlannedItems {', blockMethods + '\n  List<String> get todayPlannedItems {');

// Fix uses of planner['continuous']
content = content.replace(/planner\['continuous'\] \?\? \[\]/g, 'flatContinuousList');

// Update import methods to use block logic for continuous
const regexImportFrom = /void importFromFixedDay\(String sourceDay, String targetKey\) \{([\s\S]*?)\}/;
const replaceImportFrom = `void importFromFixedDay(String sourceDay, String targetKey) {
    if (targetKey == 'continuous') {
      copyDayToContinuousBlock(sourceDay);
      return;
    }
    final sourceItems = List<String>.from(planner[sourceDay] ?? []);
    final validItems = sourceItems.where((item) => item.isNotEmpty).toList();
    if (validItems.isEmpty) return;
    
    planner[targetKey] = List<String>.from(planner[targetKey] ?? [])..addAll(validItems);
    _save();
  }`;

content = content.replace(regexImportFrom, replaceImportFrom);

const regexImportAll = /void importAllFixedDays\(String targetKey\) \{([\s\S]*?)_save\(\);\n  \}/;
const replaceImportAll = `void importAllFixedDays(String targetKey) {
    final days = ['seg', 'ter', 'qua', 'qui', 'sex', 'sab', 'dom'];
    
    if (targetKey == 'continuous') {
      for (final day in days) {
        copyDayToContinuousBlock(day);
      }
      return;
    }

    final List<String> newPlannerEntries = [];

    for (final day in days) {
      final sourceItems = List<String>.from(planner[day] ?? []);
      final validItems = sourceItems.where((item) => item.isNotEmpty).toList();
      if (validItems.isEmpty) continue;

      // Adiciona os modelos originais daquele dia
      newPlannerEntries.addAll(validItems);
    }

    if (newPlannerEntries.isEmpty) return;

    planner[targetKey] = List<String>.from(planner[targetKey] ?? [])
      ..addAll(newPlannerEntries);
    _save();
  }`;

content = content.replace(regexImportAll, replaceImportAll);


fs.writeFileSync('lib/providers/workout_provider.dart', content);
