import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker_flutter/utils/date_utils.dart';

void main() {
  group('parseUtcDate', () {
    test('returns now for empty string', () {
      final before = DateTime.now();
      final result = parseUtcDate('');
      final after = DateTime.now();
      expect(result.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(result.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('parses UTC ISO string', () {
      final result = parseUtcDate('2024-06-15T12:00:00.000Z');
      expect(result.year, 2024);
      expect(result.month, 6);
      expect(result.day, 15);
    });

    test('parses local date-only string as UTC midnight', () {
      final result = parseUtcDate('2024-06-15');
      expect(result.year, 2024);
      expect(result.month, 6);
      expect(result.day, 15);
    });

    test('returns now for invalid string', () {
      final before = DateTime.now();
      final result = parseUtcDate('not-a-date');
      expect(result.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
    });
  });
}
