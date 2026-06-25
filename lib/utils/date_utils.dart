DateTime parseUtcDate(String dateStr) {
  if (dateStr.isEmpty) return DateTime.now();
  try {
    DateTime parsed = DateTime.parse(dateStr);
    if (!parsed.isUtc &&
        !dateStr.contains('Z') &&
        !dateStr.contains('+') &&
        !dateStr.contains('-')) {
      parsed = DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
        parsed.microsecond,
      );
    }
    return parsed.toLocal();
  } catch (_) {
    return DateTime.now();
  }
}
