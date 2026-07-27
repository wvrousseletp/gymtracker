import sys

with open('lib/screens/routines_screen.dart', 'r') as f:
    lines = f.readlines()

start_idx = -1
end_idx = -1

for i, line in enumerate(lines):
    if line.startswith("  void _addExercisePicker(List<LibraryExercise> library) {"):
        start_idx = i
    if line.startswith("// =========================================="):
        if i > start_idx and start_idx != -1:
            # We want to replace up to the line before this block
            # Actually, let's just find the closing bracket of _RoutineFormSheetState
            # which is right before this comment block.
            end_idx = i - 1
            break

if start_idx != -1 and end_idx != -1:
    print(f"Found at {start_idx} to {end_idx}")
    
    new_method = """  void _addExercisePicker(List<LibraryExercise> library) {
    final accentColor = ThemeUtils.getColor(
        widget.provider.currentProfile?.colorAccent ?? 'Peito');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExerciseSelectionSheet(
        library: library,
        accentColor: accentColor,
        onSave: (selectedExercises) {
          setState(() {
            for (final ex in selectedExercises) {
              final isCardioEx = ex.measurementType == MeasurementType.cardio ||
                  ex.measurementType == MeasurementType.distance ||
                  ex.measurementType == MeasurementType.time;
              _exercises.add(RoutineExercise(
                id: "e-${const Uuid().v4()}",
                exerciseId: ex.id,
                sets: isCardioEx ? 1 : 3,
                reps: isCardioEx
                    ? 0
                    : (ex.measurementType == MeasurementType.time ? 45 : 10),
                rest: int.tryParse(_restController.text.trim()) ?? 60,
                weight: 0,
                isCardio: isCardioEx,
                allowCardioSets: false,
              ));
            }
          });
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        },
      ),
    );
  }
}

class _ExerciseSelectionSheet extends StatefulWidget {
  final List<LibraryExercise> library;
  final Color accentColor;
  final void Function(List<LibraryExercise>) onSave;

  const _ExerciseSelectionSheet({
    super.key,
    required this.library,
    required this.accentColor,
    required this.onSave,
  });

  @override
  State<_ExerciseSelectionSheet> createState() => _ExerciseSelectionSheetState();
}

class _ExerciseSelectionSheetState extends State<_ExerciseSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _activeFilters = {};
  final Set<LibraryExercise> _selectedExercises = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Agrupar por músculo e filtrar
    final Map<String, List<LibraryExercise>> grouped = {};
    for (final ex in widget.library) {
      if (_searchQuery.isNotEmpty && !ex.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        continue;
      }
      grouped.putIfAbsent(ex.muscle, () => []).add(ex);
    }
    
    final sortedMuscles = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      
    final allMusclesForChips = widget.library.map((e) => e.muscle).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Selecionar Exercícios",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 24),
                  onPressed: () => Navigator.pop(context),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: "Buscar exercício...",
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: Colors.white.withOpacity(0.3), size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Muscle filters
          if (_searchQuery.isEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: allMusclesForChips.map((muscle) {
                  final isSelected = _activeFilters.contains(muscle);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _activeFilters.remove(muscle);
                          } else {
                            _activeFilters.add(muscle);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? widget.accentColor.withOpacity(0.15)
                              : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? widget.accentColor.withOpacity(0.5)
                                : Colors.white.withOpacity(0.08),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          muscle.toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? widget.accentColor : Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            
          if (_searchQuery.isEmpty) const SizedBox(height: 16),
          
          const Divider(color: Colors.white10, height: 1),
          
          // List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              physics: const BouncingScrollPhysics(),
              itemCount: sortedMuscles.where((m) => _activeFilters.isEmpty || _activeFilters.contains(m)).length,
              itemBuilder: (context, mIdx) {
                final filteredMuscles = sortedMuscles
                    .where((m) => _activeFilters.isEmpty || _activeFilters.contains(m))
                    .toList();
                final muscle = filteredMuscles[mIdx];
                final exs = grouped[muscle]!;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Text(
                        muscle.toUpperCase(),
                        style: TextStyle(
                          color: widget.accentColor.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ...exs.map((ex) {
                      final isSelected = _selectedExercises.contains(ex);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedExercises.remove(ex);
                            } else {
                              _selectedExercises.add(ex);
                            }
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? widget.accentColor.withOpacity(0.08)
                                : Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? widget.accentColor.withOpacity(0.4)
                                  : Colors.white.withOpacity(0.05),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isSelected ? widget.accentColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? widget.accentColor : Colors.white38,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, color: Colors.black, size: 16)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  ex.name,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontSize: 16,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
          
          // Footer button
          if (_selectedExercises.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onSave(_selectedExercises.toList());
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      "ADICIONAR ${_selectedExercises.length} EXERCÍCIO${_selectedExercises.length > 1 ? 'S' : ''}",
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
"""
    lines = lines[:start_idx] + [new_method, '\n'] + lines[end_idx:]
    with open('lib/screens/routines_screen.dart', 'w') as f:
        f.writelines(lines)
    print("Replaced successfully")
else:
    print("Could not find bounds")
