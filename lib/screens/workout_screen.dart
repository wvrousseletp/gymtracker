import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../utils/workout_starter.dart';
import '../services/rest_timer_service.dart';
import '../widgets/premium_strength_set_card.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/premium_cardio_view.dart';
import 'notification_settings_dialog.dart';

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
      case 1:
        return 'seg';
      case 2:
        return 'ter';
      case 3:
        return 'qua';
      case 4:
        return 'qui';
      case 5:
        return 'sex';
      case 6:
        return 'sab';
      case 7:
        return 'dom';
      default:
        return 'seg';
    }
  }

  String _getTodayLabel() {
    final weekday = DateTime.now().weekday;
    switch (weekday) {
      case 1:
        return 'Segunda-feira';
      case 2:
        return 'Terça-feira';
      case 3:
        return 'Quarta-feira';
      case 4:
        return 'Quinta-feira';
      case 5:
        return 'Sexta-feira';
      case 6:
        return 'Sábado';
      case 7:
        return 'Domingo';
      default:
        return 'Segunda-feira';
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
    if (activeWorkout != null) {
      final trackerProvider =
          Provider.of<TrackerProvider>(context, listen: true);
      return ActiveWorkoutView(
          activeWorkout: activeWorkout, provider: trackerProvider);
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
    final List<Routine> plannedRoutines = plannedRoutineIds
        .map((item) {
          if (item.isEmpty) return null;
          if (item.startsWith('exercise:')) {
            final parts = item.split(':');
            if (parts.length >= 3) {
              final exerciseId = parts[1];
              final sets = int.tryParse(parts[2]) ?? 3;
              final libEx =
                  provider.library.where((l) => l.id == exerciseId).firstOrNull;
              if (libEx != null) {
                final isCardio =
                    libEx.measurementType == MeasurementType.cardio ||
                        libEx.measurementType == MeasurementType.distance ||
                        libEx.measurementType == MeasurementType.time;
                return Routine(
                  id: "temp-$exerciseId-$sets",
                  name: "${libEx.name} (Avulso)",
                  defaultRest: 60,
                  exercises: [
                    RoutineExercise(
                      id: "e-temp-${const Uuid().v4()}",
                      exerciseId: exerciseId,
                      sets: isCardio ? 1 : sets,
                      reps: isCardio
                          ? 0
                          : (libEx.measurementType == MeasurementType.time
                              ? 45
                              : 10),
                      rest: 60,
                      weight: 0,
                      isCardio: isCardio,
                      allowCardioSets: false,
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
            return provider.routines
                .where((r) => r.id == routineId)
                .firstOrNull;
          }
        })
        .whereType<Routine>()
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banners de Treinos Adiados
            ...provider.postponedWorkouts.asMap().entries.map((entry) {
              final index = entry.key;
              final postponed = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  borderColor: accentColor.withOpacity(0.3),
                  opacity: 0.05,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.snooze, color: accentColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "TREINO ADIADO ${provider.postponedWorkouts.length > 1 ? '(${index + 1}/${provider.postponedWorkouts.length})' : ''}",
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              postponed.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            provider.discardPostponedWorkout(index),
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent, size: 20),
                        tooltip: "Descartar",
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton(
                        onPressed: () {
                          if (provider.activeWorkout != null) {
                            // If there's an active workout, postpone it first, then resume this one
                            provider.postponeActiveWorkout();
                            // After postpone, resume this one (index might shift since we added to the list)
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              provider.resumePostponedWorkout(index);
                            });
                          } else {
                            provider.resumePostponedWorkout(index);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          "Retomar",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Cabeçalho de treinos de hoje
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "HOJE É",
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0),
                    ),
                    Text(
                      todayLabel.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                // Botão de Ajustes Rápidos
                IconButton(
                  icon: const Icon(Icons.settings_outlined,
                      color: Colors.white70),
                  onPressed: () {
                    _showSettingsDialog(context,
                        Provider.of<TrackerProvider>(context, listen: false));
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cartões de Treinos Planejados
            const Text(
              "Treino Planejado para Hoje",
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            if (plannedRoutines.isEmpty)
              const GlassCard(
                padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Center(
                  child: Text(
                    "Nenhum treino planejado para hoje.\nConfigure na aba 'Planejar' ou inicie um treino rápido abaixo.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else
              Column(
                children: plannedRoutines.map((routine) {
                  final isCompleted =
                      _isRoutineCompletedToday(routine.name, provider.history);
                  final totalSets = routine.exercises
                      .fold<int>(0, (sum, ex) => sum + ex.sets);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () {
                        // Ao clicar no card, abre uma visão dos exercícios agendados
                        _showPlannedRoutineDetails(context, provider, routine);
                      },
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        borderColor: isCompleted
                            ? Colors.green.withOpacity(0.35)
                            : Colors.white.withOpacity(0.04),
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
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      if (isCompleted) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.green.withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: Colors.green
                                                    .withOpacity(0.35)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check,
                                                  color: Colors.green,
                                                  size: 10),
                                              SizedBox(width: 2),
                                              Text(
                                                "CONCLUÍDO",
                                                style: TextStyle(
                                                    color: Colors.green,
                                                    fontSize: 9,
                                                    fontWeight:
                                                        FontWeight.w900),
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
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () {
                                if (provider.activeWorkout != null) {
                                  _promptPostponeOrCreateWorkout(
                                      context, provider, () {
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
                                  });
                                } else {
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
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isCompleted
                                    ? Colors.white.withOpacity(0.1)
                                    : accentColor,
                                foregroundColor:
                                    isCompleted ? Colors.white : Colors.black,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                elevation: 0,
                              ),
                              child: Text(
                                isCompleted ? "Treinar Denovo" : "Iniciar",
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13),
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
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            if (provider.routines.isEmpty)
              const GlassCard(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    "Nenhuma rotina cadastrada na biblioteca.",
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontStyle: FontStyle.italic),
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
                      if (provider.activeWorkout != null) {
                        _promptPostponeOrCreateWorkout(context, provider, () {
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
                        });
                      } else {
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
                      }
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
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${routine.exercises.length} ex • rest ${routine.defaultRest}s",
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10),
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
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            GestureDetector(
              onTap: () {
                _showSelectExerciseDialog(context, provider);
              },
              child: GlassCard(
                padding:
                    const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                borderColor: Colors.white.withOpacity(0.04),
                child: Row(
                  children: [
                    Icon(Icons.play_circle_outline,
                        color: accentColor, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Selecionar da Biblioteca",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Inicie uma sessão de treino rápida com unicamente esse exercício",
                            style:
                                TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.white38, size: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlannedRoutineDetails(
      BuildContext context, WorkoutProvider provider, Routine routine) {
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
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
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800),
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
                        orElse: () => LibraryExercise(
                            id: '',
                            name: 'Deletado',
                            muscle: '',
                            measurementType: MeasurementType.reps),
                      );
                      final isCardio =
                          libEx.muscle.toLowerCase().contains('cardio');

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(libEx.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(libEx.muscle,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12)),
                        trailing: Text(
                          isCardio
                              ? "${ex.reps} min"
                              : "${ex.sets}x${ex.reps} @ ${ex.weight.toStringAsFixed(1).replaceAll('.0', '')}kg",
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
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
                          orElse: () => LibraryExercise(
                              id: '',
                              name: '',
                              muscle: '',
                              measurementType: MeasurementType.reps),
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      "Métricas de Cardio",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      "Informe a distância e duração do seu treino de hoje:",
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 12),
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: distCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      style:
                                          const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        labelText: "Distância (km)",
                                        labelStyle: const TextStyle(
                                            color: Colors.white70),
                                        enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                                color: Colors.white
                                                    .withOpacity(0.12))),
                                        focusedBorder: const OutlineInputBorder(
                                            borderSide: BorderSide(
                                                color: Colors.green)),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: durCtrl,
                                      keyboardType: TextInputType.number,
                                      style:
                                          const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        labelText: "Duração (minutos)",
                                        labelStyle: const TextStyle(
                                            color: Colors.white70),
                                        enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                                color: Colors.white
                                                    .withOpacity(0.12))),
                                        focusedBorder: const OutlineInputBorder(
                                            borderSide: BorderSide(
                                                color: Colors.green)),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            distCtrl.dispose();
                                            durCtrl.dispose();
                                            Navigator.pop(dialogCtx);
                                          },
                                          child: const Text("Cancelar",
                                              style: TextStyle(
                                                  color: Colors.white54,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton(
                                          onPressed: () {
                                            final d = double.tryParse(
                                                    distCtrl.text) ??
                                                0.0;
                                            final t =
                                                int.tryParse(durCtrl.text) ??
                                                    30;
                                            distCtrl.dispose();
                                            durCtrl.dispose();
                                            Navigator.pop(dialogCtx,
                                                {"distance": d, "duration": t});
                                          },
                                          child: const Text("Salvar",
                                              style: TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold)),
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
                      final totalSets = routine.exercises
                          .fold<int>(0, (sum, ex) => sum + ex.sets);
                      final totalWeight = routine.exercises.fold<double>(
                          0, (sum, ex) => sum + (ex.sets * ex.weight));

                      final List<LogExercise> logExercises =
                          routine.exercises.map((re) {
                        final lib = provider.library.firstWhere(
                          (l) => l.id == re.exerciseId,
                          orElse: () => LibraryExercise(
                              id: '',
                              name: 'Exercício',
                              muscle: 'Geral',
                              measurementType: MeasurementType.reps),
                        );

                        final isExCardio =
                            lib.muscle.toLowerCase().contains('cardio');
                        return LogExercise(
                          name: lib.name,
                          muscle: lib.muscle,
                          sets: re.sets,
                          completedSets: re.sets,
                          reps: isExCardio ? customDurationMinutes : re.reps,
                          weight: isExCardio ? customDistance : re.weight,
                          rpe: 8,
                          performedCardios: isExCardio
                              ? List.generate(
                                  re.sets,
                                  (i) => PerformedCardio(
                                      distanceKm: customDistance,
                                      durationSeconds:
                                          customDurationMinutes * 60))
                              : [],
                          failureReport: List.filled(re.sets, false),
                          failureReps: List.filled(re.sets, null),
                        );
                      }).toList();

                      final newLog = WorkoutLog(
                        id: "l-${const Uuid().v4()}",
                        name: routine.name,
                        date: nowUtc,
                        duration:
                            customDurationMinutes * 60, // custom card duration
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
                      if (!context.mounted) return;
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              "Treino '${routine.name}' concluído com sucesso!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline,
                        color: Colors.black, size: 18),
                    label: const Text(
                      "MARCAR COMO CONCLUÍDO",
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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

  void _showSelectExerciseDialog(
      BuildContext context, WorkoutProvider provider) {
    final library = provider.library;
    final accentColor = ThemeUtils.getColor(
        Provider.of<ProfileProvider>(context, listen: false)
            .currentProfile
            .colorAccent);

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
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
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
                      child: const Text("OK",
                          style: TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold)),
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
              return ex.name
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase()) ||
                  ex.muscle.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  decoration: BoxDecoration(
                    color: const Color(0xff141416).withOpacity(0.65),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
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
                            icon:
                                const Icon(Icons.close, color: Colors.white54),
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
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
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
                                  style: TextStyle(
                                      color: Colors.white38,
                                      fontStyle: FontStyle.italic),
                                ),
                              )
                            : () {
                                // Agrupar por músculo
                                final Map<String, List<LibraryExercise>>
                                    grouped = {};
                                for (final ex in filteredList) {
                                  grouped
                                      .putIfAbsent(ex.muscle, () => [])
                                      .add(ex);
                                }
                                final sortedMuscles = grouped.keys.toList()
                                  ..sort((a, b) => a
                                      .toLowerCase()
                                      .compareTo(b.toLowerCase()));

                                return ListView.builder(
                                  itemCount: sortedMuscles.length,
                                  itemBuilder: (context, mIdx) {
                                    final muscle = sortedMuscles[mIdx];
                                    final exs = grouped[muscle]!;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 16, bottom: 8, left: 4),
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
                                            margin: const EdgeInsets.only(
                                                bottom: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withOpacity(0.02),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: Colors.white
                                                      .withOpacity(0.04)),
                                            ),
                                            child: ListTile(
                                              title: Text(
                                                ex.name,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              subtitle: Text(
                                                ex.measurementType ==
                                                        MeasurementType.time
                                                    ? 'Isometria'
                                                    : 'Repetições',
                                                style: const TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 11),
                                              ),
                                              trailing: const Icon(
                                                  Icons.play_arrow_rounded,
                                                  color: Colors.white54),
                                              onTap: () {
                                                Navigator.pop(
                                                    context); // fecha modal
                                                if (provider.activeWorkout !=
                                                    null) {
                                                  _promptPostponeOrCreateWorkout(
                                                      context, provider, () {
                                                    WorkoutStarter
                                                        .startSingleExerciseWithCountdown(
                                                            context,
                                                            provider,
                                                            ex);
                                                  });
                                                } else {
                                                  WorkoutStarter
                                                      .startSingleExerciseWithCountdown(
                                                          context, provider, ex);
                                                }
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
    final vibrationState =
        ValueNotifier<bool>(provider.state!.settings.vibration);
    final prepController = TextEditingController(
        text: provider.state!.settings.prepSeconds.toString());
    final waterController = TextEditingController(
        text: (provider.state?.diet.waterGoalMl ?? 2000).toString());
    final accentColor =
        ThemeUtils.getColor(provider.currentProfile.colorAccent);

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
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // SEÇÃO TREINO
                const Text(
                  "TREINO 🏋️",
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: soundState,
                  builder: (context, val, child) => SwitchListTile(
                    title: const Text("Bips Sonoros",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
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
                    title: const Text("Vibração",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
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
                    const Text("Tempo de Preparo",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Container(
                      width: 60,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: TextField(
                        controller: prepController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
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
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Meta de Água (ml)",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Container(
                      width: 70,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: TextField(
                        controller: waterController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Notificações",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        showNotificationSettingsDialog(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        foregroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: accentColor.withOpacity(0.3)),
                        ),
                      ),
                      icon: const Icon(Icons.notifications_active_outlined,
                          size: 16),
                      label: const Text("Configurar",
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // AÇÕES
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        prepController.dispose();
                        waterController.dispose();
                        Navigator.pop(dialogCtx);
                      },
                      child: const Text("Cancelar",
                          style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        final prep =
                            int.tryParse(prepController.text.trim()) ?? 5;
                        final waterGoal =
                            int.tryParse(waterController.text.trim()) ?? 2000;
                        provider.updateSettings(
                            soundState.value, vibrationState.value, prep);
                        provider.updateWaterGoal(waterGoal);
                        prepController.dispose();
                        waterController.dispose();
                        Navigator.pop(dialogCtx);
                      },
                      child: Text("Salvar",
                          style: TextStyle(
                              color: accentColor, fontWeight: FontWeight.bold)),
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

  void _promptPostponeOrCreateWorkout(BuildContext context,
      WorkoutProvider provider, VoidCallback onConfirmNewWorkout) {
    final accentColor =
        ThemeUtils.getColor(provider.currentProfile?.colorAccent ?? 'Branco');
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
                "Treino em Andamento ⏳",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              const SizedBox(height: 12),
              const Text(
                "Você possui uma sessão ativa. O que deseja fazer com ela antes de iniciar a nova?",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text("Voltar",
                        style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      provider.discardActiveWorkout();
                      Navigator.pop(dialogCtx);
                      onConfirmNewWorkout();
                    },
                    child: const Text("Descartar",
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      provider.postponeActiveWorkout();
                      Navigator.pop(dialogCtx);
                      onConfirmNewWorkout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    child: const Text("Adiar",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
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

class _ActiveWorkoutViewState extends State<ActiveWorkoutView> with WidgetsBindingObserver {
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
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentExIdx = widget.activeWorkout.currentExerciseIndex;
    _pageController = PageController(initialPage: _currentExIdx, viewportFraction: 0.95);

    // Calculate initial elapsed seconds from startTime if valid
    final initialElapsed = _calculateRealElapsed();
    _workoutDurationNotifier = ValueNotifier<int>(
      initialElapsed > 0 ? initialElapsed : widget.activeWorkout.elapsedSeconds,
    );

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
    WidgetsBinding.instance.removeObserver(this);
    widget.provider.removeListener(_onProviderChange);
    RestTimerService.instance.secondsRemaining.removeListener(_onRestTimerTick);
    _stopwatchTimer?.cancel();
    _healthSyncTimer?.cancel();
    _workoutDurationNotifier.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncElapsedSecondsFromClock();
    }
  }

  int _calculateRealElapsed() {
    final start = widget.activeWorkout.startTime;
    if (start <= 0) return widget.activeWorkout.elapsedSeconds;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = (now - start) ~/ 1000;
    return diff > 0 ? diff : widget.activeWorkout.elapsedSeconds;
  }

  void _syncElapsedSecondsFromClock() {
    if (!mounted || widget.activeWorkout.paused) return;
    final realElapsed = _calculateRealElapsed();
    if (_workoutDurationNotifier.value != realElapsed) {
      _workoutDurationNotifier.value = realElapsed;
      widget.provider.updateWorkoutTimer(realElapsed);
    }
  }

  void _startStopwatch() {
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!widget.activeWorkout.paused) {
        final realElapsed = _calculateRealElapsed();
        if (realElapsed != _workoutDurationNotifier.value) {
          _workoutDurationNotifier.value = realElapsed;
          widget.provider.updateWorkoutTimer(realElapsed);
        }
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

  bool _autoFinishDialogShowing = false;

  void _onProviderChange() {
    if (!mounted) return;
    final active = widget.provider.state?.activeWorkout;
    if (active == null) {
      _autoFinishDialogShowing = false;
      return;
    }

    if (active.currentExerciseIndex != _currentExIdx) {
      setState(() {
        _currentExIdx = active.currentExerciseIndex;
      });
    }

    // Auto-finalize workout when all sets of all exercises are completed
    final bool allDone = active.exercises
        .every((ex) => ex.setsState.every((setDone) => setDone));
    if (allDone && !_autoFinishDialogShowing) {
      _autoFinishDialogShowing = true;
      // Schedule dialog launch after current build frame to avoid layout errors
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFinishWorkoutDialog(context);
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
    final accentColor =
        ThemeUtils.getColor(widget.provider.currentProfile.colorAccent);
    final hr = widget.provider.currentHeartRate > 0
        ? widget.provider.currentHeartRate
        : workout.heartRate;
    final cal = widget.provider.todayBurnedCalories > 0
        ? widget.provider.todayBurnedCalories
        : workout.activeCalories;
    final steps = widget.provider.todaySteps;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Dynamic Glowing Background
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(seconds: 2),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.8),
                  radius: 1.5,
                  colors: [
                    accentColor.withOpacity(0.15),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          // Tela Principal de Treino Ativo
          Column(
            children: [
              // Barra superior do treino (Header Centered)
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      workout.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<int>(
                      valueListenable: _workoutDurationNotifier,
                      builder: (context, elapsed, child) {
                        return Text(
                          _formatDuration(elapsed),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            fontFeatures: [FontFeature.tabularFigures()],
                            letterSpacing: -2.0,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Telemetry Glass Pills
                    if (hr > 0 || cal > 0 || steps > 0)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          if (hr > 0)
                            _buildTelemetryPill(
                                Icons.favorite, Colors.redAccent, "$hr bpm"),
                          if (cal > 0)
                            _buildTelemetryPill(Icons.local_fire_department,
                                Colors.orangeAccent, "$cal kcal"),
                          if (steps > 0)
                            _buildTelemetryPill(Icons.directions_walk,
                                Colors.blueAccent, "$steps steps"),
                        ],
                      ),
                  ],
                ),
              ),

              // Carrossel de Exercícios (PageView)
              if (exercises.isNotEmpty) ...[
                // Dots indicator
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(exercises.length, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentExIdx == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentExIdx == index
                              ? accentColor
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
                
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() {
                        _currentExIdx = index;
                        widget.provider.setCurrentExerciseIndex(_currentExIdx);
                      });
                    },
                    itemCount: exercises.length,
                    itemBuilder: (context, index) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Column(
                          children: [
                            _buildExerciseCard(
                                exercises[index], index, accentColor),
                            
                            // Botão Concluir Treino no último exercício
                            if (index == exercises.length - 1)
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 32.0, bottom: 100.0),
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _showFinishWorkoutDialog(context);
                                  },
                                  icon: const Icon(Icons.check_circle_outline,
                                      size: 24, color: Colors.black),
                                  label: const Text(
                                    "FINALIZAR TREINO",
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        letterSpacing: 1),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentColor,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 16),
                                    elevation: 8,
                                    shadowColor: accentColor.withOpacity(0.5),
                                  ),
                                ),
                              )
                            else
                              const SizedBox(height: 100), // Espaço para a Action Bar
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),

          // FLOATING BOTTOM ACTION BAR (Glassmorphism)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Mais Opções (Adiar / Descartar)
                      PopupMenuButton<String>(
                        color: const Color(0xff2c2c2e),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) {
                          if (value == 'postpone') {
                            widget.provider.postponeActiveWorkout();
                          } else if (value == 'discard') {
                            _confirmDiscardWorkout(context);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'postpone',
                            child: Row(
                              children: [
                                const Icon(Icons.snooze, color: Colors.amberAccent, size: 20),
                                const SizedBox(width: 12),
                                const Text("Adiar Treino", style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'discard',
                            child: Row(
                              children: [
                                const Icon(Icons.close, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 12),
                                const Text("Descartar", style: TextStyle(color: Colors.redAccent)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Botão Play/Pause Gigante no Centro
                      GestureDetector(
                        onTap: () {
                          widget.provider.pauseWorkout(!workout.paused);
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: workout.paused ? Colors.white : accentColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (workout.paused ? Colors.white : accentColor).withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: Icon(
                            workout.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                            color: Colors.black,
                            size: 32,
                          ),
                        ),
                      ),

                      // Botão Finalizar Minimalista
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: Colors.white70),
                        tooltip: "Finalizar Treino",
                        onPressed: () {
                          _showFinishWorkoutDialog(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // OVERLAY DE DESCANSO / PREPARO ATIVO (CircularProgressTimer) - REDESENHO PREMIUM TELA CHEIA
          if (_timerActive)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: Colors.black.withOpacity(0.94),
                  child: SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                                minHeight: constraints.maxHeight),
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: 24,
                                right: 24,
                                top: 24,
                                bottom: 24 +
                                    88 +
                                    MediaQuery.of(context).padding.bottom,
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Cabeçalho da tela de descanso
                                  Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _timerIsPrep
                                              ? Colors.amber.withOpacity(0.12)
                                              : accentColor.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: _timerIsPrep
                                                ? Colors.amber.withOpacity(0.25)
                                                : accentColor.withOpacity(0.25),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Text(
                                          _timerIsPrep
                                              ? "TEMPO DE PREPARO"
                                              : "DESCANSO ATIVO",
                                          style: TextStyle(
                                            color: _timerIsPrep
                                                ? Colors.amber
                                                : accentColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Painel Central com Timer e controles de acréscimo
                                  Column(
                                    children: [
                                      ValueListenableBuilder<int>(
                                        valueListenable: RestTimerService
                                            .instance.secondsRemaining,
                                        builder: (context, remaining, child) {
                                          return Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              // Anel de progresso grande e elegante
                                              SizedBox(
                                                width: 220,
                                                height: 220,
                                                child:
                                                    CircularProgressIndicator(
                                                  value: _countdownTotalSeconds >
                                                          0
                                                      ? (remaining /
                                                          _countdownTotalSeconds)
                                                      : 0,
                                                  strokeWidth: 6,
                                                  backgroundColor: Colors.white
                                                      .withOpacity(0.04),
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                              Color>(
                                                          _timerIsPrep
                                                              ? Colors.amber
                                                              : accentColor),
                                                ),
                                              ),
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    "$remaining",
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 72,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      letterSpacing: -2.0,
                                                    ),
                                                  ),
                                                  const Text(
                                                    "segundos",
                                                    style: TextStyle(
                                                      color: Colors.white30,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 32),
                                      // Ajustes rápidos de tempo (+15s / -15s) - Mais destacados
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withOpacity(0.06),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                  color: Colors.white
                                                      .withOpacity(0.12),
                                                  width: 1.5),
                                            ),
                                            child: IconButton(
                                              onPressed: () {
                                                final currentRemaining =
                                                    RestTimerService.instance
                                                        .secondsRemaining.value;
                                                if (currentRemaining > 15) {
                                                  widget.provider
                                                      .startRestTimer(
                                                    currentRemaining - 15,
                                                    _timerNextExName,
                                                    _timerNextSetNum,
                                                    _timerIsPrep,
                                                  );
                                                }
                                              },
                                              icon: const Icon(Icons.remove,
                                                  color: Colors.white,
                                                  size: 24),
                                              padding: const EdgeInsets.all(12),
                                              constraints: const BoxConstraints(
                                                  minWidth: 56, minHeight: 56),
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          Container(
                                            decoration: BoxDecoration(
                                              color:
                                                  accentColor.withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                  color: accentColor
                                                      .withOpacity(0.3),
                                                  width: 1.0),
                                            ),
                                            child: IconButton(
                                              onPressed: () {
                                                final currentRemaining =
                                                    RestTimerService.instance
                                                        .secondsRemaining.value;
                                                widget.provider.startRestTimer(
                                                  currentRemaining + 15,
                                                  _timerNextExName,
                                                  _timerNextSetNum,
                                                  _timerIsPrep,
                                                );
                                              },
                                              icon: Icon(Icons.add,
                                                  color: accentColor, size: 24),
                                              padding: const EdgeInsets.all(12),
                                              constraints: const BoxConstraints(
                                                  minWidth: 56, minHeight: 56),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  // Próximo Exercício e Botão de Pular no rodapé
                                  Column(
                                    children: [
                                      GlassCard(
                                        padding: const EdgeInsets.all(16),
                                        borderColor:
                                            Colors.white.withOpacity(0.06),
                                        borderRadius: 16,
                                        child: Column(
                                          children: [
                                            Text(
                                              _timerIsPrep
                                                  ? "PREPARE-SE PARA A SÉRIE $_timerNextSetNum"
                                                  : "PRÓXIMO EXERCÍCIO",
                                              style: TextStyle(
                                                color: _timerIsPrep
                                                    ? Colors.amber
                                                        .withOpacity(0.7)
                                                    : accentColor
                                                        .withOpacity(0.7),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _timerNextExName,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "Série $_timerNextSetNum",
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      // Botão de Pular Premium
                                      SizedBox(
                                        width: double.infinity,
                                        height: 52,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            if (_timerIsPrep) {
                                              widget.provider.clearRestTimer();
                                            } else {
                                              final settings = widget
                                                  .provider.state!.settings;
                                              widget.provider.startRestTimer(
                                                settings.prepSeconds,
                                                _timerNextExName,
                                                _timerNextSetNum,
                                                true,
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.black,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            elevation: 0,
                                          ),
                                          child: Text(
                                            _timerIsPrep
                                                ? "Iniciar Exercício Agora"
                                                : "Pular Descanso",
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
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
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(ActiveExercise ex, int exIdx, Color accentColor) {
    final isCardio = ex.isCardio;
    final isSingleCardio = isCardio && !ex.allowCardioSets;

    // Calculate total accumulated volume for strength exercises
    double totalVolume = 0;
    for (int i = 0; i < ex.sets; i++) {
      if (ex.setsState[i]) {
        final w = (ex.weightsPerSet != null && i < ex.weightsPerSet!.length)
            ? ex.weightsPerSet![i]
            : ex.weight;
        final r = (ex.repsPerSet != null && i < ex.repsPerSet!.length)
            ? ex.repsPerSet![i]
            : ex.reps;
        totalVolume += (w * r);
      }
    }

    const cardioAccent = Color(0xff00e676); // Vibrant Lime/Cyan for Cardio

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: isCardio
          ? cardioAccent.withOpacity(0.25)
          : accentColor.withOpacity(0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category Icon, Name and Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCardio
                      ? cardioAccent.withOpacity(0.12)
                      : accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCardio
                        ? cardioAccent.withOpacity(0.4)
                        : accentColor.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isCardio ? Icons.directions_run : Icons.fitness_center,
                  color: isCardio ? cardioAccent : accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Text(
                            ex.muscle.toUpperCase(),
                            style: TextStyle(
                              color: isCardio ? cardioAccent : accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (ex.executionType != null &&
                            ex.executionType!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            "• ${ex.executionType}",
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!isCardio && totalVolume > 0) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "VOLUME",
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 8,
                            fontWeight: FontWeight.w800),
                      ),
                      Text(
                        "${totalVolume.toStringAsFixed(0)} kg",
                        style: TextStyle(
                            color: accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Lista de Séries ou Sessão de Cardio Única
          Builder(builder: (context) {
            // For single cardio sessions, show one input instead of multiple sets
            if (isSingleCardio) {
              final pc = ex.singleCardioSession;
              final isDone = ex.setsState.isNotEmpty && ex.setsState[0];
              return PremiumCardioSessionView(
                key: ValueKey('cardio_${exIdx}_single'),
                setIndex: 0,
                isDone: isDone,
                initialDistance: pc?.distanceKm,
                initialMinutes: pc != null ? pc.durationSeconds ~/ 60 : null,
                workoutDurationNotifier: _workoutDurationNotifier,
                onChanged: (dist, durMinutes, done) {
                  widget.provider.completeSet(
                    exIdx,
                    0,
                    done,
                    distance: dist,
                    duration: durMinutes * 60,
                  );
                },
              );
            }

            // Traditional sets or cardio with sets (HIIT)
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
                  // RENDERIZAR SESSÃO DE CARDIO COM SETS (HIIT)
                  final pc = ex.performedCardios[setIdx];
                  return PremiumCardioSessionView(
                    key: ValueKey('cardio_${exIdx}_$setIdx'),
                    setIndex: setIdx,
                    isDone: isDone,
                    initialDistance: pc?.distanceKm,
                    initialMinutes:
                        pc != null ? pc.durationSeconds ~/ 60 : null,
                    workoutDurationNotifier: _workoutDurationNotifier,
                    onChanged: (dist, durMinutes, done) {
                      widget.provider.completeSet(
                        exIdx,
                        setIdx,
                        done,
                        distance: dist,
                        duration: durMinutes * 60,
                      );
                    },
                  );
                } else {
                  return PremiumStrengthSetCard(
                    setIndex: setIdx,
                    ex: ex,
                    isDone: isDone,
                    isActive: isActive,
                    isFailure: isFailure,
                    accentColor: accentColor,
                    onEditTap: () => _showEditSetWeightRepsDialog(
                        context, exIdx, setIdx, ex),
                    onFailureTap: () {
                      widget.provider.completeSet(
                        exIdx,
                        setIdx,
                        isDone,
                        isFailure: !isFailure,
                        failureRep: !isFailure ? ex.failureReps[setIdx] : null,
                      );
                      if (!isFailure) {
                        _showFailureRepDialog(context, exIdx, setIdx, ex.failureReps[setIdx]);
                      }
                    },
                    onDoneTap: () {
                      if (isDone) {
                        widget.provider.completeSet(
                          exIdx,
                          setIdx,
                          false,
                          isFailure: isFailure,
                          failureRep: isFailure ? ex.failureReps[setIdx] : null,
                        );
                      } else {
                        widget.provider.completeSet(
                          exIdx,
                          setIdx,
                          true,
                          isFailure: isFailure,
                          failureRep: isFailure ? ex.failureReps[setIdx] : null,
                        );
                      }
                    },
                  );
                }
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTelemetryPill(IconData icon, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSetWeightRepsDialog(
      BuildContext context, int exIdx, int setIdx, ActiveExercise ex) {
    final currentWeight =
        ex.weightsPerSet != null && setIdx < ex.weightsPerSet!.length
            ? ex.weightsPerSet![setIdx]
            : ex.weight;
    final currentReps = ex.repsPerSet != null && setIdx < ex.repsPerSet!.length
        ? ex.repsPerSet![setIdx]
        : ex.reps;

    final weightController = TextEditingController(
        text: currentWeight.toStringAsFixed(1).replaceAll('.0', ''));
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
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Peso (kg)",
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
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
                      Text(
                          ex.measurementType == MeasurementType.time
                              ? "Tempo (s)"
                              : "Reps",
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: repsController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
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
            child:
                const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final newWeight = double.tryParse(weightController.text.trim()) ??
                  currentWeight;
              final newReps =
                  int.tryParse(repsController.text.trim()) ?? currentReps;
              widget.provider.updateExerciseSetWeightReps(
                  exIdx, setIdx, newWeight, newReps);
              Navigator.pop(dialogCtx);
            },
            child: const Text("Salvar",
                style: TextStyle(
                    color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showFailureRepDialog(
      BuildContext context, int exIdx, int setIdx, int? currentRep) {
    final controller =
        TextEditingController(text: currentRep?.toString() ?? "");
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xff1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text("Repetição de Falha",
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
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
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child:
                const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final rep = int.tryParse(controller.text.trim());
              final provider =
                  Provider.of<TrackerProvider>(context, listen: false);
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
            child: const Text("Salvar",
                style: TextStyle(
                    color: Colors.blueAccent, fontWeight: FontWeight.bold)),
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
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
              const SizedBox(height: 12),
              const Text(
                "Tem certeza que deseja cancelar e descartar este treino em andamento? O progresso de hoje será perdido.",
                style:
                    TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
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
                      widget.provider.discardActiveWorkout();
                      Navigator.pop(dialogCtx);
                    },
                    child: const Text("Descartar",
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

  void _showFinishWorkoutDialog(BuildContext context) {
    double rpeVal = 7.0;
    final notesCtrl = TextEditingController();
    final accentColor =
        ThemeUtils.getColor(widget.provider.currentProfile.colorAccent);

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
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
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
                        const Text("Leve (1)",
                            style:
                                TextStyle(color: Colors.white30, fontSize: 10)),
                        Text(
                          "Esforço: ${rpeVal.toInt()}/10",
                          style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                        const Text("Máximo (10)",
                            style:
                                TextStyle(color: Colors.white30, fontSize: 10)),
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
                          borderSide:
                              BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text("Voltar",
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.bold)),
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
                          child: Text("Salvar Treino",
                              style: TextStyle(
                                  color: accentColor,
                                  fontWeight: FontWeight.bold)),
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
          ? widget.initialDistance!.toStringAsFixed(widget.initialDistance! ==
                  widget.initialDistance!.truncateToDouble()
              ? 0
              : 1)
          : '',
    );
    _durCtrl = TextEditingController(
      text:
          widget.initialMinutes != null ? widget.initialMinutes.toString() : '',
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

    final dist = double.tryParse(_distCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final dur = int.tryParse(_durCtrl.text.trim()) ?? 0;

    String paceStr = "--:-- /km";
    String speedStr = "-- km/h";
    if (dist > 0 && dur > 0) {
      final paceMinutesPerKm = dur / dist;
      final speedKmH = dist / (dur / 60);

      int paceM = paceMinutesPerKm.floor();
      int paceS = ((paceMinutesPerKm - paceM) * 60).round();
      paceStr = "$paceM:${paceS.toString().padLeft(2, '0')} /km";
      speedStr = "${speedKmH.toStringAsFixed(1)} km/h";
    }

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Sessão ${widget.setIndex + 1}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
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
                    labelStyle:
                        const TextStyle(color: Colors.white38, fontSize: 11),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.1)),
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
                    setState(() {});
                    final d = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                    final t = int.tryParse(_durCtrl.text.trim()) ?? 0;
                    widget.onChanged(d, t, isDone);
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
                    labelStyle:
                        const TextStyle(color: Colors.white38, fontSize: 11),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.1)),
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
                    setState(() {});
                    final d =
                        double.tryParse(_distCtrl.text.replaceAll(',', '.')) ??
                            0.0;
                    final t = int.tryParse(val.trim()) ?? 0;
                    widget.onChanged(d, t, isDone);
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Checkbox Concluir
              Checkbox(
                value: isDone,
                activeColor: Colors.blueAccent,
                onChanged: (val) {
                  final d =
                      double.tryParse(_distCtrl.text.replaceAll(',', '.')) ??
                          0.0;
                  final t = int.tryParse(_durCtrl.text.trim()) ?? 0;
                  widget.onChanged(d, t, val ?? false);
                },
              ),
            ],
          ),
          if (dist > 0 && dur > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.speed, size: 14, color: Colors.blueAccent),
                const SizedBox(width: 4),
                Text(
                  "Pace: $paceStr",
                  style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.electric_bolt,
                    size: 14, color: Colors.orangeAccent),
                const SizedBox(width: 4),
                Text(
                  "Vel: $speedStr",
                  style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }
}
