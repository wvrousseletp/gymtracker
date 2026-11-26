import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/tracker_provider.dart';
import '../providers/diet_provider.dart';
import '../models/workout_log.dart';
import '../widgets/glass_card.dart';
import 'diet_analytics_tab.dart';
import '../widgets/analytics/kpi_cards.dart';
import '../widgets/analytics/activity_rings.dart';
import '../widgets/analytics/macros_donut_chart.dart';
import '../widgets/analytics/human_body_heatmap.dart';
import '../widgets/analytics/exercise_progression_chart.dart';

class AnalyticsTab extends StatefulWidget {
  final Color accentColor;
  const AnalyticsTab({super.key, required this.accentColor});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  bool _isLoading = false;
  int _selectedPeriod = 7; // 7, 30, 365
  bool _isEditing = false;
  String? _selectedExerciseName;

  final List<String> _defaultOrder = [
    "week_comparison",
    "kpi_cards",
    "activity_rings",
    "cardio_stats",
    "volume_chart",
    "exercise_progression",
    "muscle_heatmap",
    "macros_donut",
    "diet_analytics",
  ];
  List<String> _widgetOrder = [];

  @override
  void initState() {
    super.initState();
    _widgetOrder = List.from(_defaultOrder);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<TrackerProvider>(context, listen: false);
    
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList('analytics_order');
    if (savedOrder != null && savedOrder.isNotEmpty) {
      // Ensure no missing keys and no extra keys
      final validOrder = savedOrder.where((k) => _defaultOrder.contains(k)).toList();
      for (var k in _defaultOrder) {
        if (!validOrder.contains(k)) validOrder.add(k);
      }
      _widgetOrder = validOrder;
    }

    if (provider.state?.history.isEmpty ?? true) {
      await provider.loadWorkoutHistory();
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('analytics_order', _widgetOrder);
  }
  
  void _resetOrder() {
    setState(() {
      _widgetOrder = List.from(_defaultOrder);
      _saveOrder();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final trackerProvider = Provider.of<TrackerProvider>(context);
    final dietProvider = Provider.of<DietProvider>(context);
    final history = trackerProvider.state?.history ?? [];
    
    if (history.isEmpty && dietProvider.dietHistory.isEmpty) {
      return Center(
        child: Text(
          "Sem dados suficientes para estatísticas.",
          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)).withOpacity(0.5)),
        ),
      );
    }

    // Filter history based on selected period
    final now = DateTime.now();
    final cutoffDate = now.subtract(Duration(days: _selectedPeriod));
    
    final filteredHistory = history.where((log) {
      if (log.isRestDayLog) return false;
      final dt = DateTime.tryParse(log.date);
      if (dt == null) return false;
      return dt.isAfter(cutoffDate) || dt.isAtSameMomentAs(cutoffDate);
    }).toList();

    // Generate date strings for diet
    final List<String> filteredDateStrings = List.generate(_selectedPeriod, (i) {
      final d = now.subtract(Duration(days: _selectedPeriod - 1 - i));
      return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    });

    return Column(
      children: [
        // Top Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Segmented Control
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text("7D")),
                  ButtonSegment(value: 30, label: Text("30D")),
                  ButtonSegment(value: 365, label: Text("Ano")),
                ],
                selected: {_selectedPeriod},
                onSelectionChanged: (Set<int> newSelection) {
                  setState(() => _selectedPeriod = newSelection.first);
                },
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.selected)) {
                      return widget.accentColor.withOpacity(0.2);
                    }
                    return Colors.transparent;
                  }),
                  foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.selected)) return widget.accentColor;
                    return (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73));
                  }),
                  side: MaterialStateProperty.all(BorderSide(color: Colors.white.withOpacity(0.1))),
                ),
              ),
              // Edit Button
              if (_isEditing)
                 Row(
                   children: [
                     IconButton(
                       icon: Icon(Icons.restore, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73))),
                       onPressed: _resetOrder,
                       tooltip: "Restaurar Padrão",
                     ),
                     IconButton(
                       icon: Icon(Icons.check, color: widget.accentColor),
                       onPressed: () => setState(() => _isEditing = false),
                     ),
                   ],
                 )
              else
                IconButton(
                  icon: Icon(Icons.edit, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73))),
                  onPressed: () => setState(() => _isEditing = true),
                )
            ],
          ),
        ),
        
        Expanded(
          child: _isEditing
              ? ReorderableListView(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                  physics: const BouncingScrollPhysics(),
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _widgetOrder.removeAt(oldIndex);
                      _widgetOrder.insert(newIndex, item);
                      _saveOrder();
                    });
                  },
                  children: _widgetOrder.map((key) {
                    return Padding(
                      key: ValueKey(key),
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.drag_handle, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF8E8E93))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildWidgetForKey(key, filteredHistory, dietProvider, filteredDateStrings),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _widgetOrder.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final key = _widgetOrder[index];
                    return _buildWidgetForKey(key, filteredHistory, dietProvider, filteredDateStrings);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWidgetForKey(
    String key, 
    List<WorkoutLog> filteredHistory,
    DietProvider dietProvider,
    List<String> filteredDateStrings,
  ) {
    switch (key) {
      case "week_comparison":
        final allHistory = Provider.of<TrackerProvider>(context, listen: false).state?.history ?? [];
        return _buildWeekComparisonCard(allHistory);
      case "kpi_cards":
        return KPICards(history: filteredHistory, accentColor: widget.accentColor);
      case "activity_rings":
        final tracker = Provider.of<TrackerProvider>(context, listen: false);
        final todayStr =
            "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
        final hasRestLog = (tracker.state?.history ?? [])
            .any((l) => l.isRestDayLog && l.date.startsWith(todayStr));
        return ActivityRings(
          currentDiet: dietProvider.diet,
          history: filteredHistory,
          accentColor: widget.accentColor,
          isRestDayToday: tracker.isContinuousRestToday || hasRestLog,
        );
      case "cardio_stats":
        return _buildCardioStatsCard(filteredHistory);

      case "volume_chart":
        return _buildVolumeChart(filteredHistory);
      case "exercise_progression":
        final allHistory = Provider.of<TrackerProvider>(context, listen: false).state?.history ?? [];
        return _buildExerciseQuickProgression(allHistory);
      case "muscle_heatmap":
        return _buildMuscleHeatmap(filteredHistory);
      case "macros_donut":
        return MacrosDonutChart(
          dietHistory: dietProvider.dietHistory,
          currentDiet: dietProvider.diet,
          filteredDateStrings: filteredDateStrings,
          accentColor: widget.accentColor,
        );
      case "diet_analytics":
        // Refactored DietAnalyticsTab to accept filtered values could be done, 
        // but for now we wrap it in a card or use it directly. 
        // DietAnalyticsTab natively uses its own 7-day logic. 
        // Let's replace DietAnalyticsTab with our own logic here or keep it.
        // I will just return the DietAnalyticsTab, it has its own style.
        return DietAnalyticsTab(accentColor: widget.accentColor);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildVolumeChart(List<WorkoutLog> history) {
    final sorted = List<WorkoutLog>.from(history)
      ..sort((a, b) => (DateTime.tryParse(a.date) ?? DateTime(0))
          .compareTo(DateTime.tryParse(b.date) ?? DateTime(0)));

    final spots = <FlSpot>[];
    for (int i = 0; i < sorted.length; i++) {
      spots.add(FlSpot(i.toDouble(), sorted[i].totalWeight));
    }

    return GlassCard(
      useBlur: true,
      borderColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08),
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Evolução de Volume Total",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Treinos no período: ${sorted.length} (kg)",
            style: TextStyle(fontSize: 12, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)).withOpacity(0.5)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: sorted.isEmpty
                ? Center(child: Text("Sem dados suficientes", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)))))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
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
                                style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)).withOpacity(0.5), fontSize: 10),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= sorted.length) return const SizedBox();
                              final date = DateTime.tryParse(sorted[index].date);
                              if (date == null) return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  DateFormat("dd/MM").format(date),
                                  style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)).withOpacity(0.5), fontSize: 10),
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
    Map<String, int> muscleCounts = {};
    for (var log in history) {
      for (var ex in log.exercises) {
        muscleCounts[ex.muscle] = (muscleCounts[ex.muscle] ?? 0) + 1;
      }
    }

    int maxCount = 1;
    if (muscleCounts.isNotEmpty) {
      maxCount = muscleCounts.values.reduce((a, b) => a > b ? a : b);
    }

    final muscles = [
      "Peito", "Costas", "Pernas", "Ombros", "Bíceps", "Tríceps", "Abdômen", "Geral"
    ];

    return GlassCard(
      useBlur: true,
      borderColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08),
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Frequência Muscular",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Músculos treinados no período",
            style: TextStyle(fontSize: 12, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)).withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: muscles.map((m) {
                    final count = muscleCounts[m] ?? 0;
                    final intensity = maxCount > 0 ? count / maxCount : 0.0;
                    
                    Color chipColor = widget.accentColor.withOpacity(0.1 + (0.9 * intensity));
                    if (count == 0) chipColor = (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05);

                    return GestureDetector(
                      onTap: () {
                        if (count > 0) {
                          _showMuscleDetails(context, m, history);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: chipColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: count > 0 ? widget.accentColor.withOpacity(0.3) : Colors.transparent,
                          )
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              m,
                              style: TextStyle(
                                color: count > 0 ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
                                fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                            if (count > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                "$count",
                                style: TextStyle(
                                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)).withOpacity(0.8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              )
                            ]
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 16),
              HumanBodyHeatmap(
                muscleIntensity: muscleCounts.map((k, v) => MapEntry(k, maxCount > 0 ? v / maxCount : 0.0)),
                accentColor: widget.accentColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMuscleDetails(BuildContext context, String muscle, List<WorkoutLog> history) {
    // Collect all exercises for this muscle
    List<Map<String, dynamic>> muscleExercises = [];
    for (var log in history) {
      for (var ex in log.exercises) {
        if (ex.muscle == muscle) {
          muscleExercises.add({
            'date': log.date,
            'exerciseName': ex.name,
            'sets': ex.sets,
            'reps': ex.reps,
            'weight': ex.weight,
          });
        }
      }
    }

    // Sort by date descending
    muscleExercises.sort((a, b) {
      final dtA = DateTime.tryParse(a['date']) ?? DateTime(0);
      final dtB = DateTime.tryParse(b['date']) ?? DateTime(0);
      return dtB.compareTo(dtA);
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Exercícios para $muscle",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: muscleExercises.isEmpty
                    ? Center(child: Text("Nenhum exercício encontrado.", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)))))
                    : ListView.builder(
                        itemCount: muscleExercises.length,
                        itemBuilder: (context, index) {
                          final data = muscleExercises[index];
                          final dateStr = data['date'];
                          String dateFormatted = "";
                          if (dateStr != null) {
                            final dt = DateTime.tryParse(dateStr);
                            if (dt != null) {
                              dateFormatted = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
                            }
                          }
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(data['exerciseName'], style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)))),
                            subtitle: Text(
                              dateFormatted,
                              style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)).withOpacity(0.5)),
                            ),
                            trailing: Text(
                              "${data['sets']}x${data['reps']} • ${data['weight']}kg",
                              style: TextStyle(
                                color: widget.accentColor,
                                fontWeight: FontWeight.bold,
                              ),
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
  }

  Widget _buildCardioStatsCard(List<WorkoutLog> history) {
    double totalDistance = 0;
    int totalDurationSeconds = 0;
    int cardioSessions = 0;

    for (var log in history) {
      bool hasCardioInLog = false;
      for (var ex in log.exercises) {
        final hasCardio = ex.muscle.toLowerCase().contains('cardio') || 
            (ex.performedCardios != null && ex.performedCardios!.isNotEmpty);
            
        if (hasCardio && ex.performedCardios != null) {
          for (var pc in ex.performedCardios!) {
            if (pc != null) {
              totalDistance += pc.distanceKm;
              totalDurationSeconds += pc.durationSeconds;
              hasCardioInLog = true;
            }
          }
        }
      }
      if (hasCardioInLog) {
        cardioSessions++;
      }
    }

    if (cardioSessions == 0) {
      return const SizedBox.shrink(); // Don't show if no cardio has been recorded yet
    }

    // Format pace (min/km)
    String paceStr = "-";
    if (totalDistance > 0) {
      double totalMinutes = totalDurationSeconds / 60.0;
      double paceDecimal = totalMinutes / totalDistance;
      int paceMins = paceDecimal.toInt();
      int paceSecs = ((paceDecimal - paceMins) * 60).round();
      paceStr = "$paceMins:${paceSecs.toString().padLeft(2, '0')} /km";
    }

    // Format time
    String durationStr = "-";
    if (totalDurationSeconds > 0) {
      if (totalDurationSeconds < 3600) {
        durationStr = "${totalDurationSeconds ~/ 60}m";
      } else {
        final hours = totalDurationSeconds ~/ 3600;
        final mins = (totalDurationSeconds % 3600) ~/ 60;
        durationStr = "${hours}h ${mins}m";
      }
    }

    final accentColor = widget.accentColor;

    return GlassCard(
      useBlur: true,
      borderColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08),
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_run, color: accentColor, size: 22),
              const SizedBox(width: 8),
              Text(
                "Métricas de Cardio",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSubMetric("Distância Total", "${totalDistance.toStringAsFixed(1)} km", (Theme.of(context).brightness == Brightness.dark ? Colors.greenAccent : const Color(0xFF1E8E3E))),
              ),
              Expanded(
                child: _buildSubMetric("Tempo Total", durationStr, Colors.blueAccent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSubMetric("Ritmo Médio (Pace)", paceStr, Colors.orangeAccent),
              ),
              Expanded(
                child: _buildSubMetric("Sessões de Cardio", "$cardioSessions", Colors.purpleAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekComparisonCard(List<WorkoutLog> allHistory) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final now = DateTime.now();
    final startCurrentWeek = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final startPrevWeek = startCurrentWeek.subtract(const Duration(days: 7));

    double currVol = 0, prevVol = 0;
    int currWorkouts = 0, prevWorkouts = 0;
    int currSets = 0, prevSets = 0;

    for (final log in allHistory) {
      if (log.isRestDayLog) continue;
      final dt = DateTime.tryParse(log.date);
      if (dt == null) continue;
      final d = DateTime(dt.year, dt.month, dt.day);

      double logVol = 0;
      int logSets = 0;
      for (final ex in log.exercises) {
        final isCardioEx = ex.muscle.toLowerCase().contains('cardio') ||
            (ex.performedCardios?.isNotEmpty ?? false);
        if (ex.completedSets > 0 && !isCardioEx) {
          logVol += ex.weight * ex.reps * ex.completedSets;
          logSets += ex.completedSets;
        } else if (ex.completedSets > 0) {
          logSets += ex.completedSets;
        }
      }

      if (!d.isBefore(startCurrentWeek)) {
        currVol += logVol;
        currWorkouts++;
        currSets += logSets;
      } else if (!d.isBefore(startPrevWeek) && d.isBefore(startCurrentWeek)) {
        prevVol += logVol;
        prevWorkouts++;
        prevSets += logSets;
      }
    }

    Widget deltaBadge(double curr, double prev) {
      if (prev <= 0 && curr <= 0) {
        return Text("=", style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold));
      }
      if (prev <= 0) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
          child: Text("Novo", style: TextStyle(color: isDark ? Colors.greenAccent : const Color(0xFF1E8E3E), fontSize: 10, fontWeight: FontWeight.w800)),
        );
      }
      final pct = ((curr - prev) / prev * 100).round();
      final isUp = pct >= 0;
      final badgeColor = pct == 0
          ? textColor.withOpacity(0.5)
          : (isUp ? (isDark ? Colors.greenAccent : const Color(0xFF1E8E3E)) : Colors.redAccent);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: badgeColor.withOpacity(0.14), borderRadius: BorderRadius.circular(6)),
        child: Text(
          "${pct > 0 ? '+' : ''}$pct%",
          style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w800),
        ),
      );
    }

    String formatVol(double v) => v >= 1000 ? "${(v / 1000).toStringAsFixed(1)}t" : "${v.toStringAsFixed(0)} kg";

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows_rounded, color: widget.accentColor, size: 18),
              const SizedBox(width: 8),
              Text(
                "ESTA SEMANA VS. PASSADA",
                style: TextStyle(
                  color: textColor.withOpacity(0.65),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Volume", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(formatVol(currVol), style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    deltaBadge(currVol, prevVol),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Treinos", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text("$currWorkouts", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    deltaBadge(currWorkouts.toDouble(), prevWorkouts.toDouble()),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Séries", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text("$currSets", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    deltaBadge(currSets.toDouble(), prevSets.toDouble()),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseQuickProgression(List<WorkoutLog> allHistory) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final Map<String, int> freq = {};
    for (final log in allHistory) {
      if (log.isRestDayLog) continue;
      for (final ex in log.exercises) {
        final isCardioEx = ex.muscle.toLowerCase().contains('cardio') ||
            (ex.performedCardios?.isNotEmpty ?? false);
        if (!isCardioEx && ex.completedSets > 0 && ex.weight > 0) {
          freq[ex.name] = (freq[ex.name] ?? 0) + 1;
        }
      }
    }
    if (freq.isEmpty) return const SizedBox.shrink();

    final sortedExercises = freq.keys.toList()
      ..sort((a, b) => freq[b]!.compareTo(freq[a]!));
    final selected = (_selectedExerciseName != null && freq.containsKey(_selectedExerciseName))
        ? _selectedExerciseName!
        : sortedExercises.first;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, color: widget.accentColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "EVOLUÇÃO POR EXERCÍCIO",
                  style: TextStyle(
                    color: textColor.withOpacity(0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sortedExercises.take(15).length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final name = sortedExercises[idx];
                final isSel = name == selected;
                return GestureDetector(
                  onTap: () => setState(() => _selectedExerciseName = name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSel
                          ? widget.accentColor.withOpacity(0.18)
                          : (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSel
                            ? widget.accentColor.withOpacity(0.6)
                            : (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: isSel ? widget.accentColor : textColor.withOpacity(0.75),
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ExerciseProgressionChart(
              exerciseName: selected,
              history: allHistory,
              accentColor: widget.accentColor,
              showWeight: true,
            ),
          ),
        ],
      ),
    );
  }
}
