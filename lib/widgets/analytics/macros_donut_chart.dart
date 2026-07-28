import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/diet.dart';
import '../glass_card.dart';

class MacrosDonutChart extends StatelessWidget {
  final Map<String, DietHistoryDay> dietHistory;
  final DietState currentDiet;
  final List<String> filteredDateStrings;
  final Color accentColor;

  const MacrosDonutChart({
    super.key,
    required this.dietHistory,
    required this.currentDiet,
    required this.filteredDateStrings,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (filteredDateStrings.isEmpty) return const SizedBox.shrink();

    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    int count = 0;

    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    for (var dateStr in filteredDateStrings) {
      if (dateStr == todayStr) {
        double p = 0;
        double c = 0;
        double f = 0;
        for (var meal in currentDiet.meals) {
          p += meal.protein;
          c += meal.carbs;
          f += meal.fat;
        }
        totalProtein += p;
        totalCarbs += c;
        totalFat += f;
        count++;
      } else if (dietHistory.containsKey(dateStr)) {
        final day = dietHistory[dateStr]!;
        totalProtein += day.proteinIntake;
        totalCarbs += day.carbsIntake;
        totalFat += day.fatIntake;
        count++;
      }
    }

    if (count == 0 || (totalProtein == 0 && totalCarbs == 0 && totalFat == 0)) {
      return const GlassCard(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text("Sem dados de macros.", style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    double avgProtein = totalProtein / count;
    double avgCarbs = totalCarbs / count;
    double avgFat = totalFat / count;
    double totalAvg = avgProtein + avgCarbs + avgFat;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Distribuição de Macros (Média)",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: [
                            PieChartSectionData(
                              color: Colors.redAccent,
                              value: avgProtein,
                              title: "${((avgProtein/totalAvg)*100).toStringAsFixed(0)}%",
                              radius: 20,
                              titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            PieChartSectionData(
                              color: Colors.blueAccent,
                              value: avgCarbs,
                              title: "${((avgCarbs/totalAvg)*100).toStringAsFixed(0)}%",
                              radius: 20,
                              titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            PieChartSectionData(
                              color: Colors.orangeAccent,
                              value: avgFat,
                              title: "${((avgFat/totalAvg)*100).toStringAsFixed(0)}%",
                              radius: 20,
                              titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Kcal", style: TextStyle(color: Colors.white54, fontSize: 10)),
                          Text(
                            ((avgProtein * 4) + (avgCarbs * 4) + (avgFat * 9)).toStringAsFixed(0),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegend("Proteínas", Colors.redAccent, "${avgProtein.toStringAsFixed(0)}g"),
                      const SizedBox(height: 12),
                      _buildLegend("Carbos", Colors.blueAccent, "${avgCarbs.toStringAsFixed(0)}g"),
                      const SizedBox(height: 12),
                      _buildLegend("Gorduras", Colors.orangeAccent, "${avgFat.toStringAsFixed(0)}g"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String title, Color color, String value) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
