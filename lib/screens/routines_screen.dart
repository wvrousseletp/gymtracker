import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/workout_provider.dart';
import '../providers/profile_provider.dart';
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
    final accentColor = context.select<ProfileProvider, Color>(
      (p) => ThemeUtils.getColor(p.currentProfile.colorAccent),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Container(
            color: Colors.black,
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
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const PlannerScreen(),
                RoutinesTab(accentColor: accentColor),
                LibraryTab(accentColor: accentColor),
              ],
            ),
          ),
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
    final provider = context.select<WorkoutProvider, WorkoutProvider>((p) => p);
    final routines = context.select<WorkoutProvider, List<Routine>>((p) => p.routines);

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
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
              itemCount: routines.length,
              itemBuilder: (context, index) {
                final routine = routines[index];
                return _buildRoutineCard(context, provider, routine);
              },
            ),
    );
  }

  Widget _buildRoutineCard(BuildContext context, WorkoutProvider provider, Routine routine) {
    final state = provider;

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
                  orElse: () => LibraryExercise(id: '', name: 'Deletado', muscle: 'Desconhecido', measurementType: MeasurementType.reps),
                );

                final isCardio = ref.muscle.toLowerCase().contains('cardio');
                final isTime = ref.measurementType == MeasurementType.time;
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
                        WorkoutRecovery(sleepOk: SleepQuality.okay, pain: [], warmUpDone: false),
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

  void _confirmDeleteRoutine(BuildContext context, WorkoutProvider provider, Routine routine) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          useBlur: true,
          borderColor: Colors.white.withOpacity(0.08),
          borderRadius: 20,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Excluir Rotina?",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                "Tem certeza que deseja excluir '${routine.name}'?",
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text("Cancelar", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      provider.deleteRoutine(routine.id);
                      Navigator.pop(dialogCtx);
                    },
                    child: const Text("Excluir", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openRoutineForm(BuildContext context, WorkoutProvider provider, Routine? existing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      builder: (context) => RoutineFormSheet(provider: provider, existing: existing),
    );
  }
}

// FORMULÁRIO DE ROTINA (SHEET)
class RoutineFormSheet extends StatefulWidget {
  final WorkoutProvider provider;
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
    final library = widget.provider.library;
    final accentColor = ThemeUtils.getColor(Provider.of<ProfileProvider>(context, listen: false).currentProfile.colorAccent);

