import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/tracker_provider.dart';

class CardioWeekData {
  final String title;
  final String shortTitle;
  final String dateRange;
  final DateTime start;
  final DateTime end;
  double totalMinutes;

  CardioWeekData({
    required this.title,
    required this.shortTitle,
    required this.dateRange,
    required this.start,
    required this.end,
    this.totalMinutes = 0,
  });
}

class CardioHistorySheet extends StatefulWidget {
  final Color accentColor;
  const CardioHistorySheet({super.key, required this.accentColor});

  @override
  State<CardioHistorySheet> createState() => _CardioHistorySheetState();
}

class _CardioHistorySheetState extends State<CardioHistorySheet> {
  List<CardioWeekData> _weeks = [];

  @override
  void initState() {
    super.initState();
    _calculateHistory();
  }

  void _calculateHistory() {
    final provider = Provider.of<TrackerProvider>(context, listen: false);
    final history = provider.state?.history ?? [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final mondayThisWeek = today.subtract(Duration(days: (now.weekday - 1)));

    _weeks = [];
    final labels = [
      {"title": "Semana Atual", "short": "Atual"},
      {"title": "Semana Passada", "short": "Sem -1"},
      {"title": "2 Semanas Atrás", "short": "Sem -2"},
      {"title": "3 Semanas Atrás", "short": "Sem -3"},
    ];

    for (int i = 0; i < 4; i++) {
      final start = mondayThisWeek.subtract(Duration(days: i * 7));
      final end = start.add(const Duration(days: 7));
      final endDisplay = start.add(const Duration(days: 6));

      final dateRangeStr =
          "${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')} a ${endDisplay.day.toString().padLeft(2, '0')}/${endDisplay.month.toString().padLeft(2, '0')}";

      _weeks.add(
        CardioWeekData(
          title: labels[i]["title"]!,
          shortTitle: labels[i]["short"]!,
          dateRange: dateRangeStr,
          start: start,
          end: end,
          totalMinutes: 0,
        ),
      );
    }

    for (var log in history) {
      final logDate = DateTime.tryParse(log.date);
      if (logDate == null) continue;

      for (int i = 0; i < 4; i++) {
        final w = _weeks[i];
        if (logDate.isAfter(w.start.subtract(const Duration(seconds: 1))) &&
            logDate.isBefore(w.end)) {
          for (var ex in log.exercises) {
            final hasCardio = ex.muscle.toLowerCase().contains('cardio') ||
                (ex.performedCardios != null &&
                    ex.performedCardios!.isNotEmpty);

            if (hasCardio && ex.performedCardios != null) {
              for (var pc in ex.performedCardios!) {
                if (pc != null) {
                  w.totalMinutes += (pc.durationSeconds / 60.0);
                }
              }
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Chronological order for the chart (from Sem -3 to Atual)
    final chronWeeks = _weeks.reversed.toList();
    final double maxVal = chronWeeks
        .map((w) => w.totalMinutes)
        .fold(300.0, (prev, val) => val > prev ? val : prev);
    final double maxY = ((maxVal + 60) / 50).ceil() * 50.0;

    final double totalMonthMinutes =
        _weeks.fold(0.0, (sum, w) => sum + w.totalMinutes);
    final double avgMonthMinutes = totalMonthMinutes / 4.0;
    final int weeksOnGoal = _weeks.where((w) => w.totalMinutes >= 300).length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title & subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Histórico de Cardio",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Minutos executados por semana (Meta: 300m)",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.3),
                    ),
                  ),
                  child: const Text(
                    "Meta: 300 min",
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Bar Chart
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => const FlLine(
                      color: Colors.white12,
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 300,
                        color: Colors.greenAccent,
                        strokeWidth: 2,
                        dashArray: const [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 5, bottom: 5),
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          labelResolver: (line) => "Meta (300m)",
                        ),
                      ),
                    ],
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          if (value == 100 ||
                              value == 200 ||
                              value == 300 ||
                              value == 400) {
                            return Text(
                              "${value.toInt()}m",
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < chronWeeks.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                chronWeeks[idx].shortTitle,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                  barGroups: chronWeeks.asMap().entries.map((e) {
                    final w = e.value;
                    final isGoalReached = w.totalMinutes >= 300;
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: w.totalMinutes,
                          color: isGoalReached
                              ? Colors.greenAccent
                              : (w.totalMinutes > 0
                                  ? Colors.blueAccent
                                  : Colors.white12),
                          width: 28,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          const Divider(color: Colors.white12, height: 20),

          // Week-by-Week Detailed Breakdown List
          Expanded(
            flex: 4,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              children: [
                // Summary KPI Row
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        "Média Mensal",
                        "${avgMonthMinutes.toStringAsFixed(0)} min/sem",
                        avgMonthMinutes >= 300
                            ? Colors.greenAccent
                            : Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        "Semanas na Meta",
                        "$weeksOnGoal / 4",
                        weeksOnGoal >= 2
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // List of 4 weeks
                ..._weeks.map((w) {
                  final pct = (w.totalMinutes / 300.0 * 100).clamp(0, 999).toInt();
                  final isReached = w.totalMinutes >= 300;
                  final Color c = isReached
                      ? Colors.greenAccent
                      : (w.totalMinutes > 0
                          ? Colors.blueAccent
                          : Colors.white30);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              w.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              w.dateRange,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${w.totalMinutes.toStringAsFixed(0)} min",
                              style: TextStyle(
                                color: c,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "$pct% da meta",
                              style: TextStyle(
                                color: isReached
                                    ? Colors.greenAccent
                                    : Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
