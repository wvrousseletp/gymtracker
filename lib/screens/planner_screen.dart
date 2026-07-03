import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tracker_provider.dart';
import '../models/exercise.dart';
import '../models/planner_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/profile_avatar.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final List<String> _daysOfWeek = ['seg', 'ter', 'qua', 'qui', 'sex', 'sab', 'dom'];

  String _getDayNamePt(String day) {
    switch (day) {
      case 'seg': return 'Segunda-feira';
      case 'ter': return 'Terça-feira';
      case 'qua': return 'Quarta-feira';
      case 'qui': return 'Quinta-feira';
      case 'sex': return 'Sexta-feira';
      case 'sab': return 'Sábado';
      case 'dom': return 'Domingo';
      default: return '';
    }
  }

  Widget _buildWeeklyStreakHeader(
    BuildContext context,
    TrackerProvider provider,
    PlannerState state,
    Color accentColor,
  ) {
    final streak = state.streak;
    
    // Formatar data do último treino
    String lastWorkoutStr = "Nenhum";
    if (streak.lastWorkoutDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(streak.lastWorkoutDate).toLocal();
        final diff = DateTime.now().difference(dt);
        if (diff.inDays == 0) {
          lastWorkoutStr = "Hoje";
        } else if (diff.inDays == 1) {
          lastWorkoutStr = "Ontem";
        } else {
          lastWorkoutStr = "Há ${diff.inDays} dias";
        }
      } catch (_) {
        lastWorkoutStr = "Recente";
      }
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: Colors.orangeAccent.withOpacity(0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 24),
              const SizedBox(width: 8),
              const Text(
                "Consistência Semanal",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.orangeAccent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "${streak.consecutiveWeeks} ${streak.consecutiveWeeks == 1 ? 'semana' : 'semanas'}",
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
          // Indicador de treinos na semana
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Frequência Semanal:",
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                "${streak.currentWeekCount} ${streak.currentWeekCount == 1 ? 'dia' : 'dias'}",
                style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 7 círculos representando os treinos realizados
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (dayIndex) {
              final filled = streak.weekdaysTrained.isNotEmpty
                  ? streak.weekdaysTrained.contains(dayIndex + 1)
                  : dayIndex < streak.currentWeekCount;
              final dayInitial = _daysOfWeek[dayIndex].substring(0, 1).toUpperCase();
              return Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: filled
                      ? RadialGradient(
                          colors: [
                            Colors.greenAccent.withOpacity(0.35),
                            Colors.green.withOpacity(0.12),
                          ],
                          center: const Alignment(-0.3, -0.3),
                          radius: 0.8,
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.05),
                            Colors.white.withOpacity(0.01),
                          ],
                        ),
                  boxShadow: filled
                      ? [
                          BoxShadow(
                            color: Colors.greenAccent.withOpacity(0.25),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                  border: Border.all(
                    color: filled ? Colors.greenAccent.withOpacity(0.8) : Colors.white.withOpacity(0.08),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  dayInitial,
                  style: TextStyle(
                    color: filled ? Colors.white : Colors.white24,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // Último treino realizado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Último treino:",
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              Text(
                lastWorkoutStr,
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
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
          final routine = state.routines.where((r) => r.id == routineId).firstOrNull;
          if (routine != null) {
            for (final re in routine.exercises) {
              final libEx = state.library.where((e) => e.id == re.exerciseId).firstOrNull;
              if (libEx != null) {
                final muscle = libEx.muscle;
                final isCardio = muscle.toLowerCase().contains('cardio') || libEx.measurementType == 'time';
                if (isCardio) {
                  cardioMap[muscle] = (cardioMap[muscle] ?? 0) + re.sets.toInt();
                } else {
                  strengthMap[muscle] = (strengthMap[muscle] ?? 0) + re.sets.toInt();
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
              final isCardio = muscle.toLowerCase().contains('cardio') || libEx.measurementType == 'time';
              if (isCardio) {
                cardioMap[muscle] = (cardioMap[muscle] ?? 0) + quantity;
              } else {
                strengthMap[muscle] = (strengthMap[muscle] ?? 0) + quantity;
              }
            }
          }
        } else if (rawItem.isNotEmpty) {
          final routine = state.routines.where((r) => r.id == rawItem).firstOrNull;
          if (routine != null) {
            for (final re in routine.exercises) {
              final libEx = state.library.where((e) => e.id == re.exerciseId).firstOrNull;
              if (libEx != null) {
                final muscle = libEx.muscle;
                final isCardio = muscle.toLowerCase().contains('cardio') || libEx.measurementType == 'time';
                if (isCardio) {
                  cardioMap[muscle] = (cardioMap[muscle] ?? 0) + re.sets.toInt();
                } else {
                  strengthMap[muscle] = (strengthMap[muscle] ?? 0) + re.sets.toInt();
                }
              }
            }
          }
        }
      }
    }

    final sortedStrength = strengthMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sortedCardio = cardioMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
                children: [
                  Icon(Icons.fitness_center_rounded, color: accentColor, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    "Volume de Treino Planejado",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (sortedStrength.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      "Nenhum treino de musculação planejado.",
                      style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic, fontSize: 13),
                    ),
                  ),
                )
              else
                Column(
                  children: sortedStrength.map((entry) {
                    final maxVolume = sortedStrength.isNotEmpty ? sortedStrength.first.value : 1;
                    final fraction = maxVolume > 0 ? entry.value / maxVolume : 0.0;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "${entry.value} séries",
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: Container(
                              height: 5,
                              width: double.infinity,
                              color: Colors.white.withOpacity(0.05),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: fraction,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          accentColor.withOpacity(0.35),
                                          accentColor,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),

        if (sortedCardio.isNotEmpty) ...[
          const SizedBox(height: 16),
          // 2. Volume de Cardio
          GlassCard(
            padding: const EdgeInsets.all(16),
            borderColor: Colors.amber.withOpacity(0.15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.directions_run_rounded, color: Colors.amber, size: 22),
                    SizedBox(width: 8),
                    Text(
                      "Volume de Cardio Planejado",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  children: sortedCardio.map((entry) {
                    final maxVolume = sortedCardio.isNotEmpty ? sortedCardio.first.value : 1;
                    final fraction = maxVolume > 0 ? entry.value / maxVolume : 0.0;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "${entry.value} min",
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: Container(
                              height: 5,
                              width: double.infinity,
                              color: Colors.white.withOpacity(0.05),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: fraction,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.amber.withOpacity(0.35),
                                          Colors.amber,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.select<TrackerProvider, PlannerState?>((p) => p.state);
    final accentColor = context.select<TrackerProvider, Color>(
      (p) => ThemeUtils.getColor(p.currentProfile.colorAccent),
    );
    final provider = Provider.of<TrackerProvider>(context, listen: false);

    if (state == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
        children: [
          // 1. Consistência Semanal
          _buildWeeklyStreakHeader(context, provider, state, accentColor),
          const SizedBox(height: 16),

          // 2. Volume de Treino Planejado
          _buildPlannedVolumeHeader(context, provider, state, accentColor),
          const SizedBox(height: 24),

          // Seção Cronograma Semanal
          const Row(
            children: [
              Icon(Icons.calendar_month, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text(
                "Cronograma Semanal",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dias da semana
          ..._daysOfWeek.map((day) {
            final items = state.planner[day] ?? [];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                borderColor: Colors.white.withOpacity(0.06),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabeçalho do dia
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getDayNamePt(day),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_box_outlined, color: accentColor, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            provider.addPlannerItem(day);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          "Nenhum treino agendado",
                          style: TextStyle(
                            color: Colors.white30,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        itemBuilder: (context, idx) {
                          final rawItem = items[idx];
                          return _buildPlannerItemRow(context, provider, day, idx, rawItem, accentColor);
                        },
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPlannerItemRow(
    BuildContext context,
    TrackerProvider provider,
    String day,
    int idx,
    String rawItem,
    Color accentColor,
  ) {
    final state = provider.state!;
    final library = state.library;
    final routines = state.routines;

    // Decodificar valor selecionado e quantidade
    String selectedValue = ""; // "routine:preset-a" ou "exercise:lib-14"
    int quantityValue = 3;     // séries ou minutos

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

    // Identificar se é cardio
    bool isCardio = false;
    if (selectedValue.startsWith('exercise:')) {
      final exId = selectedValue.substring(9);
      final libEx = library.where((e) => e.id == exId).firstOrNull;
      if (libEx != null && libEx.muscle.toLowerCase().contains('cardio')) {
        isCardio = true;
      }
    }

    // Ordenar biblioteca de exercícios (corrigindo bug de desorganização)
    final sortedLibrary = List<LibraryExercise>.from(library)
      ..sort((a, b) {
        final muscleComp = a.muscle.toLowerCase().compareTo(b.muscle.toLowerCase());
        if (muscleComp != 0) return muscleComp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Dropdown de Seleção de Item
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedValue.isEmpty ? null : selectedValue,
                  hint: const Text(
                    "Selecione o Item",
                    style: TextStyle(color: Colors.white30, fontSize: 13),
                  ),
                  dropdownColor: const Color(0xff1c1c1e),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 18),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  isExpanded: true,
                  onChanged: (val) {
                    if (val == null) return;
                    if (val.startsWith('exercise:')) {
                      final exId = val.substring(9);
                      final libEx = library.where((e) => e.id == exId).firstOrNull;
                      final checkCardio = libEx != null && libEx.muscle.toLowerCase().contains('cardio');
                      if (checkCardio) {
                        provider.updatePlannerItem(day, idx, "$val:30"); // Default 30 min
                      } else {
                        provider.updatePlannerItem(day, idx, "$val:3");  // Default 3 sets
                      }
                    } else {
                      provider.updatePlannerItem(day, idx, val);
                    }
                  },
                  items: [
                    // Categoria Rotinas
                    const DropdownMenuItem<String>(
                      enabled: false,
                      value: "title:routines",
                      child: Text(
                        "--- Blocos de Treino (Rotinas) ---",
                        style: TextStyle(color: Colors.white30, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    ...routines.map((r) => DropdownMenuItem<String>(
                      value: "routine:${r.id}",
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(r.name),
                      ),
                    )),
                    // Categoria Exercícios Avulsos
                    const DropdownMenuItem<String>(
                      enabled: false,
                      value: "title:exercises",
                      child: Text(
                        "--- Exercícios Avulsos ---",
                        style: TextStyle(color: Colors.white30, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    ...sortedLibrary.map((ex) => DropdownMenuItem<String>(
                      value: "exercise:${ex.id}",
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text("${ex.name} (${ex.muscle})"),
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Seletor de Quantidade (séries ou min para exercícios avulsos)
          if (selectedValue.startsWith('exercise:')) ...[
            Container(
              width: 50,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: TextFormField(
                initialValue: quantityValue.toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onChanged: (val) {
                  int quantity = int.tryParse(val) ?? (isCardio ? 30 : 3);
                  if (quantity < 1) quantity = 1;
                  
                  final parts = rawItem.split(':');
                  if (parts.length >= 2) {
                    provider.updatePlannerItem(day, idx, "${parts[0]}:${parts[1]}:$quantity");
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            Text(
              isCardio ? 'min' : 'sér',
              style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
          ],

          // Botões Reordenar (▲)
          GestureDetector(
            onTap: idx == 0
                ? null
                : () {
                    provider.reorderPlannerItem(day, idx, true);
                  },
            child: Opacity(
              opacity: idx == 0 ? 0.3 : 1.0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: const Text('▲', style: TextStyle(color: Colors.white70, fontSize: 10)),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Botões Reordenar (▼)
          GestureDetector(
            onTap: idx == (provider.state!.planner[day]!.length - 1)
                ? null
                : () {
                    provider.reorderPlannerItem(day, idx, false);
                  },
            child: Opacity(
              opacity: idx == (provider.state!.planner[day]!.length - 1) ? 0.3 : 1.0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: const Text('▼', style: TextStyle(color: Colors.white70, fontSize: 10)),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Botão Remover
          GestureDetector(
            onTap: () {
              provider.removePlannerItem(day, idx);
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
