import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker_flutter/models/enums.dart';

void main() {
  group('Enums Unit Tests', () {
    test('SleepQuality serialization and deserialization', () {
      expect(sleepQualityToString(SleepQuality.good), 'bom');
      expect(sleepQualityToString(SleepQuality.okay), 'ok');
      expect(sleepQualityToString(SleepQuality.bad), 'ruim');

      expect(sleepQualityFromString('bom'), SleepQuality.good);
      expect(sleepQualityFromString('ok'), SleepQuality.okay);
      expect(sleepQualityFromString('ruim'), SleepQuality.bad);
      expect(sleepQualityFromString('unknown_string'), SleepQuality.okay); // Default value
    });

    test('MeasurementType serialization and deserialization', () {
      expect(measurementTypeToString(MeasurementType.reps), 'reps');
      expect(measurementTypeToString(MeasurementType.time), 'time');

      expect(measurementTypeFromString('reps'), MeasurementType.reps);
      expect(measurementTypeFromString('time'), MeasurementType.time);
      expect(measurementTypeFromString('unknown_type'), MeasurementType.reps); // Default value
    });
  });
}
