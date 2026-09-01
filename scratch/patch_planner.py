import re

with open('lib/screens/planner_screen.dart', 'r') as f:
    content = f.read()

# Add _buildModernPlannerCard and _showItemSelectionSheet before _buildBlockItemRow
methods_to_add = """
  void _showItemSelectionSheet(BuildContext context, TrackerProvider provider, PlannerState state, Color accentColor, {required Function(String) onSelected, bool allowExercises = true}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Color(0xFF141414),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const Text("Selecionar", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    const Text("MODELOS DE TREINO", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    ...state.routines.map((r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: accentColor.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(Icons.fitness_center, color: accentColor, size: 20),
                      ),
                      title: Text(r.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: Text("${r.exercises.length} exercícios", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      onTap: () { Navigator.pop(ctx); onSelected("routine:${r.id}"); },
                    )),
                    if (allowExercises) ...[
                      const SizedBox(height: 24),
                      const Text("CARDIO E EXERCÍCIOS AVULSOS", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      ...state.library.map((ex) {
                        final isCardio = ex.muscle.toLowerCase().contains('cardio');
                        final color = isCardio ? Colors.blueAccent : Colors.orangeAccent;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                            child: Icon(isCardio ? Icons.directions_run : Icons.accessibility_new, color: color, size: 20),
                          ),
                          title: Text(ex.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          subtitle: Text(ex.muscle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          onTap: () { Navigator.pop(ctx); onSelected("exercise:${ex.id}"); },
                        );
                      }),
                    ]
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildModernPlannerCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onStart,
    VoidCallback? onDelete,
    Widget? trailing,
  }) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissibleDirection.endToStart,
      onDismissed: (_) => onDelete?.call(),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    if (subtitle.isNotEmpty)
                      const SizedBox(height: 2),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              if (trailing != null) trailing,
              if (onStart != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                      ]
                    ),
                    child: const Text("COMEÇAR", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
"""

content = content.replace("  Widget _buildBlockItemRow(", methods_to_add + "\n  Widget _buildBlockItemRow(")

# Rewrite _buildBlockItemRow
old_block_row = r"""  Widget _buildBlockItemRow\((.*?)\{.*?// old format or generic, let's keep empty if unknown\s*selectedValue = "";\s*\}\s*final dropdownItems.*?onPressed: \(\) \{\s*provider\.removeRoutineFromContinuousBlock\(blockId, idx\);\s*\},\s*\),\s*\]\s*\);\s*\}"""

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

content = re.sub(old_block_row, new_block_row, content, flags=re.DOTALL)

# Rewrite _buildPlannerItemRow
old_planner_row = r"""  Widget _buildPlannerItemRow\((.*?)\{.*?// Identificar se é cardio.*?if \(muscleComp != 0\) return muscleComp;\s*return a\.name\.toLowerCase\(\)\.compareTo\(b\.name\.toLowerCase\(\)\);\s*\}\);\s*return Container\(.*?if \(isCardio\) \.\.\.\[.*?\]\s*\]\s*\);\s*\}\s*\)\s*\]\s*\);\s*\}"""

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
      onDelete: () => provider.updatePlannerItem(day, idx, ""), // Clearing the item effectively deletes it from fixed days unless we shift them (which the app doesn't currently do). Actually wait, the planner expects a fixed number of rows or empty strings.
      trailing: selectedValue.startsWith('exercise:') ? Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("$quantityValue", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 4),
            Text(isCardio ? "min" : "sér", style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ) : null,
    );
  }"""

content = re.sub(old_planner_row, new_planner_row, content, flags=re.DOTALL)

with open('lib/screens/planner_screen.dart', 'w') as f:
    f.write(content)
print("Patched planner_screen.dart")
