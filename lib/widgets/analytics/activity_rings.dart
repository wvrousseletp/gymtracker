import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/diet.dart';
import '../../models/workout_log.dart';
import '../glass_card.dart';

class ActivityRings extends StatelessWidget {
  final DietState currentDiet;
  final List<WorkoutLog> history;
  final Color accentColor;

  const ActivityRings({
    super.key,
    required this.currentDiet,
    required this.history,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate today's values
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // Diet
    double calGoal = currentDiet.caloriesGoal.toDouble();
    double calIntake = currentDiet.meals.fold(0, (sum, m) => sum + m.calories).toDouble();
    double calPercent = calGoal > 0 ? (calIntake / calGoal).clamp(0.0, 1.0) : 0.0;

    double waterGoal = currentDiet.waterGoalMl.toDouble();
    double waterIntake = currentDiet.waterIntakeMl.toDouble();
    double waterPercent = waterGoal > 0 ? (waterIntake / waterGoal).clamp(0.0, 1.0) : 0.0;

    // Workout
    bool workedOutToday = false;
    for (var log in history) {
      if (log.date.startsWith(todayStr)) {
        workedOutToday = true;
        break;
      }
    }
    double workoutPercent = workedOutToday ? 1.0 : 0.0;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Conclusão Diária (Hoje)",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: RingsPainter(
                    workoutPercent: workoutPercent,
                    calPercent: calPercent,
                    waterPercent: waterPercent,
                    workoutColor: accentColor,
                    calColor: Colors.redAccent,
                    waterColor: Colors.blueAccent,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRingLegend("Treino", accentColor, workedOutToday ? "Concluído" : "Pendente"),
                  const SizedBox(height: 12),
                  _buildRingLegend("Calorias", Colors.redAccent, "${calIntake.toInt()} / ${calGoal.toInt()}"),
                  const SizedBox(height: 12),
                  _buildRingLegend("Água", Colors.blueAccent, "${waterIntake.toInt()} / ${waterGoal.toInt()} ml"),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRingLegend(String title, Color color, String value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
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

class RingsPainter extends CustomPainter {
  final double workoutPercent;
  final double calPercent;
  final double waterPercent;
  final Color workoutColor;
  final Color calColor;
  final Color waterColor;

  RingsPainter({
    required this.workoutPercent,
    required this.calPercent,
    required this.waterPercent,
    required this.workoutColor,
    required this.calColor,
    required this.waterColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 12.0;
    const spacing = 4.0;

    // Radius
    final r1 = (size.width / 2) - (strokeWidth / 2);
    final r2 = r1 - strokeWidth - spacing;
    final r3 = r2 - strokeWidth - spacing;

    // Background paints
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Foreground paints
    final fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw backgrounds
    bgPaint.color = workoutColor.withOpacity(0.2);
    canvas.drawCircle(center, r1, bgPaint);

    bgPaint.color = calColor.withOpacity(0.2);
    canvas.drawCircle(center, r2, bgPaint);

    bgPaint.color = waterColor.withOpacity(0.2);
    canvas.drawCircle(center, r3, bgPaint);

    // Draw foregrounds (Arcs)
    const startAngle = -pi / 2;
    
    // Workout
    fgPaint.color = workoutColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r1),
      startAngle,
      workoutPercent * 2 * pi,
      false,
      fgPaint,
    );

    // Calories
    fgPaint.color = calColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r2),
      startAngle,
      calPercent * 2 * pi,
      false,
      fgPaint,
    );

    // Water
    fgPaint.color = waterColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r3),
      startAngle,
      waterPercent * 2 * pi,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
