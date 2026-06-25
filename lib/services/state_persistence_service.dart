import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/planner_state.dart';
import '../models/profile.dart';

/// Handles local persistence via SharedPreferences with legacy key migration.
class StatePersistenceService {
  static const _legacyStatePrefix = 'shapeup_tracker_state_';
  static const _statePrefix = 'los_mooscles_state_';
  static const _profilePrefix = 'los_mooscles_profile_';
  static const _legacyVicenteStateKey = 'shapeup_tracker_state_vicente';
  static const _clientUpdatedAtPrefix = 'los_mooscles_updated_at_';

  Future<String?> loadStateJson(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentKey = '$_statePrefix$userId';
    final legacyKey = '$_legacyStatePrefix$userId';

    final current = prefs.getString(currentKey);
    if (current != null) return current;

    final legacy = prefs.getString(legacyKey);
    if (legacy != null) {
      await prefs.setString(currentKey, legacy);
      return legacy;
    }
    return null;
  }

  Future<String?> loadLegacyVicenteStateJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_legacyVicenteStateKey);
  }

  Future<void> saveStateJson(String userId, String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_statePrefix$userId', json);
    await prefs.setString(
      '$_clientUpdatedAtPrefix$userId',
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<DateTime?> loadClientUpdatedAt(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_clientUpdatedAtPrefix$userId');
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).toUtc();
    } catch (_) {
      return null;
    }
  }

  Future<String?> loadProfileJson(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_profilePrefix$userId');
  }

  Future<void> saveProfileJson(String userId, String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_profilePrefix$userId', json);
  }

  PlannerState decodeState(String raw) {
    return PlannerState.fromJson(json.decode(raw));
  }

  String encodeState(PlannerState state) {
    return json.encode(state.toJson());
  }

  Profile decodeProfile(String raw) {
    return Profile.fromJson(json.decode(raw));
  }

  String encodeProfile(Profile profile) {
    return json.encode(profile.toJson());
  }
}
