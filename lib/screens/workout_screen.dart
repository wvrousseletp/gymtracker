import 'routines_screen.dart';
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
import '../widgets/speech_notes_dialog.dart';

import '../widgets/profile_avatar.dart';
import '../utils/workout_starter.dart';
import '../services/rest_timer_service.dart';
import '../widgets/premium_strength_set_card.dart';
import '../widgets/workout_numpad_sheet.dart';
import '../widgets/plate_calculator_dialog.dart';
import 'exercise_hub_screen.dart';

import '../widgets/premium_cardio_view.dart';
import 'notification_settings_dialog.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  String _quickRoutineFilter = 'Todos';

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return "BOM DIA";
    } else if (hour >= 12 && hour < 18) {
      return "BOA TARDE";
    } else {
      return "BOA NOITE";
    }
  }

  String _getDaysAgoText(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "";
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diffDays = now.difference(DateTime(date.year, date.month, date.day)).inDays;
      if (diffDays == 0) return "Hoje";
      if (diffDays == 1) return "Ontem";
      return "Há ${diffDays}d";
    } catch (_) {
      return "";
    }
  }

  Widget _buildQuickRoutineFilterChip(String label, Color accentColor) {
    final isSelected = _quickRoutineFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _quickRoutineFilter = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.2) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accentColor.withOpacity(0.6) : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? accentColor : Colors.white60,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _showRestDayModal(BuildContext context, WorkoutProvider provider, Color accentColor) {
    String selectedReason = 'Recuperação Muscular';
    final reasons = [
      'Recuperação Muscular',
      'Falta de Tempo',
      'Lesão ou Dor',
      'Viagem ou Lazer',
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 24,
            borderColor: accentColor.withOpacity(0.3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.nightlight_round, color: accentColor, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      "Registrar Dia de Descanso",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "Selecione o motivo do descanso de hoje para manter seu histórico organizado:",
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reasons.map((reason) {
                    final isSelected = selectedReason == reason;
                    return ChoiceChip(
                      label: Text(reason),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setDialogState(() => selectedReason = reason);
                      },
                      selectedColor: accentColor.withOpacity(0.25),
                      backgroundColor: Colors.white.withOpacity(0.06),
                      labelStyle: TextStyle(
                        color: isSelected ? accentColor : Colors.white70,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        HapticFeedback.lightImpact();
                        provider.shiftPlannerForward();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Descanso registrado ($selectedReason). Treinos adiados.'),
                            action: SnackBarAction(
                              label: 'Desfazer',
                              onPressed: () {
                                provider.undoShiftPlannerForward();
                              },
                            ),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Confirmar", style: TextStyle(fontWeight: FontWeight.bold)),
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

  bool _isRestDayToday(List<WorkoutLog> history) {
    final todayStr = DateTime.now().toLocal().toString().substring(0, 10);
    return history.any((log) {
      if (log.name != 'Dia de Descanso') return false;
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
    final todayLabel = _getTodayLabel();
    final plannedRoutineIds = provider.todayPlannedItems;
    final accentColor = context.select<ProfileProvider, Color>(
      (p) => ThemeUtils.getColor(p.currentProfile.colorAccent),
    );

    final isRestDay = _isRestDayToday(provider.history);

    // Mapear IDs do planejador para as rotinas reais do usuário
    final List<Routine> plannedRoutines = isRestDay
        ? []
        : plannedRoutineIds
            .map((item) {
              if (item.isEmpty) return null;
              if (item.startsWith('exercise:')) {
                final parts = item.split(':');
                if (parts.length >= 3) {
                  final exerciseId = parts[1];
                  final sets = int.tryParse(parts[2]) ?? 3;
                  final libEx = provider.library
                      .where((l) => l.id == exerciseId)
                      .firstOrNull;
                  if (libEx != null) {
                    final isCardio =
                        (libEx.measurementType == MeasurementType.cardio ||
                                libEx.measurementType ==
                                    MeasurementType.distance) &&
                            libEx.measurementType != MeasurementType.time;
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

            // Cabeçalho Enriquecido com Saudação e Streak
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${_getGreeting()}, ${(provider.currentProfile?.name ?? 'ATLETA').toUpperCase()} 👋",
                      style: TextStyle(
                          color: accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      todayLabel.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Badge de Ofensiva / Streak
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accentColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("🔥", style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            "${provider.streak.consecutiveWeeks} sem",
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
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
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Treino Planejado para Hoje",
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
                if (!isRestDay)
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showRestDayModal(context, provider, accentColor);
                    },
                    icon: Icon(Icons.nightlight_round,
                        color: accentColor, size: 14),
                    label: Text(
                      "Descansar Hoje",
                      style: TextStyle(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (isRestDay)
              const GlassCard(
                padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Center(
                  child: Text(
                    "Hoje é seu dia de descanso!\nAproveite para se recuperar.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else if (plannedRoutines.isEmpty)
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
                                  Builder(builder: (context) {
                                    final estMin = provider.estimateRoutineDurationMinutes(routine);
                                    final tags = provider.getRoutineMuscleTags(routine);
                                    final last = provider.getLastRoutineExecution(routine.name);
                                    final daysAgo = _getDaysAgoText(last?.date);
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "${routine.exercises.length} ex • $totalSets séries • ~$estMin min${daysAgo.isNotEmpty ? ' • $daysAgo' : ''}",
                                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                                        ),
                                        if (tags.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: tags.map((tag) => Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: accentColor.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                tag,
                                                style: TextStyle(
                                                    color: accentColor,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold),
                                              ),
                                            )).toList(),
                                          ),
                                        ],
                                      ],
                                    );
                                  }),
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

            // Iniciar Treino Avulso/Rápido com Filtros
            const Text(
              "Treino Rápido (Qualquer Rotina)",
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickRoutineFilterChip('Todos', accentColor),
                  const SizedBox(width: 6),
                  _buildQuickRoutineFilterChip('Superiores', accentColor),
                  const SizedBox(width: 6),
                  _buildQuickRoutineFilterChip('Inferiores', accentColor),
                  const SizedBox(width: 6),
                  _buildQuickRoutineFilterChip('Cardio', accentColor),
                ],
              ),
            ),
            const SizedBox(height: 10),

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
              Builder(builder: (context) {
                final filtered = provider.routines.where((r) {
                  if (_quickRoutineFilter == 'Todos') return true;
                  final tags = provider.getRoutineMuscleTags(r).map((t) => t.toLowerCase()).toList();
                  if (_quickRoutineFilter == 'Superiores') {
                    return tags.any((t) => t.contains('peito') || t.contains('costas') || t.contains('ombro') || t.contains('bíceps') || t.contains('tríceps'));
                  } else if (_quickRoutineFilter == 'Inferiores') {
                    return tags.any((t) => t.contains('perna') || t.contains('quad') || t.contains('panturrilha') || t.contains('glút'));
                  } else if (_quickRoutineFilter == 'Cardio') {
                    return r.exercises.any((e) => e.isCardio);
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      "Nenhuma rotina nesta categoria.",
                      style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  );
                }

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.0,
                  children: filtered.map((routine) {
                    final estMin = provider.estimateRoutineDurationMinutes(routine);
                    final lastLog = provider.getLastRoutineExecution(routine.name);
                    final daysAgoText = _getDaysAgoText(lastLog?.date);
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${routine.exercises.length} ex • ~$estMin min",
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 10),
                                ),
                                if (daysAgoText.isNotEmpty)
                                  Text(
                                    daysAgoText,
                                    style: TextStyle(
                                        color: accentColor.withOpacity(0.8),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        routine.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.08),
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(36, 36),
                      ),
                    ),
                  ],
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
            final Map<String, int> exerciseFrequency = {};
            for (final log in provider.history) {
              for (final ex in log.exercises) {
                if (ex.completedSets > 0) {
                  exerciseFrequency[ex.name] =
                      (exerciseFrequency[ex.name] ?? 0) + 1;
                }
              }
            }

            final filteredList = library.where((ex) {
              return ex.name
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase()) ||
                  ex.muscle.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList()
              ..sort((a, b) {
                final freqA = exerciseFrequency[a.name] ?? 0;
                final freqB = exerciseFrequency[b.name] ?? 0;
                if (freqA != freqB) {
                  return freqB.compareTo(freqA);
                }
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });

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
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 22),
                            onPressed: () => Navigator.pop(context),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.08),
                              padding: const EdgeInsets.all(6),
                              minimumSize: const Size(36, 36),
                            ),
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
                                                          context,
                                                          provider,
                                                          ex);
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
                    ButtonTheme(
                      alignedDropdown: true,
                      child: ElevatedButton.icon(
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
                            side:
                                BorderSide(color: accentColor.withOpacity(0.3)),
                          ),
                        ),
                        icon: const Icon(Icons.notifications_active_outlined,
                            size: 16),
                        label: const Text("Configurar",
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
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
                        final waterGoal =
                            int.tryParse(waterController.text.trim()) ?? 2000;
                        provider.updateSettings(
                            soundState.value,
                            vibrationState.value,
                            provider.state!.settings.prepSeconds);
                        provider.updateWaterGoal(waterGoal);
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

class _ActiveWorkoutViewState extends State<ActiveWorkoutView>
    with WidgetsBindingObserver {
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
  int? _timerNextTargetReps;
  double? _timerNextTargetWeight;
  int _countdownTotalSeconds = 0;

  // Track last endTime to avoid re-registering the same timer
  int _lastEndTime = 0;

  // Global keys for sets to allow accurate scrolling centering
  final Map<String, GlobalKey> _setCardKeys = {};

  List<List<int>> get _exerciseGroups {
    final exercises = widget.provider.state?.activeWorkout?.exercises ?? [];
    List<List<int>> groups = [];
    for (int i = 0; i < exercises.length; i++) {
      final ex = exercises[i];
      if (ex.supersetId != null &&
          groups.isNotEmpty &&
          groups.last.isNotEmpty &&
          exercises[groups.last.first].supersetId == ex.supersetId) {
        groups.last.add(i);
      } else {
        groups.add([i]);
      }
    }
    return groups;
  }


  GlobalKey _getOrCreateKey(int exIdx, int setIdx) {
    final keyStr = '${exIdx}_$setIdx';
    return _setCardKeys.putIfAbsent(keyStr, () => GlobalKey());
  }

  // Controladores de páginas para exercícios
  int _currentExIdx = 0;
  late PageController _pageController;
  late List<ScrollController> _scrollControllers;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentExIdx = widget.activeWorkout.currentExerciseIndex;
    _pageController =
        PageController(initialPage: _currentExIdx, viewportFraction: 0.95);
    _scrollControllers = List.generate(
      widget.activeWorkout.exercises.length,
      (_) => ScrollController(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToNextSet(_currentExIdx);
    });

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
    for (var sc in _scrollControllers) {
      sc.dispose();
    }
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
        svc.nextTargetReps.value != _timerNextTargetReps ||
        svc.nextTargetWeight.value != _timerNextTargetWeight ||
        svc.totalSeconds.value != _countdownTotalSeconds) {
      if (mounted) {
        setState(() {
          _timerActive = active;
          _timerIsPrep = svc.isPrep.value;
          _timerNextExName = svc.nextExName.value;
          _timerNextSetNum = svc.nextSetNum.value;
          _timerNextTargetReps = svc.nextTargetReps.value;
          _timerNextTargetWeight = svc.nextTargetWeight.value;
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
        _finishWorkoutDirectly(context);
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
        _timerNextTargetReps = svc.nextTargetReps.value;
        _timerNextTargetWeight = svc.nextTargetWeight.value;
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

    widget.provider.clearRestTimer();
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

    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
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
                  // Barra Superior Compacta Glass (~48px)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Esquerda: Nome do Treino + Chip do Exercício Atual
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: accentColor.withOpacity(0.35)),
                                  ),
                                  child: Text(
                                    workout.name.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ),
                              if (exercises.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                if (workout.executionType ==
                                        RoutineExecutionType.circuit &&
                                    workout.circuitCycles > 0) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.deepOrangeAccent
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.deepOrangeAccent
                                              .withOpacity(0.35)),
                                    ),
                                    child: Text(
                                      "Ciclo ${(_currentExIdx ~/ (exercises.length / workout.circuitCycles)) + 1}/${workout.circuitCycles}",
                                      style: const TextStyle(
                                        color: Colors.deepOrangeAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    workout.executionType ==
                                                RoutineExecutionType.circuit &&
                                            workout.circuitCycles > 0
                                        ? "Ex. ${(_currentExIdx % (_exerciseGroups.length ~/ workout.circuitCycles)) + 1}/${_exerciseGroups.length ~/ workout.circuitCycles}"
                                        : "Ex. ${_currentExIdx + 1}/${_exerciseGroups.length}",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Centro/Direita: Cronômetro Compacto + Telemetria Inline + Menu
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Cronômetro digital em cápsula com telemetria
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.timer_outlined,
                                      color: accentColor, size: 14),
                                  const SizedBox(width: 5),
                                  ValueListenableBuilder<int>(
                                    valueListenable: _workoutDurationNotifier,
                                    builder: (context, elapsed, child) {
                                      return Text(
                                        _formatDuration(elapsed),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          fontFeatures: [
                                            FontFeature.tabularFigures()
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  if (hr > 0) ...[
                                    const SizedBox(width: 8),
                                    Text("❤️ $hr",
                                        style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                  if (cal > 0) ...[
                                    const SizedBox(width: 6),
                                    Text("🔥 $cal",
                                        style: const TextStyle(
                                            color: Colors.orangeAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(width: 4),

                            // Menu de Opções Rápido (Adiar / Descartar)
                            PopupMenuButton<String>(
                              color: const Color(0xff2c2c2e),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              icon: const Icon(Icons.more_vert_rounded,
                                  color: Colors.white70, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onSelected: (value) {
                                if (value == 'postpone') {
                                  widget.provider.postponeActiveWorkout();
                                } else if (value == 'discard') {
                                  _confirmDiscardWorkout(context);
                                } else if (value == 'reorder') {
                                  _showReorderExercisesSheet(context);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'reorder',
                                  child: Row(
                                    children: [
                                      Icon(Icons.swap_vert,
                                          color: Colors.blueAccent, size: 20),
                                      SizedBox(width: 12),
                                      Text("Reordenar",
                                          style:
                                              TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'postpone',
                                  child: Row(
                                    children: [
                                      Icon(Icons.snooze,
                                          color: Colors.amberAccent, size: 20),
                                      SizedBox(width: 12),
                                      Text("Adiar Treino",
                                          style:
                                              TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'discard',
                                  child: Row(
                                    children: [
                                      Icon(Icons.close,
                                          color: Colors.redAccent, size: 20),
                                      SizedBox(width: 12),
                                      Text("Descartar",
                                          style: TextStyle(
                                              color: Colors.redAccent)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Micro-barra de Progresso Segmentada dos Exercícios (3px de altura)
                  if (exercises.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Row(
                        children: List.generate(exercises.length, (index) {
                          final isCurrent = _currentExIdx == index;
                          final isCompleted = index < _currentExIdx ||
                              (exercises[index].setsState.isNotEmpty &&
                                  exercises[index]
                                      .setsState
                                      .every((done) => done));
                          return Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 3,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? accentColor
                                    : isCompleted
                                        ? accentColor.withOpacity(0.4)
                                        : Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                  // Carrossel de Exercícios (PageView)
                  if (exercises.isNotEmpty)
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: (index) {
                          setState(() {
                            _currentExIdx = index;
                            widget.provider
                                .setCurrentExerciseIndex(_currentExIdx);
                          });
                          _scrollToNextSet(index, fromUserSwipe: true);
                        },
                        itemCount: _exerciseGroups.length,
                        itemBuilder: (context, groupIndex) {
                          final group = _exerciseGroups[groupIndex];
                          return SingleChildScrollView(
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            controller: _scrollControllers[groupIndex],
                            padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 40),
                            child: Column(
                              children: [
                                for (int i = 0; i < group.length; i++) ...[
                                  _buildExerciseCard(exercises[group[i]], group[i], accentColor),
                                  if (i < group.length - 1)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Icon(Icons.link, color: accentColor.withOpacity(0.5), size: 28),
                                    ),
                                ],

                                // Botão Concluir Treino no último grupo
                                if (groupIndex == _exerciseGroups.length - 1)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 24.0, bottom: 80.0),
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        _finishWorkoutDirectly(context);
                                      },
                                      icon: const Icon(
                                          Icons.check_circle_outline,
                                          size: 22,
                                          color: Colors.black),
                                      label: const Text(
                                        "FINALIZAR TREINO",
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                            letterSpacing: 1),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accentColor,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 14),
                                        elevation: 8,
                                        shadowColor:
                                            accentColor.withOpacity(0.5),
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox(height: 80),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),

              // FLOATING BOTTOM ACTION BAR (Ultra-sleek Glass Capsule)
              if (!keyboardOpen)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 96,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xff1c1c1e).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.12), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Botão Play/Pause Compacto
                            GestureDetector(
                              onTap: () {
                                widget.provider.pauseWorkout(!workout.paused);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: workout.paused
                                      ? Colors.amberAccent.withOpacity(0.2)
                                      : accentColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: workout.paused
                                        ? Colors.amberAccent.withOpacity(0.5)
                                        : accentColor.withOpacity(0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      workout.paused
                                          ? Icons.play_arrow_rounded
                                          : Icons.pause_rounded,
                                      color: workout.paused
                                          ? Colors.amberAccent
                                          : accentColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      workout.paused ? "PAUSADO" : "PAUSAR",
                                      style: TextStyle(
                                        color: workout.paused
                                            ? Colors.amberAccent
                                            : accentColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Botão Finalizar Treino (Direita)
                            GestureDetector(
                              onTap: () {
                                _finishWorkoutDirectly(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: Colors.black,
                                      size: 16,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      "FINALIZAR",
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // Cabeçalho da tela de descanso
                                      Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: _timerIsPrep
                                                  ? Colors.amber
                                                      .withOpacity(0.12)
                                                  : accentColor
                                                      .withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: _timerIsPrep
                                                    ? Colors.amber
                                                        .withOpacity(0.25)
                                                    : accentColor
                                                        .withOpacity(0.25),
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
                                            builder:
                                                (context, remaining, child) {
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
                                                      backgroundColor: Colors
                                                          .white
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
                                                    mainAxisSize:
                                                        MainAxisSize.min,
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
                                                        RestTimerService
                                                            .instance
                                                            .secondsRemaining
                                                            .value;
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
                                                  icon: const Text("-15s",
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16)),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16,
                                                      vertical: 12),
                                                  constraints:
                                                      const BoxConstraints(
                                                          minWidth: 56,
                                                          minHeight: 56),
                                                ),
                                              ),
                                              const SizedBox(width: 24),
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: accentColor
                                                      .withOpacity(0.12),
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
                                                        RestTimerService
                                                            .instance
                                                            .secondsRemaining
                                                            .value;
                                                    widget.provider
                                                        .startRestTimer(
                                                      currentRemaining + 15,
                                                      _timerNextExName,
                                                      _timerNextSetNum,
                                                      _timerIsPrep,
                                                    );
                                                  },
                                                  icon: Text("+15s",
                                                      style: TextStyle(
                                                          color: accentColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16)),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16,
                                                      vertical: 12),
                                                  constraints:
                                                      const BoxConstraints(
                                                          minWidth: 56,
                                                          minHeight: 56),
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
                                                if (_timerNextTargetReps !=
                                                        null &&
                                                    _timerNextTargetWeight !=
                                                        null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 4),
                                                    child: Text(
                                                      "$_timerNextTargetReps reps • ${_timerNextTargetWeight == _timerNextTargetWeight!.toInt() ? _timerNextTargetWeight!.toInt() : _timerNextTargetWeight} kg",
                                                      style: const TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
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
                                                widget.provider
                                                    .clearRestTimer();
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
        ));
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              final libEx = widget.provider.state?.library
                                      .where((l) => l.id == ex.id)
                                      .firstOrNull ??
                                  LibraryExercise(
                                    id: ex.id,
                                    name: ex.name,
                                    muscle: ex.muscle,
                                    measurementType: ex.measurementType,
                                  );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ExerciseHubScreen(exercise: libEx),
                                ),
                              );
                            },
                            child: Text(
                              ex.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert,
                              color: Colors.white54, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showExerciseOptionsBottomSheet(
                              context, widget.provider, ex, accentColor),
                        ),
                      ],
                    ),
                    if (widget
                            .provider.state?.exerciseNotes[ex.id]?.isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.edit_note, color: accentColor, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.provider.state!.exerciseNotes[ex.id]!,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
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
                key: _getOrCreateKey(exIdx, 0),
                setIndex: 0,
                isDone: isDone,
                initialDistance: pc?.distanceKm,
                initialMinutes: pc != null ? pc.durationSeconds ~/ 60 : null,
                goalMinutes: ex.reps > 0 ? ex.reps : null,
                workoutDurationNotifier: _workoutDurationNotifier,
                onChanged: (dist, durMinutes, done) {
                  widget.provider.completeSet(
                    exIdx,
                    0,
                    done,
                    distance: dist,
                    duration: durMinutes * 60,
                  );
                  if (done) {
                    HapticFeedback.heavyImpact();
                    _scrollToNextSet(exIdx);
                  }
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
                    key: _getOrCreateKey(exIdx, setIdx),
                    setIndex: setIdx,
                    isDone: isDone,
                    initialDistance: pc?.distanceKm,
                    initialMinutes:
                        pc != null ? pc.durationSeconds ~/ 60 : null,
                    goalMinutes: ex.reps > 0 ? ex.reps : null,
                    workoutDurationNotifier: _workoutDurationNotifier,
                    onChanged: (dist, durMinutes, done) {
                      widget.provider.completeSet(
                        exIdx,
                        setIdx,
                        done,
                        distance: dist,
                        duration: durMinutes * 60,
                      );
                      if (done) {
                        HapticFeedback.heavyImpact();
                        _scrollToNextSet(exIdx);
                      }
                    },
                  );
                } else {
                  final ghostSet = widget.provider.workoutProvider?.getLastPerformance(ex.name);
                  final card = PremiumStrengthSetCard(
                    key: _getOrCreateKey(exIdx, setIdx),
                    setIndex: setIdx,
                    ex: ex,
                    ghostSet: ghostSet,
                    isDone: isDone,
                    isActive: isActive,
                    isFailure: isFailure,
                    accentColor: accentColor,
                    onEditTap: () async {
                      final currentWeight = ex.weightsPerSet != null && setIdx < ex.weightsPerSet!.length
                          ? ex.weightsPerSet![setIdx]
                          : ex.weight;
                      final currentReps = ex.repsPerSet != null && setIdx < ex.repsPerSet!.length
                          ? ex.repsPerSet![setIdx]
                          : ex.reps;
                      final result = await WorkoutNumpadSheet.show(
                        context,
                        initialWeight: currentWeight,
                        initialReps: currentReps,
                        isTime: ex.measurementType == MeasurementType.time,
                        title: "Editar Série ${setIdx + 1}",
                        ghostText: ghostSet != null ? "Último: ${ghostSet.reps} reps - ${ghostSet.weight}kg" : null,
                      );
                      if (result != null) {
                        widget.provider.updateExerciseSetWeightReps(
                            exIdx, setIdx, result['weight'], result['reps']);
                      }
                    },
                    onSaveValues: (w, r) {
                      widget.provider
                          .updateExerciseSetWeightReps(exIdx, setIdx, w, r);
                    },
                    onFailureTap: () {
                      widget.provider.completeSet(
                        exIdx,
                        setIdx,
                        isDone,
                        isFailure: !isFailure,
                        failureRep: !isFailure ? ex.failureReps[setIdx] : null,
                      );
                      if (!isFailure) {
                        HapticFeedback.heavyImpact();
                        _showFailureRepDialog(
                            context, exIdx, setIdx, ex.failureReps[setIdx]);
                        _scrollToNextSet(exIdx);
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
                        HapticFeedback.heavyImpact();
                        _scrollToNextSet(exIdx);
                      }
                    },
                  );
                  return Dismissible(
                    key: ValueKey('dismiss-${ex.id}-$setIdx'),
                    direction: DismissDirection.horizontal,
                    confirmDismiss: (direction) async {
                      HapticFeedback.heavyImpact();
                      if (direction == DismissDirection.startToEnd) {
                        // Swipe Right: Falha
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
                      } else if (direction == DismissDirection.endToStart) {
                        // Swipe Left: Drop-set
                        final w = ex.weightsPerSet != null && setIdx < ex.weightsPerSet!.length ? ex.weightsPerSet![setIdx] : ex.weight;
                        final dropWeight = (w * 0.8).roundToDouble(); // -20%
                        final r = ex.repsPerSet != null && setIdx < ex.repsPerSet!.length ? ex.repsPerSet![setIdx] : ex.reps;
                        
                        // We need a method to append a drop set. We will just modify the provider.
                        widget.provider.workoutProvider?.addDropSet(exIdx, setIdx, dropWeight, r);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Drop-set adicionado!'), duration: Duration(seconds: 1)));
                      }
                      return false; // Nunca remove o card
                    },
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      color: Colors.redAccent,
                      child: const Row(children: [Icon(Icons.warning, color: Colors.white), SizedBox(width: 8), Text("Falha", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                    ),
                    secondaryBackground: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.purpleAccent,
                      child: const Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text("Drop-set", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), SizedBox(width: 8), Icon(Icons.arrow_downward, color: Colors.white)]),
                    ),
                    child: card,
                  );
                }
              },
            );
          }),
        ],
      ),
    );
  }

  void _showExerciseOptionsBottomSheet(BuildContext context,
      TrackerProvider provider, ActiveExercise ex, Color accentColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1c1c1e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: Icon(Icons.edit_note, color: accentColor),
                title: const Text("Anotações do Exercício",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Salvo globalmente para este exercício",
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showExerciseNotesDialog(context, provider, ex);
                },
              ),
              ListTile(
                leading: Icon(Icons.swap_horiz, color: accentColor),
                title: const Text("Substituir Exercício",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Trocar por outro exercício similar",
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => ExerciseSelectionSheet(
                      library: provider.state?.library ?? [],
                      accentColor: accentColor,
                      onSave: (selected) {
                        if (selected.isNotEmpty) {
                          provider.workoutProvider?.replaceActiveExercise(ex.id, selected.first);
                        }
                      },
                    ),
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.calculate_outlined, color: Colors.white),
                title: const Text("Calculadora de Anilhas",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (_) =>
                        PlateCalculatorDialog(accentColor: accentColor),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showExerciseNotesDialog(
      BuildContext context, TrackerProvider provider, ActiveExercise ex) {
    final initialNote = provider.state?.exerciseNotes[ex.id] ?? "";
    showDialog(
      context: context,
      builder: (ctx) => SpeechNotesDialog(
        exerciseName: ex.name,
        initialNote: initialNote,
        onSave: (note) {
          provider.updateExerciseNote(ex.id, note);
        },
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
              HapticFeedback.lightImpact();
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
  void _showReorderExercisesSheet(BuildContext context) {
    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1c1c1e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            final workout = workoutProvider.activeWorkout;
            if (workout == null) return const SizedBox.shrink();
            final exercises = List<ActiveExercise>.from(workout.exercises);

            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Reordenar Exercícios",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: exercises.length,
                    onReorder: (oldIndex, newIndex) {
                      setStateSheet(() {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final item = exercises.removeAt(oldIndex);
                        exercises.insert(newIndex, item);
                      });
                      workoutProvider.reorderActiveExercises(exercises);
                    },
                    itemBuilder: (ctx, idx) {
                      final ex = exercises[idx];
                      return ListTile(
                        key: ValueKey(ex.id),
                        leading: const Icon(Icons.drag_handle, color: Colors.white54),
                        title: Text(ex.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text("${ex.sets} séries", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeUtils.getColor(widget.provider.currentProfile.colorAccent),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(sheetCtx),
                    child: const Text("Pronto", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }


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

  bool _shouldShowRpeForExercise(int exIdx) {
    final active = widget.provider.state?.activeWorkout;
    if (active == null) return false;

    if (active.executionType == RoutineExecutionType.circuit &&
        active.circuitCycles > 0) {
      final exercisesPerCycle = active.exercises.length ~/ active.circuitCycles;
      if (exercisesPerCycle == 0) return false;
      return (exIdx + 1) % exercisesPerCycle == 0;
    }

    return true; // Always show for standard workouts
  }

  void _scrollToNextSet(int exIdx, {bool fromUserSwipe = false}) {
    final active = widget.provider.state?.activeWorkout;
    if (active == null || exIdx < 0 || exIdx >= active.exercises.length) return;

    final ex = active.exercises[exIdx];
    final allCompleted = ex.setsState.every((isDone) => isDone);

    if (allCompleted) {
      if (fromUserSwipe) return;

      // If RPE has not been answered yet, show the RPE dialog instead of transitioning.
      if (_shouldShowRpeForExercise(exIdx) && ex.rpe == null) {
        _onSetCompleted(exIdx);
      } else {
        // Transition immediately since RPE is already recorded or not needed
        _scrollToNextExerciseAfterRpe(exIdx);
      }
    } else {
      if (fromUserSwipe) return;

      // Find next unfinished set index
      final nextSetIdx = ex.setsState.indexOf(false);
      if (nextSetIdx != -1) {
        final keyStr = '${exIdx}_$nextSetIdx';
        final key = _setCardKeys[keyStr];
        if (key != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final context = key.currentContext;
            if (context != null) {
              Scrollable.ensureVisible(
                context,
                alignment: 0.15,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
              );
            }
          });
        }
      }
    }
  }

  void _onSetCompleted(int exIdx) {
    final active = widget.provider.state?.activeWorkout;
    if (active == null || exIdx < 0 || exIdx >= active.exercises.length) return;

    final ex = active.exercises[exIdx];
    final allCompleted = ex.setsState.every((isDone) => isDone);

    if (allCompleted && ex.rpe == null && _shouldShowRpeForExercise(exIdx)) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _showExerciseRpeDialog(context, exIdx, ex);
        }
      });
    }
  }

  void _scrollToNextExerciseAfterRpe(int exIdx) {
    final active = widget.provider.state?.activeWorkout;
    if (active == null) return;
    if (exIdx < active.exercises.length - 1) {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          exIdx + 1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    } else {
      // Last exercise completed - scroll smoothly to the finish workout button
      if (exIdx < _scrollControllers.length &&
          _scrollControllers[exIdx].hasClients) {
        final sc = _scrollControllers[exIdx];
        sc.animateTo(
          sc.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  String _getRpeDescription(int rpe) {
    switch (rpe) {
      case 1:
      case 2:
        return "Muito Leve (Aquecimento)";
      case 3:
      case 4:
        return "Leve (Fácil de completar)";
      case 5:
      case 6:
        return "Moderado (Esforço perceptível)";
      case 7:
      case 8:
        return "Difícil (Série de trabalho pesada)";
      case 9:
        return "Muito Difícil (Quase falha, 1 rep na reserva)";
      case 10:
        return "Esforço Máximo (Falha total, 0 reps na reserva)";
      default:
        return "";
    }
  }

  void _showExerciseRpeDialog(
      BuildContext context, int exIdx, ActiveExercise ex) {
    double rpeVal = 8.0;
    final accentColor =
        ThemeUtils.getColor(widget.provider.currentProfile.colorAccent);
    final active = widget.provider.state?.activeWorkout;
    final isCircuit = active?.executionType == RoutineExecutionType.circuit;
    final exercisesPerCycle = isCircuit && active!.circuitCycles > 0
        ? active.exercises.length ~/ active.circuitCycles
        : 1;
    final currentCycle = isCircuit && exercisesPerCycle > 0
        ? (exIdx ~/ exercisesPerCycle) + 1
        : 1;

    showDialog(
      context: context,
      barrierDismissible: false, // Force they explicitly save or skip
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
                    Text(
                      isCircuit
                          ? "RPE do Ciclo $currentCycle 🔄"
                          : "RPE do Exercício 💪",
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isCircuit ? "Rodada completa de exercícios" : ex.name,
                      style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isCircuit
                          ? "Qual foi a intensidade do esforço para este ciclo?"
                          : "Qual foi a intensidade do esforço para este exercício?",
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Leve (1)",
                            style:
                                TextStyle(color: Colors.white30, fontSize: 10)),
                        Text(
                          "RPE: ${rpeVal.toInt()}/10",
                          style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
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
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _getRpeDescription(rpeVal.toInt()),
                        key: ValueKey<int>(rpeVal.toInt()),
                        style: TextStyle(
                            color: accentColor.withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            _scrollToNextExerciseAfterRpe(exIdx);
                          },
                          child: const Text("Pular",
                              style: TextStyle(
                                  color: Colors.white30,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            if (isCircuit && exercisesPerCycle > 0) {
                              final cycleStart = (exIdx ~/ exercisesPerCycle) *
                                  exercisesPerCycle;
                              for (int i = cycleStart; i <= exIdx; i++) {
                                widget.provider
                                    .updateExerciseRpe(i, rpeVal.toInt());
                              }
                            } else {
                              widget.provider
                                  .updateExerciseRpe(exIdx, rpeVal.toInt());
                            }
                            Navigator.pop(dialogCtx);
                            _scrollToNextExerciseAfterRpe(exIdx);
                          },
                          child: Text("Salvar",
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

  void _finishWorkoutDirectly(BuildContext context) {

    widget.provider.finishWorkout(
      _workoutDurationNotifier.value,
      8, // calculatedRpe is automatically resolved inside the provider
      "",
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
