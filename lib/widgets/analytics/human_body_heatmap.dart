import 'package:flutter/material.dart';

class HumanBodyHeatmap extends StatelessWidget {
  final Map<String, double> muscleIntensity;
  final Color accentColor;

  const HumanBodyHeatmap({
    super.key,
    required this.muscleIntensity,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 150,
        height: 300,
        child: CustomPaint(
          painter: _HumanBodyPainter(
            muscleIntensity: muscleIntensity,
            accentColor: accentColor,
          ),
        ),
      ),
    );
  }
}

class _HumanBodyPainter extends CustomPainter {
  final Map<String, double> muscleIntensity;
  final Color accentColor;

  _HumanBodyPainter({
    required this.muscleIntensity,
    required this.accentColor,
  });

  Color _getColorForMuscle(String muscleName) {
    // Map muscles to logical groups if necessary
    double intensity = 0.0;
    for (var entry in muscleIntensity.entries) {
      if (entry.key.toLowerCase().contains(muscleName.toLowerCase())) {
        intensity = entry.value;
        break;
      }
    }
    
    if (intensity <= 0) return Colors.white12;
    // interpolate between accentColor and deep red/orange based on intensity
    return Color.lerp(Colors.white24, accentColor, intensity)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;
      
    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white24
      ..strokeWidth = 1.5;

    // Helper to draw a body part
    void drawPart(Path path, String muscleName) {
      paint.color = _getColorForMuscle(muscleName);
      canvas.drawPath(path, paint);
      canvas.drawPath(path, strokePaint);
    }

    final double w = size.width;
    final double h = size.height;

    // Head
    final headPath = Path()
      ..addOval(Rect.fromCenter(center: Offset(w/2, h*0.1), width: w*0.25, height: h*0.15));
    drawPart(headPath, "Head");

    // Torso (Peito, Abdômen, Costas)
    final chestPath = Path()
      ..moveTo(w*0.35, h*0.2)
      ..lineTo(w*0.65, h*0.2)
      ..lineTo(w*0.65, h*0.35)
      ..lineTo(w*0.35, h*0.35)
      ..close();
    drawPart(chestPath, "Peito");

    final absPath = Path()
      ..moveTo(w*0.35, h*0.35)
      ..lineTo(w*0.65, h*0.35)
      ..lineTo(w*0.6, h*0.5)
      ..lineTo(w*0.4, h*0.5)
      ..close();
    drawPart(absPath, "Abdômen");

    // Shoulders (Ombros)
    final leftShoulder = Path()
      ..addOval(Rect.fromCenter(center: Offset(w*0.3, h*0.22), width: w*0.15, height: h*0.08));
    drawPart(leftShoulder, "Ombros");
    
    final rightShoulder = Path()
      ..addOval(Rect.fromCenter(center: Offset(w*0.7, h*0.22), width: w*0.15, height: h*0.08));
    drawPart(rightShoulder, "Ombros");

    // Arms (Bíceps, Tríceps)
    final leftArm = Path()
      ..moveTo(w*0.25, h*0.26)
      ..lineTo(w*0.35, h*0.26)
      ..lineTo(w*0.3, h*0.45)
      ..lineTo(w*0.2, h*0.45)
      ..close();
    drawPart(leftArm, "Bíceps");

    final rightArm = Path()
      ..moveTo(w*0.65, h*0.26)
      ..lineTo(w*0.75, h*0.26)
      ..lineTo(w*0.8, h*0.45)
      ..lineTo(w*0.7, h*0.45)
      ..close();
    drawPart(rightArm, "Bíceps");

    // Legs (Pernas)
    final leftLeg = Path()
      ..moveTo(w*0.4, h*0.5)
      ..lineTo(w*0.5, h*0.5)
      ..lineTo(w*0.45, h*0.8)
      ..lineTo(w*0.35, h*0.8)
      ..close();
    drawPart(leftLeg, "Pernas");

    final rightLeg = Path()
      ..moveTo(w*0.5, h*0.5)
      ..lineTo(w*0.6, h*0.5)
      ..lineTo(w*0.65, h*0.8)
      ..lineTo(w*0.55, h*0.8)
      ..close();
    drawPart(rightLeg, "Pernas");
  }

  @override
  bool shouldRepaint(covariant _HumanBodyPainter oldDelegate) {
    return oldDelegate.muscleIntensity != muscleIntensity ||
           oldDelegate.accentColor != accentColor;
  }
}
