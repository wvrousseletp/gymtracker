import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/exercise.dart';
import '../models/workout_log.dart';
import '../models/routine.dart';
import '../providers/workout_provider.dart';
import '../providers/profile_provider.dart';
import '../services/ai_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/analytics/exercise_progression_chart.dart';

class ExerciseHubScreen extends StatefulWidget {
  final LibraryExercise exercise;
  
  const ExerciseHubScreen({super.key, required this.exercise});

  @override
  State<ExerciseHubScreen> createState() => _ExerciseHubScreenState();
}

class _ExerciseHubScreenState extends State<ExerciseHubScreen> {
  bool _isLoadingAI = false;
  String? _aiInsight;
  String? _aiError;

  List<WorkoutLog> _exerciseLogs = [];
  double _maxWeight = 0;
  double _maxVolume = 0;
  int _totalSets = 0;
  double _estimated1RM = 0;

  @override
  void initState() {
    super.initState();
    _calculateStats();
    _loadAIInsight();
  }

  Future<void> _loadAIInsight() async {
    final prefs = await SharedPreferences.getInstance();
    final savedInsight = prefs.getString('ai_insight_${widget.exercise.name}');
    if (savedInsight != null && savedInsight.isNotEmpty) {
      if (mounted) {
        setState(() {
          _aiInsight = savedInsight;
        });
      }
    }
  }

  void _calculateStats() {
    final provider = Provider.of<WorkoutProvider>(context, listen: false);
    
    _exerciseLogs = provider.history.where((log) {
      return log.exercises.any((ex) => ex.name == widget.exercise.name && ex.completedSets > 0);
    }).toList();

    // Sort descending (newest first) for the list
    _exerciseLogs.sort((a, b) {
      final dateA = DateTime.tryParse(a.date) ?? DateTime.now();
      final dateB = DateTime.tryParse(b.date) ?? DateTime.now();
      return dateB.compareTo(dateA);
    });

    for (var log in _exerciseLogs) {
      for (var ex in log.exercises) {
        if (ex.name == widget.exercise.name) {
          _totalSets += ex.completedSets;
          if (ex.weight > _maxWeight) _maxWeight = ex.weight;
          
          double volume = ex.weight * ex.reps * ex.completedSets;
          if (volume > _maxVolume) _maxVolume = volume;

          // Epley Formula for 1RM: w * (1 + r/30)
          if (ex.reps > 0) {
            double e1rm = ex.weight * (1.0 + (ex.reps / 30.0));
            if (e1rm > _estimated1RM) _estimated1RM = e1rm;
          }
        }
      }
    }
  }

