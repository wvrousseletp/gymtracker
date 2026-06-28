import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/tracker_provider.dart';
import '../models/exercise.dart';
import '../models/routine.dart';
import '../models/workout_log.dart';
import '../widgets/glass_card.dart';
import '../widgets/profile_avatar.dart';

import 'planner_screen.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.select<TrackerProvider, Color>(
      (p) => ThemeUtils.getColor(p.currentProfile.colorAccent),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: TabBar(
          controller: _tabController,
          indicatorColor: accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [
            Tab(text: "Agenda"),
            Tab(text: "Modelos"),
            Tab(text: "Biblioteca"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const PlannerScreen(),
          RoutinesTab(accentColor: accentColor),
          LibraryTab(accentColor: accentColor),
        ],
      ),
    );
  }
}

// ==========================================
// 1. ROTINAS TAB
// ==========================================
class RoutinesTab extends StatelessWidget {
  final Color accentColor;
  const RoutinesTab({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final state = provider.state;

    if (state == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final routines = state.routines;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton(
          onPressed: () {
            _openRoutineForm(context, provider, null);
          },
          backgroundColor: accentColor,
          mini: true,
          child: const Icon(Icons.add, color: Colors.black),
        ),
      ),
      body: routines.isEmpty
          ? const Center(
              child: Text(
                "Nenhuma rotina criada.\nToque no botão + para adicionar.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
              itemCount: routines.length,
              itemBuilder: (context, index) {
                final routine = routines[index];
                return _buildRoutineCard(context, provider, routine);
              },
            ),
    );
  }

  Widget _buildRoutineCard(BuildContext context, TrackerProvider provider, Routine routine) {
    final state = provider.state!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderColor: Colors.white.withOpacity(0.06),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    routine.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Text(
                    "Rest: ${routine.defaultRest}s",
                    style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Exercícios
            Column(
              children: routine.exercises.map((ex) {
                final ref = state.library.firstWhere(
                  (l) => l.id == ex.exerciseId,
                  orElse: () => LibraryExercise(id: '', name: 'Deletado', muscle: 'Desconhecido', measurementType: 'reps'),
                );

                final isCardio = ref.muscle.toLowerCase().contains('cardio');
                final isTime = ref.measurementType == 'time';
                final repsSuffix = isCardio ? 'min' : (isTime ? 's' : '');
                final repsBadgeText = "${ex.sets}x${ex.reps}$repsSuffix";
                final restTime = ex.rest;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ref.name,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            ref.muscle,
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _buildBadge(repsBadgeText),
                          const SizedBox(width: 4),
                          _buildBadge("${restTime}s", highlighted: ex.rest != routine.defaultRest),
                          if (ex.weight > 0) ...[
                            const SizedBox(width: 4),
                            _buildBadge("${ex.weight.toStringAsFixed(1).replaceAll('.0', '')}kg"),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Ações
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Disparar o treino ativo
                      provider.startWorkout(
                        routine,
                        WorkoutRecovery(sleepOk: 'ok', pain: [], warmUpDone: false),
                        false,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Treino '${routine.name}' iniciado!"),
                          backgroundColor: accentColor,
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow, color: Colors.black, size: 18),
                    label: const Text(
                      "Iniciar Treino",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.04),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                  ),
                  onPressed: () {
                    _openRoutineForm(context, provider, routine);
                  },
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.redAccent.withOpacity(0.2)),
                    ),
                  ),
                  onPressed: () {
                    _confirmDeleteRoutine(context, provider, routine);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, {bool highlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: highlighted ? accentColor.withOpacity(0.12) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: highlighted ? accentColor.withOpacity(0.4) : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: highlighted ? accentColor : Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _confirmDeleteRoutine(BuildContext context, TrackerProvider provider, Routine routine) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xff1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text("Excluir Rotina?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text("Tem certeza que deseja excluir '${routine.name}'?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              provider.deleteRoutine(routine.id);
              Navigator.pop(dialogCtx);
            },
            child: const Text("Excluir", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openRoutineForm(BuildContext context, TrackerProvider provider, Routine? existing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RoutineFormSheet(provider: provider, existing: existing),
    );
  }
}

// FORMULÁRIO DE ROTINA (SHEET)
class RoutineFormSheet extends StatefulWidget {
  final TrackerProvider provider;
  final Routine? existing;

  const RoutineFormSheet({super.key, required this.provider, this.existing});

  @override
  State<RoutineFormSheet> createState() => _RoutineFormSheetState();
}

class _RoutineFormSheetState extends State<RoutineFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _restController = TextEditingController(text: "60");

  List<RoutineExercise> _exercises = [];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameController.text = widget.existing!.name;
      _restController.text = widget.existing!.defaultRest.toString();
      _exercises = List<RoutineExercise>.from(widget.existing!.exercises);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _restController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = widget.provider.state!.library;
    final accentColor = ThemeUtils.getColor(widget.provider.currentProfile.colorAccent);

    // Ordena biblioteca de exercícios para seleção
    final sortedLibrary = List<LibraryExercise>.from(library)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff1c1c1e).withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                margin: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existing == null ? "Nova Rotina" : "Editar Rotina",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: accentColor),
                  onPressed: () {
                    _addExercisePicker(sortedLibrary);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            labelText: "Nome da Rotina",
                            labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          validator: (value) => (value == null || value.trim().isEmpty) ? "Obrigatório" : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _restController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            labelText: "Descanso (seg)",
                            labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          validator: (value) => (value == null || int.tryParse(value) == null) ? "Inválido" : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              "Exercícios Agendados",
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            // Lista de exercícios adicionados na rotina
            _exercises.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        "Nenhum exercício adicionado.\nToque no botão + no topo para selecionar.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  )
                : SizedBox(
                    height: 250,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _exercises.length,
                      itemBuilder: (context, idx) {
                        final ex = _exercises[idx];
                        final ref = library.firstWhere(
                          (l) => l.id == ex.exerciseId,
                          orElse: () => LibraryExercise(id: '', name: 'Deletado', muscle: '', measurementType: 'reps'),
                        );
                        final isCardio = ref.muscle.toLowerCase().contains('cardio');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    ref.name,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                  Row(
                                    children: [
                                      // Up Button
                                      IconButton(
                                        icon: const Icon(Icons.arrow_upward, color: Colors.white54, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: idx == 0 ? null : () => _moveExercise(idx, true),
                                      ),
                                      const SizedBox(width: 8),
                                      // Down Button
                                      IconButton(
                                        icon: const Icon(Icons.arrow_downward, color: Colors.white54, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: idx == _exercises.length - 1 ? null : () => _moveExercise(idx, false),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _exercises.removeAt(idx);
                                          });
                                        },
                                        child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // Sets
                                  Expanded(
                                    child: _buildInputRow(
                                      label: isCardio ? "Repet." : "Séries",
                                      value: ex.sets.toString(),
                                      onChanged: (val) {
                                        _updateExerciseField(idx, sets: int.tryParse(val) ?? 0);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Reps / Cardio Time
                                  Expanded(
                                    child: _buildInputRow(
                                      label: isCardio ? "Minutos" : (ref.measurementType == 'time' ? "Segundos" : "Reps"),
                                      value: ex.reps.toString(),
                                      onChanged: (val) {
                                        _updateExerciseField(idx, reps: int.tryParse(val) ?? 0);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Weight (only for non-cardio)
                                  if (!isCardio) ...[
                                    Expanded(
                                      child: _buildInputRow(
                                        label: "Carga (kg)",
                                        value: ex.weight.toString(),
                                        onChanged: (val) {
                                          _updateExerciseField(idx, weight: double.tryParse(val) ?? 0.0);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  // Rest Override
                                  Expanded(
                                    child: _buildInputRow(
                                      label: "Desc. (s)",
                                      value: ex.rest.toString(),
                                      onChanged: (val) {
                                        _updateExerciseField(idx, rest: int.tryParse(val) ?? 0);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 16),

            // Botão de Confirmação
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    if (_exercises.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Adicione pelo menos um exercício à rotina!"),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    // Validar se há exercícios com 0 séries ou reps
                    bool anyInvalid = false;
                    for (var ex in _exercises) {
                      if (ex.sets <= 0 || ex.reps <= 0) {
                        anyInvalid = true;
                        break;
                      }
                    }
                    if (anyInvalid) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Todas as séries e repetições/tempo devem ser maiores que zero!"),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    final name = _nameController.text.trim();
                    final rest = int.parse(_restController.text.trim());

                    if (widget.existing == null) {
                      widget.provider.addRoutine(name, rest, _exercises);
                    } else {
                      final updated = Routine(
                        id: widget.existing!.id,
                        name: name,
                        defaultRest: rest,
                        exercises: _exercises,
                      );
                      widget.provider.updateRoutine(updated);
                    }
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  widget.existing == null ? "Criar Rotina" : "Salvar Alterações",
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow({required String label, required String value, required ValueChanged<String> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextFormField(
            initialValue: value == "0" || value == "0.0" ? "" : value,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _moveExercise(int index, bool moveUp) {
    setState(() {
      final targetIndex = moveUp ? index - 1 : index + 1;
      final temp = _exercises[index];
      _exercises[index] = _exercises[targetIndex];
      _exercises[targetIndex] = temp;
    });
  }

  void _updateExerciseField(int index, {int? sets, int? reps, double? weight, int? rest}) {
    final cur = _exercises[index];
    _exercises[index] = RoutineExercise(
      id: cur.id,
      exerciseId: cur.exerciseId,
      sets: sets ?? cur.sets,
      reps: reps ?? cur.reps,
      weight: weight ?? cur.weight,
      rest: rest ?? cur.rest,
    );
  }

  void _addExercisePicker(List<LibraryExercise> library) {
    final accentColor = ThemeUtils.getColor(widget.provider.currentProfile.colorAccent);
    // Agrupar por músculo
    final Map<String, List<LibraryExercise>> grouped = {};
    for (final ex in library) {
      grouped.putIfAbsent(ex.muscle, () => []).add(ex);
    }
    final sortedMuscles = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xff1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text("Selecione o Exercício", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sortedMuscles.length,
            itemBuilder: (context, mIdx) {
              final muscle = sortedMuscles[mIdx];
              final exs = grouped[muscle]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6, left: 4),
                    child: Text(
                      muscle.toUpperCase(),
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  ...exs.map((ex) {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              ex.name,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (ex.executionType != null && ex.executionType!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ex.executionType!,
                                style: const TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        ex.measurementType == 'time' ? 'Isometria' : 'Repetições',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      onTap: () {
                        setState(() {
                          _exercises.add(RoutineExercise(
                            id: "e-${const Uuid().v4()}",
                            exerciseId: ex.id,
                            sets: 3,
                            reps: ex.measurementType == 'time' ? 45 : 10,
                            rest: int.tryParse(_restController.text.trim()) ?? 60,
                            weight: 0,
                          ));
                        });
                        Navigator.pop(dialogCtx);
                      },
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. LIBRARY TAB
// ==========================================
class LibraryTab extends StatefulWidget {
  final Color accentColor;
  const LibraryTab({super.key, required this.accentColor});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  String _selectedMuscleFilter = "todos";

  List<String> _getMusclesList(List<LibraryExercise> library) {
    final set = <String>{};
    for (var e in library) {
      set.add(e.muscle);
    }
    return ["todos", ...set];
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final state = provider.state;

    if (state == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final muscles = _getMusclesList(state.library);
    final filteredExs = _selectedMuscleFilter == "todos"
        ? state.library
        : state.library.where((e) => e.muscle == _selectedMuscleFilter).toList();

    // Organizar biblioteca em ordem alfabética de nome
    final sortedExs = List<LibraryExercise>.from(filteredExs)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // Agrupar por músculo
    final Map<String, List<LibraryExercise>> groupedExs = {};
    for (final ex in sortedExs) {
      groupedExs.putIfAbsent(ex.muscle, () => []).add(ex);
    }
    final sortedMuscles = groupedExs.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton(
          onPressed: () {
            _openAddExerciseDialog(context, provider);
          },
          backgroundColor: widget.accentColor,
          mini: true,
          child: const Icon(Icons.add, color: Colors.black),
        ),
      ),
      body: Column(
        children: [
          // Filtro por Músculo
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: muscles.length,
              itemBuilder: (context, index) {
                final m = muscles[index];
                final isSelected = m == _selectedMuscleFilter;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMuscleFilter = m;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? widget.accentColor.withOpacity(0.15) : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? widget.accentColor : Colors.white.withOpacity(0.08),
                        width: 1.2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      m.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? widget.accentColor : Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Lista de Exercícios
          Expanded(
            child: sortedExs.isEmpty
                ? const Center(
                    child: Text(
                      "Nenhum exercício encontrado.",
                      style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
                    itemCount: sortedMuscles.length,
                    itemBuilder: (context, mIdx) {
                      final muscle = sortedMuscles[mIdx];
                      final exs = groupedExs[muscle]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
                            child: Text(
                              muscle.toUpperCase(),
                              style: TextStyle(
                                color: widget.accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          ...exs.map((ex) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: GlassCard(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                borderColor: Colors.white.withOpacity(0.04),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                ex.name,
                                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                              ),
                                              if (ex.measurementType == 'time') ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    "Isometria",
                                                    style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                              if (ex.executionType != null && ex.executionType!.isNotEmpty) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blueAccent.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    ex.executionType!,
                                                    style: const TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "${ex.muscle} • ${ex.measurementType == 'time' ? 'Isometria' : 'Repetições'}",
                                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                                          ),
                                          if (ex.notes != null && ex.notes!.trim().isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              ex.notes!,
                                              style: const TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
                                          onPressed: () {
                                            _openAddExerciseDialog(context, provider, existing: ex);
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                          onPressed: () {
                                            _confirmDeleteExercise(context, provider, ex);
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteExercise(BuildContext context, TrackerProvider provider, LibraryExercise ex) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xff1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text("Excluir Exercício?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text("Deseja realmente deletar '${ex.name}' da biblioteca?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              provider.deleteLibraryExercise(ex.id);
              Navigator.pop(dialogCtx);
            },
            child: const Text("Excluir", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openAddExerciseDialog(BuildContext context, TrackerProvider provider, {LibraryExercise? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? "");
    String category = existing != null
        ? (existing.muscle == "Cardio" ? "Cardio" : "Musculação")
        : "Musculação";
    String muscle = existing != null
        ? (existing.muscle == "Cardio" ? "Peito" : existing.muscle)
        : "Peito";
    String equipment = existing?.executionType ?? "Barra";
    String measurement = existing != null
        ? (existing.measurementType == 'time' ? "Tempo de Isometria" : "Repetições")
        : "Repetições";
    final notesCtrl = TextEditingController(text: existing?.notes ?? "");

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xff1c1c1e),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            title: Row(
              children: [
                Icon(existing == null ? Icons.add_circle_outline_rounded : Icons.edit_calendar_rounded, color: widget.accentColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  existing == null ? "Novo Exercício" : "Editar Exercício",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ],
            ),
            content: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.03),
                        hintText: "Nome do Exercício",
                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: widget.accentColor.withOpacity(0.5), width: 1.5),
                        ),
                        prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.white30, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tipo de Exercício
                    const Text("Tipo de Exercício", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                category = "Musculação";
                                if (muscle == "Cardio") {
                                  muscle = "Peito";
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: category == "Musculação"
                                    ? widget.accentColor.withOpacity(0.12)
                                    : Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: category == "Musculação"
                                      ? widget.accentColor.withOpacity(0.4)
                                      : Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  "Musculação 🏋️",
                                  style: TextStyle(
                                    color: category == "Musculação" ? Colors.white : Colors.white60,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                category = "Cardio";
                                muscle = "Cardio";
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: category == "Cardio"
                                    ? widget.accentColor.withOpacity(0.12)
                                    : Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: category == "Cardio"
                                      ? widget.accentColor.withOpacity(0.4)
                                      : Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  "Cardio 🏃",
                                  style: TextStyle(
                                    color: category == "Cardio" ? Colors.white : Colors.white60,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Grupo Muscular (se Musculação)
                    if (category == "Musculação") ...[
                      const Text("Grupo Muscular", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: muscle == "Cardio" ? "Peito" : muscle,
                            dropdownColor: const Color(0xff1c1c1e),
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
                            onChanged: (val) {
                              if (val != null) setState(() => muscle = val);
                            },
                            items: ["Peito", "Costas", "Pernas", "Ombros", "Bíceps", "Tríceps", "Core", "Outros"]
                                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Tipo de Equipamento (se Musculação)
                    if (category == "Musculação") ...[
                      const Text("Tipo de Equipamento", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: equipment,
                            dropdownColor: const Color(0xff1c1c1e),
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
                            onChanged: (val) {
                              if (val != null) setState(() => equipment = val);
                            },
                            items: ["Barra", "Haltere", "Máquina", "Livre"]
                                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Tipo de Medição (se Musculação)
                    if (category == "Musculação") ...[
                      const Text("Tipo de Medição", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => measurement = "Repetições"),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  color: measurement == "Repetições"
                                      ? Colors.blueAccent.withOpacity(0.12)
                                      : Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: measurement == "Repetições"
                                      ? Colors.blueAccent.withOpacity(0.4)
                                      : Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    "Repetições",
                                    style: TextStyle(
                                      color: measurement == "Repetições" ? Colors.white : Colors.white60,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => measurement = "Tempo de Isometria"),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  color: measurement == "Tempo de Isometria"
                                      ? Colors.amber.withOpacity(0.12)
                                      : Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: measurement == "Tempo de Isometria"
                                      ? Colors.amber.withOpacity(0.4)
                                      : Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    "Isometria",
                                    style: TextStyle(
                                      color: measurement == "Tempo de Isometria" ? Colors.white : Colors.white60,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Tipo de Medição (se Cardio)
                    if (category == "Cardio") ...[
                      const Text("Tipo de Medição", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.flash_on_rounded, color: widget.accentColor, size: 16),
                            const SizedBox(width: 8),
                            const Text(
                              "Distância + Tempo (Automático)",
                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Observação
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.03),
                        hintText: "Observação (Opcional)",
                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: widget.accentColor.withOpacity(0.5), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.only(bottom: 20, right: 24, left: 24),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Cancelar", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isNotEmpty) {
                          final isCardioEx = category == "Cardio";
                          final mType = isCardioEx
                              ? "time"
                              : (measurement == "Tempo de Isometria" ? "time" : "reps");
                          final execType = isCardioEx
                              ? "Livre"
                              : equipment;

                          if (existing == null) {
                            provider.addLibraryExercise(
                              name,
                              isCardioEx ? "Cardio" : muscle,
                              mType,
                              notesCtrl.text.trim(),
                              execType,
                            );
                          } else {
                            provider.updateLibraryExercise(
                              existing.id,
                              name,
                              isCardioEx ? "Cardio" : muscle,
                              mType,
                              notesCtrl.text.trim(),
                              execType,
                            );
                          }
                          Navigator.pop(dialogCtx);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(existing == null ? "Adicionar" : "Salvar", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
