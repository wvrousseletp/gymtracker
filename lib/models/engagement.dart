/// Dados do relatório semanal exibido na home (domingos).
class WeeklyReportData {
  final int workoutsThisWeek;
  final int workoutsLastWeek;
  final double volumeThisWeek; // kg
  final double volumeLastWeek;
  final int durationMinutesThisWeek;
  final int durationMinutesLastWeek;
  final int streakWeeks;
  final int weeklyGoal;
  final int workoutsThisWeekGoalProgress;

  WeeklyReportData({
    required this.workoutsThisWeek,
    required this.workoutsLastWeek,
    required this.volumeThisWeek,
    required this.volumeLastWeek,
    required this.durationMinutesThisWeek,
    required this.durationMinutesLastWeek,
    required this.streakWeeks,
    required this.weeklyGoal,
    required this.workoutsThisWeekGoalProgress,
  });

  double get volumeDeltaPercent {
    if (volumeLastWeek <= 0) return volumeThisWeek > 0 ? 100 : 0;
    return ((volumeThisWeek - volumeLastWeek) / volumeLastWeek) * 100;
  }

  double get workoutsDeltaPercent {
    if (workoutsLastWeek <= 0) return workoutsThisWeek > 0 ? 100 : 0;
    return ((workoutsThisWeek - workoutsLastWeek) / workoutsLastWeek) * 100;
  }
}

/// Desafio mensal com progresso calculado a partir do histórico.
class MonthlyChallenge {
  final String id;
  final String title;
  final String icon;
  final String unit;
  final double target;
  final double current;
  final String monthKey; // 'yyyy-MM'

  MonthlyChallenge({
    required this.id,
    required this.title,
    required this.icon,
    required this.unit,
    required this.target,
    required this.current,
    required this.monthKey,
  });

  double get progress => target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
  bool get isCompleted => current >= target;

  String get currentLabel {
    if (unit == 'kg') {
      if (current >= 1000) {
        return '${(current / 1000).toStringAsFixed(1)}t';
      }
      return '${current.toStringAsFixed(0)} $unit';
    }
    return '${current.toStringAsFixed(0)} $unit';
  }

  String get targetLabel {
    if (unit == 'kg') {
      if (target >= 1000) {
        return '${(target / 1000).toStringAsFixed(0)}t';
      }
      return '${target.toStringAsFixed(0)} $unit';
    }
    return '${target.toStringAsFixed(0)} $unit';
  }
}
