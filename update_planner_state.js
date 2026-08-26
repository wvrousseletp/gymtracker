const fs = require('fs');

let content = fs.readFileSync('lib/models/planner_state.dart', 'utf8');

// 1. Add WorkoutBlock class definition at the top before PlannerState
const blockClass = `
class WorkoutBlock {
  final String id;
  final String name;
  final List<String> routineIds;

  WorkoutBlock({
    required this.id,
    required this.name,
    required this.routineIds,
  });

  WorkoutBlock copyWith({
    String? id,
    String? name,
    List<String>? routineIds,
  }) {
    return WorkoutBlock(
      id: id ?? this.id,
      name: name ?? this.name,
      routineIds: routineIds ?? this.routineIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'routineIds': routineIds,
  };

  factory WorkoutBlock.fromJson(Map<String, dynamic> json) {
    return WorkoutBlock(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      routineIds: List<String>.from(json['routineIds'] ?? []),
    );
  }
}
`;

content = content.replace('class PlannerState {', blockClass + '\nclass PlannerState {');

// 2. Add continuousBlocks field to PlannerState
content = content.replace('final Map<String, List<String>> planner;', 'final Map<String, List<String>> planner;\n  final List<WorkoutBlock> continuousBlocks;');

// 3. Update constructor
content = content.replace('required this.planner,', 'required this.planner,\n    required this.continuousBlocks,');

// 4. Update copyWith
content = content.replace('Map<String, List<String>>? planner,', 'Map<String, List<String>>? planner,\n    List<WorkoutBlock>? continuousBlocks,');
content = content.replace('planner: planner ?? this.planner,', 'planner: planner ?? this.planner,\n      continuousBlocks: continuousBlocks ?? this.continuousBlocks,');

// 5. Update toJson
content = content.replace("'planner': planner,", "'planner': planner,\n    'continuousBlocks': continuousBlocks.map((b) => b.toJson()).toList(),");

// 6. Update fromJson
const fromJsonRegex = /factory PlannerState\.fromJson\(Map<String, dynamic> json\) \{/;
const fromJsonReplacement = `factory PlannerState.fromJson(Map<String, dynamic> json) {
    List<WorkoutBlock> parsedBlocks = [];
    if (json['continuousBlocks'] != null) {
      parsedBlocks = (json['continuousBlocks'] as List).map((b) => WorkoutBlock.fromJson(b)).toList();
    } else if (json['planner'] != null && json['planner']['continuous'] != null) {
      // Migrate old continuous list
      List<String> oldList = List<String>.from(json['planner']['continuous']);
      if (oldList.isNotEmpty) {
        parsedBlocks.add(WorkoutBlock(id: 'bloco-geral-migrado', name: 'Geral', routineIds: oldList));
      }
    }`;

content = content.replace(fromJsonRegex, fromJsonReplacement);

// 7. Update return inside fromJson
content = content.replace('planner: plannerMap,', 'planner: plannerMap,\n      continuousBlocks: parsedBlocks,');

fs.writeFileSync('lib/models/planner_state.dart', content);
