import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/tracker_provider.dart';
import '../models/routine.dart';
import '../models/exercise.dart';
import '../models/workout_log.dart';
import '../models/planner_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/profile_avatar.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({Key? key}) : super(key: key);

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
    final provider = Provider.of<TrackerProvider>(context);
    final state = provider.state;

    if (state == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final activeWorkout = state.activeWorkout;

    // Alternar visualização com base na presença de um treino ativo
    if (activeWorkout != null) {
      return ActiveWorkoutView(activeWorkout: activeWorkout, provider: provider);
    } else {
      return _buildIdleView(context, provider);
    }
  }

  Widget _buildIdleView(BuildContext context, TrackerProvider provider) {
    final state = provider.state!;
    final todayKey = _getTodayKey();
    final todayLabel = _getTodayLabel();
    final plannedRoutineIds = state.planner[todayKey] ?? [];
    final accentColor = ThemeUtils.getColor(provider.currentProfile.colorAccent);

    // Mapear IDs do planejador para as rotinas reais do usuário
    final List<Routine> plannedRoutines = plannedRoutineIds.map((item) {
      if (item.isEmpty) return null;
      if (item.startsWith('exercise:')) {
        final parts = item.split(':');
        if (parts.length >= 3) {
          final exerciseId = parts[1];
          final sets = int.tryParse(parts[2]) ?? 3;
          final libEx = state.library.where((l) => l.id == exerciseId).firstOrNull;
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
                  reps: isCardio ? sets : (libEx.measurementType == 'time' ? 45 : 10),
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
        return state.routines.where((r) => r.id == routineId).firstOrNull;
      }
    }).whereType<Routine>().toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    _showSettingsDialog(context, provider);
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
                  final isCompleted = _isRoutineCompletedToday(routine.name, state.history);
                  final totalSets = routine.exercises.fold<int>(0, (sum, ex) => sum + ex.sets);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () {
                        // Ao clicar no card, abre uma visão dos exercícios agendados
                        _showPlannedRoutineDetails(context, state, routine);
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
                                  WorkoutRecovery(sleepOk: 'ok', pain: [], warmUpDone: false),
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

            if (state.routines.isEmpty)
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
                children: state.routines.map((routine) {
                  return GestureDetector(
                    onTap: () {
                      provider.startWorkout(
                        routine,
                        WorkoutRecovery(sleepOk: 'ok', pain: [], warmUpDone: false),
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
                _showSelectExerciseDialog(context, provider, state);
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

  void _showPlannedRoutineDetails(BuildContext context, PlannerState state, Routine routine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xff1c1c1e).withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              routine.name,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: routine.exercises.length,
                itemBuilder: (context, idx) {
                  final ex = routine.exercises[idx];
                  final libEx = state.library.firstWhere(
                    (l) => l.id == ex.exerciseId,
                    orElse: () => LibraryExercise(id: '', name: 'Deletado', muscle: '', measurementType: 'reps'),
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
          ],
        ),
      ),
    );
  }

  void _showSelectExerciseDialog(BuildContext context, TrackerProvider provider, PlannerState state) {
    final library = state.library;
    final accentColor = ThemeUtils.getColor(provider.currentProfile.colorAccent);
    
    if (library.isEmpty) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: const Color(0xff1c1c1e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          title: const Text("Biblioteca Vazia", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text("Cadastre alguns exercícios na aba 'Rotinas' primeiro.", style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("OK", style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        String searchQuery = "";
        return StatefulBuilder(
          builder: (context, setState) {
            final filteredList = library.where((ex) {
              return ex.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  ex.muscle.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: const Color(0xff1c1c1e).withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        borderSide: BorderSide.none,
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
                        : ListView.builder(
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final ex = filteredList[index];
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
                                    ex.muscle,
                                    style: TextStyle(color: accentColor.withOpacity(0.7), fontSize: 12),
                                  ),
                                  trailing: const Icon(Icons.play_arrow_rounded, color: Colors.white54),
                                  onTap: () {
                                    Navigator.pop(context); // fecha modal
                                    provider.startSingleExercise(ex); 
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
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
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xff1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text("Configurações Gerais", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: soundState,
              builder: (context, val, child) => SwitchListTile(
                title: const Text("Bips Sonoros", style: TextStyle(color: Colors.white, fontSize: 13)),
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
                title: const Text("Vibração", style: TextStyle(color: Colors.white, fontSize: 13)),
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
                const Text("Tempo de Preparo", style: TextStyle(color: Colors.white, fontSize: 13)),
                SizedBox(
                  width: 60,
                  height: 36,
                  child: TextField(
                    controller: prepController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Meta de Água (ml)", style: TextStyle(color: Colors.white, fontSize: 13)),
                SizedBox(
                  width: 70,
                  height: 36,
                  child: TextField(
                    controller: waterController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
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
    Key? key,
    required this.activeWorkout,
    required this.provider,
  }) : super(key: key);

  @override
  State<ActiveWorkoutView> createState() => _ActiveWorkoutViewState();
}

class _ActiveWorkoutViewState extends State<ActiveWorkoutView> {
  Timer? _stopwatchTimer;
  late final ValueNotifier<int> _workoutDurationNotifier;

  // Estados dos Timers de Descanso/Preparo do painel
  Timer? _countdownTimer;
  late final ValueNotifier<int> _countdownSecondsNotifier;
  int _countdownTotalSeconds = 0;
  bool _timerActive = false;
  bool _timerIsPrep = false;
  String _timerNextExName = "";
  int _timerNextSetNum = 0;

  // Controladores de páginas para exercícios
  int _currentExIdx = 0;

  @override
  void initState() {
    super.initState();
    _currentExIdx = widget.activeWorkout.currentExerciseIndex;
    _workoutDurationNotifier = ValueNotifier<int>(widget.activeWorkout.elapsedSeconds);
    _countdownSecondsNotifier = ValueNotifier<int>(0);
    
    // Iniciar cronômetro do treino
    _startStopwatch();

    // Ouvir alterações do provedor para sincronizar timer de descanso e exercício atual
    widget.provider.addListener(_onProviderChange);

    // Se o treino acabou de começar, vamos disparar o tempo de PREPARO inicial no provedor!
    if (_workoutDurationNotifier.value == 0 && widget.activeWorkout.exercises.isNotEmpty) {
      final firstEx = widget.activeWorkout.exercises[0];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.provider.startRestTimer(
          widget.provider.state!.settings.prepSeconds,
          firstEx.name,
          1,
          true,
        );
      });
    }
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderChange);
    _stopwatchTimer?.cancel();
    _countdownTimer?.cancel();
    _workoutDurationNotifier.dispose();
    _countdownSecondsNotifier.dispose();
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

  void _onProviderChange() {
    if (!mounted) return;
    final active = widget.provider.state?.activeWorkout;
    if (active == null) return;
    
    if (active.currentExerciseIndex != _currentExIdx) {
      setState(() {
        _currentExIdx = active.currentExerciseIndex;
      });
    }

    final timer = active.restTimer;
    if (timer == null) {
      if (_timerActive) {
        _countdownTimer?.cancel();
        setState(() {
          _timerActive = false;
        });
      }
    } else {
      final remaining = ((timer.endTime - DateTime.now().millisecondsSinceEpoch) / 1000).round();
      if (!_timerActive || 
          _countdownTotalSeconds != timer.totalSeconds || 
          _timerIsPrep != timer.isPrep || 
          _timerNextExName != timer.nextExerciseName || 
          _timerNextSetNum != timer.nextSetNum) {
        _countdownTimer?.cancel();
        setState(() {
          _timerActive = true;
          _timerIsPrep = timer.isPrep;
          _countdownTotalSeconds = timer.totalSeconds;
          _timerNextExName = timer.nextExerciseName;
          _timerNextSetNum = timer.nextSetNum;
        });
        _countdownSecondsNotifier.value = remaining > 0 ? remaining : 0;
        if (remaining > 0) {
          _startCountdownTimerFromState(timer.endTime);
        } else {
          _handleTimerCompleted();
        }
      }
    }
  }

  void _startCountdownTimerFromState(int endTime) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final remaining = ((endTime - now) / 1000).round();
      
      if (remaining > 0) {
        _countdownSecondsNotifier.value = remaining;
        
        final settings = widget.provider.state!.settings;
        if (settings.sound) {
          if (remaining <= 3 && remaining > 0) {
            SystemSound.play(SystemSoundType.click);
          }
        }
      } else {
        _countdownSecondsNotifier.value = 0;
        _countdownTimer?.cancel();
        _handleTimerCompleted();
      }
    });
  }

  void _handleTimerCompleted() {
    final settings = widget.provider.state!.settings;
    if (settings.vibration) {
      HapticFeedback.vibrate();
    }
    if (settings.sound) {
      SystemSound.play(SystemSoundType.click);
    }

    if (_timerIsPrep) {
      widget.provider.clearRestTimer();
    } else {
      widget.provider.startRestTimer(
        settings.prepSeconds, 
        _timerNextExName, 
        _timerNextSetNum, 
        true
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final workout = widget.activeWorkout;
    final exercises = workout.exercises;
    final accentColor = ThemeUtils.getColor(widget.provider.currentProfile.colorAccent);

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
                        ],
                      ),
                    ),
                    Row(
                      children: [
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
                padding: const EdgeInsets.all(16.0),
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
                          valueListenable: _countdownSecondsNotifier,
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
                              _countdownTimer?.cancel();
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
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ex.sets,
            itemBuilder: (context, setIdx) {
              final isDone = ex.setsState[setIdx];
              final isFailure = ex.failureReport[setIdx];

              if (isCardio) {
                // RENDERIZAR SESSÃO DE CARDIO
                final pc = ex.performedCardios[setIdx];
                final distController = TextEditingController(text: pc?.distanceKm.toString() ?? "");
                final durController = TextEditingController(text: pc != null ? (pc.durationSeconds ~/ 60).toString() : "");

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(isDone ? 0.05 : 0.01),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDone ? Colors.blue.withOpacity(0.35) : Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "Sessão ${setIdx + 1}",
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),

                      // Input Km
                      Expanded(
                        child: TextField(
                          controller: distController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: _activeInputDeco("Km"),
                          onChanged: (val) {
                            final dist = double.tryParse(val) ?? 0.0;
                            final dur = int.tryParse(durController.text.trim()) ?? 0;
                            widget.provider.completeSet(exIdx, setIdx, isDone, distance: dist, duration: dur * 60);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Input Minutos
                      Expanded(
                        child: TextField(
                          controller: durController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: _activeInputDeco("Minutos"),
                          onChanged: (val) {
                            final dist = double.tryParse(distController.text.trim()) ?? 0.0;
                            final dur = int.tryParse(val) ?? 0;
                            widget.provider.completeSet(exIdx, setIdx, isDone, distance: dist, duration: dur * 60);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Checkbox Concluir
                      Checkbox(
                        value: isDone,
                        activeColor: Colors.blueAccent,
                        onChanged: (val) {
                          final dist = double.tryParse(distController.text.trim()) ?? 0.0;
                          final dur = int.tryParse(durController.text.trim()) ?? 0;
                          widget.provider.completeSet(exIdx, setIdx, val ?? false, distance: dist, duration: dur * 60);
                        },
                      ),
                    ],
                  ),
                );
              } else {
                // RENDERIZAR SÉRIE DE MUSCULAÇÃO / ISOMETRIA
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(isDone ? 0.05 : 0.01),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDone ? accentColor.withOpacity(0.35) : Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      // Número da série
                      Text(
                        "Série ${setIdx + 1}",
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),

                      // Quantidade (reps ou segs)
                      Expanded(
                        child: Text(
                          ex.measurementType == 'time'
                              ? "${ex.reps} segundos"
                              : "${ex.reps} reps",
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      
                      // Carga (kg)
                      Text(
                        ex.weight > 0 ? "${ex.weight.toStringAsFixed(1).replaceAll('.0', '')} kg" : "Sem carga",
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(width: 16),

                      // Botão Falha (RPE/Failure)
                      GestureDetector(
                        onTap: () {
                          widget.provider.completeSet(
                            exIdx,
                            setIdx,
                            isDone,
                            isFailure: !isFailure,
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
                      const SizedBox(width: 8),

                      // Checkbox Concluir
                      Checkbox(
                        value: isDone,
                        activeColor: accentColor,
                        onChanged: (val) {
                          widget.provider.completeSet(exIdx, setIdx, val ?? false, isFailure: isFailure);
                        },
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _activeInputDeco(String hint) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      isDense: true,
    );
  }

  // A sincronização de timers de descanso e do índice de exercício ativo
  // agora é tratada de forma centralizada pelo provedor e seu ouvinte.

  void _confirmDiscardWorkout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xff1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text("Descartar Treino?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text("Tem certeza que deseja cancelar e descartar este treino em andamento? O progresso de hoje será perdido.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              widget.provider.discardActiveWorkout();
              Navigator.pop(dialogCtx);
            },
            child: const Text("Descartar", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
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
          return AlertDialog(
            backgroundColor: const Color(0xff1c1c1e),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            title: const Text("Concluir Treino 🎉", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Como foi o esforço da sessão? (RPE)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Leve (1)", style: TextStyle(color: Colors.white30, fontSize: 10)),
                      Text(
                        "Esforço: ${rpeVal.toInt()}/10",
                        style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text("Máximo (10)", style: TextStyle(color: Colors.white30, fontSize: 10)),
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
                  const Text("Notas ou observações do treino", style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("Voltar", style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () {
                  // Concluir treino no provider
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
