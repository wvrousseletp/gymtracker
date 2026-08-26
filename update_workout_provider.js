const fs = require('fs');

let content = fs.readFileSync('lib/providers/workout_provider.dart', 'utf8');

// 1. Add flat continuous list getter
const flattenGetter = `
  List<String> get flatContinuousList {
    return _state.continuousBlocks.map((b) => b.routineIds).expand((x) => x).toList();
  }
`;
content = content.replace('List<String> get todayPlannedItems {', flattenGetter + '\n  List<String> get todayPlannedItems {');

// 2. Replace uses of planner['continuous']
content = content.replace(/planner\['continuous'\] \?\? \[\]/g, 'flatContinuousList');

// 3. Add block management methods (add, remove, rename, reorder)
const blockMethods = `
  void addContinuousBlock({String? name}) {
    final newId = Uuid().v4();
    final newName = name ?? 'Bloco \${_state.continuousBlocks.length + 1}';
    final newBlock = WorkoutBlock(id: newId, name: newName, routineIds: []);
    
    final updatedBlocks = List<WorkoutBlock>.from(_state.continuousBlocks)..add(newBlock);
    _state = _state.copyWith(continuousBlocks: updatedBlocks);
    notifyListeners();
    saveData();
  }

  void renameContinuousBlock(String blockId, String newName) {
    final updatedBlocks = _state.continuousBlocks.map((b) {
      if (b.id == blockId) return b.copyWith(name: newName);
      return b;
    }).toList();
    _state = _state.copyWith(continuousBlocks: updatedBlocks);
    notifyListeners();
    saveData();
  }

  void removeContinuousBlock(String blockId) {
    final updatedBlocks = List<WorkoutBlock>.from(_state.continuousBlocks)..removeWhere((b) => b.id == blockId);
    // Ajustar index
    final flattened = updatedBlocks.map((b) => b.routineIds).expand((x) => x).toList();
    int newIndex = _state.settings.continuousListCurrentIndex;
    if (flattened.isNotEmpty) {
      newIndex = newIndex % flattened.length;
    } else {
      newIndex = 0;
    }
    _state = _state.copyWith(
      continuousBlocks: updatedBlocks,
      settings: _state.settings.copyWith(continuousListCurrentIndex: newIndex)
    );
    notifyListeners();
    saveData();
  }

  void reorderContinuousBlocks(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final updatedBlocks = List<WorkoutBlock>.from(_state.continuousBlocks);
    final item = updatedBlocks.removeAt(oldIndex);
    updatedBlocks.insert(newIndex, item);
    _state = _state.copyWith(continuousBlocks: updatedBlocks);
    notifyListeners();
    saveData();
  }

  void addRoutineToContinuousBlock(String blockId, String routineId) {
    final updatedBlocks = _state.continuousBlocks.map((b) {
      if (b.id == blockId) {
        return b.copyWith(routineIds: List.from(b.routineIds)..add(routineId));
      }
      return b;
    }).toList();
    _state = _state.copyWith(continuousBlocks: updatedBlocks);
    notifyListeners();
    saveData();
  }

  void removeRoutineFromContinuousBlock(String blockId, int index) {
    final updatedBlocks = _state.continuousBlocks.map((b) {
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
    final flattened = updatedBlocks.map((b) => b.routineIds).expand((x) => x).toList();
    int newIndex = _state.settings.continuousListCurrentIndex;
    if (flattened.isNotEmpty) {
      newIndex = newIndex % flattened.length;
    } else {
      newIndex = 0;
    }

    _state = _state.copyWith(
      continuousBlocks: updatedBlocks,
      settings: _state.settings.copyWith(continuousListCurrentIndex: newIndex)
    );
    notifyListeners();
    saveData();
  }

  void reorderRoutinesInContinuousBlock(String blockId, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final updatedBlocks = _state.continuousBlocks.map((b) {
      if (b.id == blockId) {
        final newRoutines = List<String>.from(b.routineIds);
        final item = newRoutines.removeAt(oldIndex);
        newRoutines.insert(newIndex, item);
        return b.copyWith(routineIds: newRoutines);
      }
      return b;
    }).toList();
    _state = _state.copyWith(continuousBlocks: updatedBlocks);
    notifyListeners();
    saveData();
  }

  void copyDayToContinuousBlock(String fromDay) {
    final sourceList = _state.planner[fromDay] ?? [];
    if (sourceList.isEmpty) return;
    
    final dayNameMap = {
      'monday': 'Segunda',
      'tuesday': 'Terça',
      'wednesday': 'Quarta',
      'thursday': 'Quinta',
      'friday': 'Sexta',
      'saturday': 'Sábado',
      'sunday': 'Domingo'
    };
    final suffix = dayNameMap[fromDay] ?? fromDay;
    
    final newId = Uuid().v4();
    final newBlock = WorkoutBlock(
      id: newId, 
      name: 'Treinos de $suffix', 
      routineIds: List.from(sourceList)
    );
    
    final updatedBlocks = List<WorkoutBlock>.from(_state.continuousBlocks)..add(newBlock);
    _state = _state.copyWith(continuousBlocks: updatedBlocks);
    notifyListeners();
    saveData();
  }
`;

content = content.replace('void addPlannerItem(String day) {', blockMethods + '\n  void addPlannerItem(String day) {');

fs.writeFileSync('lib/providers/workout_provider.dart', content);
