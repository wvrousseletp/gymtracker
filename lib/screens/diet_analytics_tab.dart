import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/diet_provider.dart';
import '../widgets/glass_card.dart';

class DietAnalyticsTab extends StatelessWidget {
  final Color accentColor;
  const DietAnalyticsTab({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DietProvider>(context);
    final history = provider.dietHistory;

    final now = DateTime.now();
    final List<DateTime> last7Days =
        List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));

    final List<String> dateStrings = last7Days
        .map((d) =>
            "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}")
        .toList();
    final List<String> weekdaysShort = last7Days.map((d) {
      switch (d.weekday) {
        case 1:
          return "Seg";
        case 2:
          return "Ter";
        case 3:
          return "Qua";
        case 4:
          return "Qui";
        case 5:
          return "Sex";
        case 6:
          return "Sáb";
        case 7:
          return "Dom";
        default:
          return "";
      }
    }).toList();

    final List<double> calIntakes = [];
    final List<double> waterIntakes = [];

    double maxCal = 1000.0;
    double maxWater = 1000.0;

    final currentDiet = provider.diet;
    for (int i = 0; i < 7; i++) {
      final dateStr = dateStrings[i];
      double cal = 0;
      double water = 0;

      final todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      if (dateStr == todayStr) {
        cal = currentDiet.meals
            .fold<int>(0, (sum, m) => sum + m.calories)
            .toDouble();
        water = currentDiet.waterIntakeMl.toDouble();
      } else if (history.containsKey(dateStr)) {
        cal = history[dateStr]!.caloriesIntake.toDouble();
        water = history[dateStr]!.waterIntakeMl.toDouble();
      }

      calIntakes.add(cal);
      waterIntakes.add(water);

      if (cal > maxCal) maxCal = cal;
      if (water > maxWater) maxWater = water;
    }

    maxCal *= 1.2;
    maxWater *= 1.2;

    final double calGoal = currentDiet.caloriesGoal.toDouble();
    final double waterGoal = currentDiet.waterGoalMl.toDouble();
    if (calGoal > maxCal) maxCal = calGoal * 1.2;
    if (waterGoal > maxWater) maxWater = waterGoal * 1.2;

    final double avgCals = calIntakes.reduce((a, b) => a + b) / 7;
    final double avgWater = waterIntakes.reduce((a, b) => a + b) / 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn(
                  "Média Calorias", "${avgCals.toStringAsFixed(0)} kcal"),
              Container(width: 1, height: 40, color: Colors.white10),
              _buildStatColumn(
                  "Média Hidratação", "${avgWater.toStringAsFixed(0)} ml"),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "Histórico de Calorias (Kcal)",
          style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxCal,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < 7) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(weekdaysShort[idx],
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 10)),
                          );
                        }
                        return const Text("");
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: calGoal,
                      color: Colors.green.withOpacity(0.5),
                      strokeWidth: 2,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: const TextStyle(
                            color: Colors.green,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                        labelResolver: (line) =>
                            "Meta: ${calGoal.toInt()} kcal",
                      ),
                    ),
                  ],
                ),
                barGroups: List.generate(7, (i) {
                  final intake = calIntakes[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: intake,
                        color:
                            intake >= calGoal ? Colors.green : accentColor,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      )
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "Histórico de Hidratação (ml)",
          style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxWater,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < 7) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(weekdaysShort[idx],
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 10)),
                          );
                        }
                        return const Text("");
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: waterGoal,
                      color: Colors.blue.withOpacity(0.5),
                      strokeWidth: 2,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                        labelResolver: (line) =>
                            "Meta: ${waterGoal.toInt()} ml",
                      ),
                    ),
                  ],
                ),
                barGroups: List.generate(7, (i) {
                  final intake = waterIntakes[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: intake,
                        color:
                            intake >= waterGoal ? Colors.blue : accentColor,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      )
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String val) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text(val,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
