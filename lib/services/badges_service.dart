import 'package:flutter/foundation.dart';
import '../models/badge.dart';
import '../models/planner_state.dart';
import '../models/workout_log.dart';
import '../models/exercise.dart';

class BadgesService {
  static const List<AppBadge> allBadges = [
    AppBadge(
      id: 'first_workout',
      name: 'O Primeiro Passo',
      description: 'Você registrou o seu primeiro treino. Parabéns!',
      icon: '🎉',
      category: 'milestone',
      tier: 'bronze',
    ),
    AppBadge(
      id: 'perfect_week',
      name: 'Semana Perfeita',
      description: 'Treinou pelo menos 3 vezes em uma única semana.',
      icon: '🔥',
      category: 'consistency',
      tier: 'silver',
    ),
    AppBadge(
      id: 'hercules',
      name: 'Hércules',
      description: 'Levantou mais de 10.000 kg em volume total em um único treino.',
      icon: '💪',
      category: 'volume',
      tier: 'gold',
    ),
    AppBadge(
      id: 'early_bird',
      name: 'Madrugador',
      description: 'Finalizou um treino antes das 6:00 da manhã.',
      icon: '🌅',
      category: 'special',
      tier: 'bronze',
    ),
    AppBadge(
      id: 'marathon',
      name: 'Maratona',
      description: 'Um treino durou mais de 2 horas (120 min).',
      icon: '⏱️',
      category: 'milestone',
      tier: 'silver',
    ),
    AppBadge(
      id: 'cardio_master',
      name: 'Mestre do Cardio',
      description: 'Completou mais de 60 minutos de cardio na mesma semana.',
      icon: '🏃',
      category: 'consistency',
      tier: 'silver',
    ),
    AppBadge(
      id: 'century_club',
      name: 'Clube dos 100',
      description: 'Completou 100 treinos registrados no app.',
      icon: '💯',
      category: 'milestone',
      tier: 'platinum',
    ),
  ];

  static List<AppBadge> getUnlockedBadges(List<String> unlockedIds) {
    return allBadges.where((b) => unlockedIds.contains(b.id)).toList();
  }

  static List<AppBadge> getLockedBadges(List<String> unlockedIds) {
    return allBadges.where((b) => !unlockedIds.contains(b.id)).toList();
  }

  /// Evaluates conditions and returns a list of newly unlocked badge IDs.
  static List<String> evaluateNewBadges({
    required List<WorkoutLog> history,
    required List<String> currentUnlocked,
    required WorkoutStreak streak,
    required List<LibraryExercise> library,
  }) {
    List<String> newlyUnlocked = [];

    void unlock(String badgeId) {
      if (!currentUnlocked.contains(badgeId) && !newlyUnlocked.contains(badgeId)) {
        newlyUnlocked.add(badgeId);
        debugPrint('[BadgesService] Nova conquista desbloqueada: $badgeId');
      }
    }

    if (history.isEmpty) return newlyUnlocked;

    // 1. O Primeiro Passo
    if (history.isNotEmpty) {
      unlock('first_workout');
    }

    // 2. Clube dos 100
    if (history.length >= 100) {
      unlock('century_club');
    }

    // Iterate through history to find specific workout achievements
    for (var log in history) {
      // 3. Hércules
      if (log.totalWeight >= 10000) {
        unlock('hercules');
      }

      // 4. Maratona
      if (log.duration >= 7200) { // 7200 seconds = 120 minutes
        unlock('marathon');
      }

      // 5. Madrugador
      final dt = DateTime.tryParse(log.date);
      if (dt != null) {
        final localDt = dt.toLocal();
        if (localDt.hour < 6) {
          unlock('early_bird');
        }
      }
    }

    // 6. Semana Perfeita (from streak)
    if (streak.consecutiveWeeks > 0 && streak.currentWeekCount >= 3) {
      unlock('perfect_week');
    }

    // 7. Mestre do Cardio (from current week)
    // We calculate cardio minutes in the last 7 days
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    double cardioMinutesThisWeek = 0;

    for (var log in history) {
      final dt = DateTime.tryParse(log.date);
      if (dt != null && dt.isAfter(sevenDaysAgo)) {
        for (var ex in log.exercises) {
          final libEx = library.where((e) => e.name == ex.name).firstOrNull;
          final muscle = libEx?.muscle ?? '';
          if (muscle.toLowerCase().contains('cardio')) {
            cardioMinutesThisWeek += ex.completedSets.toDouble();
          }
        }
      }
    }

    if (cardioMinutesThisWeek >= 60) {
      unlock('cardio_master');
    }

    return newlyUnlocked;
  }
}
