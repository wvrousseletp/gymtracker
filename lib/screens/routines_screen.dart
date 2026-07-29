import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/routine_sharing_utils.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/workout_provider.dart';
import '../utils/workout_starter.dart';
import '../providers/profile_provider.dart';
import '../models/exercise.dart';
import '../models/enums.dart';
import '../models/routine.dart';
import '../models/workout_log.dart';
import '../widgets/glass_card.dart';
import '../widgets/profile_avatar.dart';

import 'planner_screen.dart';
import 'exercise_hub_screen.dart';

String _getMeasurementTypeLabelStatic(MeasurementType type) {
  switch (type) {
    case MeasurementType.cardio:
      return 'Cardio (distância + tempo)';
    case MeasurementType.distance:
      return 'Distância';
    case MeasurementType.time:
      return 'Isometria';
    case MeasurementType.reps:
      return 'Repetições';
  }
}

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen>
    with SingleTickerProviderStateMixin {
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
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
    final routines =
        context.select<WorkoutProvider, List<Routine>>((p) => p.routines);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: "importRoutineFAB",
              onPressed: () => _showImportRoutineDialog(context, provider, accentColor),
              backgroundColor: Colors.white12,
              mini: true,
              child: const Icon(Icons.download_rounded, color: Colors.white),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: "addRoutineFAB",
              onPressed: () {
                _openRoutineForm(context, provider, null);
              },
              backgroundColor: accentColor,
              mini: true,
              child: const Icon(Icons.add, color: Colors.black),
            ),
          ],
        ),
      ),
      body: routines.isEmpty
          ? const Center(
              child: Text(
                "Nenhuma rotina criada.\nToque no botão + para adicionar.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white38, fontStyle: FontStyle.italic),
              ),
            )
          : ListView.builder(
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 16, bottom: 100),
              itemCount: routines.length,
              itemExtent: 140, // Fixed height for better performance
              itemBuilder: (context, index) {
                final routine = routines[index];
                return _buildRoutineCard(context, provider, routine);
              },
            ),
    );
  }

  Widget _buildRoutineCard(
      BuildContext context, WorkoutProvider provider, Routine routine) {
    final state = provider;

    return GestureDetector(
      onTap: () => _openRoutineForm(context, provider, routine),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withOpacity(0.15),
              Colors.black.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: accentColor.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.05),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CABEÇALHO DA ROTINA E AÇÕES RAPIDAS
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routine.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.timer_outlined,
                                  size: 14,
                                  color: Colors.white.withOpacity(0.5)),
                              const SizedBox(width: 4),
                              Text(
                                "Descanso Padrão: ${routine.defaultRest}s",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withOpacity(0.3),
                      size: 28,
                    ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(color: Colors.white10, height: 1),
                ),

                // RESUMO DE EXERCÍCIOS
                Builder(
                  builder: (context) {
                    if (routine.exercises.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          "Nenhum exercício adicionado.",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: routine.exercises.map((ex) {
                        final ref = state.library.firstWhere(
                          (l) => l.id == ex.exerciseId,
                          orElse: () => LibraryExercise(
                              id: '',
                              name: 'Deletado',
                              muscle: 'Desconhecido',
                              measurementType: MeasurementType.reps),
                        );
                        
                        final isCardio = ref.muscle.toLowerCase().contains('cardio');
                        final isTime = ref.measurementType == MeasurementType.time;
                        final repsSuffix = isCardio ? 'min' : (isTime ? 's' : '');
                        final repsText = ex.reps > 0 ? "${ex.sets}x${ex.reps}$repsSuffix" : "${ex.sets} séries";

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 6, right: 10),
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  ref.name,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  repsText,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // BOTÃO INICIAR TREINO GIGANTE
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      WorkoutStarter.startWithCountdown(
                        context,
                        provider,
                        routine,
                        WorkoutRecovery(
                            sleepOk: SleepQuality.okay,
                            pain: [],
                            warmUpDone: false),
                        false,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Treino '${routine.name}' iniciado!"),
                          backgroundColor: accentColor,
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded,
                        color: Colors.black, size: 28),
                    label: const Text(
                      "INICIAR TREINO",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1.0,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: accentColor.withOpacity(0.5),
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

  void _openRoutineForm(
      BuildContext context, WorkoutProvider provider, Routine? existing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      builder: (context) =>
          RoutineFormSheet(provider: provider, existing: existing),
    );
  }

  void _showImportRoutineDialog(BuildContext context, WorkoutProvider provider, Color accentColor) {
    final controller = TextEditingController();
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
                "Importar Rotina",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Cole o código da rotina aqui",
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text("Cancelar",
                        style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final code = controller.text.trim();
                      if (code.isEmpty) return;
                      
                      final sharedData = RoutineSharingUtils.decodeRoutine(code);
                      if (sharedData != null) {
                        final routine = sharedData.routine;
                        final updatedExercises = <RoutineExercise>[];

                        for (final re in routine.exercises) {
                          final def = sharedData.exerciseDefinitions
                              .where((d) => d.id == re.exerciseId)
                              .firstOrNull;
                          String targetId = re.exerciseId;

                          final existingInLib = provider.library.where((l) =>
                              l.id == re.exerciseId ||
                              (def != null && l.name.trim().toLowerCase() == def.name.trim().toLowerCase())
                          ).firstOrNull;

                          if (existingInLib != null) {
                            targetId = existingInLib.id;
                          } else if (def != null) {
                            provider.addLibraryExercise(
                              def.name,
                              def.muscle,
                              measurementTypeToString(def.measurementType),
                              def.notes,
                              def.executionType,
                            );
                            targetId = provider.library.last.id;
                          }

                          updatedExercises.add(RoutineExercise(
                            id: re.id,
                            exerciseId: targetId,
                            sets: re.sets,
                            reps: re.reps,
                            rest: re.rest,
                            weight: re.weight,
                            weightsPerSet: re.weightsPerSet,
                            repsPerSet: re.repsPerSet,
                            isCardio: re.isCardio,
                            allowCardioSets: re.allowCardioSets,
                          ));
                        }

                        provider.addRoutine(routine.name, routine.defaultRest, updatedExercises);
                        Navigator.pop(dialogCtx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Rotina '${routine.name}' importada com sucesso!"),
                              backgroundColor: accentColor,
                            ),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Código inválido."),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Importar",
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
  final _scrollController = ScrollController();

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
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = widget.provider.library;
    final accentColor = ThemeUtils.getColor(
        Provider.of<ProfileProvider>(context, listen: false)
            .currentProfile
            .colorAccent);

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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border:
                  Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
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
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.3),
                    ),
                    Row(
                      children: [
                        if (widget.existing != null)
                          IconButton(
                            icon: const Icon(Icons.share_outlined,
                                color: Colors.blueAccent, size: 20),
                            onPressed: () {
                              final encoded = RoutineSharingUtils.encodeRoutine(widget.existing!, widget.provider.library);
                              Clipboard.setData(ClipboardData(text: encoded));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Código da rotina copiado!"),
                                  backgroundColor: Colors.blueAccent,
                                ),
                              );
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.blueAccent.withOpacity(0.1),
                              padding: const EdgeInsets.all(6),
                            ),
                          ),
                        if (widget.existing != null) const SizedBox(width: 8),
                        if (widget.existing != null)
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent, size: 20),
                            onPressed: () {
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const Text(
                                          "Excluir Rotina?",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          "Tem certeza que deseja excluir '${widget.existing!.name}'?",
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                              height: 1.4),
                                        ),
                                        const SizedBox(height: 20),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(dialogCtx),
                                              child: const Text("Cancelar",
                                                  style: TextStyle(
                                                      color: Colors.white54,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: () {
                                                widget.provider.deleteRoutine(
                                                    widget.existing!.id);
                                                Navigator.pop(dialogCtx);
                                                Navigator.pop(
                                                    context); // Close the sheet
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.redAccent,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                              ),
                                              child: const Text("Excluir",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  Colors.redAccent.withOpacity(0.1),
                              padding: const EdgeInsets.all(6),
                            ),
                          ),
                        if (widget.existing != null) const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.close,
                              color: Colors.white.withOpacity(0.6), size: 20),
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.05),
                            padding: const EdgeInsets.all(6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Form(
                          key: _formKey,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _nameController,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.06),
                                    labelText: "Nome da Rotina",
                                    labelStyle: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 12),
                                    floatingLabelStyle: TextStyle(
                                        color: accentColor,
                                        fontWeight: FontWeight.w800),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                          color: accentColor, width: 1.5),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                  ),
                                  validator: (value) =>
                                      (value == null || value.trim().isEmpty)
                                          ? "Obrigatório"
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _restController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.06),
                                    labelText: "Descanso (s)",
                                    labelStyle: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 12),
                                    floatingLabelStyle: TextStyle(
                                        color: accentColor,
                                        fontWeight: FontWeight.w800),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                          color: accentColor, width: 1.5),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                  ),
                                  validator: (value) => (value == null ||
                                          int.tryParse(value) == null)
                                      ? "Inválido"
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Exercícios",
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2),
                            ),
                            if (_exercises.isNotEmpty)
                              Text(
                                "${_exercises.length} ${_exercises.length == 1 ? 'exercício' : 'exercícios'}",
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Lista de exercícios adicionados na rotina
                        if (_exercises.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.fitness_center,
                                      size: 36,
                                      color: Colors.white.withOpacity(0.15)),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Nenhum exercício adicionado ainda.\nToque no botão abaixo para adicionar.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.35),
                                        fontSize: 12,
                                        height: 1.4,
                                        fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Column(
                            children: _exercises.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final ex = entry.value;
                              final ref = library.firstWhere(
                                (l) => l.id == ex.exerciseId,
                                orElse: () => LibraryExercise(
                                    id: '',
                                    name: 'Deletado',
                                    muscle: '',
                                    measurementType: MeasurementType.reps),
                              );
                              final isCardio = ref.measurementType ==
                                      MeasurementType.cardio ||
                                  ref.measurementType ==
                                      MeasurementType.distance ||
                                  ref.measurementType == MeasurementType.time;
                              return Container(
                                key: ValueKey(ex.id),
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: accentColor.withOpacity(0.1),
                                      width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withOpacity(0.02),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    )
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            ref.name,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                letterSpacing: -0.1),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.04),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                        Icons
                                                            .arrow_upward_rounded,
                                                        color: idx == 0
                                                            ? Colors.white10
                                                            : Colors.white70,
                                                        size: 16),
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    constraints:
                                                        const BoxConstraints(),
                                                    onPressed: idx == 0
                                                        ? null
                                                        : () => _moveExercise(
                                                            idx, true),
                                                  ),
                                                  Container(
                                                      width: 1,
                                                      height: 16,
                                                      color: Colors.white10),
                                                  IconButton(
                                                    icon: Icon(
                                                        Icons
                                                            .arrow_downward_rounded,
                                                        color: idx ==
                                                                _exercises
                                                                        .length -
                                                                    1
                                                            ? Colors.white10
                                                            : Colors.white70,
                                                        size: 16),
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    constraints:
                                                        const BoxConstraints(),
                                                    onPressed: idx ==
                                                            _exercises.length -
                                                                1
                                                        ? null
                                                        : () => _moveExercise(
                                                            idx, false),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _exercises.removeAt(idx);
                                                });
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.close_rounded,
                                                  color: Colors.redAccent,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Cardio mode toggle
                                    if (isCardio) ...[
                                      Row(
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _updateExerciseField(idx,
                                                      sets: 1);
                                                  _exercises[idx] =
                                                      RoutineExercise(
                                                    id: ex.id,
                                                    exerciseId: ex.exerciseId,
                                                    sets: 1,
                                                    reps: ex.reps,
                                                    rest: ex.rest,
                                                    weight: ex.weight,
                                                    weightsPerSet:
                                                        ex.weightsPerSet,
                                                    repsPerSet: ex.repsPerSet,
                                                    isCardio: true,
                                                    allowCardioSets: false,
                                                  );
                                                });
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: !ex.allowCardioSets
                                                      ? accentColor
                                                          .withOpacity(0.15)
                                                      : Colors.white
                                                          .withOpacity(0.04),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: !ex.allowCardioSets
                                                        ? accentColor
                                                            .withOpacity(0.5)
                                                        : Colors.white
                                                            .withOpacity(0.08),
                                                  ),
                                                ),
                                                child: Text(
                                                  "Sessão Única",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: !ex.allowCardioSets
                                                        ? accentColor
                                                        : Colors.white60,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _updateExerciseField(idx,
                                                      sets: ex.sets > 0
                                                          ? ex.sets
                                                          : 3);
                                                  _exercises[idx] =
                                                      RoutineExercise(
                                                    id: ex.id,
                                                    exerciseId: ex.exerciseId,
                                                    sets: ex.sets > 0
                                                        ? ex.sets
                                                        : 3,
                                                    reps: ex.reps,
                                                    rest: ex.rest,
                                                    weight: ex.weight,
                                                    weightsPerSet:
                                                        ex.weightsPerSet,
                                                    repsPerSet: ex.repsPerSet,
                                                    isCardio: true,
                                                    allowCardioSets: true,
                                                  );
                                                });
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: ex.allowCardioSets
                                                      ? accentColor
                                                          .withOpacity(0.15)
                                                      : Colors.white
                                                          .withOpacity(0.04),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: ex.allowCardioSets
                                                        ? accentColor
                                                            .withOpacity(0.5)
                                                        : Colors.white
                                                            .withOpacity(0.08),
                                                  ),
                                                ),
                                                child: Text(
                                                  "Múltiplas Séries (HIIT)",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: ex.allowCardioSets
                                                        ? accentColor
                                                        : Colors.white60,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    Row(
                                      children: [
                                        if (!isCardio || ex.allowCardioSets)
                                          Expanded(
                                            child: _buildInputRow(
                                              label: isCardio
                                                  ? "Séries"
                                                  : "Séries",
                                              value: ex.sets.toString(),
                                              onChanged: (val) {
                                                _updateExerciseField(idx,
                                                    sets:
                                                        int.tryParse(val) ?? 0);
                                              },
                                            ),
                                          ),
                                        if (!isCardio || ex.allowCardioSets)
                                          const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildInputRow(
                                            label: isCardio
                                                ? "Minutos"
                                                : (ref.measurementType ==
                                                        MeasurementType.time
                                                    ? "Segundos"
                                                    : "Reps"),
                                            value: ex.reps.toString(),
                                            onChanged: (val) {
                                              _updateExerciseField(idx,
                                                  reps: int.tryParse(val) ?? 0);
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
                                                _updateExerciseField(idx,
                                                    weight:
                                                        double.tryParse(val) ??
                                                            0.0);
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
                                              _updateExerciseField(idx,
                                                  rest: int.tryParse(val) ?? 0);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add_circle_outline,
                                color: Colors.black, size: 18),
                            label: const Text(
                              "ADICIONAR EXERCÍCIO",
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              _addExercisePicker(sortedLibrary);
                            },
                          ),
                        ),
                      ],
                    ),
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
                              content: Text(
                                  "Adicione pelo menos um exercício à rotina!"),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        // Validar se há exercícios com 0 séries ou reps
                        bool anyInvalid = false;
                        for (var ex in _exercises) {
                          // For cardio with single session, sets can be 1 and reps can be 0
                          if (ex.isCardio && !ex.allowCardioSets) {
                            if (ex.sets <= 0) {
                              anyInvalid = true;
                              break;
                            }
                          } else {
                            // For traditional exercises or cardio with sets
                            if (ex.sets <= 0 || ex.reps <= 0) {
                              anyInvalid = true;
                              break;
                            }
                          }
                        }
                        if (anyInvalid) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "Todas as séries e repetições/tempo devem ser maiores que zero!"),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(
                      widget.existing == null
                          ? "Criar Rotina"
                          : "Salvar Alterações",
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 14),
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

  Widget _buildInputRow(
      {required String label,
      required String value,
      required ValueChanged<String> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
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
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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

  void _updateExerciseField(int index,
      {int? sets, int? reps, double? weight, int? rest}) {
    final cur = _exercises[index];
    _exercises[index] = RoutineExercise(
      id: cur.id,
      exerciseId: cur.exerciseId,
      sets: sets ?? cur.sets,
      reps: reps ?? cur.reps,
      weight: weight ?? cur.weight,
      rest: rest ?? cur.rest,
      isCardio: cur.isCardio,
      allowCardioSets: cur.allowCardioSets,
    );
  }

  void _addExercisePicker(List<LibraryExercise> library) {
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
    required this.library,
    required this.accentColor,
    required this.onSave,
  });

  @override
  State<_ExerciseSelectionSheet> createState() =>
      _ExerciseSelectionSheetState();
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
      if (_searchQuery.isNotEmpty &&
          !ex.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        continue;
      }
      grouped.putIfAbsent(ex.muscle, () => []).add(ex);
    }

    final sortedMuscles = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final allMusclesForChips = widget.library
        .map((e) => e.muscle)
        .toSet()
        .toList()
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
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white38, size: 24),
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
                  icon: Icon(Icons.search,
                      color: Colors.white.withOpacity(0.3), size: 20),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
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
                            color: isSelected
                                ? widget.accentColor
                                : Colors.white60,
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
              itemCount: sortedMuscles
                  .where((m) =>
                      _activeFilters.isEmpty || _activeFilters.contains(m))
                  .length,
              itemBuilder: (context, mIdx) {
                final filteredMuscles = sortedMuscles
                    .where((m) =>
                        _activeFilters.isEmpty || _activeFilters.contains(m))
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
                                  color: isSelected
                                      ? widget.accentColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? widget.accentColor
                                        : Colors.white38,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        color: Colors.black, size: 16)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  ex.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 16,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
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
                border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.05))),
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
                      color: isSelected
                          ? widget.accentColor.withOpacity(0.15)
                          : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? widget.accentColor
                            : Colors.white.withOpacity(0.08),
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
                      style: TextStyle(
                          color: Colors.white38, fontStyle: FontStyle.italic),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(
                        left: 16, right: 16, top: 8, bottom: 100),
                    itemCount: sortedMuscles.length,
                    itemBuilder: (context, mIdx) {
                      final muscle = sortedMuscles[mIdx];
                      final exs = groupedExs[muscle]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 16, bottom: 8, left: 4),
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
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ExerciseHubScreen(exercise: ex),
                                    ),
                                  );
                                },
                                child: GlassCard(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  borderColor: Colors.white.withOpacity(0.04),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                ex.name,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w700),
                                              ),
                                              if (ex.measurementType ==
                                                  MeasurementType.time) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber
                                                        .withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: const Text(
                                                    "Isometria",
                                                    style: TextStyle(
                                                        color: Colors.amber,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                              if (ex.executionType != null &&
                                                  ex.executionType!
                                                      .isNotEmpty) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blueAccent
                                                        .withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Text(
                                                    ex.executionType!,
                                                    style: const TextStyle(
                                                        color:
                                                            Colors.blueAccent,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "${ex.muscle} • ${_getMeasurementTypeLabelStatic(ex.measurementType)}",
                                            style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 11),
                                          ),
                                          if (ex.notes != null &&
                                              ex.notes!.trim().isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              ex.notes!,
                                              style: const TextStyle(
                                                  color: Colors.white24,
                                                  fontSize: 10,
                                                  fontStyle: FontStyle.italic),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              color: Colors.white70, size: 18),
                                          onPressed: () {
                                            _openAddExerciseDialog(
                                                context, provider,
                                                existing: ex);
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.redAccent,
                                              size: 18),
                                          onPressed: () {
                                            _confirmDeleteExercise(
                                                context, provider, ex);
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

  void _confirmDeleteExercise(
      BuildContext context, WorkoutProvider provider, LibraryExercise ex) {
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
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                "Deseja realmente deletar '${ex.name}' da biblioteca?",
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text("Cancelar",
                        style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      provider.deleteLibraryExercise(ex.id);
                      Navigator.pop(dialogCtx);
                    },
                    child: const Text("Excluir",
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddExerciseDialog(BuildContext context, WorkoutProvider provider,
      {LibraryExercise? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? "");
    String category = existing != null
        ? (existing.muscle == "Cardio" ? "Cardio" : "Musculação")
        : "Musculação";
    String muscle = existing != null
        ? (existing.muscle == "Cardio" ? "Peito" : existing.muscle)
        : "Peito";
    String equipment = existing?.executionType ?? "Barra";
    String measurement = existing != null
        ? (existing.measurementType == MeasurementType.time
            ? "Tempo de Isometria"
            : "Repetições")
        : "Repetições";
    if (existing != null && existing.muscle == "Cardio") {
      if (existing.measurementType == MeasurementType.cardio) {
        measurement = "Cardio (distância + tempo)";
      } else if (existing.measurementType == MeasurementType.distance) {
        measurement = "Distância";
      } else if (existing.measurementType == MeasurementType.time) {
        measurement = "Tempo";
      }
    }
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
                          Icon(
                              existing == null
                                  ? Icons.add_circle_outline_rounded
                                  : Icons.edit_calendar_rounded,
                              color: widget.accentColor,
                              size: 22),
                          const SizedBox(width: 8),
                          Text(
                            existing == null
                                ? "Novo Exercício"
                                : "Editar Exercício",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Nome
                      TextField(
                        controller: nameCtrl,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.03),
                          hintText: "Nome do Exercício",
                          hintStyle: const TextStyle(
                              color: Colors.white30, fontSize: 13),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: widget.accentColor.withOpacity(0.5),
                                width: 1.5),
                          ),
                          prefixIcon: const Icon(Icons.edit_note_rounded,
                              color: Colors.white30, size: 20),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tipo de Exercício
                      const Text("Tipo de Exercício",
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
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
                                      color: category == "Musculação"
                                          ? Colors.white
                                          : Colors.white60,
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
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
                                      color: category == "Cardio"
                                          ? Colors.white
                                          : Colors.white60,
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
                        const Text("Agrupamento Muscular",
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: muscle,
                              dropdownColor: const Color(0xff1c1c1e),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                              isExpanded: true,
                              icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white54),
                              onChanged: (val) {
                                if (val != null) setState(() => muscle = val);
                              },
                              items: [
                                "Peito",
                                "Costas",
                                "Pernas",
                                "Ombros",
                                "Bíceps",
                                "Tríceps",
                                "Core",
                                "Outros"
                              ]
                                  .map((m) => DropdownMenuItem(
                                      value: m, child: Text(m)))
                                  .toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Tipo de Equipamento (se Musculação)
                      if (category == "Musculação") ...[
                        const Text("Tipo de Equipamento",
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: equipment,
                              dropdownColor: const Color(0xff1c1c1e),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                              isExpanded: true,
                              icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white54),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => equipment = val);
                                }
                              },
                              items: ["Barra", "Haltere", "Máquina", "Livre"]
                                  .map((m) => DropdownMenuItem(
                                      value: m, child: Text(m)))
                                  .toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Tipo de Medição (se Musculação)
                      if (category == "Musculação") ...[
                        const Text("Tipo de Medição",
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => measurement = "Repetições"),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
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
                                        color: measurement == "Repetições"
                                            ? Colors.white
                                            : Colors.white60,
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
                                onTap: () => setState(
                                    () => measurement = "Tempo de Isometria"),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
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
                                        color:
                                            measurement == "Tempo de Isometria"
                                                ? Colors.white
                                                : Colors.white60,
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
                        const Text("Tipo de Medição",
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() =>
                                    measurement = "Cardio (distância + tempo)"),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: measurement ==
                                            "Cardio (distância + tempo)"
                                        ? widget.accentColor.withOpacity(0.12)
                                        : Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: measurement ==
                                              "Cardio (distância + tempo)"
                                          ? widget.accentColor.withOpacity(0.4)
                                          : Colors.white.withOpacity(0.08),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      "Distância + Tempo",
                                      style: TextStyle(
                                        color: measurement ==
                                                "Cardio (distância + tempo)"
                                            ? Colors.white
                                            : Colors.white60,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => measurement = "Distância"),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: measurement == "Distância"
                                        ? widget.accentColor.withOpacity(0.12)
                                        : Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: measurement == "Distância"
                                          ? widget.accentColor.withOpacity(0.4)
                                          : Colors.white.withOpacity(0.08),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      "Apenas Distância",
                                      style: TextStyle(
                                        color: measurement == "Distância"
                                            ? Colors.white
                                            : Colors.white60,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => measurement = "Tempo"),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: measurement == "Tempo"
                                        ? widget.accentColor.withOpacity(0.12)
                                        : Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: measurement == "Tempo"
                                          ? widget.accentColor.withOpacity(0.4)
                                          : Colors.white.withOpacity(0.08),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      "Apenas Tempo",
                                      style: TextStyle(
                                        color: measurement == "Tempo"
                                            ? Colors.white
                                            : Colors.white60,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
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

                      // Observação
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.03),
                          hintText: "Observação (Opcional)",
                          hintStyle: const TextStyle(
                              color: Colors.white30, fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: widget.accentColor.withOpacity(0.5),
                                width: 1.5),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Cancelar",
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final name = nameCtrl.text.trim();
                                if (name.isNotEmpty) {
                                  final isCardioEx = category == "Cardio";
                                  String mType;
                                  if (isCardioEx) {
                                    if (measurement ==
                                        "Cardio (distância + tempo)") {
                                      mType = "cardio";
                                    } else if (measurement == "Distância") {
                                      mType = "distance";
                                    } else if (measurement == "Tempo") {
                                      mType = "time";
                                    } else {
                                      mType = "cardio"; // Default
                                    }
                                  } else {
                                    mType = measurement == "Tempo de Isometria"
                                        ? "time"
                                        : "reps";
                                  }
                                  final execType =
                                      isCardioEx ? "Livre" : equipment;

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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: Text(
                                  existing == null ? "Adicionar" : "Salvar",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
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
