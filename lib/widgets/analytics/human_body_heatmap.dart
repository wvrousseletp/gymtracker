import 'package:flutter/material.dart';
import 'anatomy_paths.dart';

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
        height: 250,
        width: 180,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // FRONT
            Expanded(
              child: AspectRatio(
                aspectRatio: 660.1 / 1146.4,
                child: CustomPaint(
                  painter: _BodyPainter(
                    muscleIntensity: muscleIntensity,
                    accentColor: accentColor,
                    paths: AnatomyPaths.front,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // BACK
            Expanded(
              child: AspectRatio(
                aspectRatio: 660.1 / 1146.4,
                child: CustomPaint(
                  painter: _BodyPainter(
                    muscleIntensity: muscleIntensity,
                    accentColor: accentColor,
                    paths: AnatomyPaths.back,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  final Map<String, double> muscleIntensity;
  final Color accentColor;
  final List<MusclePathData> paths;

  _BodyPainter({
    required this.muscleIntensity,
    required this.accentColor,
    required this.paths,
  });

  Color _getColorForMuscle(String slug) {
    double intensity = 0.0;
    for (var entry in muscleIntensity.entries) {
      final appMuscle = entry.key.toLowerCase();
      if (slug == 'chest' && appMuscle.contains('peito')) { intensity += entry.value; }
      else if (slug == 'abs' && appMuscle.contains('abdômen')) { intensity += entry.value; }
      else if (slug == 'biceps' && appMuscle.contains('bícep')) { intensity += entry.value; }
      else if (slug == 'triceps' && appMuscle.contains('trícep')) { intensity += entry.value; }
      else if (slug == 'forearm' && appMuscle.contains('ante')) { intensity += entry.value; }
      else if (slug == 'front-deltoids' && appMuscle.contains('ombro')) { intensity += entry.value; }
      else if (slug == 'back-deltoids' && appMuscle.contains('ombro')) { intensity += entry.value; }
      else if (slug == 'trapezius' && appMuscle.contains('trapézio')) { intensity += entry.value; }
      else if (slug == 'lats' && appMuscle.contains('costa')) { intensity += entry.value; }
      else if (slug == 'lower-back' && appMuscle.contains('lombar')) { intensity += entry.value; }
      else if (slug == 'quadriceps' && appMuscle.contains('quadrí')) { intensity += entry.value; }
      else if (slug == 'hamstring' && appMuscle.contains('post')) { intensity += entry.value; }
      else if (slug == 'calves' && appMuscle.contains('panturrilha')) { intensity += entry.value; }
      else if (slug == 'gluteal' && appMuscle.contains('glút')) { intensity += entry.value; }
      else if (slug == 'obliques' && appMuscle.contains('oblíq')) { intensity += entry.value; }
    }
    
    if (intensity <= 0) return const Color(0xff2c2c2e); // dark grey base
    return Color.lerp(const Color(0xff2c2c2e), accentColor, intensity.clamp(0.0, 1.0))!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / 660.1;
    final double scaleY = size.height / 1146.4;
    
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final Paint fillPaint = Paint()..style = PaintingStyle.fill;
    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xff121212)
      ..strokeWidth = 2.0;

    for (var muscle in paths) {
      fillPaint.color = _getColorForMuscle(muscle.slug);
      for (var path in muscle.paths) {
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
      }
    }
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BodyPainter oldDelegate) {
    return true;
  }
}
