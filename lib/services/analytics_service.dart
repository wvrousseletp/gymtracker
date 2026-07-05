import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static FirebaseAnalyticsObserver get observer => FirebaseAnalyticsObserver(analytics: _analytics);

  static Future<void> logLogin(String userId) async {
    try {
      await _analytics.setUserId(id: userId);
      await _analytics.logLogin();
    } catch (e) {
      debugPrint('[Analytics] Error logging login: $e');
    }
  }

  static Future<void> logWorkoutCompleted(String workoutName, int durationSec, int sets) async {
    try {
      await _analytics.logEvent(
        name: 'workout_completed',
        parameters: {
          'workout_name': workoutName,
          'duration_seconds': durationSec,
          'completed_sets': sets,
        },
      );
    } catch (e) {
      debugPrint('[Analytics] Error logging workout completion: $e');
    }
  }

  static Future<void> logMealLogged(String mealType, int calories) async {
    try {
      await _analytics.logEvent(
        name: 'meal_logged',
        parameters: {
          'meal_type': mealType,
          'calories': calories,
        },
      );
    } catch (e) {
      debugPrint('[Analytics] Error logging meal: $e');
    }
  }
}
