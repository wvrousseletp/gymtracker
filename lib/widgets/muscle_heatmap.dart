import 'package:flutter/material.dart';
import 'dart:math';

class MuscleHeatmap extends StatelessWidget {
  final Map<String, int> muscleSets; // Map from muscle name to number of sets
  
  const MuscleHeatmap({super.key, required this.muscleSets});

  @override
  Widget build(BuildContext context) {
    // We will normalize the sets to a value between 0.0 and 1.0
    // Let's say 15 sets in the last 7 days is 1.0 (max red)
    const maxSets = 15.0;

    Color getColor(String muscleGroup) {
      // Aggregate muscles into groups
      int sets = 0;
      muscleSets.forEach((key, value) {
        final k = key.toLowerCase();
        if (muscleGroup == 'chest' && (k.contains('peito') || k.contains('chest'))) sets += value;
        if (muscleGroup == 'back' && (k.contains('costas') || k.contains('back') || k.contains('lats') || k.contains('dorsal'))) sets += value;
        if (muscleGroup == 'shoulders' && (k.contains('ombro') || k.contains('shoulder') || k.contains('deltoid'))) sets += value;
        if (muscleGroup == 'biceps' && (k.contains('bíceps') || k.contains('biceps'))) sets += value;
        if (muscleGroup == 'triceps' && (k.contains('tríceps') || k.contains('triceps'))) sets += value;
        if (muscleGroup == 'abs' && (k.contains('abd') || k.contains('abs') || k.contains('core'))) sets += value;
        if (muscleGroup == 'legs' && (k.contains('perna') || k.contains('quad') || k.contains('ham') || k.contains('calf') || k.contains('panturrilha') || k.contains('glút'))) sets += value;
      });

      double intensity = min(sets / maxSets, 1.0);
      if (intensity == 0) return Colors.white10;
      
      // Interpolate from light green to deep red based on intensity
      if (intensity < 0.3) return Colors.blueAccent.withOpacity(0.5);
      if (intensity < 0.7) return Colors.orange.withOpacity(0.8);
      return Colors.redAccent;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, 260),
          painter: _HeatmapPainter(
            chestColor: getColor('chest'),
            backColor: getColor('back'),
            shouldersColor: getColor('shoulders'),
            bicepsColor: getColor('biceps'),
            tricepsColor: getColor('triceps'),
            absColor: getColor('abs'),
            legsColor: getColor('legs'),
          ),
        );
      }
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final Color chestColor;
  final Color backColor;
  final Color shouldersColor;
  final Color bicepsColor;
  final Color tricepsColor;
  final Color absColor;
  final Color legsColor;

  _HeatmapPainter({
    required this.chestColor,
    required this.backColor,
    required this.shouldersColor,
    required this.bicepsColor,
    required this.tricepsColor,
    required this.absColor,
    required this.legsColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final centerX = size.width / 2;
    const topY = 20.0;
    
    // Head (grey)
    paint.color = Colors.white24;
    canvas.drawCircle(Offset(centerX, topY + 20), 20, paint);
    
    // Neck
    canvas.drawRect(Rect.fromCenter(center: Offset(centerX, topY + 50), width: 14, height: 20), paint);

    // Shoulders
    paint.color = shouldersColor;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(centerX - 35, topY + 65), width: 25, height: 20), const Radius.circular(10)), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(centerX + 35, topY + 65), width: 25, height: 20), const Radius.circular(10)), paint);

    // Back (Lats) - slightly wider behind chest
    paint.color = backColor;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(centerX, topY + 95), width: 60, height: 45), const Radius.circular(10)), paint);

    // Chest
    paint.color = chestColor;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(centerX, topY + 85), width: 45, height: 35), const Radius.circular(8)), paint);

    // Abs
    paint.color = absColor;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(centerX, topY + 130), width: 35, height: 40), const Radius.circular(6)), paint);

    // Left Bicep
    paint.color = bicepsColor;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(centerX - 55, topY + 95), width: 18, height: 35), const Radius.circular(9)), paint);
    // Right Bicep
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(centerX + 55, topY + 95), width: 18, height: 35), const Radius.circular(9)), paint);

    // Left Tricep
    paint.color = tricepsColor;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(centerX - 55, topY + 135), width: 14, height: 30), const Radius.circular(7)), paint);
    // Right Tricep
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(centerX + 55, topY + 135), width: 14, height: 30), const Radius.circular(7)), paint);

    // Left Leg
    paint.color = legsColor;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(centerX - 18, topY + 190), width: 22, height: 60), const Radius.circular(8)), paint);
    // Right Leg
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(centerX + 18, topY + 190), width: 22, height: 60), const Radius.circular(8)), paint);
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) => true;
}