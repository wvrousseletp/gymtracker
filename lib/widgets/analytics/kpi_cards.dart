import 'package:flutter/material.dart';
import '../../models/workout_log.dart';
import '../glass_card.dart';

class KPICards extends StatelessWidget {
  final List<WorkoutLog> history;
  final Color accentColor;

  const KPICards({
    super.key,
    required this.history,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    // Calculate Streak
    int streak = _calculateStreak(history);

    // Calculate Favorite Muscle
    String favMuscle = _calculateFavoriteMuscle(history);

    // Calculate Total Time
    int totalSeconds = _calculateTotalTime(history);
    String timeStr = _formatTime(totalSeconds);

    return Row(
      children: [
        Expanded(
          child: _buildKPICard(
            "Ofensiva",
            "$streak Dias",
            Icons.local_fire_department,
            Colors.orangeAccent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKPICard(
            "Músculo",
            favMuscle,
            Icons.fitness_center,
            accentColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKPICard(
            "Tempo",
            timeStr,
            Icons.timer,
            Colors.blueAccent,
          ),
        ),
      ],
    );
  }

  int _calculateStreak(List<WorkoutLog> logs) {
    if (logs.isEmpty) return 0;
    // Sort descending
    final sorted = List<WorkoutLog>.from(logs)
      ..sort((a, b) => (DateTime.tryParse(b.date) ?? DateTime(0))
          .compareTo(DateTime.tryParse(a.date) ?? DateTime(0)));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    int streak = 0;

    // Extract unique dates sorted descending
    final uniqueDates = <DateTime>{};
    for (var log in sorted) {
      final dt = DateTime.tryParse(log.date);
      if (dt != null) {
        uniqueDates.add(DateTime(dt.year, dt.month, dt.day));
      }
    }
    
    final sortedUniqueDates = uniqueDates.toList()..sort((a, b) => b.compareTo(a));

    if (sortedUniqueDates.isEmpty) return 0;

    final firstLogDate = sortedUniqueDates.first;
    // Streak only active if first log is today or yesterday
    if (firstLogDate.isAtSameMomentAs(today) || firstLogDate.isAtSameMomentAs(yesterday)) {
      DateTime expectedDate = firstLogDate;
      for (var dt in sortedUniqueDates) {
        if (dt.isAtSameMomentAs(expectedDate)) {
          streak++;
          expectedDate = expectedDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }
    return streak;
  }

  String _calculateFavoriteMuscle(List<WorkoutLog> logs) {
    if (logs.isEmpty) return "-";
    Map<String, int> counts = {};
    for (var log in logs) {
      for (var ex in log.exercises) {
        counts[ex.muscle] = (counts[ex.muscle] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return "-";
    var sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  int _calculateTotalTime(List<WorkoutLog> logs) {
    int total = 0;
    for (var log in logs) {
      total += log.duration;
    }
    return total;
  }

  String _formatTime(int seconds) {
    if (seconds < 3600) {
      int mins = seconds ~/ 60;
      return "${mins}m";
    } else {
      double hours = seconds / 3600.0;
      return "${hours.toStringAsFixed(1)}h";
    }
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
