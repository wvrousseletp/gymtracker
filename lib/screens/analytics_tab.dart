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
import '../widgets/analytics/exercise_progression_card.dart';
import '../widgets/analytics/human_body_heatmap.dart';

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

  final List<String> _defaultOrder = [
    "kpi_cards",
    "activity_rings",
    "exercise_progression",
    "volume_chart",
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
          style: TextStyle(color: Colors.white.withOpacity(0.5)),
        ),
      );
    }

    // Filter history based on selected period
    final now = DateTime.now();
    final cutoffDate = now.subtract(Duration(days: _selectedPeriod));
    
    final filteredHistory = history.where((log) {
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
                    return Colors.white54;
                  }),
                  side: MaterialStateProperty.all(BorderSide(color: Colors.white.withOpacity(0.1))),
                ),
              ),
              // Edit Button
              if (_isEditing)
                 Row(
                   children: [
                     IconButton(
                       icon: const Icon(Icons.restore, color: Colors.white54),
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
                  icon: const Icon(Icons.edit, color: Colors.white54),
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
                          const Icon(Icons.drag_handle, color: Colors.white38),
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
      case "kpi_cards":
        return KPICards(history: filteredHistory, accentColor: widget.accentColor);
      case "activity_rings":
        return ActivityRings(
          currentDiet: dietProvider.diet,
          history: filteredHistory, // passed only for today's check
          accentColor: widget.accentColor,
        );
      case "exercise_progression":
        return ExerciseProgressionCard(
          history: filteredHistory,
          accentColor: widget.accentColor,
        );
      case "volume_chart":
        return _buildVolumeChart(filteredHistory);
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
            "Treinos no período: ${sorted.length} (kg)",
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: sorted.isEmpty
                ? const Center(child: Text("Sem dados suficientes", style: TextStyle(color: Colors.white54)))
                : LineChart(
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
                              if (index < 0 || index >= sorted.length) return const SizedBox();
                              final date = DateTime.tryParse(sorted[index].date);
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
      borderColor: Colors.white.withOpacity(0.08),
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Frequência Muscular",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Músculos treinados no período",
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
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
                    if (count == 0) chipColor = Colors.white.withOpacity(0.05);

                    return Container(
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
                              color: count > 0 ? Colors.white : Colors.white54,
                              fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                          if (count > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              "$count",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            )
                          ]
                        ],
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
}
