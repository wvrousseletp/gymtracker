import re

with open('lib/screens/workout_screen.dart', 'r') as f:
    content = f.read()

# 1. Replace _buildIdleView
start_idx = content.find('Widget _buildIdleView(BuildContext context, WorkoutProvider provider) {')
end_idx = content.find('void _showPlannedRoutineDetails(')
if start_idx == -1 or end_idx == -1:
    print("Could not find bounds of _buildIdleView")
    exit(1)

real_end_idx = content.rfind('  }', start_idx, end_idx) + 3

new_build_idle_view = """Widget _buildIdleView(BuildContext context, WorkoutProvider provider) {
    final todayLabel = _getTodayLabel();
    final plannedRoutineIds = provider.todayPlannedItems;
    final trackerProvider = Provider.of<TrackerProvider>(context, listen: false);
    final accentColor = ThemeUtils.getColor(trackerProvider.currentProfile.colorAccent);

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
                      id: "temp-${exerciseId}-${sets}",
                      name: "${libEx.name} (Avulso)",
                      defaultRest: 60,
                      exercises: [
                        RoutineExercise(
                          id: "e-temp-1",
                          exerciseId: libEx.id,
                          sets: sets,
                          reps: isCardio ? 30 : 10,
                          rest: 60,
                          weight: 0.0,
                          isCardio: isCardio,
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
      body: CustomScrollView(
        slivers: [
          // 1. Sticky Header
          SliverAppBar(
            backgroundColor: Colors.transparent,
            pinned: true,
            elevation: 0,
            expandedHeight: 90,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${_getGreeting()}, ${(trackerProvider.currentProfile.name.isNotEmpty ? trackerProvider.currentProfile.name : 'ATLETA').toUpperCase()} 👋",
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0
                    ),
                  ),
                  Text(
                    todayLabel.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // Badge de Ofensiva / Streak
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
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
              ),
              // Botão de dicas (gestos ocultos)
              Center(
                child: IconButton(
                  icon: const Icon(Icons.help_outline, color: Colors.white54, size: 20),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: Color(0xff1c1c1e),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb_outline, color: accentColor),
                                const SizedBox(width: 8),
                                const Text("Dicas e Gestos", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildTipRow(Icons.swipe_right, "Deslize para a Direita", "Marque a série instantaneamente como Falha.", accentColor),
                            _buildTipRow(Icons.swipe_left, "Deslize para a Esquerda", "Cria um Drop-Set automático cortando 20% do peso.", accentColor),
                            _buildTipRow(Icons.dialpad, "Teclado Rápido", "Toque no peso ou nas repetições para abrir o teclado numérico customizado.", accentColor),
                            _buildTipRow(Icons.mic, "Notas por Voz", "No botão de notas do exercício, segure o microfone para ditar suas observações.", accentColor),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Settings
              Center(
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                  onPressed: () {
                    _showSettingsDialog(context, trackerProvider);
                  },
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Main Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Shimmer & Swipe nos Treinos Adiados
                  ...provider.postponedWorkouts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final postponed = entry.value;
                    return Dismissible(
                      key: ValueKey("postponed-${index}-${postponed.name}"),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) {
                        provider.discardPostponedWorkout(index);
                      },
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              accentColor.withOpacity(0.1),
                              accentColor.withOpacity(0.02),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: accentColor.withOpacity(0.3)),
                        ),
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
                                    "TREINO ADIADO ${provider.postponedWorkouts.length > 1 ? '(' + (index + 1).toString() + '/' + provider.postponedWorkouts.length.toString() + ')' : ''}",
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
                            ElevatedButton(
                              onPressed: () {
                                if (provider.activeWorkout != null) {
                                  provider.postponeActiveWorkout();
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text("Retomar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Treino Planejado para Hoje",
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      if (!isRestDay)
                        TextButton.icon(
                          onPressed: () {
                            _showRestDayModal(context, provider, accentColor);
                          },
                          icon: Icon(Icons.nightlight_round, color: accentColor, size: 14),
                          label: Text(
                            "Descansar Hoje",
                            style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 3. Hero Card
                  if (isRestDay)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [Color(0xff1a1a2e), Color(0xff16213e)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(color: const Color(0xff1a1a2e).withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))
                        ],
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.nightlight_round, color: Colors.blueAccent, size: 40),
                          SizedBox(height: 12),
                          Text(
                            "Dia de Descanso",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Aproveite para se recuperar.",
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else if (plannedRoutines.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: const Color(0xff1c1c1e),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.calendar_today_outlined, color: Colors.white38, size: 40),
                          SizedBox(height: 12),
                          Text(
                            "Nenhum treino planejado.",
                            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Selecione um treino rápido abaixo.",
                            style: TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: plannedRoutines.map((routine) {
                        final isCompleted = _isRoutineCompletedToday(routine.name, provider.history);
                        return GestureDetector(
                          onTap: () => _showPlannedRoutineDetails(context, provider, routine),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: isCompleted 
                                ? LinearGradient(colors: [Colors.green.withOpacity(0.2), Colors.green.withOpacity(0.05)])
                                : LinearGradient(colors: [accentColor.withOpacity(0.3), accentColor.withOpacity(0.05)]),
                              border: Border.all(
                                color: isCompleted ? Colors.green.withOpacity(0.5) : accentColor.withOpacity(0.5),
                                width: 1.5
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isCompleted ? Colors.green : accentColor).withOpacity(0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8)
                                )
                              ],
                            ),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(isCompleted ? Icons.check_circle : Icons.fitness_center, 
                                               color: isCompleted ? Colors.greenAccent : accentColor, size: 24),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              routine.name,
                                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: provider.getRoutineMuscleTags(routine).take(4).map((tag) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.4),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(tag, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                        )).toList(),
                                      ),
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            if (provider.activeWorkout != null) {
                                              _promptPostponeOrCreateWorkout(context, provider, () {
                                                WorkoutStarter.startWithCountdown(context, provider, routine, WorkoutRecovery(sleepOk: SleepQuality.okay, pain: [], warmUpDone: false), false);
                                              });
                                            } else {
                                              WorkoutStarter.startWithCountdown(context, provider, routine, WorkoutRecovery(sleepOk: SleepQuality.okay, pain: [], warmUpDone: false), false);
                                            }
                                          },
                                          icon: Icon(isCompleted ? Icons.replay : Icons.play_arrow, color: isCompleted ? Colors.white : Colors.black),
                                          label: Text(
                                            isCompleted ? "TREINAR NOVAMENTE" : "INICIAR TREINO",
                                            style: TextStyle(color: isCompleted ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isCompleted ? Colors.white.withOpacity(0.2) : accentColor,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                            elevation: 0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 24),
                  
                  // 4. Quick Filters
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Treino Rápido",
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          // Treino Livre Vazio
                          final emptyRoutine = Routine(
                            id: "free-${const Uuid().v4()}",
                            name: "Treino Livre",
                            defaultRest: 60,
                            exercises: [],
                          );
                          WorkoutStarter.startWithCountdown(context, provider, emptyRoutine, WorkoutRecovery(sleepOk: SleepQuality.okay, pain: [], warmUpDone: false), false);
                        },
                        icon: const Icon(Icons.add, color: Colors.white, size: 16),
                        label: const Text("Treino Livre", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        style: TextButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.1), padding: const EdgeInsets.symmetric(horizontal: 12)),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPremiumFilterChip('Todos', Icons.grid_view, accentColor),
                        const SizedBox(width: 8),
                        _buildPremiumFilterChip('Superiores', Icons.fitness_center, accentColor),
                        const SizedBox(width: 8),
                        _buildPremiumFilterChip('Inferiores', Icons.directions_run, accentColor),
                        const SizedBox(width: 8),
                        _buildPremiumFilterChip('Cardio', Icons.favorite, accentColor),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Horizontal Carousel
                  if (provider.routines.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16)
                      ),
                      child: const Center(
                        child: Text("Nenhuma rotina cadastrada.", style: TextStyle(color: Colors.white38)),
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
                          child: Text("Nenhuma rotina nesta categoria.", style: TextStyle(color: Colors.white38)),
                        );
                      }

                      return SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final routine = filtered[index];
                            final tags = provider.getRoutineMuscleTags(routine);
                            return GestureDetector(
                              onTap: () {
                                if (provider.activeWorkout != null) {
                                  _promptPostponeOrCreateWorkout(context, provider, () {
                                    WorkoutStarter.startWithCountdown(context, provider, routine, WorkoutRecovery(sleepOk: SleepQuality.okay, pain: [], warmUpDone: false), false);
                                  });
                                } else {
                                  WorkoutStarter.startWithCountdown(context, provider, routine, WorkoutRecovery(sleepOk: SleepQuality.okay, pain: [], warmUpDone: false), false);
                                }
                              },
                              child: Container(
                                width: 140,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xff1c1c1e),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.fitness_center, color: accentColor, size: 20),
                                    ),
                                    const Spacer(),
                                    Text(
                                      routine.name,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${routine.exercises.length} ex.",
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                    const SizedBox(height: 8),
                                    if (tags.isNotEmpty)
                                      Text(
                                        tags.first,
                                        style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
"""

