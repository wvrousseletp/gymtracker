import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/tracker_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/profile_provider.dart';
import '../models/routine.dart';
import '../models/exercise.dart';
import '../models/workout_log.dart';
import '../models/planner_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/profile_avatar.dart';
import '../services/rest_timer_service.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  // Retorna a chave do dia atual compatível com o planner ('seg', 'ter', etc.)
  String _getTodayKey() {
    final weekday = DateTime.now().weekday;
    switch (weekday) {
      case 1: return 'seg';
      case 2: return 'ter';
      case 3: return 'qua';
      case 4: return 'qui';
      case 5: return 'sex';
      case 6: return 'sab';
      case 7: return 'dom';
      default: return 'seg';
    }
  }

  String _getTodayLabel() {
    final weekday = DateTime.now().weekday;
    switch (weekday) {
      case 1: return 'Segunda-feira';
      case 2: return 'Terça-feira';
      case 3: return 'Quarta-feira';
      case 4: return 'Quinta-feira';
      case 5: return 'Sexta-feira';
      case 6: return 'Sábado';
      case 7: return 'Domingo';
      default: return 'Segunda-feira';
    }
  }

  bool _isRoutineCompletedToday(String name, List<WorkoutLog> history) {
    final todayStr = DateTime.now().toLocal().toString().substring(0, 10);
    return history.any((log) {
      if (log.name != name) return false;
      try {
        final logDate = DateTime.parse(log.date).toLocal();
        return logDate.toString().substring(0, 10) == todayStr;
      } catch (e) {
        return false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WorkoutProvider>(context);
    final activeWorkout = provider.activeWorkout;

    // Alternar visualização com base na presença de um treino ativo
    if (activeWorkout != null && !activeWorkout.postponed) {
      final trackerProvider = Provider.of<TrackerProvider>(context, listen: true);
      return ActiveWorkoutView(activeWorkout: activeWorkout, provider: trackerProvider);
    } else {
      return _buildIdleView(context, provider);
    }
  }

  Widget _buildIdleView(BuildContext context, WorkoutProvider provider) {
    final todayKey = _getTodayKey();
    final todayLabel = _getTodayLabel();
    final plannedRoutineIds = provider.planner[todayKey] ?? [];
    final accentColor = context.select<ProfileProvider, Color>(
      (p) => ThemeUtils.getColor(p.currentProfile.colorAccent),
    );

    // Mapear IDs do planejador para as rotinas reais do usuário
    final List<Routine> plannedRoutines = plannedRoutineIds.map((item) {
      if (item.isEmpty) return null;
      if (item.startsWith('exercise:')) {
        final parts = item.split(':');
        if (parts.length >= 3) {
          final exerciseId = parts[1];
          final sets = int.tryParse(parts[2]) ?? 3;
          final libEx = provider.library.where((l) => l.id == exerciseId).firstOrNull;
          if (libEx != null) {
            final isCardio = libEx.muscle.toLowerCase().contains('cardio');
            return Routine(
              id: "temp-$exerciseId-$sets",
              name: "${libEx.name} (Avulso)",
              defaultRest: 60,
              exercises: [
                RoutineExercise(
                  id: "e-temp-${const Uuid().v4()}",
                  exerciseId: exerciseId,
                  sets: isCardio ? 1 : sets,
                  reps: isCardio ? sets : (libEx.measurementType == MeasurementType.time ? 45 : 10),
                  rest: 60,
                  weight: 0,
                )
              ],
            );
          }
        }
        return null;
      } else {
        String routineId = item;
        if (item.startsWith('routine:')) {
          routineId = item.substring(8);
        }
        return provider.routines.where((r) => r.id == routineId).firstOrNull;
      }
    }).whereType<Routine>().toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de Treino Adiado
            if (provider.activeWorkout != null && provider.activeWorkout!.postponed)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GlassCard(
                  borderColor: accentColor.withOpacity(0.3),
                  opacity: 0.05,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.snooze, color: accentColor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "TREINO ADIADO EM ANDAMENTO",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              provider.activeWorkout!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          provider.resumeActiveWorkout();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          "Continuar",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Cabeçalho de treinos de hoje
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "HOJE É",
                      style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                    Text(
                      todayLabel.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                // Botão de Ajustes Rápidos
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                  onPressed: () {
                    _showSettingsDialog(context, Provider.of<TrackerProvider>(context, listen: false));
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cartões de Treinos Planejados
            const Text(
              "Treino Planejado para Hoje",
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            if (plannedRoutines.isEmpty)
              const GlassCard(
                padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Center(
                  child: Text(
                    "Nenhum treino planejado para hoje.\nConfigure na aba 'Planejar' ou inicie um treino rápido abaixo.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else
              Column(
                children: plannedRoutines.map((routine) {
                  final isCompleted = _isRoutineCompletedToday(routine.name, provider.history);
                  final totalSets = routine.exercises.fold<int>(0, (sum, ex) => sum + ex.sets);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () {
                        // Ao clicar no card, abre uma visão dos exercícios agendados
                        _showPlannedRoutineDetails(context, provider, routine);
                      },
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        borderColor: isCompleted ? Colors.green.withOpacity(0.35) : Colors.white.withOpacity(0.04),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          routine.name,
                                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      if (isCompleted) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.green.withOpacity(0.35)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check, color: Colors.green, size: 10),
                                              SizedBox(width: 2),
                                              Text(
                                                "CONCLUÍDO",
                                                style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.w900),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "${routine.exercises.length} exercício(s) • $totalSets séries no total",
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () {
                                provider.startWorkout(
                                  routine,
                                  WorkoutRecovery(sleepOk: SleepQuality.okay, pain: [], warmUpDone: false),
                                  false,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isCompleted ? Colors.white.withOpacity(0.1) : accentColor,
                                foregroundColor: isCompleted ? Colors.white : Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                elevation: 0,
                              ),
                              child: Text(
                                isCompleted ? "Treinar Denovo" : "Iniciar",
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 24),

            // Iniciar Treino Avulso/Rápido
            const Text(
              "Treino Rápido (Qualquer Rotina)",
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            if (provider.routines.isEmpty)
              const GlassCard(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    "Nenhuma rotina cadastrada na biblioteca.",
                    style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.2,
                children: provider.routines.map((routine) {
                  return GestureDetector(
                    onTap: () {
                      provider.startWorkout(
                        routine,
                        WorkoutRecovery(sleepOk: SleepQuality.okay, pain: [], warmUpDone: false),
                        false,
                      );
                    },
                    child: GlassCard(
                      padding: const EdgeInsets.all(10),
                      borderColor: Colors.white.withOpacity(0.04),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routine.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${routine.exercises.length} ex • rest ${routine.defaultRest}s",
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),

            // Iniciar Exercício Avulso
            const Text(
              "Iniciar Exercício Avulso",
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            GestureDetector(
              onTap: () {
                _showSelectExerciseDialog(context, provider);
              },
              child: GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                borderColor: Colors.white.withOpacity(0.04),
                child: Row(
                  children: [
                    Icon(Icons.play_circle_outline, color: accentColor, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Selecionar da Biblioteca",
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Inicie uma sessão de treino rápida com unicamente esse exercício",
                            style: TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlannedRoutineDetails(BuildContext context, WorkoutProvider provider, Routine routine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: BoxDecoration(
              color: const Color(0xff141416).withOpacity(0.65),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  routine.name,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: routine.exercises.length,
                    itemBuilder: (context, idx) {
                      final ex = routine.exercises[idx];
                      final libEx = provider.library.firstWhere(
                        (l) => l.id == ex.exerciseId,
                        orElse: () => LibraryExercise(id: '', name: 'Deletado', muscle: '', measurementType: MeasurementType.reps),
                      );
                      final isCardio = libEx.muscle.toLowerCase().contains('cardio');

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(libEx.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Text(libEx.muscle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        trailing: Text(
                          isCardio
                              ? "${ex.reps} min"
                              : "${ex.sets}x${ex.reps} @ ${ex.weight.toStringAsFixed(1).replaceAll('.0', '')}kg",
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Check if there are any cardio exercises in this routine
                      final hasCardio = routine.exercises.any((ex) {
                        final libEx = provider.library.firstWhere(
                          (l) => l.id == ex.exerciseId,
                          orElse: () => LibraryExercise(id: '', name: '', muscle: '', measurementType: MeasurementType.reps),
                        );
                        return libEx.muscle.toLowerCase().contains('cardio');
                      });

                      double customDistance = 0.0;
                      int customDurationMinutes = 30;

                      if (hasCardio) {
                        final result = await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (dialogCtx) {
                            final distCtrl = TextEditingController(text: "5.0");
                            final durCtrl = TextEditingController(text: "30");
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
                                    const Text(
                                      "Métricas de Cardio",
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      "Informe a distância e duração do seu treino de hoje:",
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: distCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        labelText: "Distância (km)",
                                        labelStyle: const TextStyle(color: Colors.white70),
                                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
                                        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: durCtrl,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        labelText: "Duração (minutos)",
                                        labelStyle: const TextStyle(color: Colors.white70),
                                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
                                        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                                      ),
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
                                            final d = double.tryParse(distCtrl.text) ?? 0.0;
                                            final t = int.tryParse(durCtrl.text) ?? 30;
                                            Navigator.pop(dialogCtx, {"distance": d, "duration": t});
                                          },
                                          child: const Text("Salvar", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );

                        if (result == null) {
                          // User cancelled the cardio prompt
                          return;
                        }
                        customDistance = result["distance"] as double;
                        customDurationMinutes = result["duration"] as int;
                      }

                      final nowUtc = DateTime.now().toUtc().toIso8601String();
                      final totalSets = routine.exercises.fold<int>(0, (sum, ex) => sum + ex.sets);
                      final totalWeight = routine.exercises.fold<double>(0, (sum, ex) => sum + (ex.sets * ex.weight));
                      
                      final List<LogExercise> logExercises = routine.exercises.map((re) {
                        final lib = provider.library.firstWhere(
                          (l) => l.id == re.exerciseId,
                          orElse: () => LibraryExercise(id: '', name: 'Exercício', muscle: 'Geral', measurementType: MeasurementType.reps),
                        );
                        
                        final isExCardio = lib.muscle.toLowerCase().contains('cardio');
                        return LogExercise(
                          name: lib.name,
                          muscle: lib.muscle,
                          sets: re.sets,
                          completedSets: re.sets,
                          reps: isExCardio ? customDurationMinutes : re.reps,
                          weight: isExCardio ? customDistance : re.weight,
                          rpe: 8,
                          performedCardios: isExCardio 
                              ? List.generate(re.sets, (i) => PerformedCardio(distanceKm: customDistance, durationSeconds: customDurationMinutes * 60))
                              : [],
                          failureReport: List.filled(re.sets, false),
                          failureReps: List.filled(re.sets, null),
                        );
                      }).toList();

                      final newLog = WorkoutLog(
                        id: "l-${const Uuid().v4()}",
                        name: routine.name,
                        date: nowUtc,
                        duration: customDurationMinutes * 60, // custom card duration
                        completedSets: totalSets,
                        totalSets: totalSets,
                        totalWeight: hasCardio ? 0.0 : totalWeight,
                        rpe: 8,
                        notes: "Concluído manualmente sem celular",
                        avgHeartRate: null,
                        activeCalories: null,
                        exercises: logExercises,
                      );

                      provider.addManualWorkoutLog(newLog);
                      Navigator.pop(context);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Treino '${routine.name}' concluído com sucesso!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline, color: Colors.black, size: 18),
                    label: const Text(
                      "MARCAR COMO CONCLUÍDO",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
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

  void _showSelectExerciseDialog(BuildContext context, WorkoutProvider provider) {
    final library = provider.library;
    final accentColor = ThemeUtils.getColor(Provider.of<ProfileProvider>(context, listen: false).currentProfile.colorAccent);
    
    if (library.isEmpty) {
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
                  "Biblioteca Vazia",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Cadastre alguns exercícios na aba 'Rotinas' primeiro.",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text("OK", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      isScrollControlled: true,
      builder: (context) {
        String searchQuery = "";
        return StatefulBuilder(
          builder: (context, setState) {
            final filteredList = library.where((ex) {
              return ex.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  ex.muscle.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  decoration: BoxDecoration(
                    color: const Color(0xff141416).withOpacity(0.65),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Cabeçalho
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Iniciar Exercício",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Campo de busca
                      TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Buscar exercício ou grupo muscular...",
                          hintStyle: const TextStyle(color: Colors.white30),
                          prefixIcon: const Icon(Icons.search, color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (val) {
                          setState(() {
                            searchQuery = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Lista de exercícios
                      Expanded(
                        child: filteredList.isEmpty
                            ? const Center(
                                child: Text(
                                  "Nenhum exercício encontrado.",
                                  style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
                                ),
                              )
                            : () {
                                // Agrupar por músculo
                                final Map<String, List<LibraryExercise>> grouped = {};
                                for (final ex in filteredList) {
                                  grouped.putIfAbsent(ex.muscle, () => []).add(ex);
                                }
                                final sortedMuscles = grouped.keys.toList()
                                  ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

                                return ListView.builder(
                                  itemCount: sortedMuscles.length,
                                  itemBuilder: (context, mIdx) {
                                    final muscle = sortedMuscles[mIdx];
                                    final exs = grouped[muscle]!;
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
                                          child: Text(
                                            muscle.toUpperCase(),
                                            style: TextStyle(
                                              color: accentColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                        ...exs.map((ex) {
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.02),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.white.withOpacity(0.04)),
                                            ),
                                            child: ListTile(
                                              title: Text(
                                                ex.name,
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                              subtitle: Text(
                                                ex.measurementType == MeasurementType.time ? 'Isometria' : 'Repetições',
                                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                                              ),
                                              trailing: const Icon(Icons.play_arrow_rounded, color: Colors.white54),
                                              onTap: () {
                                                Navigator.pop(context); // fecha modal
                                                provider.startSingleExercise(ex);
                                              },
                                            ),
                                          );
                                        }),
                                      ],
                                    );
                                  },
                                );
                              }(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSettingsDialog(BuildContext context, TrackerProvider provider) {
    final soundState = ValueNotifier<bool>(provider.state!.settings.sound);
    final vibrationState = ValueNotifier<bool>(provider.state!.settings.vibration);
    final prepController = TextEditingController(text: provider.state!.settings.prepSeconds.toString());
    final waterController = TextEditingController(text: (provider.state?.diet.waterGoalMl ?? 2000).toString());
    final accentColor = ThemeUtils.getColor(provider.currentProfile.colorAccent);

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: GlassCard(
          useBlur: true,
          borderColor: Colors.white.withOpacity(0.08),
          borderRadius: 24,
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings, color: accentColor, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      "Configurações Gerais",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // SEÇÃO TREINO
                const Text(
                  "TREINO 🏋️",
                  style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: soundState,
                  builder: (context, val, child) => SwitchListTile(
                    title: const Text("Bips Sonoros", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    value: val,
                    activeColor: accentColor,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (newVal) => soundState.value = newVal,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: vibrationState,
                  builder: (context, val, child) => SwitchListTile(
                    title: const Text("Vibração", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    value: val,
                    activeColor: accentColor,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (newVal) => vibrationState.value = newVal,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Tempo de Preparo", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    Container(
                      width: 60,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: TextField(
                        controller: prepController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // SEÇÃO DIETA/HIDRATAÇÃO
                const Text(
                  "HIDRATAÇÃO 💧",
                  style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Meta de Água (ml)", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    Container(
                      width: 70,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: TextField(
                        controller: waterController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Backup de Dados", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final jsonStr = json.encode(provider.state?.toJson() ?? {});
                          await Clipboard.setData(ClipboardData(text: jsonStr));
                          final dir = await getApplicationDocumentsDirectory();
                          final file = File('${dir.path}/los_mooscles_backup.json');
                          await file.writeAsString(jsonStr);
                          
                          if (dialogCtx.mounted) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xff1c1c1e),
                                content: Text(
                                  "Backup salvo em ${file.path.split('/').last} e copiado para a área de transferência!",
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (dialogCtx.mounted) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.redAccent,
                                content: Text("Erro ao exportar dados: $e"),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        foregroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: accentColor.withOpacity(0.3)),
                        ),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text("Exportar", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // AÇÕES
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
                        final prep = int.tryParse(prepController.text.trim()) ?? 5;
                        final waterGoal = int.tryParse(waterController.text.trim()) ?? 2000;
                        provider.updateSettings(soundState.value, vibrationState.value, prep);
                        provider.updateWaterGoal(waterGoal);
                        Navigator.pop(dialogCtx);
                      },
                      child: Text("Salvar", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// VIEW DE TREINO ATIVO (ACTIVE WORKOUT VIEW)
// ==========================================
class ActiveWorkoutView extends StatefulWidget {
  final ActiveWorkoutState activeWorkout;
  final TrackerProvider provider;

  const ActiveWorkoutView({
    super.key,
    required this.activeWorkout,
    required this.provider,
  });

  @override
  State<ActiveWorkoutView> createState() => _ActiveWorkoutViewState();
}

class _ActiveWorkoutViewState extends State<ActiveWorkoutView> {
  Timer? _stopwatchTimer;
  Timer? _healthSyncTimer;
  late final ValueNotifier<int> _workoutDurationNotifier;

  // ─── Rest/Prep timer – driven by RestTimerService (global singleton) ───
  // We only keep local UI state here; the actual countdown runs in the service.
  // _countdownSecondsNotifier mirrors RestTimerService.secondsRemaining so the
  // circular ring and text update each second, but the timer keeps running even
  // when this widget is not mounted (user navigated to another tab).
  bool _timerActive = false;
  bool _timerIsPrep = false;
  String _timerNextExName = '';
  int _timerNextSetNum = 0;
  int _countdownTotalSeconds = 0;

  // Track last endTime to avoid re-registering the same timer
  int _lastEndTime = 0;

  // Controladores de páginas para exercícios
  int _currentExIdx = 0;

  @override
  void initState() {
    super.initState();
    _currentExIdx = widget.activeWorkout.currentExerciseIndex;
    _workoutDurationNotifier = ValueNotifier<int>(widget.activeWorkout.elapsedSeconds);

    // Iniciar cronômetro do treino
    _startStopwatch();

    // Sincronizar métricas de saúde inicialmente e a cada 15 segundos
    widget.provider.syncHealthMetrics();
    _healthSyncTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      widget.provider.syncHealthMetrics();
    });

    // Ouvir alterações do provedor para sincronizar timer de descanso e exercício atual
    widget.provider.addListener(_onProviderChange);

    // Listen to RestTimerService for tick sounds (the service itself handles the countdown)
    RestTimerService.instance.secondsRemaining.addListener(_onRestTimerTick);

    // Sync initial timer state from service (in case user navigated back during rest)
    _syncFromService();
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderChange);
    RestTimerService.instance.secondsRemaining.removeListener(_onRestTimerTick);
    _stopwatchTimer?.cancel();
    _healthSyncTimer?.cancel();
    _workoutDurationNotifier.dispose();
    super.dispose();
  }

  void _startStopwatch() {
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!widget.activeWorkout.paused) {
        _workoutDurationNotifier.value++;
        // Sincroniza periodicamente com o provider
        widget.provider.updateWorkoutTimer(_workoutDurationNotifier.value);
      }
    });
  }

  /// Called every second by RestTimerService – play tick sound if near end.
  void _onRestTimerTick() {
    if (!mounted) return;
    final remaining = RestTimerService.instance.secondsRemaining.value;
    final settings = widget.provider.state?.settings;
    if (settings?.sound == true && remaining <= 3 && remaining > 0) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// Sync local UI state from the global RestTimerService.
  void _syncFromService() {
    final svc = RestTimerService.instance;
    final active = svc.isActive.value;
    if (active != _timerActive ||
        svc.isPrep.value != _timerIsPrep ||
        svc.nextExName.value != _timerNextExName ||
        svc.nextSetNum.value != _timerNextSetNum ||
        svc.totalSeconds.value != _countdownTotalSeconds) {
      if (mounted) {
        setState(() {
          _timerActive = active;
          _timerIsPrep = svc.isPrep.value;
          _timerNextExName = svc.nextExName.value;
          _timerNextSetNum = svc.nextSetNum.value;
          _countdownTotalSeconds = svc.totalSeconds.value;
        });
      }
    }
  }

  void _onProviderChange() {
    if (!mounted) return;
    final active = widget.provider.state?.activeWorkout;
    if (active == null) return;

    if (active.currentExerciseIndex != _currentExIdx) {
      setState(() {
        _currentExIdx = active.currentExerciseIndex;
      });
    }

    final timerState = active.restTimer;
    if (timerState == null) {
      if (_timerActive) {
        setState(() {
          _timerActive = false;
        });
      }
    } else {
      // A new timer started in the provider – register its completion callback
      // only if the endTime changed (avoid duplicate registrations).
      if (_lastEndTime != timerState.endTime) {
        _lastEndTime = timerState.endTime;
        // The RestTimerService was already started by TrackerProvider.startRestTimer().
        // We just update local UI state and attach the completion callback.
        RestTimerService.instance.onTimerCompleted = _handleTimerCompleted;
      }
      final svc = RestTimerService.instance;
      setState(() {
        _timerActive = svc.isActive.value;
        _timerIsPrep = svc.isPrep.value;
        _countdownTotalSeconds = svc.totalSeconds.value;
        _timerNextExName = svc.nextExName.value;
        _timerNextSetNum = svc.nextSetNum.value;
      });
    }
  }

  void _handleTimerCompleted() {
    if (!mounted) return;
    final settings = widget.provider.state?.settings;
    if (settings?.vibration == true) {
      HapticFeedback.vibrate();
    }
    if (settings?.sound == true) {
      SystemSound.play(SystemSoundType.click);
    }

    setState(() {
      _timerActive = false;
    });

    if (!_timerIsPrep && settings != null) {
      // Transition from Rest to Prep automatically when rest finishes naturally
      widget.provider.startRestTimer(
        settings.prepSeconds,
        _timerNextExName,
        _timerNextSetNum,
        true,
      );
    } else {
      widget.provider.clearRestTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final workout = widget.activeWorkout;
    final exercises = workout.exercises;
    final accentColor = ThemeUtils.getColor(widget.provider.currentProfile.colorAccent);
    final hr = widget.provider.currentHeartRate > 0 ? widget.provider.currentHeartRate : workout.heartRate;
    final cal = widget.provider.todayBurnedCalories > 0 ? widget.provider.todayBurnedCalories : workout.activeCalories;
    final steps = widget.provider.todaySteps;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Tela Principal de Treino Ativo
          Column(
            children: [
              // Barra superior do treino
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workout.name.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable: _workoutDurationNotifier,
                            builder: (context, elapsed, child) {
                              return Text(
                                _formatDuration(elapsed),
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                              );
                            },
                          ),
                          if (hr > 0 || cal > 0 || steps > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (hr > 0) ...[
                                  const Icon(Icons.favorite, color: Colors.redAccent, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    "$hr bpm",
                                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                if (cal > 0) ...[
                                  const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    "$cal kcal",
                                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                if (steps > 0) ...[
                                  const Icon(Icons.directions_walk, color: Colors.blueAccent, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    "$steps passos",
                                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        // Adiar
                        IconButton(
                          icon: const Icon(Icons.snooze, color: Colors.amberAccent),
                          tooltip: "Adiar Treino",
                          onPressed: () {
                            widget.provider.postponeActiveWorkout();
                          },
                        ),
                        // Pausar
                        IconButton(
                          icon: Icon(workout.paused ? Icons.play_arrow : Icons.pause, color: Colors.white70),
                          onPressed: () {
                            widget.provider.pauseWorkout(!workout.paused);
                          },
                        ),
                        // Descartar
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.redAccent),
                          onPressed: () => _confirmDiscardWorkout(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Navegação do Exercício Ativo (Páginas)
              if (exercises.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 16),
                        onPressed: _currentExIdx == 0
                            ? null
                            : () {
                                setState(() {
                                  _currentExIdx--;
                                  widget.provider.setCurrentExerciseIndex(_currentExIdx);
                                });
                              },
                      ),
                      Text(
                        "Exercício ${_currentExIdx + 1} de ${exercises.length}",
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                        onPressed: _currentExIdx == exercises.length - 1
                            ? null
                            : () {
                                setState(() {
                                  _currentExIdx++;
                                  widget.provider.setCurrentExerciseIndex(_currentExIdx);
                                });
                              },
                      ),
                    ],
                  ),
                ),

                // Cartão do Exercício Atual
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _buildExerciseCard(exercises[_currentExIdx], _currentExIdx, accentColor),
                  ),
                ),
              ],

              // Botão Concluir Treino
              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 100.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      _showFinishWorkoutDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Finalizar Treino",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // OVERLAY DE DESCANSO / PREPARO ATIVO (CircularProgressTimer)
          if (_timerActive)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.92),
                child: Center(
                  child: GlassCard(
                    padding: const EdgeInsets.all(24),
                    borderColor: _timerIsPrep ? Colors.amber.withOpacity(0.3) : accentColor.withOpacity(0.3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _timerIsPrep ? "TEMPO DE PREPARO" : "DESCANSO ATIVO",
                          style: TextStyle(
                            color: _timerIsPrep ? Colors.amber : accentColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _timerIsPrep
                              ? "Prepare-se para: $_timerNextExName (Série $_timerNextSetNum)"
                              : "Próximo: $_timerNextExName (Série $_timerNextSetNum)",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 24),

                        // Relógio
                        ValueListenableBuilder<int>(
                          valueListenable: RestTimerService.instance.secondsRemaining,
                          builder: (context, remaining, child) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 140,
                                  height: 140,
                                  child: RepaintBoundary(
                                    child: CircularProgressIndicator(
                                      value: _countdownTotalSeconds > 0
                                          ? (remaining / _countdownTotalSeconds)
                                          : 0,
                                      strokeWidth: 8,
                                      backgroundColor: Colors.white.withOpacity(0.05),
                                      valueColor: AlwaysStoppedAnimation<Color>(_timerIsPrep ? Colors.amber : accentColor),
                                    ),
                                  ),
                                ),
                                Text(
                                  "$remaining",
                                  style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Ação pular
                        SizedBox(
                          width: 140,
                          child: ElevatedButton(
                            onPressed: () {
                              // RestTimerService is cleared via clearRestTimer() or startRestTimer() below
                              if (_timerIsPrep) {
                                widget.provider.clearRestTimer();
                              } else {
                                final settings = widget.provider.state!.settings;
                                widget.provider.startRestTimer(
                                  settings.prepSeconds,
                                  _timerNextExName,
                                  _timerNextSetNum,
                                  true,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.06),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.white.withOpacity(0.12)),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _timerIsPrep ? "Pular Preparo" : "Pular Descanso",
                              style: TextStyle(color: _timerIsPrep ? Colors.amber : accentColor, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(ActiveExercise ex, int exIdx, Color accentColor) {
    final isCardio = ex.muscle.toLowerCase().contains('cardio');

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: Colors.white.withOpacity(0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ex.name,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          Text(
            ex.executionType != null && ex.executionType!.isNotEmpty
                ? "${ex.muscle} • ${ex.executionType}"
                : ex.muscle,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Lista de Séries
          Builder(
            builder: (context) {
              final activeSetIdx = ex.setsState.indexOf(false);
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ex.sets,
                itemBuilder: (context, setIdx) {
                  final isDone = ex.setsState[setIdx];
                  final isFailure = ex.failureReport[setIdx];
                  final isActive = (setIdx == activeSetIdx);

                  if (isCardio) {
                    // RENDERIZAR SESSÃO DE CARDIO
                    final pc = ex.performedCardios[setIdx];
                    return Opacity(
                      opacity: isDone ? 0.65 : 1.0,
                      child: _CardioSetRow(
                        key: ValueKey('cardio_${exIdx}_$setIdx'),
                        setIndex: setIdx,
                        isDone: isDone,
                        initialDistance: pc?.distanceKm,
                        initialMinutes: pc != null ? pc.durationSeconds ~/ 60 : null,
                        onChanged: (dist, durMinutes, done) {
                          widget.provider.completeSet(
                            exIdx, setIdx, done,
                            distance: dist,
                            duration: durMinutes * 60,
                          );
                        },
                      ),
                    );
                  } else {
                    // RENDERIZAR SÉRIE DE MUSCULAÇÃO / ISOMETRIA
                    return Opacity(
                      opacity: isDone ? 0.65 : 1.0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive
                              ? accentColor.withOpacity(0.04)
                              : Colors.white.withOpacity(isDone ? 0.03 : 0.01),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? accentColor.withOpacity(0.85)
                                : (isDone ? accentColor.withOpacity(0.2) : Colors.white.withOpacity(0.06)),
                            width: isActive ? 1.5 : 1.0,
                          ),
                          boxShadow: isActive ? [
                            BoxShadow(
                              color: accentColor.withOpacity(0.08),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ] : null,
                        ),
                        child: Row(
                          children: [
                            // Número da série
                            Text(
                              "Série ${setIdx + 1}",
                              style: TextStyle(
                                color: isActive ? Colors.white : Colors.white70,
                                fontSize: 12,
                                fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Quantidade (reps ou segs) e Peso - editáveis por clique
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _showEditSetWeightRepsDialog(context, exIdx, setIdx, ex),
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        ex.measurementType == MeasurementType.time
                                            ? "${(ex.repsPerSet != null && setIdx < ex.repsPerSet!.length) ? ex.repsPerSet![setIdx] : ex.reps} segundos"
                                            : "${(ex.repsPerSet != null && setIdx < ex.repsPerSet!.length) ? ex.repsPerSet![setIdx] : ex.reps} reps",
                                        style: TextStyle(
                                          color: isActive ? Colors.white : Colors.white60,
                                          fontSize: 12,
                                          fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      ((ex.weightsPerSet != null && setIdx < ex.weightsPerSet!.length) ? ex.weightsPerSet![setIdx] : ex.weight) > 0
                                          ? "${((ex.weightsPerSet != null && setIdx < ex.weightsPerSet!.length) ? ex.weightsPerSet![setIdx] : ex.weight).toStringAsFixed(1).replaceAll('.0', '')} kg"
                                          : "Sem carga",
                                      style: TextStyle(
                                        color: isActive ? Colors.white : Colors.white38,
                                        fontSize: 11,
                                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.edit,
                                      size: 11,
                                      color: isActive ? Colors.white38 : Colors.white12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    widget.provider.completeSet(
                                      exIdx,
                                      setIdx,
                                      isDone,
                                      isFailure: !isFailure,
                                      failureRep: !isFailure ? ex.failureReps[setIdx] : null,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: isFailure ? Colors.redAccent.withOpacity(0.15) : Colors.white.withOpacity(0.02),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isFailure ? Colors.redAccent : Colors.white.withOpacity(0.08)),
                                    ),
                                    child: Text(
                                      "❌ Falha",
                                      style: TextStyle(
                                        color: isFailure ? Colors.redAccent : Colors.white24,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                if (isFailure) ...[
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      _showFailureRepDialog(context, exIdx, setIdx, ex.failureReps[setIdx]);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
                                      ),
                                      child: Text(
                                        "Rep: ${ex.failureReps[setIdx] ?? '-'}",
                                        style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(width: 12),

                            // Checkbox Concluir (Premium Custom Animated Circle)
                            GestureDetector(
                              onTap: () {
                                widget.provider.completeSet(
                                  exIdx,
                                  setIdx,
                                  !isDone,
                                  isFailure: isFailure,
                                  failureRep: ex.failureReps[setIdx],
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 44,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isDone 
                                      ? accentColor 
                                      : (isActive ? accentColor.withOpacity(0.08) : Colors.transparent),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDone 
                                        ? accentColor 
                                        : (isActive ? accentColor.withOpacity(0.6) : Colors.white.withOpacity(0.18)),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: isDone
                                      ? const Icon(Icons.check, color: Colors.black, size: 16, weight: 800)
                                      : Icon(
                                          Icons.check, 
                                          color: isActive ? accentColor.withOpacity(0.7) : Colors.white24, 
                                          size: 14
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              );
            }
          ),
        ],
      ),
    );
  }

  void _showEditSetWeightRepsDialog(BuildContext context, int exIdx, int setIdx, ActiveExercise ex) {
    final currentWeight = ex.weightsPerSet != null && setIdx < ex.weightsPerSet!.length
        ? ex.weightsPerSet![setIdx]
        : ex.weight;
    final currentReps = ex.repsPerSet != null && setIdx < ex.repsPerSet!.length
        ? ex.repsPerSet![setIdx]
        : ex.reps;

    final weightController = TextEditingController(text: currentWeight.toStringAsFixed(1).replaceAll('.0', ''));
    final repsController = TextEditingController(text: currentReps.toString());

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xff1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: Text("Editar Série ${setIdx + 1}",
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Peso (kg)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.measurementType == MeasurementType.time ? "Tempo (s)" : "Reps",
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: repsController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final newWeight = double.tryParse(weightController.text.trim()) ?? currentWeight;
              final newReps = int.tryParse(repsController.text.trim()) ?? currentReps;
              widget.provider.updateExerciseSetWeightReps(exIdx, setIdx, newWeight, newReps);
              Navigator.pop(dialogCtx);
            },
            child: const Text("Salvar", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showFailureRepDialog(BuildContext context, int exIdx, int setIdx, int? currentRep) {
    final controller = TextEditingController(text: currentRep?.toString() ?? "");
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xff1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text("Repetição de Falha", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            hintText: "Digite a repetição (ex: 8)",
            hintStyle: const TextStyle(color: Colors.white24),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final rep = int.tryParse(controller.text.trim());
              final provider = Provider.of<TrackerProvider>(context, listen: false);
              final active = provider.state!.activeWorkout!;
              final ex = active.exercises[exIdx];
              provider.completeSet(
                exIdx,
                setIdx,
                ex.setsState[setIdx],
                isFailure: true,
                failureRep: rep,
              );
              Navigator.pop(dialogCtx);
            },
            child: const Text("Salvar", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // A sincronização de timers de descanso e do índice de exercício ativo
  // agora é tratada de forma centralizada pelo provedor e seu ouvinte.

  void _confirmDiscardWorkout(BuildContext context) {
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
                "Descartar Treino?",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 12),
              const Text(
                "Tem certeza que deseja cancelar e descartar este treino em andamento? O progresso de hoje será perdido.",
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
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
                      widget.provider.discardActiveWorkout();
                      Navigator.pop(dialogCtx);
                    },
                    child: const Text("Descartar", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFinishWorkoutDialog(BuildContext context) {
    double rpeVal = 7.0;
    final notesCtrl = TextEditingController();
    final accentColor = ThemeUtils.getColor(widget.provider.currentProfile.colorAccent);

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: GlassCard(
              useBlur: true,
              borderColor: Colors.white.withOpacity(0.08),
              borderRadius: 24,
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Concluir Treino 🎉",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Como foi o esforço da sessão? (RPE)",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Leve (1)", style: TextStyle(color: Colors.white30, fontSize: 10)),
                        Text(
                          "Esforço: ${rpeVal.toInt()}/10",
                          style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Text("Máximo (10)", style: TextStyle(color: Colors.white30, fontSize: 10)),
                      ],
                    ),
                    Slider(
                      value: rpeVal,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      activeColor: accentColor,
                      inactiveColor: Colors.white10,
                      onChanged: (val) {
                        setDialogState(() {
                          rpeVal = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Notas ou observações do treino",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        hintText: "Como se sentiu hoje? Aumentou cargas?",
                        hintStyle: const TextStyle(color: Colors.white30),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text("Voltar", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            widget.provider.finishWorkout(
                              _workoutDurationNotifier.value,
                              rpeVal.toInt(),
                              notesCtrl.text.trim(),
                            );
                            Navigator.pop(dialogCtx);
                          },
                          child: Text("Salvar Treino", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    String twoDigits(int n) => n.toString().padLeft(2, '0');

    if (hours > 0) {
      return "${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}";
    }
    return "${twoDigits(minutes)}:${twoDigits(seconds)}";
  }
}

// ---------------------------------------------------------------------------
// _CardioSetRow — StatefulWidget that owns its TextEditingControllers so they
// survive rebuilds and don't lose text/focus while the user is typing.
// ---------------------------------------------------------------------------
class _CardioSetRow extends StatefulWidget {
  final int setIndex;
  final bool isDone;
  final double? initialDistance;
  final int? initialMinutes;
  /// (distance km, duration minutes, isDone)
  final void Function(double dist, int durMinutes, bool done) onChanged;

  const _CardioSetRow({
    super.key,
    required this.setIndex,
    required this.isDone,
    this.initialDistance,
    this.initialMinutes,
    required this.onChanged,
  });

  @override
  State<_CardioSetRow> createState() => _CardioSetRowState();
}

class _CardioSetRowState extends State<_CardioSetRow> {
  late final TextEditingController _distCtrl;
  late final TextEditingController _durCtrl;

  @override
  void initState() {
    super.initState();
    _distCtrl = TextEditingController(
      text: widget.initialDistance != null
          ? widget.initialDistance!.toStringAsFixed(
              widget.initialDistance! == widget.initialDistance!.truncateToDouble() ? 0 : 1)
          : '',
    );
    _durCtrl = TextEditingController(
      text: widget.initialMinutes != null ? widget.initialMinutes.toString() : '',
    );
  }

  @override
  void dispose() {
    _distCtrl.dispose();
    _durCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDone = widget.isDone;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isDone ? 0.05 : 0.01),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone
              ? Colors.blue.withOpacity(0.35)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Sessão ${widget.setIndex + 1}',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),

          // Input Km
          Expanded(
            child: TextField(
              controller: _distCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                labelText: 'Km',
                labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                filled: true,
                fillColor: Colors.white.withOpacity(0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blueAccent),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              onChanged: (val) {
                final dist = double.tryParse(val) ?? 0.0;
                final dur = int.tryParse(_durCtrl.text.trim()) ?? 0;
                widget.onChanged(dist, dur, isDone);
              },
            ),
          ),
          const SizedBox(width: 8),

          // Input Minutos
          Expanded(
            child: TextField(
              controller: _durCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                labelText: 'Minutos',
                labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                filled: true,
                fillColor: Colors.white.withOpacity(0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blueAccent),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              onChanged: (val) {
                final dist = double.tryParse(_distCtrl.text.trim()) ?? 0.0;
                final dur = int.tryParse(val) ?? 0;
                widget.onChanged(dist, dur, isDone);
              },
            ),
          ),
          const SizedBox(width: 12),

          // Checkbox Concluir
          Checkbox(
            value: isDone,
            activeColor: Colors.blueAccent,
            onChanged: (val) {
              final dist = double.tryParse(_distCtrl.text.trim()) ?? 0.0;
              final dur = int.tryParse(_durCtrl.text.trim()) ?? 0;
              widget.onChanged(dist, dur, val ?? false);
            },
          ),
        ],
      ),
    );
  }
}