  Future<void> _fetchAIInsight() async {
    setState(() {
      _isLoadingAI = true;
      _aiError = null;
    });

    final isCardio = widget.exercise.measurementType == MeasurementType.cardio ||
        widget.exercise.muscle.toLowerCase().contains('cardio') ||
        widget.exercise.measurementType == MeasurementType.time;

    try {
      final insight = await AIService().analyzeExerciseHistory(
        exerciseName: widget.exercise.name,
        exerciseHistory: _exerciseLogs,
        isCardio: isCardio,
      );

      if (!mounted) return;

      setState(() {
        _isLoadingAI = false;
        _aiInsight = insight;
      });

      if (insight.isNotEmpty && !insight.startsWith("Erro")) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ai_insight_${widget.exercise.name}', insight);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAI = false;
        _aiError = "Erro: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WorkoutProvider>(context);
    final accentColor = context.select<ProfileProvider, Color>(
      (p) => ThemeUtils.getColor(p.currentProfile.colorAccent),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13), // Deep dark bg
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.exercise.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Muscle Group
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentColor.withOpacity(0.3)),
                ),
                child: Text(
                  widget.exercise.muscle.toUpperCase(),
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // AI Insight Section
            _buildAISection(accentColor),
            const SizedBox(height: 24),

            // KPIs Grid
            _buildKPIsGrid(accentColor),
            const SizedBox(height: 24),

            // Modelos de Treino (Rotinas)
            _buildRoutinesSection(context, provider, accentColor),
            const SizedBox(height: 24),

            // Progression Chart
            if (_exerciseLogs.isNotEmpty) ...[
              const Text(
                "Progressão de Carga",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: SizedBox(
                  height: 220,
                  child: ExerciseProgressionChart(
                    exerciseName: widget.exercise.name,
                    history: _exerciseLogs,
                    accentColor: accentColor,
                    showWeight: true,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // History List
            const Text(
              "Histórico do Exercício",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _exerciseLogs.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text("Nenhum histórico encontrado para este exercício.", style: TextStyle(color: Colors.white54)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _exerciseLogs.length,
                    itemBuilder: (context, index) {
                      return _buildHistoryItem(_exerciseLogs[index], accentColor);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildAISection(Color accentColor) {
    if (_exerciseLogs.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: accentColor, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Treinador IA",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              if (!_isLoadingAI)
                IconButton(
                  icon: Icon(Icons.refresh, color: accentColor, size: 20),
                  onPressed: _fetchAIInsight,
                  tooltip: "Nova Consulta",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoadingAI)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: accentColor, strokeWidth: 2.5),
                    const SizedBox(height: 12),
                    const Text(
                      "Analisando histórico e hipertrofia...",
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else if (_aiInsight != null && _aiInsight!.isNotEmpty) ...[
            Text(
              _aiInsight!,
              style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 14),
            ),
            if (_aiError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_aiError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
          ] else ...[
            Text(
              "Obtenha uma análise profunda do seu progresso e recomendações para hipertrofia neste exercício.",
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
            ),
            if (_aiError != null) ...[
              const SizedBox(height: 8),
              Text(_aiError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _fetchAIInsight,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text("Analisar Histórico", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildKPIsGrid(Color accentColor) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildKPI("Carga Máx (PR)", "${_maxWeight.toStringAsFixed(1)} kg", Icons.emoji_events, accentColor),
        _buildKPI("Séries Totais", "$_totalSets", Icons.layers, accentColor),
        _buildKPI("Volume Máx", "${_maxVolume.toStringAsFixed(0)} kg", Icons.fitness_center, accentColor),
        _buildKPI("1RM Estimado", "${_estimated1RM.toStringAsFixed(1)} kg", Icons.speed, accentColor),
      ],
    );
  }

  Widget _buildKPI(String label, String value, IconData icon, Color accentColor) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(WorkoutLog log, Color accentColor) {
    // Extract only the specific exercise info from this log
    final ex = log.exercises.firstWhere((e) => e.name == widget.exercise.name);
    
    DateTime? dt = DateTime.tryParse(log.date);
    String dateStr = dt != null ? DateFormat('dd MMM yyyy').format(dt) : log.date;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  log.name,
                  style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${ex.completedSets} séries x ${ex.reps} reps",
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  "${ex.weight.toStringAsFixed(1)} kg",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutinesSection(BuildContext context, WorkoutProvider provider, Color accentColor) {
    final containingRoutines = provider.routines.where((routine) {
      return routine.exercises.any((ex) => ex.exerciseId == widget.exercise.id);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Modelos / Rotinas de Treino",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (containingRoutines.isEmpty)
          const GlassCard(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.white30, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Este exercício não está incluído em nenhuma rotina ainda.",
                    style: TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: containingRoutines.map((routine) {
              final routineEx = routine.exercises.firstWhere((ex) => ex.exerciseId == widget.exercise.id);
              final isTime = widget.exercise.measurementType == MeasurementType.time;
              
              String details = "${routineEx.sets} séries x ${routineEx.reps}";
              if (isTime) {
                details += "s";
              } else {
                details += " reps";
              }
              if (routineEx.weight > 0) {
                details += " @ ${routineEx.weight.toStringAsFixed(1).replaceAll('.0', '')} kg";
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.folder_open_rounded, color: accentColor, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              routine.name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              details,
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_note_rounded, color: accentColor, size: 24),
                        onPressed: () => _showEditRoutineExerciseDialog(context, provider, routine, routineEx),
                        tooltip: "Ajustar Carga e Repetições",
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _showEditRoutineExerciseDialog(
      BuildContext context, WorkoutProvider provider, Routine routine, RoutineExercise routineEx) {
    final weightCtrl = TextEditingController(text: routineEx.weight.toStringAsFixed(1).replaceAll('.0', ''));
    final repsCtrl = TextEditingController(text: routineEx.reps.toString());
    final setsCtrl = TextEditingController(text: routineEx.sets.toString());
    final restCtrl = TextEditingController(text: routineEx.rest.toString());

    final isTime = widget.exercise.measurementType == MeasurementType.time;
    final isCardio = widget.exercise.measurementType == MeasurementType.cardio ||
        widget.exercise.measurementType == MeasurementType.distance;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Ajustar no Modelo: ${routine.name}",
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Séries
                const Text("Séries", style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: setsCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // Reps / Tempo
                Text(
                  isTime ? "Tempo (segundos)" : "Repetições",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: repsCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // Carga / Resistência
                Text(
                  isCardio ? "Resistência / Nível" : "Carga (kg)",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // Descanso
                const Text("Descanso (segundos)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: restCtrl,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                final double? w = double.tryParse(weightCtrl.text.replaceAll(',', '.'));
                final int? r = int.tryParse(repsCtrl.text);
                final int? s = int.tryParse(setsCtrl.text);
                final int? rst = int.tryParse(restCtrl.text);

                provider.updateRoutineExerciseSettings(
                  routine.id,
                  widget.exercise.id,
                  weight: w,
                  reps: r,
                  sets: s,
                  rest: rst,
                );
                
                Navigator.pop(dialogCtx);
                
                // Show confirmation snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Modelo '${routine.name}' atualizado com sucesso!"),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Salvar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
