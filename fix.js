const fs = require('fs');
let content = fs.readFileSync('lib/widgets/analytics/human_body_heatmap.dart', 'utf8');

const regex = /Color _getColorForMuscle.*?return Color\.lerp[^;]+;/s;

const newFunc = `Color _getColorForMuscle(String slug) {
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
  }`;

content = content.replace(regex, newFunc);
fs.writeFileSync('lib/widgets/analytics/human_body_heatmap.dart', content);
