import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/tracker_provider.dart';
import '../models/workout_log.dart';
import '../widgets/glass_card.dart';

class AnalyticsTab extends StatefulWidget {
  final Color accentColor;
  const AnalyticsTab({super.key, required this.accentColor});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<TrackerProvider>(context, listen: false);
    if (provider.state?.history.isEmpty ?? true) {
      await provider.loadWorkoutHistory();
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final history = context.select<TrackerProvider, List<WorkoutLog>>(
      (p) => p.state?.history ?? [],
    );

    if (history.isEmpty) {
      return Center(
        child: Text(
          "Sem dados suficientes para estatísticas.",
          style: TextStyle(color: Colors.white.withOpacity(0.5)),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildVolumeChart(history),
          const SizedBox(height: 24),
          _buildMuscleHeatmap(history),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildVolumeChart(List<WorkoutLog> history) {
    // Sort chronologically (oldest first)
    final sorted = List<WorkoutLog>.from(history)
      ..sort((a, b) => (DateTime.tryParse(a.date) ?? DateTime(0))
          .compareTo(DateTime.tryParse(b.date) ?? DateTime(0)));

    // Take last 10 workouts
    final recentLogs = sorted.length > 10 ? sorted.sublist(sorted.length - 10) : sorted;

    final spots = <FlSpot>[];
    for (int i = 0; i < recentLogs.length; i++) {
      spots.add(FlSpot(i.toDouble(), recentLogs[i].totalWeight));
    }

    return GlassCard(
      useBlur: true,
      borderColor: Colors.white.withOpacity(0.08),
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Evolução de Volume Total",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Últimos ${recentLogs.length} treinos (kg)",
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          "${(value / 1000).toStringAsFixed(1)}k",
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= recentLogs.length) return const SizedBox();
                        final date = DateTime.tryParse(recentLogs[index].date);
                        if (date == null) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            DateFormat("dd/MM").format(date),
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: widget.accentColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: widget.accentColor.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMuscleHeatmap(List<WorkoutLog> history) {
    // Only last 30 days
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final recentLogs = history.where((log) {
      final date = DateTime.tryParse(log.date);
      return date != null && date.isAfter(thirtyDaysAgo);
    }).toList();

    // Calculate volume (sets * weight) per muscle, or just completed sets
    final Map<String, int> muscleSets = {};
    for (final log in recentLogs) {
      for (final ex in log.exercises) {
        final muscle = ex.muscle.trim();
        if (muscle.isEmpty) continue;
        muscleSets[muscle] = (muscleSets[muscle] ?? 0) + ex.completedSets;
      }
    }

    if (muscleSets.isEmpty) {
      return const SizedBox();
    }

    final sortedMuscles = muscleSets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Take top 5
    final topMuscles = sortedMuscles.take(5).toList();

    double maxSets = 0;
    for (var m in topMuscles) {
      if (m.value > maxSets) maxSets = m.value.toDouble();
    }

    return GlassCard(
      useBlur: true,
      borderColor: Colors.white.withOpacity(0.08),
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Foco Muscular (30 dias)",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Músculos mais treinados por total de séries",
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxSets * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        "${topMuscles[group.x.toInt()].key}\n",
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(
                            text: "${rod.toY.toInt()} séries",
                            style: TextStyle(color: widget.accentColor),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= topMuscles.length) return const SizedBox();
                        // Truncate name
                        String name = topMuscles[index].key;
                        if (name.length > 8) name = name.substring(0, 8);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            name.toUpperCase(),
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: topMuscles.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.value.toDouble(),
                        color: widget.accentColor,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxSets * 1.2,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
