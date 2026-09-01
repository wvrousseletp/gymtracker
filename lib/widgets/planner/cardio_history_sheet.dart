import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/tracker_provider.dart';

class CardioHistorySheet extends StatefulWidget {
  final Color accentColor;
  const CardioHistorySheet({super.key, required this.accentColor});

  @override
  State<CardioHistorySheet> createState() => _CardioHistorySheetState();
}

class _CardioHistorySheetState extends State<CardioHistorySheet> {
  final List<double> _weeklyMinutes = [0, 0, 0, 0]; // Index 0 is 3 weeks ago, 3 is this week.
  
  @override
  void initState() {
    super.initState();
    _calculateHistory();
  }
  
  void _calculateHistory() {
    final provider = Provider.of<TrackerProvider>(context, listen: false);
    final history = provider.state?.history ?? [];
    
    final now = DateTime.now();
    
    for (var log in history) {
      final logDate = DateTime.tryParse(log.date);
      if (logDate == null) continue;
      
      final daysAgo = now.difference(logDate).inDays;
      if (daysAgo <= 28 && daysAgo >= 0) {
        int weekIndex = 3 - (daysAgo ~/ 7);
        if (weekIndex < 0) weekIndex = 0;
        if (weekIndex > 3) weekIndex = 3;
        
        for (var ex in log.exercises) {
          final hasCardio = ex.muscle.toLowerCase().contains('cardio') || 
            (ex.performedCardios != null && ex.performedCardios!.isNotEmpty);
            
          if (hasCardio && ex.performedCardios != null) {
            for (var pc in ex.performedCardios!) {
              if (pc != null) {
                _weeklyMinutes[weekIndex] += (pc.durationSeconds / 60.0);
              }
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const Text("Histórico de Cardio", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text("Minutos executados nas últimas 4 semanas", style: TextStyle(color: Colors.white54, fontSize: 13)),
          
          const SizedBox(height: 32),
          
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 350,
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.white12, strokeWidth: 1, dashArray: [5, 5]),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 300,
                        color: Colors.greenAccent,
                        strokeWidth: 2,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 5, bottom: 5),
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                          labelResolver: (line) => "Meta (300m)",
                        ),
                      )
                    ]
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == 100 || value == 200 || value == 300) {
                            return Text("${value.toInt()}", style: const TextStyle(color: Colors.white54, fontSize: 10));
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final labels = ["Sem -3", "Sem -2", "Sem Pass.", "Atual"];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(labels[value.toInt()], style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: _weeklyMinutes.asMap().entries.map((e) {
                    final isGoalReached = e.value >= 300;
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value,
                          color: isGoalReached ? Colors.greenAccent : Colors.blueAccent,
                          width: 24,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          Expanded(
            flex: 2,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                _buildStatRow("Média do Mês", "${(_weeklyMinutes.fold(0.0, (a, b) => a + b) / 4).toStringAsFixed(0)} min/sem", Colors.white),
                const Divider(color: Colors.white12, height: 24),
                _buildStatRow("Semanas na Meta", "${_weeklyMinutes.where((v) => v >= 300).length} / 4", Colors.greenAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }
}
