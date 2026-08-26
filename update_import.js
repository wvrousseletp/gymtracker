const fs = require('fs');

let content = fs.readFileSync('lib/providers/workout_provider.dart', 'utf8');

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
