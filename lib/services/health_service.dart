import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class HealthService {
  HealthService._privateConstructor();
  static final HealthService instance = HealthService._privateConstructor();

  static const MethodChannel _channel = MethodChannel('com.vicente.losmooscles/watch');

  /// Requests read permission for steps, calories, and heart rate on iOS.
  Future<bool> requestAuthorization() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('requestHealthAuth');
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint("[HealthService] Erro ao solicitar permissão HealthKit: $e");
      return false;
    }
  }

  /// Fetches today's steps, active calories, and last heart rate from HealthKit.
  Future<Map<String, int>?> getDailyMetrics() async {
    try {
      final Map? res = await _channel.invokeMethod<Map>('getDailyHealthMetrics');
      if (res != null) {
        return Map<String, int>.from(res);
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint("[HealthService] Erro ao buscar métricas diárias do HealthKit: $e");
      return null;
    }
  }

  /// Fetches recent workouts from Apple Health / HealthKit from the past 7 days.
  Future<List<Map<String, dynamic>>> getRecentWorkouts() async {
    try {
      final List? res = await _channel.invokeMethod<List>('getRecentWorkouts');
      if (res != null) {
        return res.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      return [];
    } on PlatformException catch (e) {
      debugPrint("[HealthService] Erro ao buscar treinos recentes do HealthKit: $e");
      return [];
    }
  }
}
