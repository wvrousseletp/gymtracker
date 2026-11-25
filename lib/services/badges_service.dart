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
    AppBadge(
      id: 'two_week_streak',
      name: 'Embalou',
      description: 'Manteve treinos por 2 semanas consecutivas.',
      icon: '⚡',
      category: 'consistency',
      tier: 'bronze',
    ),
    AppBadge(
      id: 'month_of_gains',
      name: 'Mês Perfeito',
      description: 'Manteve treinos por 4 semanas consecutivas.',
      icon: '🏆',
      category: 'consistency',
      tier: 'gold',
    ),
    AppBadge(
      id: 'week_machine',
      name: 'Semana de Ferro',
      description: 'Completou 6 ou mais treinos em uma única semana.',
      icon: '🤖',
      category: 'consistency',
      tier: 'silver',
    ),
    AppBadge(
      id: 'century_tonnage',
      name: '100 Toneladas',
      description: 'Acumulou mais de 100.000 kg de volume total.',
      icon: '🗿',
      category: 'volume',
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

    final realWorkouts = history.where((l) => !l.isRestDayLog).toList();
    if (realWorkouts.isEmpty) return newlyUnlocked;

    // 1. O Primeiro Passo
    if (realWorkouts.isNotEmpty) {
      unlock('first_workout');
    }

    // 2. Clube dos 100
    if (realWorkouts.length >= 100) {
      unlock('century_club');
    }

    // Iterate through history to find specific workout achievements
    for (var log in realWorkouts) {
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

    // 6b. Sequências de semanas consecutivas
    if (streak.consecutiveWeeks >= 2) {
      unlock('two_week_streak');
    }
    if (streak.consecutiveWeeks >= 4) {
      unlock('month_of_gains');
    }

    // 6c. Semana de Ferro
    if (streak.currentWeekCount >= 6) {
      unlock('week_machine');
    }

    // 6d. 100 Toneladas (volume acumulado)
    final totalVolume =
        realWorkouts.fold<double>(0, (sum, l) => sum + l.totalWeight);
    if (totalVolume >= 100000) {
      unlock('century_tonnage');
    }

    // 7. Mestre do Cardio (soma minutos reais de cardio nos últimos 7 dias)
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    double cardioMinutesThisWeek = 0;

    bool isCardioName(String s) {
      final lower = s.toLowerCase();
      return lower.contains('cardio') ||
          lower.contains('corrida') ||
          lower.contains('esteira') ||
          lower.contains('bicicleta') ||
          lower.contains('bike') ||
          lower.contains('ciclismo') ||
          lower.contains('elíptico') ||
          lower.contains('eliptico') ||
          lower.contains('caminhada') ||
          lower.contains('natação') ||
          lower.contains('natacao') ||
          lower.contains('remo') ||
          lower.contains('escada') ||
          lower.contains('hiit') ||
          lower.contains('futebol');
    }

    for (var log in realWorkouts) {
      final dt = DateTime.tryParse(log.date);
      if (dt != null && dt.isAfter(sevenDaysAgo)) {
        if (log.exercises.isEmpty) {
          if (isCardioName(log.name) && log.duration > 0) {
            cardioMinutesThisWeek += log.duration / 60.0;
          }
          continue;
        }

        double logCardioMinutes = 0;
        for (var ex in log.exercises) {
          final libEx = library.where((e) => e.name == ex.name).firstOrNull;
          final muscle = ex.muscle.isNotEmpty ? ex.muscle : (libEx?.muscle ?? '');
          final isExCardio = muscle.toLowerCase().contains('cardio') ||
              (libEx?.isCardio ?? false) ||
              isCardioName(ex.name) ||
              (ex.performedCardios != null &&
                  ex.performedCardios!.any((c) => c != null && c.durationSeconds > 0));

          if (!isExCardio) continue;

          if (ex.performedCardios != null &&
              ex.performedCardios!.any((c) => c != null && c.durationSeconds > 0)) {
            for (final pc in ex.performedCardios!) {
              if (pc != null && pc.durationSeconds > 0) {
                logCardioMinutes += pc.durationSeconds / 60.0;
              }
            }
          } else if (ex.reps > 0) {
            // Em sessões únicas de cardio e HealthKit, ex.reps guarda a duração em minutos
            logCardioMinutes += ex.reps.toDouble();
          } else if (log.duration > 0) {
            logCardioMinutes += log.duration / 60.0;
          }
        }
        cardioMinutesThisWeek += logCardioMinutes;
      }
    }

    if (cardioMinutesThisWeek >= 60) {
      unlock('cardio_master');
    }

    return newlyUnlocked;
  }
}
