  void _showItemSelectionSheet(BuildContext context, TrackerProvider provider, PlannerState state, Color accentColor, {required Function(String) onSelected, bool allowExercises = true}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const Text("Selecionar Treino", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const Text("ROTINAS", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...state.routines.map((r) => ListTile(
                      leading: Icon(Icons.fitness_center, color: accentColor),
                      title: Text(r.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text("${r.exercises.length} exercícios", style: const TextStyle(color: Colors.white54)),
                      onTap: () { Navigator.pop(ctx); onSelected("routine:${r.id}"); },
                    )),
                    if (allowExercises) ...[
                      const SizedBox(height: 16),
                      const Text("EXERCÍCIOS AVULSOS (CARDIO / FORÇA)", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...state.library.map((ex) => ListTile(
                        leading: Icon(ex.muscle.toLowerCase().contains('cardio') ? Icons.directions_run : Icons.accessibility_new, color: Colors.blueAccent),
                        title: Text(ex.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(ex.muscle, style: const TextStyle(color: Colors.white54)),
                        onTap: () { Navigator.pop(ctx); onSelected("exercise:${ex.id}"); },
                      )),
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
