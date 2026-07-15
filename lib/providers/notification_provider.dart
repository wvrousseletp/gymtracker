import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_preferences.dart';
import '../services/watch_service.dart';

class NotificationProvider extends ChangeNotifier {
  static const _prefsKey = 'los_mooscles_notification_prefs';
  
  NotificationPreferences _preferences = const NotificationPreferences();
  bool _isLoaded = false;

  NotificationPreferences get preferences => _preferences;
  bool get isLoaded => _isLoaded;

  NotificationProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null) {
        _preferences = NotificationPreferences.fromJson(jsonStr);
      }
      await WatchService.instance.syncNotificationPreferences(_preferences);
    } catch (e) {
      debugPrint('[NotificationProvider] Error loading prefs: $e');
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updatePreferences(NotificationPreferences newPrefs) async {
    _preferences = newPrefs;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _preferences.toJson());
      
      // Update the iOS native side with the new preferences
      await WatchService.instance.syncNotificationPreferences(_preferences);
    } catch (e) {
      debugPrint('[NotificationProvider] Error saving prefs: $e');
    }
  }

  Future<void> setHydrationAggressiveness(HydrationAggressiveness value) async {
    await updatePreferences(_preferences.copyWith(hydrationAggressiveness: value));
  }

  Future<void> setSilenceHydrationAtNight(bool value) async {
    await updatePreferences(_preferences.copyWith(silenceHydrationAtNight: value));
  }

  Future<void> setRestTimerMode(RestTimerMode value) async {
    await updatePreferences(_preferences.copyWith(restTimerMode: value));
  }

  Future<void> setMotivationRemindersEnabled(bool value) async {
    await updatePreferences(_preferences.copyWith(motivationRemindersEnabled: value));
  }
}