content = content[:start_idx] + new_build_idle_view + content[real_end_idx:]

# 2. Add the two new widget functions and DELETE the old _buildQuickRoutineFilterChip
def delete_function(func_name, code):
    match = re.search(f'Widget {func_name}\(', code)
    if not match:
        return code
    start = match.start()
    open_braces = 0
    in_function = False
    for i in range(start, len(code)):
        if code[i] == '{':
            open_braces += 1
            in_function = True
        elif code[i] == '}':
            open_braces -= 1
            
        if in_function and open_braces == 0:
            return code[:start] + code[i+1:]
    return code

content = delete_function('_buildQuickRoutineFilterChip', content)

new_widgets = """
  Widget _buildTipRow(IconData icon, String title, String desc, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: accent, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.3)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPremiumFilterChip(String label, IconData icon, Color accentColor) {
    final isSelected = _quickRoutineFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _quickRoutineFilter = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.black : Colors.white54, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
"""

# Insert before the end of the _WorkoutScreenState class
# To safely find the end of _WorkoutScreenState, let's insert it before the last method in _WorkoutScreenState
# The last method is usually `_promptPostponeOrCreateWorkout` or similar, but the safest is to put it right after `_buildIdleView`
content = content.replace('Widget _buildIdleView', new_widgets + '\n  Widget _buildIdleView')


with open('lib/screens/workout_screen.dart', 'w') as f:
    f.write(content)
print("Patched successfully via Python!")

