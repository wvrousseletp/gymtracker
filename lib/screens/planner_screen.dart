// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, use_key_in_widget_constructors
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/planner/volume_history_sheet.dart';
import '../widgets/planner/cardio_history_sheet.dart';
import '../widgets/planner/modern_planner_card.dart';

import '../providers/tracker_provider.dart';
import '../models/planner_state.dart';
import '../models/routine.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';
import '../utils/workout_starter.dart';
import '../models/workout_log.dart';
import '../services/ai_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/profile_avatar.dart';


class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  static const String _aiCachePrefsKey = 'planner_ai_suggestions_v1';

  final List<String> _daysOfWeek = [
    'seg',
    'ter',
    'qua',
    'qui',
    'sex',
    'sab',
    'dom'
  ];

  // AI Insights State
  final Map<String, Map<String, String>> _aiSuggestionsByDay = {};
  final Map<String, bool> _isLoadingAIByDay = {};
  final Map<String, bool> _showAIByDay = {};

  @override
  void initState() {
    super.initState();
    _loadCachedAISuggestions();
  }

  Future<void> _loadCachedAISuggestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_aiCachePrefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = json.decode(raw);
      if (decoded is! Map) return;
      final Map<String, Map<String, String>> loaded = {};
      decoded.forEach((day, val) {
        if (val is Map) {
          loaded[day.toString()] =
              val.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      });
      if (mounted && loaded.isNotEmpty) {
        setState(() {
          _aiSuggestionsByDay.addAll(loaded);
        });
      }
    } catch (_) {}
  }

  Future<void> _saveCachedAISuggestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_aiCachePrefsKey, json.encode(_aiSuggestionsByDay));
    } catch (_) {}
  }

  Future<void> _toggleOrFetchAI(String day, List<String> items,
      List<WorkoutLog> history, PlannerState state,
      {bool forceRefresh = false}) async {
    if (!forceRefresh && _showAIByDay[day] == true) {
      setState(() => _showAIByDay[day] = false);
      return;
    }

    setState(() {
      _showAIByDay[day] = true;
    });

    if (!forceRefresh && _aiSuggestionsByDay.containsKey(day) &&
        _aiSuggestionsByDay[day]!.isNotEmpty) {
      return; // already fetched/cached
    }

    setState(() {
      _isLoadingAIByDay[day] = true;
    });

    // Parse planned exercises
    List<String> plannedExercises = [];
    for (var rawItem in items) {
      if (rawItem.startsWith('routine:')) {
        final rId = rawItem.substring(8);
        final r = state.routines.where((x) => x.id == rId).firstOrNull;
        if (r != null) {
          for (var e in r.exercises) {
            final libEx =
                state.library.where((x) => x.id == e.exerciseId).firstOrNull;
            if (libEx != null) plannedExercises.add(libEx.name);
          }
        }
      } else if (rawItem.startsWith('exercise:')) {
        final parts = rawItem.split(':');
        if (parts.length >= 2) {
          final libEx =
              state.library.where((x) => x.id == parts[1]).firstOrNull;
          if (libEx != null) plannedExercises.add(libEx.name);
        }
      } else if (rawItem.isNotEmpty) {
        final r = state.routines.where((x) => x.id == rawItem).firstOrNull;
        if (r != null) {
          for (var e in r.exercises) {
            final libEx =
                state.library.where((x) => x.id == e.exerciseId).firstOrNull;
            if (libEx != null) plannedExercises.add(libEx.name);
          }
        }
      }
    }

    final aiService = AIService();
    final suggestions = await aiService.generateWorkoutSuggestions(
      plannedExercises: plannedExercises,
      recentHistory: history,
    );

    if (mounted) {
      setState(() {
        if (suggestions.isNotEmpty || !_aiSuggestionsByDay.containsKey(day)) {
          _aiSuggestionsByDay[day] = suggestions;
        }
        _isLoadingAIByDay[day] = false;
      });
      if (suggestions.isNotEmpty) {
        await _saveCachedAISuggestions();
      }
    }
  }

  String _getDayNamePt(String day) {
    switch (day) {
      case 'seg':
        return 'Segunda-feira';
      case 'ter':
        return 'Terça-feira';
      case 'qua':
        return 'Quarta-feira';
      case 'qui':
        return 'Quinta-feira';
      case 'sex':
        return 'Sexta-feira';
      case 'sab':
        return 'Sábado';
      case 'dom':
        return 'Domingo';
      default:
        return '';
    }
  }

  Widget _buildWeeklyStreakHeader(BuildContext context, TrackerProvider provider,
      PlannerState state, Color accentColor) {
    final streak = state.streak;
    
    // Calcula progresso da meta
    final currentCount = streak.currentWeekCount;
    final goal = streak.weeklyGoal > 0 ? streak.weeklyGoal : 1;
    final progress = (currentCount / goal).clamp(0.0, 1.0);
    final goalMet = currentCount >= goal;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: goalMet ? Colors.amber.withOpacity(0.3) : Colors.orangeAccent.withOpacity(0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department_rounded,
                  color: goalMet ? Colors.amber : Colors.orangeAccent, size: 24),
              const SizedBox(width: 8),
              Text(
                "Consistência Semanal",
                style: TextStyle(
                  color: goalMet ? Colors.amber : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              // Freezes badge
              if (streak.availableFreezes > 0)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.ac_unit, color: Colors.blueAccent, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        "${streak.availableFreezes}",
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              // Weeks badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star,
                        color: Colors.orangeAccent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "${streak.consecutiveWeeks} sem.",
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Indicador de treinos na semana com Barra de Progresso
          GestureDetector(
            onTap: () => _showGoalSettings(context, provider, streak),
            child: Container(
              color: Colors.transparent, // expand tap area
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Meta Semanal:",
                            style: TextStyle(
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Color(0xFF3C3C43)),
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.edit, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Color(0xFF8E8E93)), size: 14),
                        ],
                      ),
                      Text(
                        "$currentCount / $goal dias",
                        style: TextStyle(
                            color: goalMet ? Colors.amber : Colors.greenAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          goalMet ? Colors.amber : Colors.greenAccent),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 7 círculos representando os treinos realizados
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (dayIndex) {
              final weekday = dayIndex + 1;
              final isToday = weekday == DateTime.now().weekday;
              final filled = streak.weekdaysTrained.contains(weekday);
              final isPlannedRest = streak.plannedRestDays.contains(weekday);
              final dayInitial = _daysOfWeek[dayIndex].substring(0, 1).toUpperCase();
              
              final dayData = streak.weekdaysData[weekday];
              final isCardio = dayData != null && (dayData['isCardio'] == true);
              final isMixed = dayData != null && (dayData['isMixed'] == true);
              
              Color primaryColor = Colors.greenAccent;
              Color secondaryColor = Colors.green;
              if (isMixed) {
                primaryColor = Colors.purpleAccent;
                secondaryColor = Colors.deepPurple;
              } else if (isCardio) {
                primaryColor = Colors.lightBlueAccent;
                secondaryColor = Colors.blue;
              }
              
              Widget content = Text(
                dayInitial,
                style: TextStyle(
                  color: filled ? Colors.white : (isToday ? (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)) : (Theme.of(context).brightness == Brightness.dark ? Colors.white24 : const Color(0xFFC7C7CC))),
                  fontSize: 12,
                  fontWeight: filled || isToday ? FontWeight.bold : FontWeight.normal,
                ),
              );
              
              if (!filled && isPlannedRest) {
                content = Icon(Icons.battery_charging_full_rounded, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)), size: 16);
              }

              return GestureDetector(
                onTap: filled && dayData != null ? () {
                  _showWorkoutSummary(context, weekday, dayData);
                } : null,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: filled
                        ? RadialGradient(
                            colors: [
                              primaryColor.withOpacity(0.35),
                              secondaryColor.withOpacity(0.12),
                            ],
                            center: const Alignment(-0.3, -0.3),
                            radius: 0.8,
                          )
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
                              (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.01),
                            ],
                          ),
                    boxShadow: filled
                        ? [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.25),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : [],
                    border: Border.all(
                      color: isToday
                          ? Colors.white.withOpacity(0.5)
                          : (filled
                              ? primaryColor.withOpacity(0.8)
                              : (isPlannedRest ? Colors.white.withOpacity(0.15) : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08))),
                      width: isToday ? 2.0 : 1.5,
                    ),
                  ),
                  child: content,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showWorkoutSummary(BuildContext context, int weekday, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Treino';
    final isCardio = data['isCardio'] == true;
    final isMixed = data['isMixed'] == true;
    final tonnage = data['tonnage'] ?? 0.0;
    final duration = data['duration'] ?? 0;
    final cals = data['activeCalories'] ?? 0;
    final workoutCount = data['workoutCount'] ?? 1;
    
    final mins = duration ~/ 60;
    final String dayName = _daysOfWeek[weekday - 1];
    
    IconData iconType = Icons.fitness_center;
    Color iconColor = Colors.greenAccent;
    if (isMixed) {
      iconType = Icons.all_inclusive;
      iconColor = Colors.purpleAccent;
    } else if (isCardio) {
      iconType = Icons.directions_run;
      iconColor = Colors.lightBlueAccent;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(iconType, color: iconColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workoutCount > 1 ? "Treino Duplo ($workoutCount)" : name,
                          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)), fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          dayName,
                          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)), fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryStat(Icons.timer, "$mins min", "Duração"),
                  if (cals > 0) _buildSummaryStat(Icons.local_fire_department, "$cals kcal", "Calorias"),
                  if (!isCardio && tonnage > 0) _buildSummaryStat(Icons.monitor_weight, "${(tonnage / 1000).toStringAsFixed(1)}t", "Volume"),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)), size: 28),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)), fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)), fontSize: 12)),
      ],
    );
  }

  void _showGoalSettings(BuildContext context, TrackerProvider provider, WorkoutStreak streak) {
    int currentGoal = streak.weeklyGoal;
    List<int> currentRestDays = List.from(streak.plannedRestDays);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Configurar Consistência", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Text("Meta Semanal (dias)", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)), fontSize: 14)),
                  Slider(
                    value: currentGoal.toDouble(),
                    min: 1,
                    max: 7,
                    divisions: 6,
                    activeColor: Colors.amber,
                    label: currentGoal.toString(),
                    onChanged: (val) {
                      setModalState(() => currentGoal = val.toInt());
                    },
                  ),
                  Center(
                    child: Text("$currentGoal dias por semana", style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 32),
                  Text("Dias de Descanso (Rest Days)", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)), fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      final weekday = index + 1;
                      final isRest = currentRestDays.contains(weekday);
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            if (isRest) {
                              currentRestDays.remove(weekday);
                            } else {
                              currentRestDays.add(weekday);
                            }
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isRest ? Colors.white.withOpacity(0.15) : Colors.transparent,
                            border: Border.all(color: isRest ? (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)) : (Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.black12)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _daysOfWeek[index].substring(0, 1).toUpperCase(),
                            style: TextStyle(color: isRest ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)), fontWeight: isRest ? FontWeight.bold : FontWeight.normal),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        provider.workoutProvider?.updateWeeklyConsistencySettings(currentGoal, currentRestDays);
                        Navigator.pop(ctx);
                      },
                      child: const Text("Salvar Preferências", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          }
        );
      }
    );
  }


  Widget _buildPlannedVolumeHeader(
    BuildContext context,
    TrackerProvider provider,
    PlannerState state,
    Color accentColor,
  ) {
    // Calcular volume planejado por grupo muscular
    final Map<String, int> strengthMap = {};
    final Map<String, int> cardioMap = {};

    for (final day in state.planner.keys) {
      final items = state.planner[day] ?? [];
      for (final rawItem in items) {
        if (rawItem.startsWith('routine:')) {
          final routineId = rawItem.substring(8);
          final routine =
              state.routines.where((r) => r.id == routineId).firstOrNull;
          if (routine != null) {
            for (final re in routine.exercises) {
              final libEx =
                  state.library.where((e) => e.id == re.exerciseId).firstOrNull;
              if (libEx != null) {
                final muscle = libEx.muscle;
                final isCardio = muscle.toLowerCase().contains('cardio');
                if (isCardio) {
                  int durationMinutes = (re.reps > 0) ? (re.reps ~/ 60) : 30; // Default 30 min if no duration set
                  if (re.sets > 1) durationMinutes *= re.sets;
                  cardioMap[muscle] = (cardioMap[muscle] ?? 0) + durationMinutes;
                } else {
                  strengthMap[muscle] =
                      (strengthMap[muscle] ?? 0) + re.sets.toInt();
                }
              }
            }
          }
        } else if (rawItem.startsWith('exercise:')) {
          final parts = rawItem.split(':');
          if (parts.length >= 3) {
            final exId = parts[1];
            final quantity = int.tryParse(parts[2]) ?? 3;
            final libEx = state.library.where((e) => e.id == exId).firstOrNull;
            if (libEx != null) {
              final muscle = libEx.muscle;
              final isCardio = muscle.toLowerCase().contains('cardio');
              if (isCardio) {
                cardioMap[muscle] = (cardioMap[muscle] ?? 0) + quantity;
              } else {
                strengthMap[muscle] = (strengthMap[muscle] ?? 0) + quantity;
              }
            }
          }
        } else if (rawItem.isNotEmpty) {
          final routine =
              state.routines.where((r) => r.id == rawItem).firstOrNull;
          if (routine != null) {
            for (final re in routine.exercises) {
              final libEx =
                  state.library.where((e) => e.id == re.exerciseId).firstOrNull;
              if (libEx != null) {
                final muscle = libEx.muscle;
                final isCardio = muscle.toLowerCase().contains('cardio');
                if (isCardio) {
                  int durationMinutes = (re.reps > 0) ? (re.reps ~/ 60) : 30;
                  if (re.sets > 1) durationMinutes *= re.sets;
                  cardioMap[muscle] = (cardioMap[muscle] ?? 0) + durationMinutes;
                } else {
                  strengthMap[muscle] =
                      (strengthMap[muscle] ?? 0) + re.sets.toInt();
                }
              }
            }
          }
        }
      }
    }

    // Filter "Outros"
    int outrosVolume = 0;
    final keysToRemove = [];
    for (final key in strengthMap.keys) {
      if (key.toLowerCase().contains("outros")) {
        outrosVolume += strengthMap[key]!;
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      strengthMap.remove(key);
    }

    final sortedStrength = strengthMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final int totalCardio = cardioMap.values.fold(0, (sum, val) => sum + val);

    Color getVolumeColor(int sets) {
      if (sets < 10) return Colors.orangeAccent;
      if (sets <= 20) return Colors.greenAccent;
      return Colors.redAccent;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Volume de Musculação
        GlassCard(
          padding: const EdgeInsets.all(16),
          borderColor: accentColor.withOpacity(0.15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.fitness_center_rounded, color: accentColor, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        "Volume de Treino Planejado",
                        style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)), fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => VolumeHistorySheet(accentColor: accentColor),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.black12), shape: BoxShape.circle),
                      child: Icon(Icons.history, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)), size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (sortedStrength.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      "Nenhum treino de musculação planejado.",
                      style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Color(0xFF8E8E93)), fontStyle: FontStyle.italic, fontSize: 13),
                    ),
                  ),
                )
              else
                Column(
                  children: sortedStrength.map((entry) {
                    const maxTarget = 24.0;
                    final fraction = (entry.value / maxTarget).clamp(0.0, 1.0);
                    final barColor = getVolumeColor(entry.value);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)), fontSize: 13, fontWeight: FontWeight.bold)),
                              Text(
                                "${entry.value} séries",
                                style: TextStyle(color: barColor, fontSize: 13, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              height: 6,
                              width: double.infinity,
                              child: Stack(
                                children: [
                                  Container(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05)),
                                  // Marker 10 sets
                                  FractionallySizedBox(
                                    widthFactor: 10 / maxTarget,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(width: 2, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF8E8E93))),
                                    )
                                  ),
                                  // Marker 20 sets
                                  FractionallySizedBox(
                                    widthFactor: 20 / maxTarget,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(width: 2, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF8E8E93))),
                                    )
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: fraction,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        gradient: LinearGradient(
                                          colors: [barColor.withOpacity(0.5), barColor],
                                        ),
                                        boxShadow: [
                                          BoxShadow(color: barColor.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 1))
                                        ]
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              if (outrosVolume > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    "Você também possui $outrosVolume séries de exercícios marcados como 'Outros'.",
                    style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF8E8E93)), fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        // 2. Volume de Cardio
        GlassCard(
          padding: const EdgeInsets.all(16),
          borderColor: Colors.blueAccent.withOpacity(0.15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.directions_run_rounded, color: Colors.blueAccent, size: 22),
                      SizedBox(width: 8),
                      Text(
                        "Volume de Cardio Planejado",
                        style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)), fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => CardioHistorySheet(accentColor: Colors.blueAccent),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.black12), shape: BoxShape.circle),
                      child: Icon(Icons.history, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)), size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (totalCardio == 0)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      "Nenhum cardio planejado.",
                      style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Color(0xFF8E8E93)), fontStyle: FontStyle.italic, fontSize: 13),
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Progresso Semanal", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)), fontSize: 13, fontWeight: FontWeight.bold)),
                        Text(
                          "$totalCardio / 300 min",
                          style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 6,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            Container(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05)),
                            FractionallySizedBox(
                              widthFactor: (totalCardio / 300.0).clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: LinearGradient(
                                    colors: [Colors.blueAccent.withOpacity(0.5), Colors.blueAccent],
                                  ),
                                  boxShadow: [
                                    BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 1))
                                  ]
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Meta ideal de saúde e queima calórica: 300 min/semana.",
                      style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Color(0xFF6E6E73)), fontSize: 11),
                    )
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final state =
        context.select<TrackerProvider, PlannerState?>((p) => p.state);
    final accentColor = context.select<TrackerProvider, Color>(
      (p) => ThemeUtils.getColor(p.currentProfile.colorAccent),
    );
    final provider = Provider.of<TrackerProvider>(context, listen: true);

    if (state == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding:
            const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
        children: [
          // 1. Consistência Semanal
          _buildWeeklyStreakHeader(context, provider, state, accentColor),
          const SizedBox(height: 16),

          // 2. Volume de Treino Planejado
          _buildPlannedVolumeHeader(context, provider, state, accentColor),
          const SizedBox(height: 24),

          // Seletor de Modo de Organização
          _buildOrganizationModeSelector(context, provider, state, accentColor),
          const SizedBox(height: 16),

          // Agenda
          if (state.settings.organizationMode ==
              OrganizationMode.continuousList)
            ..._buildContinuousListAgenda(context, provider, state, accentColor)
          else
            ..._buildFixedDaysAgenda(context, provider, state, accentColor),
        ],
      ),
    );
  }

  

  void _showItemSelectionSheet(BuildContext context, TrackerProvider provider, PlannerState state, Color accentColor, {required Function(String) onSelected, bool allowExercises = true}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetText = isDark ? Colors.white : const Color(0xFF1C1C1E);
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141414) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white24 : const Color(0xFFC7C7CC)), borderRadius: BorderRadius.circular(2)),
              ),
              Text("Selecionar", style: TextStyle(color: sheetText, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    Text("MODELOS DE TREINO", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    ...state.routines.map((r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: accentColor.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(Icons.fitness_center, color: accentColor, size: 20),
                      ),
                      title: Text(r.name, style: TextStyle(color: sheetText, fontWeight: FontWeight.w600)),
                      subtitle: Text("${r.exercises.length} exercícios", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)), fontSize: 12)),
                      onTap: () { Navigator.pop(ctx); onSelected("routine:${r.id}"); },
                    )),
                    if (allowExercises) ...[
                      const SizedBox(height: 24),
                      Text("CARDIO E EXERCÍCIOS AVULSOS", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
                          title: Text(ex.name, style: TextStyle(color: sheetText, fontWeight: FontWeight.w600)),
                          subtitle: Text(ex.muscle, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)), fontSize: 12)),
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

  Widget _buildBlockItemRow(
    BuildContext context,
    TrackerProvider provider,
    PlannerState state,
    String blockId,
    int idx,
    String rawItem,
    Color accentColor,
    int flatIndex,
    int blockLength,
  ) {
    void onPick(String val) {
      if (val.startsWith('exercise:')) {
        final exId = val.substring(9);
        final libEx =
            state.library.where((e) => e.id == exId).firstOrNull;
        final isCardio = libEx != null &&
            ((libEx.measurementType == MeasurementType.cardio ||
                    libEx.measurementType == MeasurementType.distance) &&
                libEx.measurementType != MeasurementType.time);
        provider.updateRoutineInContinuousBlock(
            blockId, idx, "$val:${isCardio ? 30 : 3}");
      } else {
        provider.updateRoutineInContinuousBlock(blockId, idx, val);
      }
    }

    void openSelection() {
      _showItemSelectionSheet(context, provider, state, accentColor,
          onSelected: onPick);
    }

    Widget buildTrailing() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rawItem.startsWith('exercise:'))
              InkWell(
                onTap: () => _showExercisePlanConfigSheet(
                  context,
                  state,
                  rawItem,
                  accentColor,
                  (newRaw) => provider.updateRoutineInContinuousBlock(
                      blockId, idx, newRaw),
                ),
                child: Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.tune,
                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Color(0xFF6E6E73)), size: 16),
                ),
              ),
            InkWell(
              onTap: () => provider.setContinuousListIndex(flatIndex),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.play_circle_outline,
                    color: accentColor, size: 18),
              ),
            ),
            InkWell(
              onTap: idx > 0
                  ? () => provider.reorderRoutinesInContinuousBlock(
                      blockId, idx, idx - 1)
                  : null,
              child: Icon(Icons.keyboard_arrow_up,
                  color: idx > 0 ? (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)) : Colors.transparent,
                  size: 20),
            ),
            InkWell(
              onTap: idx < blockLength - 1
                  ? () => provider.reorderRoutinesInContinuousBlock(
                      blockId, idx, idx + 1)
                  : null,
              child: Icon(Icons.keyboard_arrow_down,
                  color: idx < blockLength - 1
                      ? (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73))
                      : Colors.transparent,
                  size: 20),
            ),
          ],
        );

    // Rotina
    Routine? selectedRoutine;
    if (rawItem.startsWith('routine:')) {
      final rId = rawItem.substring(8);
      selectedRoutine =
          state.routines.where((r) => r.id == rId).firstOrNull;
    } else if (rawItem.isNotEmpty && !rawItem.startsWith('exercise:')) {
      selectedRoutine =
          state.routines.where((r) => r.id == rawItem).firstOrNull;
    }

    if (selectedRoutine != null) {
      return ModernPlannerCard(
        title: selectedRoutine.name,
        subtitle: "${selectedRoutine.exercises.length} exercícios",
        icon: Icons.fitness_center,
        color: accentColor,
        onTap: openSelection,
        onStart: () {
          final wp = Provider.of<WorkoutProvider>(context, listen: false);
          WorkoutStarter.startWithCountdown(
            context,
            wp,
            selectedRoutine!,
            WorkoutRecovery(
                sleepOk: SleepQuality.okay, pain: [], warmUpDone: false),
            false,
          );
        },
        onDelete: () => provider.removeRoutineFromContinuousBlock(blockId, idx),
        trailing: buildTrailing(),
      );
    }

    // Exercício avulso / cardio
    LibraryExercise? selectedExercise;
    int exerciseQty = 3;
    int exerciseReps = 0;
    double exerciseWeight = 0;
    bool exerciseIsCardio = false;
    if (rawItem.startsWith('exercise:')) {
      final parts = rawItem.split(':');
      if (parts.length >= 2) {
        exerciseQty =
            parts.length >= 3 ? (int.tryParse(parts[2]) ?? 3) : 3;
        exerciseReps =
            parts.length >= 4 ? int.tryParse(parts[3]) ?? 0 : 0;
        exerciseWeight = parts.length >= 5
            ? double.tryParse(parts[4]) ?? 0
            : 0;
        selectedExercise =
            state.library.where((e) => e.id == parts[1]).firstOrNull;
        if (selectedExercise != null) {
          exerciseIsCardio =
              (selectedExercise.measurementType == MeasurementType.cardio ||
                      selectedExercise.measurementType ==
                          MeasurementType.distance) &&
                  selectedExercise.measurementType != MeasurementType.time;
        }
      }
    }

    if (selectedExercise != null) {
      final libEx = selectedExercise;
      final wTxt =
          exerciseWeight > 0 ? ' • $exerciseWeight' 'kg' : '';
      return ModernPlannerCard(
        title: libEx.name,
        subtitle: exerciseIsCardio
            ? "Cardio • $exerciseQty min"
            : (exerciseReps > 0 || exerciseWeight > 0)
                ? "Avulso • $exerciseQty×${exerciseReps > 0 ? exerciseReps : 10} reps$wTxt"
                : "Avulso • $exerciseQty séries",
        icon: exerciseIsCardio
            ? Icons.directions_run
            : Icons.accessibility_new,
        color: exerciseIsCardio ? Colors.blueAccent : Colors.orangeAccent,
        onTap: openSelection,
        onStart: () {
          final tempRoutine = Routine(
            id: "temp-${libEx.id}-$exerciseQty",
            name: "${libEx.name} (Avulso)",
            defaultRest: 60,
            isDynamicExercise: true,
            exercises: [
              RoutineExercise(
                id: "e-temp-1",
                exerciseId: libEx.id,
                sets: exerciseQty,
                reps: exerciseIsCardio ? 30 : (exerciseReps > 0 ? exerciseReps : 10),
                rest: 60,
                weight: exerciseIsCardio ? 0.0 : exerciseWeight,
                isCardio: exerciseIsCardio,
              )
            ],
          );
          final wp = Provider.of<WorkoutProvider>(context, listen: false);
          WorkoutStarter.startWithCountdown(
            context,
            wp,
            tempRoutine,
            WorkoutRecovery(
                sleepOk: SleepQuality.okay, pain: [], warmUpDone: false),
            false,
          );
        },
        onDelete: () => provider.removeRoutineFromContinuousBlock(blockId, idx),
        trailing: buildTrailing(),
      );
    }

    return ModernPlannerCard(
      title: "Tocar para escolher treino...",
      subtitle: "",
      icon: Icons.search,
      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
      onTap: openSelection,
      onDelete: () => provider.removeRoutineFromContinuousBlock(blockId, idx),
    );
  }

  /// Abre um sheet para configurar séries/reps/peso (ou minutos, no caso de
  /// cardio) de um item "exercise:" do planejador. Salva no formato
  /// exercise:<id>:<sets>:<reps>:<weight> (cardio mantém exercise:<id>:<min>).
  void _showExercisePlanConfigSheet(
    BuildContext context,
    PlannerState state,
    String rawItem,
    Color accentColor,
    void Function(String newRaw) onSave,
  ) {
    final parts = rawItem.split(':');
    if (parts.length < 2) return;
    final exId = parts[1];
    final libEx =
        state.library.where((e) => e.id == exId).firstOrNull;
    if (libEx == null) return;
    final isCardio =
        (libEx.measurementType == MeasurementType.cardio ||
                libEx.measurementType == MeasurementType.distance) &&
            libEx.measurementType != MeasurementType.time;

    final setsCtrl = TextEditingController(
        text: parts.length >= 3 && parts[2].isNotEmpty ? parts[2] : '3');
    final repsCtrl = TextEditingController(
        text: parts.length >= 4 && parts[3].isNotEmpty ? parts[3] : '10');
    final weightCtrl = TextEditingController(
        text: parts.length >= 5 && parts[4].isNotEmpty ? parts[4] : '0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141414),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white24 : const Color(0xFFC7C7CC)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Configurar ${libEx.name}",
                style: TextStyle(
                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)),
                    fontSize: 17,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                isCardio
                    ? "Defina a duração em minutos"
                    : "Defina séries, repetições e peso-alvo",
                style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)), fontSize: 12),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _configField(
                      label: isCardio ? "Minutos" : "Séries",
                      controller: setsCtrl,
                    ),
                  ),
                  if (!isCardio) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _configField(
                          label: "Reps", controller: repsCtrl),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _configField(
                          label: "Peso (kg)", controller: weightCtrl),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    final sets =
                        int.tryParse(setsCtrl.text.trim()) ?? (isCardio ? 30 : 3);
                    if (isCardio) {
                      onSave("exercise:$exId:${sets < 1 ? 1 : sets}");
                    } else {
                      final reps =
                          int.tryParse(repsCtrl.text.trim()) ?? 10;
                      final weight =
                          double.tryParse(weightCtrl.text.trim()) ?? 0.0;
                      onSave(
                          "exercise:$exId:${sets < 1 ? 1 : sets}:${reps < 1 ? 1 : reps}:${weight < 0 ? 0 : weight}");
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text("Salvar",
                      style: TextStyle(
                          color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)),
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _configField(
      {required String label, required TextEditingController controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Color(0xFF6E6E73)),
                fontSize: 11,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E))),
          decoration: InputDecoration(
            filled: true,
            fillColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPlannerItemRow(
    BuildContext context,
    TrackerProvider provider,
    String day,
    int idx,
    int itemCount,
    String rawItem,
    Color accentColor,
  ) {
    final state = context.select<TrackerProvider, PlannerState>((p) => p.state!);
    final library = state.library;
    final routines = state.routines;

    String selectedValue = "";
    int quantityValue = 3;
    int exerciseReps = 0;
    double exerciseWeight = 0;

    if (rawItem.startsWith('routine:')) {
      selectedValue = rawItem;
    } else if (rawItem.startsWith('exercise:')) {
      final parts = rawItem.split(':');
      if (parts.length >= 3) {
        selectedValue = "${parts[0]}:${parts[1]}";
        quantityValue = int.tryParse(parts[2]) ?? 3;
        exerciseReps =
            parts.length >= 4 ? int.tryParse(parts[3]) ?? 0 : 0;
        exerciseWeight = parts.length >= 5
            ? double.tryParse(parts[4]) ?? 0
            : 0;
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
    Color color = (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73));
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
        if (isCardio) {
          subtitle = "Cardio";
        } else if (exerciseReps > 0 || exerciseWeight > 0) {
          final wTxt = exerciseWeight > 0 ? ' • $exerciseWeight' 'kg' : '';
          subtitle =
              "Avulso • $quantityValue×${exerciseReps > 0 ? exerciseReps : 10} reps$wTxt";
        } else {
          subtitle = "Exercício Isolado";
        }
        icon = isCardio ? Icons.directions_run : Icons.accessibility_new;
        color = isCardio ? Colors.blueAccent : Colors.orangeAccent;
      }
    }

    return ModernPlannerCard(
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
      onStart: routineToStart != null ? () {
        final wp = Provider.of<WorkoutProvider>(context, listen: false);
        WorkoutStarter.startWithCountdown(
          context,
          wp,
          routineToStart!,
          WorkoutRecovery(sleepOk: SleepQuality.okay, pain: [], warmUpDone: false),
          false,
        );
      } : null,
      onDelete: () => provider.removePlannerItem(day, idx),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedValue.startsWith('exercise:')) ...[
            InkWell(
              onTap: () => _showExercisePlanConfigSheet(
                context,
                state,
                rawItem,
                accentColor,
                (newRaw) =>
                    provider.updatePlannerItem(day, idx, newRaw),
              ),
              child: Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.tune,
                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Color(0xFF6E6E73)), size: 18),
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (selectedValue.startsWith('exercise:'))
            Container(
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
                      style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)), fontSize: 14, fontWeight: FontWeight.bold),
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
                          final tail = parts.length > 3
                              ? ':${parts.sublist(3).join(':')}'
                              : '';
                          provider.updatePlannerItem(
                              day, idx, "${parts[0]}:${parts[1]}:$quantity$tail");
                        }
                      },
                    ),
                  ),
                  Text(isCardio ? "min" : "sér", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)), fontSize: 10)),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: idx > 0 ? () => provider.reorderPlannerItem(day, idx, true) : null,
                child: Icon(Icons.keyboard_arrow_up,
                    color: idx > 0 ? (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)) : Colors.transparent, size: 20),
              ),
              InkWell(
                onTap: idx < itemCount - 1 ? () => provider.reorderPlannerItem(day, idx, false) : null,
                child: Icon(Icons.keyboard_arrow_down,
                    color: idx < itemCount - 1 ? (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)) : Colors.transparent, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationModeSelector(BuildContext context,
      TrackerProvider provider, PlannerState state, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildModeOption(
            context: context,
            title: "Dias Fixos",
            icon: Icons.calendar_month,
            mode: OrganizationMode.fixedDays,
            currentMode: state.settings.organizationMode,
            provider: provider,
            accentColor: accentColor,
          ),
          _buildModeOption(
            context: context,
            title: "Contínuo",
            icon: Icons.format_list_numbered,
            mode: OrganizationMode.continuousList,
            currentMode: state.settings.organizationMode,
            provider: provider,
            accentColor: accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    required OrganizationMode mode,
    required OrganizationMode currentMode,
    required TrackerProvider provider,
    required Color accentColor,
  }) {
    final isSelected = mode == currentMode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          provider.setOrganizationMode(mode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected ? accentColor.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: isSelected ? accentColor : (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)), size: 20),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? accentColor : (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFixedDaysAgenda(BuildContext context,
      TrackerProvider provider, PlannerState state, Color accentColor) {
    return [
      // Seção Cronograma Semanal
      Row(
        children: [
          Icon(Icons.calendar_month, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)), size: 20),
          const SizedBox(width: 8),
          Text(
            "Cronograma Semanal",
            style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_rounded,
                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Color(0xFF3C3C43)), size: 14),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  constraints: const BoxConstraints(),
                  tooltip: "Voltar cronograma em 1 dia",
                  onPressed: () {
                    provider.shiftPlannerBackwardWithoutLog();
                  },
                ),
                Container(
                    width: 1, height: 16, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)).withOpacity(0.1)),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios_rounded,
                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Color(0xFF3C3C43)), size: 14),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  constraints: const BoxConstraints(),
                  tooltip: "Avançar cronograma em 1 dia",
                  onPressed: () {
                    provider.shiftPlannerForwardWithoutLog();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: IconButton(
              icon: Icon(Icons.view_week_outlined,
                  color: accentColor, size: 18),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: const BoxConstraints(),
              tooltip: "Modelos de semana",
              onPressed: () {
                _showWeekTemplatesSheet(context, provider, accentColor);
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),

      // Dias da semana
      ..._daysOfWeek.map((day) {
        final items = state.planner[day] ?? [];
        final isToday = (_daysOfWeek.indexOf(day) + 1) == DateTime.now().weekday;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            borderColor: isToday ? accentColor.withOpacity(0.6) : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.06),
            opacity: isToday ? 0.12 : 0.07,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho do dia
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getDayNamePt(day),
                          style: TextStyle(
                            color: isToday ? Colors.white : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (isToday)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              "HOJE",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        if (items.isNotEmpty)
                          IconButton(
                            icon: Icon(
                              _showAIByDay[day] == true
                                  ? Icons.auto_awesome
                                  : Icons.auto_awesome_outlined,
                              color: _showAIByDay[day] == true
                                  ? accentColor
                                  : Colors.amber,
                              size: 22,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: "Dicas de Treino (IA)",
                            onPressed: () => _toggleOrFetchAI(
                                day, items, provider.state!.history, state),
                          ),
                        if (items.isNotEmpty) const SizedBox(width: 16),
                        IconButton(
                          icon: Icon(Icons.copy_all_outlined,
                              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)), size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: "Copiar este dia para outro",
                          onPressed: () {
                            _showCopyDayDialog(context, provider, day, accentColor);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.add_box_outlined,
                              color: accentColor, size: 22),
                          visualDensity: VisualDensity.compact,
                          tooltip: "Adicionar treino",
                          onPressed: () {
                            _showItemSelectionSheet(
                              context,
                              provider,
                              state,
                              accentColor,
                              onSelected: (val) {
                                final newIdx =
                                    (provider.state?.planner[day] ?? []).length;
                                provider.addPlannerItem(day);
                                if (val.startsWith('exercise:')) {
                                  final exId = val.substring(9);
                                  final libEx = state.library
                                      .where((e) => e.id == exId)
                                      .firstOrNull;
                                  final isCardio = libEx != null &&
                                      libEx.muscle
                                          .toLowerCase()
                                          .contains('cardio');
                                  provider.updatePlannerItem(day, newIdx,
                                      "$val:${isCardio ? 30 : 3}");
                                } else {
                                  provider.updatePlannerItem(day, newIdx, val);
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (items.isEmpty)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      _showItemSelectionSheet(
                        context,
                        provider,
                        state,
                        accentColor,
                        onSelected: (val) {
                          final newIdx =
                              (provider.state?.planner[day] ?? []).length;
                          provider.addPlannerItem(day);
                          if (val.startsWith('exercise:')) {
                            final exId = val.substring(9);
                            final libEx = state.library
                                .where((e) => e.id == exId)
                                .firstOrNull;
                            final isCardio = libEx != null &&
                                libEx.muscle.toLowerCase().contains('cardio');
                            provider.updatePlannerItem(
                                day, newIdx, "$val:${isCardio ? 30 : 3}");
                          } else {
                            provider.updatePlannerItem(day, newIdx, val);
                          }
                        },
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline,
                              color: accentColor.withOpacity(0.6), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            "Nenhum treino agendado — tocar para adicionar",
                            style: TextStyle(
                              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Color(0xFF8E8E93)),
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    onReorder: (oldIndex, newIndex) {
                      provider.movePlannerItem(day, oldIndex, newIndex);
                    },
                    itemBuilder: (context, idx) {
                      final rawItem = items[idx];
                      return KeyedSubtree(
                        key: ValueKey('planner-$day-$idx-$rawItem'),
                        child: _buildPlannerItemRow(
                            context, provider, day, idx, items.length, rawItem, accentColor),
                      );
                    },
                  ),

                // AI Insights Card
                if (_showAIByDay[day] == true) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor.withOpacity(0.3)),
                    ),
                    child: _isLoadingAIByDay[day] == true
                        ? Row(
                            children: [
                              SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: accentColor, strokeWidth: 2)),
                              const SizedBox(width: 12),
                              Text(
                                  "A IA está analisando seu histórico...",
                                  style: TextStyle(
                                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Color(0xFF3C3C43)), fontSize: 12)),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome,
                                      color: accentColor, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Sugestões de Progressão (IA)",
                                      style: TextStyle(
                                        color: accentColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _toggleOrFetchAI(
                                      day,
                                      items,
                                      provider.state!.history,
                                      state,
                                      forceRefresh: true,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Icon(
                                        Icons.refresh_rounded,
                                        color: accentColor.withOpacity(0.8),
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_aiSuggestionsByDay[day] == null ||
                                  _aiSuggestionsByDay[day]!.isEmpty)
                                Text(
                                    "Não foi possível gerar dicas baseadas no seu histórico atual.",
                                    style: TextStyle(
                                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Color(0xFF6E6E73)), fontSize: 12))
                              else
                                ..._aiSuggestionsByDay[day]!.entries.map((e) =>
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 6.0),
                                      child: RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                                text: "• ${e.key}: ",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)),
                                                    fontSize: 12)),
                                            TextSpan(
                                                text: e.value,
                                                style: TextStyle(
                                                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Color(0xFF3C3C43)),
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    )),
                            ],
                          ),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    ];
  }

  String _resolveContinuousItemName(PlannerState state, String raw) {
    if (raw.isEmpty) return "Treino não definido";
    String id = raw;
    if (raw.startsWith('routine:')) id = raw.substring(8);
    final r = state.routines.where((x) => x.id == id).firstOrNull;
    if (r != null) return r.name;
    if (raw.startsWith('exercise:')) {
      final parts = raw.split(':');
      if (parts.length >= 2) {
        final ex = state.library.where((e) => e.id == parts[1]).firstOrNull;
        if (ex != null) return ex.name;
      }
    }
    return raw;
  }

  Widget _buildContinuousTodayCard(
    BuildContext context,
    TrackerProvider provider,
    PlannerState state,
    Color accentColor,
    List<String> flatList,
    int currentIndex,
  ) {
    final len = flatList.length;
    final idx = len > 0 ? currentIndex % len : 0;
    final isRest = provider.isContinuousRestToday;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: isRest
          ? (Theme.of(context).brightness == Brightness.dark ? Colors.white24 : const Color(0xFFC7C7CC))
          : accentColor.withOpacity(0.35),
      child: Row(
        children: [
          Icon(
            isRest ? Icons.bedtime_outlined : Icons.play_circle_outline,
            color: isRest ? (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)) : accentColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRest ? "HOJE: DESCANSO" : "PRÓXIMO TREINO",
                  style: TextStyle(
                    color: isRest ? (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)) : accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isRest
                      ? "Nenhum treino será exibido na página inicial"
                      : _resolveContinuousItemName(state, flatList[idx]),
                  style: TextStyle(
                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isRest && len > 1)
                  Text(
                    "Posição ${idx + 1} de $len na sequência",
                    style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Color(0xFF8E8E93)),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.skip_previous,
                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Color(0xFF6E6E73)), size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: "Treino anterior",
            onPressed: len > 1
                ? () => provider
                    .setContinuousListIndex((idx - 1 + len) % len)
                : null,
          ),
          IconButton(
            icon: Icon(Icons.skip_next,
                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Color(0xFF6E6E73)), size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: "Pular para o próximo da fila",
            onPressed: len > 1
                ? () => provider.setContinuousListIndex((idx + 1) % len)
                : null,
          ),
          if (!isRest && len > 1)
            IconButton(
              icon: Icon(Icons.spa_outlined,
                  color: accentColor, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: "Sugerir treino menos fadigado",
              onPressed: () {
                final suggestion =
                    provider.suggestContinuousIndexByFatigue();
                if (suggestion != null && suggestion != idx) {
                  provider.setContinuousListIndex(suggestion);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Próximo treino sugerido: ${_resolveContinuousItemName(state, flatList[suggestion])}",
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              provider.setContinuousListRestToday(!isRest);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isRest
                    ? accentColor.withOpacity(0.2)
                    : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isRest
                      ? accentColor.withOpacity(0.5)
                      : Colors.white.withOpacity(0.15),
                ),
              ),
              child: Text(
                isRest ? "Voltar Treino" : "Descanso Hoje",
                style: TextStyle(
                  color: isRest ? accentColor : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContinuousListAgenda(BuildContext context,
      TrackerProvider provider, PlannerState state, Color accentColor) {
    
    final blocks = state.continuousBlocks;
    final flatList = provider.flatContinuousList;
    final currentIndex = state.settings.continuousListCurrentIndex;

    return [
      Row(
        children: [
          Icon(Icons.format_list_numbered,
              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Color(0xFF3C3C43)), size: 20),
          const SizedBox(width: 8),
          Text(
            "Lista Contínua",
            style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.copy, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)), size: 20),
            tooltip: "Importar de Dias Fixos",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              _showImportDialog(context, provider, 'continuous');
            },
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(Icons.add_box, color: accentColor, size: 22),
            tooltip: "Novo Bloco",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              provider.addContinuousBlock();
            },
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (flatList.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildContinuousTodayCard(
              context, provider, state, accentColor, flatList, currentIndex),
        ),
      if (blocks.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            "Nenhum bloco na lista. Crie blocos de treino (A, B, C...) que se repetirão em sequência.",
            style: TextStyle(
                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white30 : Color(0xFFAEAEB2)),
                fontSize: 13,
                fontStyle: FontStyle.italic),
          ),
        )
      else
        ...blocks.asMap().entries.map((entry) {
          final blockIdx = entry.key;
          final block = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              borderColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: block.name,
                          style: TextStyle(
                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onFieldSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              provider.renameContinuousBlock(block.id, val.trim());
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${blockIdx + 1}/${blocks.length} • ${block.routineIds.length} ${block.routineIds.length == 1 ? 'treino' : 'treinos'}",
                        style: TextStyle(
                          color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Color(0xFF8E8E93)),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.keyboard_arrow_up, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)), size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: blockIdx > 0 ? () {
                              provider.reorderContinuousBlocks(blockIdx, blockIdx - 1);
                            } : null,
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(Icons.keyboard_arrow_down, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)), size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: blockIdx < blocks.length - 1 ? () {
                              provider.reorderContinuousBlocks(blockIdx, blockIdx + 1);
                            } : null,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              provider.removeContinuousBlock(block.id);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (block.routineIds.isEmpty)
                    Text("Nenhum treino neste bloco.", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white30 : const Color(0xFFAEAEB2)), fontSize: 12))
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: block.routineIds.length,
                      onReorder: (oldIndex, newIndex) {
                        provider.reorderRoutinesInContinuousBlock(
                            block.id, oldIndex, newIndex);
                      },
                      itemBuilder: (context, rIdx) {
                        final rawItem = block.routineIds[rIdx];

                        // Find flat index to check if it's the current workout
                        int flatIndex = 0;
                        for (int i = 0; i < blockIdx; i++) {
                          flatIndex += blocks[i].routineIds.length;
                        }
                        flatIndex += rIdx;

                        final isCurrent = flatList.isNotEmpty && (flatIndex == (currentIndex % flatList.length));

                        return Container(
                          key: ValueKey('block-${block.id}-$rIdx-$rawItem'),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isCurrent ? accentColor.withOpacity(0.1) : Colors.black12,
                            borderRadius: BorderRadius.circular(12),
                            border: isCurrent ? Border.all(color: accentColor.withOpacity(0.5)) : null,
                          ),
                          child: Column(
                            children: [
                              if (isCurrent)
                                Align(
                                  alignment: Alignment.topRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    margin: const EdgeInsets.only(bottom: 4),
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text("PRÓXIMO", style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              _buildBlockItemRow(context, provider, state, block.id, rIdx, rawItem, accentColor, flatIndex, block.routineIds.length),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      icon: Icon(Icons.add, color: accentColor, size: 18),
                      label: Text("Adicionar Treino", style: TextStyle(color: accentColor)),
                      style: TextButton.styleFrom(
                        backgroundColor: accentColor.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        provider.addRoutineToContinuousBlock(block.id, '');
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
    ];
  }

  void _showCopyDayDialog(BuildContext context, TrackerProvider provider,
      String sourceDay, Color accentColor) {
    final sourceName = _getDayNamePt(sourceDay);
    final targets = _daysOfWeek.where((d) => d != sourceDay).toList();
    final state = provider.state!;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08)),
        ),
        title: Text("Copiar $sourceName",
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: targets.map((day) {
              final targetItems = state.planner[day] ?? [];
              final hasItems = targetItems.any((i) => i.isNotEmpty);
              return ListTile(
                dense: true,
                leading: Icon(Icons.calendar_month,
                    color: hasItems ? Colors.orangeAccent : accentColor,
                    size: 20),
                title: Text(_getDayNamePt(day),
                    style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)), fontWeight: FontWeight.w600)),
                subtitle: hasItems
                    ? const Text("Substituirá itens existentes",
                        style: TextStyle(color: Colors.orangeAccent, fontSize: 11))
                    : null,
                onTap: () {
                  Navigator.pop(dialogCtx);
                  if (hasItems) {
                    showDialog(
                      context: context,
                      builder: (confirmCtx) => AlertDialog(
                        backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08)),
                        ),
                        title: Text("Substituir dia?",
                            style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)), fontSize: 15)),
                        content: Text(
                          "${_getDayNamePt(day)} já tem itens. O conteúdo de $sourceName vai substituir tudo.",
                          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)), fontSize: 13),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(confirmCtx),
                            child: Text("Cancelar",
                                style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Color(0xFF6E6E73)))),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(confirmCtx);
                              provider.copyPlannerDay(sourceDay, day);
                            },
                            child: const Text("Substituir",
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  } else {
                    provider.copyPlannerDay(sourceDay, day);
                  }
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showWeekTemplatesSheet(
      BuildContext context, TrackerProvider provider, Color accentColor) {
    final days = ['seg', 'ter', 'qua', 'qui', 'sex', 'sab', 'dom'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final templates = provider.state?.weekTemplates ?? {};
            final ordered = templates.values.toList()
              ..sort((a, b) => a.name.compareTo(b.name));

            return Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                      child: Row(
                        children: [
                          Icon(Icons.view_week_outlined,
                              color: accentColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Modelos de Semana",
                              style: TextStyle(
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)),
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close,
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Color(0xFF6E6E73)), size: 20),
                            onPressed: () => Navigator.pop(sheetCtx),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "Salve a semana atual (seg–dom) como modelo e aplique em outras semanas — útil para alternar entre semanas de volume e intensidade.",
                        style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Color(0xFF6E6E73)), fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.save_outlined,
                              color: Colors.black, size: 18),
                          label: const Text("Salvar semana atual como modelo",
                              style: TextStyle(color: Colors.black)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            final controller = TextEditingController();
                            showDialog(
                              context: ctx,
                              builder: (dCtx) => AlertDialog(
                                backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white),
                                title: Text("Nome do modelo",
                                    style: TextStyle(
                                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                content: TextField(
                                  controller: controller,
                                  autofocus: true,
                                  style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E))),
                                  decoration: InputDecoration(
                                    hintText: "Ex.: Semana A - Volume",
                                    hintStyle:
                                        TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white30 : Color(0xFFAEAEB2))),
                                  ),
                                  onSubmitted: (val) {
                                    if (val.trim().isNotEmpty) {
                                      provider.saveCurrentWeekAsTemplate(
                                          val.trim());
                                      setSheetState(() {});
                                    }
                                    Navigator.pop(dCtx);
                                  },
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dCtx),
                                    child: Text("Cancelar",
                                        style:
                                            TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Color(0xFF6E6E73)))),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      if (controller.text.trim().isNotEmpty) {
                                        provider.saveCurrentWeekAsTemplate(
                                            controller.text.trim());
                                        setSheetState(() {});
                                      }
                                      Navigator.pop(dCtx);
                                    },
                                    child: Text("Salvar",
                                        style: TextStyle(
                                            color: accentColor,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ordered.isEmpty
                          ? Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                "Nenhum modelo salvo ainda.",
                                style: TextStyle(
                                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white30 : Color(0xFFAEAEB2)),
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: ordered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final t = ordered[i];
                                final filledDays =
                                    t.days.keys.where((d) => days.contains(d)).length;
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t.name,
                                              style: TextStyle(
                                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "$filledDays dia(s) com treino",
                                              style: TextStyle(
                                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Color(0xFF8E8E93)),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.edit_outlined,
                                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)), size: 18),
                                        tooltip: "Renomear",
                                        onPressed: () {
                                          final c = TextEditingController(
                                              text: t.name);
                                          showDialog(
                                            context: ctx,
                                            builder: (dCtx) => AlertDialog(
                                              backgroundColor:
                                                  (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white),
                                              title: Text("Renomear",
                                                  style: TextStyle(
                                                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)),
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              content: TextField(
                                                controller: c,
                                                autofocus: true,
                                                style: TextStyle(
                                                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E))),
                                                onSubmitted: (val) {
                                                  provider.renameWeekTemplate(
                                                      t.id, val);
                                                  setSheetState(() {});
                                                  Navigator.pop(dCtx);
                                                },
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(dCtx),
                                                  child: Text(
                                                      "Cancelar",
                                                      style: TextStyle(
                                                          color:
                                                              (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Color(0xFF6E6E73)))),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    provider
                                                        .renameWeekTemplate(
                                                            t.id, c.text);
                                                    setSheetState(() {});
                                                    Navigator.pop(dCtx);
                                                  },
                                                  child: Text("OK",
                                                      style: TextStyle(
                                                          color: accentColor,
                                                          fontWeight:
                                                              FontWeight
                                                                  .bold)),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline,
                                            color: Colors.redAccent,
                                            size: 18),
                                        tooltip: "Excluir",
                                        onPressed: () {
                                          provider.deleteWeekTemplate(t.id);
                                          setSheetState(() {});
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.play_arrow_rounded,
                                            color: accentColor, size: 22),
                                        tooltip: "Aplicar esta semana",
                                        onPressed: () {
                                          final state = provider.state;
                                          final hasItems = days.any((d) =>
                                              (state?.planner[d] ?? [])
                                                  .any((i) => i.isNotEmpty));
                                          void doApply() {
                                            provider.applyWeekTemplate(t.id);
                                            setSheetState(() {});
                                          }

                                          if (hasItems) {
                                            showDialog(
                                              context: ctx,
                                              builder: (dCtx) => AlertDialog(
                                                backgroundColor:
                                                    (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white),
                                                title: Text(
                                                    "Substituir semana?",
                                                    style: TextStyle(
                                                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)),
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                content: Text(
                                                  "A semana atual tem treinos agendados. Aplicar o modelo vai substituir todos os dias (seg–dom).",
                                                  style: TextStyle(
                                                      color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Color(0xFF3C3C43)),
                                                      fontSize: 13),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(dCtx),
                                                    child: Text(
                                                        "Cancelar",
                                                        style: TextStyle(
                                                            color:
                                                                (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Color(0xFF6E6E73)))),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(dCtx);
                                                      doApply();
                                                    },
                                                    child: const Text(
                                                        "Substituir",
                                                        style: TextStyle(
                                                            color: Colors
                                                                .redAccent,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          } else {
                                            doApply();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showImportDialog(
      BuildContext context, TrackerProvider provider, String targetKey) {
    final accentColor =
        ThemeUtils.getColor(provider.currentProfile.colorAccent);
    final daysMap = {
      'seg': 'Segunda-feira',
      'ter': 'Terça-feira',
      'qua': 'Quarta-feira',
      'qui': 'Quinta-feira',
      'sex': 'Sexta-feira',
      'sab': 'Sábado',
      'dom': 'Domingo',
    };

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          useBlur: true,
          borderColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08),
          borderRadius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.copy, color: accentColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Importar de Dias Fixos",
                    style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)),
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Copie as rotinas e exercícios já planejados em dias fixos diretamente para o modelo atual.",
                style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Color(0xFF6E6E73)), fontSize: 12),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Opção especial para importar TODOS os dias
                      ListTile(
                        leading: Icon(Icons.all_inclusive,
                            color: accentColor, size: 20),
                        title: Text(
                          "Importar Todos os Dias",
                          style: TextStyle(
                              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)),
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Copia Seg, Ter, Qua, Qui, Sex, Sáb e Dom em sequência",
                          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Color(0xFF8E8E93)), fontSize: 10),
                        ),
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        onTap: () {
                          provider.importAllFixedDays(targetKey);
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Compilado com sucesso para a ${targetKey == 'continuous' ? 'Lista Contínua' : 'Metas Semanais'}!",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: accentColor,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      Divider(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.black12)),
                      ...daysMap.entries.map((entry) {
                        final key = entry.key;
                        final label = entry.value;
                        final itemsCount = provider.state?.planner[key]
                                ?.where((item) => item.isNotEmpty)
                                .length ??
                            0;

                        return ListTile(
                          title: Text(
                            label,
                            style: TextStyle(
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF1C1C1E)),
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            "$itemsCount item(ns) planejado(s)",
                            style: TextStyle(
                              color: itemsCount > 0
                                  ? (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73))
                                  : (Theme.of(context).brightness == Brightness.dark ? Colors.white24 : const Color(0xFFC7C7CC)),
                              fontSize: 10,
                            ),
                          ),
                          trailing: itemsCount > 0
                              ? Icon(Icons.chevron_right,
                                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white30 : Color(0xFFAEAEB2)), size: 16)
                              : null,
                          dense: true,
                          enabled: itemsCount > 0,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          onTap: () {
                            provider.importFromFixedDay(key, targetKey);
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Importado de $label com sucesso!",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                backgroundColor: accentColor,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    "Fechar",
                    style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Color(0xFF6E6E73)), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
