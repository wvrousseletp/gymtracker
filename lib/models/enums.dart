enum SleepQuality {
  bad,  // 'ruim'
  okay, // 'ok'
  good, // 'bom'
}

enum MeasurementType {
  reps, // 'reps'
  time, // 'time'
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
  if (val.toLowerCase() == 'time') {
    return MeasurementType.time;
  }
  return MeasurementType.reps;
}

String measurementTypeToString(MeasurementType t) {
  switch (t) {
    case MeasurementType.time:
      return 'time';
    case MeasurementType.reps:
      return 'reps';
  }
}
