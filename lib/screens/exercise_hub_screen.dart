import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/exercise.dart';
import '../models/workout_log.dart';
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
}
