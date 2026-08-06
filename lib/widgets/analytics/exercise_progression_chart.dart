import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/workout_log.dart';

class ExerciseProgressionChart extends StatelessWidget {
  final String exerciseName;
  final List<WorkoutLog> history;
  final Color accentColor;
  final bool showWeight; // if true, shows weight. If false, shows reps/volume

  const ExerciseProgressionChart({
    super.key,
    required this.exerciseName,
    required this.history,
    required this.accentColor,
    this.showWeight = true,
  });

  @override
  Widget build(BuildContext context) {
    // Extract data points
    final List<FlSpot> spots = [];
    final List<String> dates = [];
    final List<int> rpes = [];
    
    // Sort history by date ascending for the chart
    final sortedHistory = List<WorkoutLog>.from(history)
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a.date) ?? DateTime.now();
        final dateB = DateTime.tryParse(b.date) ?? DateTime.now();
        return dateA.compareTo(dateB);
      });

    double minVal = double.infinity;
    double maxVal = -double.infinity;

    int index = 0;
    for (var log in sortedHistory) {
      for (var ex in log.exercises) {
        if (ex.name == exerciseName && ex.completedSets > 0) {
          double val = showWeight ? ex.weight : ex.reps.toDouble();
          if (val > 0) {
            spots.add(FlSpot(index.toDouble(), val));
            rpes.add(ex.rpe);
            
            final dt = DateTime.tryParse(log.date);
            if (dt != null) {
              dates.add('${dt.day}/${dt.month}');
            } else {
              dates.add('');
            }
            
            if (val < minVal) minVal = val;
            if (val > maxVal) maxVal = val;
            
            index++;
          }
        }
      }
    }

    if (spots.isEmpty) {
      return Center(
        child: Text(
          "Sem dados suficientes para '$exerciseName'.",
          style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
        ),
      );
    }

    // Add padding to max/min for better chart visualization
    if (minVal == maxVal) {
      minVal -= 5;
      maxVal += 5;
    } else {
      double diff = maxVal - minVal;
      minVal -= diff * 0.2;
      maxVal += diff * 0.2;
    }
    
    if (minVal < 0) minVal = 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: minVal,
          maxY: maxVal,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxVal - minVal) / 4 == 0 ? 1 : (maxVal - minVal) / 4,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.white.withOpacity(0.05),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= dates.length) return const SizedBox.shrink();
                  // Show at most 5 labels to avoid clutter
                  if (spots.length > 5 && i % ((spots.length / 5).ceil()) != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      dates[i],
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (maxVal - minVal) / 4 == 0 ? 1 : (maxVal - minVal) / 4,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(0),
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                    textAlign: TextAlign.right,
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
              curveSmoothness: 0.3,
              color: accentColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: accentColor,
                    strokeWidth: 2,
                    strokeColor: Colors.black,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: accentColor.withOpacity(0.15),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.black.withOpacity(0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final i = touchedSpot.x.toInt();
                  final rpe = (i >= 0 && i < rpes.length) ? rpes[i] : 0;
                  final textStyle = TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  );
                  final rpeSuffix = rpe > 0 ? "\nRPE: $rpe/10" : "";
                  return LineTooltipItem(
                    '${touchedSpot.y.toStringAsFixed(1)} ${showWeight ? 'kg' : 'reps'}$rpeSuffix',
                    textStyle,
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
        ),
      ),
    );
  }
}