    // Ordena biblioteca de exercícios para seleção
    final sortedLibrary = List<LibraryExercise>.from(library)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: BoxDecoration(
              color: const Color(0xff0d0d0f).withOpacity(0.92),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom > 0
                  ? MediaQuery.of(context).viewInsets.bottom + 12
                  : MediaQuery.of(context).padding.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.existing == null ? "Nova Rotina" : "Editar Rotina",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white.withOpacity(0.6), size: 20),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Form(
                  key: _formKey,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.04),
                            labelText: "Nome da Rotina",
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                            floatingLabelStyle: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: accentColor, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (value) => (value == null || value.trim().isEmpty) ? "Obrigatório" : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _restController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.04),
                            labelText: "Descanso (seg)",
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                            floatingLabelStyle: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: accentColor, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (value) => (value == null || int.tryParse(value) == null) ? "Inválido" : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Botão Proeminente e Bonito de Adicionar Exercício
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.black, size: 18),
                    label: const Text(
                      "ADICIONAR EXERCÍCIO",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      _addExercisePicker(sortedLibrary);
                    },
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Exercícios Adicionados",
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                    ),
                    if (_exercises.isNotEmpty)
                      Text(
                        "${_exercises.length} ${_exercises.length == 1 ? 'exercício' : 'exercícios'}",
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Lista de exercícios adicionados na rotina
                Expanded(
                  child: _exercises.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fitness_center, size: 36, color: Colors.white.withOpacity(0.15)),
                              const SizedBox(height: 8),
                              Text(
                                "Nenhum exercício adicionado ainda.\nToque no botão acima para adicionar.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12, height: 1.4, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: _exercises.length,
                          itemBuilder: (context, idx) {
                            final ex = _exercises[idx];
                            final ref = library.firstWhere(
                              (l) => l.id == ex.exerciseId,
                              orElse: () => LibraryExercise(id: '', name: 'Deletado', muscle: '', measurementType: MeasurementType.reps),
                            );
                            final isCardio = ref.muscle.toLowerCase().contains('cardio');
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.06)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          ref.name,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.1),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.arrow_upward_rounded, color: idx == 0 ? Colors.white10 : Colors.white60, size: 18),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: idx == 0 ? null : () => _moveExercise(idx, true),
                                          ),
                                          const SizedBox(width: 12),
                                          IconButton(
                                            icon: Icon(Icons.arrow_downward_rounded, color: idx == _exercises.length - 1 ? Colors.white10 : Colors.white60, size: 18),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: idx == _exercises.length - 1 ? null : () => _moveExercise(idx, false),
                                          ),
                                          const SizedBox(width: 12),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _exercises.removeAt(idx);
                                              });
                                            },
                                            child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withOpacity(0.8), size: 20),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
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
                                      Expanded(
                                        child: _buildInputRow(
                                          label: isCardio ? "Minutos" : (ref.measurementType == MeasurementType.time ? "Segundos" : "Reps"),
                                          value: ex.reps.toString(),
                                          onChanged: (val) {
                                            _updateExerciseField(idx, reps: int.tryParse(val) ?? 0);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
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
                const SizedBox(height: 12),

                // Botão de Confirmação
                SizedBox(
                  width: double.infinity,
                  height: 48,
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(
                      widget.existing == null ? "Criar Rotina" : "Salvar Alterações",
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    final accentColor = ThemeUtils.getColor(widget.provider.currentProfile?.colorAccent ?? 'Peito');
    // Agrupar por músculo
    final Map<String, List<LibraryExercise>> grouped = {};
    for (final ex in library) {
      grouped.putIfAbsent(ex.muscle, () => []).add(ex);
    }
    final sortedMuscles = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final List<String> activeFilters = [];
    final Set<LibraryExercise> selectedExercises = {};

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: GlassCard(
              useBlur: true,
              borderColor: Colors.white.withOpacity(0.08),
              borderRadius: 20,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Selecione o Exercício",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                        onPressed: () => Navigator.pop(dialogCtx),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Horizontal muscle filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: sortedMuscles.map((muscle) {
                        final isSelected = activeFilters.contains(muscle);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                if (!isSelected) {
                                  activeFilters.clear();
                                  activeFilters.add(muscle);
                                } else {
                                  activeFilters.remove(muscle);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? accentColor.withOpacity(0.15) 
                                    : Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected 
                                      ? accentColor.withOpacity(0.5) 
                                      : Colors.white.withOpacity(0.08),
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                muscle.toUpperCase(),
                                style: TextStyle(
                                  color: isSelected ? accentColor : Colors.white60,
                                  fontSize: 10,
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
                  const SizedBox(height: 8),
                  Expanded(
                    child: SizedBox(
                      width: double.maxFinite,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: sortedMuscles.where((m) => activeFilters.isEmpty || activeFilters.contains(m)).length,
                        itemBuilder: (context, mIdx) {
                          final filteredMuscles = sortedMuscles.where((m) => activeFilters.isEmpty || activeFilters.contains(m)).toList();
                          final muscle = filteredMuscles[mIdx];
                          final exs = grouped[muscle]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 16, bottom: 6),
                                child: Text(
                                  muscle.toUpperCase(),
                                  style: TextStyle(
                                    color: accentColor.withOpacity(0.9),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              ...exs.map((ex) {
                                final isSelected = selectedExercises.contains(ex);
                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? accentColor.withOpacity(0.08) 
                                        : Colors.white.withOpacity(0.02),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected 
                                          ? accentColor.withOpacity(0.4) 
                                          : Colors.white.withOpacity(0.04),
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            ex.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -0.1,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (ex.executionType != null && ex.executionType!.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blueAccent.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                                            ),
                                            child: Text(
                                              ex.executionType!,
                                              style: const TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.w800),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 3.0),
                                      child: Text(
                                        ex.measurementType == MeasurementType.time ? 'Isometria' : 'Repetições',
                                        style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
                                      ),
                                    ),
                                    trailing: Icon(
                                      isSelected ? Icons.check_circle : Icons.add_circle_outline_rounded,
                                      color: isSelected ? accentColor : accentColor.withOpacity(0.7),
                                      size: 20,
                                    ),
                                    onTap: () {
                                      setDialogState(() {
                                        if (isSelected) {
                                          selectedExercises.remove(ex);
                                        } else {
                                          selectedExercises.add(ex);
                                        }
                                      });
                                    },
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  if (selectedExercises.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 44,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            for (final ex in selectedExercises) {
                              _exercises.add(RoutineExercise(
                                id: "e-${const Uuid().v4()}",
                                exerciseId: ex.id,
                                sets: 3,
                                reps: ex.measurementType == MeasurementType.time ? 45 : 10,
                                rest: int.tryParse(_restController.text.trim()) ?? 60,
                                weight: 0,
                              ));
                            }
                          });
                          Navigator.pop(dialogCtx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          "ADICIONAR ${selectedExercises.length} ${selectedExercises.length == 1 ? 'EXERCÍCIO' : 'EXERCÍCIOS'}",
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
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
    final provider = Provider.of<WorkoutProvider>(context);
    final library = provider.library;

    final muscles = _getMusclesList(library);
    final filteredExs = _selectedMuscleFilter == "todos"
        ? library
        : library.where((e) => e.muscle == _selectedMuscleFilter).toList();

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
                                              if (ex.measurementType == MeasurementType.time) ...[
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
                                            "${ex.muscle} • ${ex.measurementType == MeasurementType.time ? 'Isometria' : 'Repetições'}",
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

  void _confirmDeleteExercise(BuildContext context, WorkoutProvider provider, LibraryExercise ex) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          useBlur: true,
          borderColor: Colors.white.withOpacity(0.08),
          borderRadius: 20,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Excluir Exercício?",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                "Deseja realmente deletar '${ex.name}' da biblioteca?",
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text("Cancelar", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      provider.deleteLibraryExercise(ex.id);
                      Navigator.pop(dialogCtx);
                    },
                    child: const Text("Excluir", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddExerciseDialog(BuildContext context, WorkoutProvider provider, {LibraryExercise? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? "");
    String category = existing != null
        ? (existing.muscle == "Cardio" ? "Cardio" : "Musculação")
        : "Musculação";
    String muscle = existing != null
        ? (existing.muscle == "Cardio" ? "Peito" : existing.muscle)
        : "Peito";
    String equipment = existing?.executionType ?? "Barra";
    String measurement = existing != null
        ? (existing.measurementType == MeasurementType.time ? "Tempo de Isometria" : "Repetições")
        : "Repetições";
    final notesCtrl = TextEditingController(text: existing?.notes ?? "");

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: GlassCard(
              useBlur: true,
              borderColor: Colors.white.withOpacity(0.08),
              borderRadius: 24,
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(existing == null ? Icons.add_circle_outline_rounded : Icons.edit_calendar_rounded, color: widget.accentColor, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            existing == null ? "Novo Exercício" : "Editar Exercício",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
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

                      // Agrupamento Muscular (se Musculação)
                      if (category == "Musculação") ...[
                        const Text("Agrupamento Muscular", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
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
                              value: muscle,
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
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: measurement == "Repetições"
                                        ? widget.accentColor.withOpacity(0.12)
                                        : Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: measurement == "Repetições"
                                          ? widget.accentColor.withOpacity(0.4)
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
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: measurement == "Tempo de Isometria"
                                        ? widget.accentColor.withOpacity(0.12)
                                        : Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: measurement == "Tempo de Isometria"
                                          ? widget.accentColor.withOpacity(0.4)
                                          : Colors.white.withOpacity(0.08),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      "Tempo (s)",
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
                      const SizedBox(height: 20),
                      
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
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
