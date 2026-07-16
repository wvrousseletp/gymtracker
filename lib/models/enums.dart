enum SleepQuality {
  bad,  // 'ruim'
  okay, // 'ok'
  good, // 'bom'
}

enum MeasurementType {
  reps, // 'reps' - weight & reps (musculação tradicional)
  time, // 'time' - duration based (prancha, isometria)
  cardio, // 'cardio' - distance & duration (corrida, ciclismo)
  distance, // 'distance' - distance only (remo, natação)
}

SleepQuality sleepQualityFromString(String val) {
  switch (val.toLowerCase()) {
    case 'ruim':
      return SleepQuality.bad;
    case 'bom':
      return SleepQuality.good;
    case 'ok':
    default:
      return SleepQuality.okay;
  }
}

String sleepQualityToString(SleepQuality q) {
  switch (q) {
    case SleepQuality.bad:
      return 'ruim';
    case SleepQuality.good:
      return 'bom';
    case SleepQuality.okay:
      return 'ok';
  }
}

MeasurementType measurementTypeFromString(String val) {
  switch (val.toLowerCase()) {
    case 'time':
      return MeasurementType.time;
    case 'cardio':
      return MeasurementType.cardio;
    case 'distance':
      return MeasurementType.distance;
    case 'reps':
    default:
      return MeasurementType.reps;
  }
}

String measurementTypeToString(MeasurementType t) {
  switch (t) {
    case MeasurementType.time:
      return 'time';
    case MeasurementType.cardio:
      return 'cardio';
    case MeasurementType.distance:
      return 'distance';
    case MeasurementType.reps:
      return 'reps';
  }
}
