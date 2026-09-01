import re

with open('lib/screens/planner_screen.dart', 'r') as f:
    lines = f.readlines()

def replace_block(lines, start_str, end_str, new_content):
    start_idx = -1
    for i, line in enumerate(lines):
        if start_str in line:
            start_idx = i
            break
    
    if start_idx == -1:
        return lines
        
    end_idx = -1
    # Count braces
    brace_count = 0
    for i in range(start_idx, len(lines)):
        brace_count += lines[i].count('{')
        brace_count -= lines[i].count('}')
        if brace_count == 0 and '{' in ''.join(lines[start_idx:i+1]):
            end_idx = i
            break
            
    if end_idx != -1:
        return lines[:start_idx] + [new_content + "\n"] + lines[end_idx+1:]
    return lines

new_block_row = """  Widget _buildBlockItemRow(
    BuildContext context,
    TrackerProvider provider,
    PlannerState state,
    String blockId,
    int idx,
    String rawItem,
    Color accentColor,
    int blockLength,
  ) {
    String selectedValue = rawItem.startsWith('routine:') ? rawItem : "";
    Routine? selectedRoutine;
    if (selectedValue.isNotEmpty) {
      final rId = selectedValue.substring(8);
      selectedRoutine = state.routines.where((r) => r.id == rId).firstOrNull;
    }

    if (selectedRoutine == null) {
      return _buildModernPlannerCard(
        context: context,
        title: "Tocar para escolher treino...",
        subtitle: "",
        icon: Icons.search,
        color: Colors.white54,
        onTap: () {
          _showItemSelectionSheet(context, provider, state, accentColor, allowExercises: false, onSelected: (val) {
            provider.updateRoutineInContinuousBlock(blockId, idx, val);
          });
        },
        onDelete: () => provider.removeRoutineFromContinuousBlock(blockId, idx),
      );
    }

    return _buildModernPlannerCard(
      context: context,
      title: selectedRoutine.name,
      subtitle: "${selectedRoutine.exercises.length} exercícios",
      icon: Icons.fitness_center,
      color: accentColor,
      onTap: () {
        _showItemSelectionSheet(context, provider, state, accentColor, allowExercises: false, onSelected: (val) {
          provider.updateRoutineInContinuousBlock(blockId, idx, val);
        });
      },
      onStart: () {
        provider.startRoutineWorkout(context, selectedRoutine!);
      },
      onDelete: () => provider.removeRoutineFromContinuousBlock(blockId, idx),
      trailing: Column(
        children: [
          InkWell(
            onTap: idx > 0 ? () => provider.reorderRoutinesInContinuousBlock(blockId, idx, idx - 1) : null,
            child: Icon(Icons.keyboard_arrow_up, color: idx > 0 ? Colors.white54 : Colors.transparent, size: 20),
          ),
          InkWell(
            onTap: idx < blockLength - 1 ? () => provider.reorderRoutinesInContinuousBlock(blockId, idx, idx + 1) : null,
            child: Icon(Icons.keyboard_arrow_down, color: idx < blockLength - 1 ? Colors.white54 : Colors.transparent, size: 20),
          ),
        ],
      ),
    );
  }"""

new_planner_row = """  Widget _buildPlannerItemRow(
    BuildContext context,
    TrackerProvider provider,
    String day,
    int idx,
    String rawItem,
    Color accentColor,
  ) {
    final state = context.select<TrackerProvider, PlannerState>((p) => p.state!);
    final library = state.library;
    final routines = state.routines;

    String selectedValue = "";
    int quantityValue = 3;

    if (rawItem.startsWith('routine:')) {
      selectedValue = rawItem;
    } else if (rawItem.startsWith('exercise:')) {
      final parts = rawItem.split(':');
      if (parts.length >= 3) {
        selectedValue = "${parts[0]}:${parts[1]}";
        quantityValue = int.tryParse(parts[2]) ?? 3;
      } else {
        selectedValue = rawItem;
      }
    } else if (rawItem.isNotEmpty) {
      selectedValue = "routine:$rawItem";
    }

    bool isCardio = false;
    String title = "Tocar para adicionar...";
    String subtitle = "";
    IconData icon = Icons.add_circle_outline;
    Color color = Colors.white54;
    Routine? routineToStart;

    if (selectedValue.startsWith('routine:')) {
      final rId = selectedValue.substring(8);
      routineToStart = routines.where((r) => r.id == rId).firstOrNull;
      if (routineToStart != null) {
        title = routineToStart.name;
        subtitle = "${routineToStart.exercises.length} exercícios";
        icon = Icons.fitness_center;
        color = accentColor;
      }
    } else if (selectedValue.startsWith('exercise:')) {
      final exId = selectedValue.substring(9);
      final libEx = library.where((e) => e.id == exId).firstOrNull;
      if (libEx != null) {
        isCardio = libEx.muscle.toLowerCase().contains('cardio');
        title = libEx.name;
        subtitle = isCardio ? "Cardio" : "Exercício Isolado";
        icon = isCardio ? Icons.directions_run : Icons.accessibility_new;
        color = isCardio ? Colors.blueAccent : Colors.orangeAccent;
      }
    }

    return _buildModernPlannerCard(
      context: context,
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      onTap: () {
        _showItemSelectionSheet(context, provider, state, accentColor, onSelected: (val) {
          if (val.startsWith('exercise:')) {
            final exId = val.substring(9);
            final libEx = library.where((e) => e.id == exId).firstOrNull;
            if (libEx != null && libEx.muscle.toLowerCase().contains('cardio')) {
              provider.updatePlannerItem(day, idx, "$val:30");
            } else {
              provider.updatePlannerItem(day, idx, "$val:3");
            }
          } else {
            provider.updatePlannerItem(day, idx, val);
          }
        });
      },
      onStart: routineToStart != null ? () => provider.startRoutineWorkout(context, routineToStart!) : null,
      onDelete: () => provider.updatePlannerItem(day, idx, ""),
      trailing: selectedValue.startsWith('exercise:') ? Container(
        margin: const EdgeInsets.only(right: 8),
        width: 70,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: TextFormField(
                initialValue: quantityValue.toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(bottom: 14),
                  isDense: true,
                ),
                onChanged: (val) {
                  int quantity = int.tryParse(val) ?? (isCardio ? 30 : 3);
                  if (quantity < 1) quantity = 1;
                  final parts = rawItem.split(':');
                  if (parts.length >= 2) {
                    provider.updatePlannerItem(day, idx, "${parts[0]}:${parts[1]}:$quantity");
                  }
                },
              ),
            ),
            Text(isCardio ? "min" : "sér", style: const TextStyle(color: Colors.white54, fontSize: 10)),
            const SizedBox(width: 8),
          ],
        ),
      ) : null,
    );
  }"""

lines = replace_block(lines, "Widget _buildBlockItemRow(", "", new_block_row)
lines = replace_block(lines, "Widget _buildPlannerItemRow(", "", new_planner_row)

content = "".join(lines)
content = content.replace("DismissibleDirection", "DismissDirection")

with open('lib/screens/planner_screen.dart', 'w') as f:
    f.write(content)

print("Properly replaced!")
