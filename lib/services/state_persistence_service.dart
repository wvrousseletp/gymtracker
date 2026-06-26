import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import '../models/planner_state.dart';
import '../models/profile.dart';

/// Handles local persistence via PathProvider (File System) with lazy-loading division and legacy SharedPreferences migration.
class StatePersistenceService {
  static const _legacyStatePrefix = 'shapeup_tracker_state_';
  static const _statePrefix = 'los_mooscles_state_';
  static const _profilePrefix = 'los_mooscles_profile_';
  static const _clientUpdatedAtPrefix = 'los_mooscles_updated_at_';

  Future<File> _getFile(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  /// Loads the main PlannerState JSON (excluding history for fast startup).
  Future<String?> loadStateJson(String userId) async {
    final file = await _getFile('planner_state_$userId.json');
    if (await file.exists()) {
      return await file.readAsString();
    }

    // Fallback/Migration from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final currentKey = '$_statePrefix$userId';
    final legacyKey = '$_legacyStatePrefix$userId';

    String? rawJson = prefs.getString(currentKey) ?? prefs.getString(legacyKey);
    if (rawJson != null) {
      try {
        // Migrate to files
        final decoded = json.decode(rawJson) as Map<String, dynamic>;
        
        // Extract history and save separately
        final history = decoded['history'] ?? [];
        await saveWorkoutsHistoryJson(userId, json.encode(history));

        // Remove history from main state and save
        decoded['history'] = [];
        final cleanStateJson = json.encode(decoded);
        await file.writeAsString(cleanStateJson);

        // Delete from SharedPreferences to save space
        await prefs.remove(currentKey);
        await prefs.remove(legacyKey);

        return cleanStateJson;
      } catch (e) {
        debugPrint('[Migration] Error migrating state: $e');
        return rawJson;
      }
    }
    return null;
  }

  Future<String?> loadLegacyVicenteStateJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('shapeup_tracker_state_vicente');
  }

  /// Loads only the workout logs history JSON.
  Future<String?> loadWorkoutsHistoryJson(String userId) async {
    final file = await _getFile('workouts_history_$userId.json');
    if (await file.exists()) {
      return await file.readAsString();
    }
    return '[]';
  }

  /// Saves only the workout logs history JSON.
  Future<void> saveWorkoutsHistoryJson(String userId, String json) async {
    final file = await _getFile('workouts_history_$userId.json');
    await file.writeAsString(json);
  }

  /// Saves the PlannerState JSON (splits history automatically to maintain signature compatibility).
  Future<void> saveStateJson(String userId, String stateJson) async {
    try {
      final decoded = json.decode(stateJson) as Map<String, dynamic>;
      
      // Split history if present
      if (decoded.containsKey('history')) {
        final history = decoded['history'] ?? [];
        await saveWorkoutsHistoryJson(userId, json.encode(history));
        decoded['history'] = [];
      }

      final file = await _getFile('planner_state_$userId.json');
      await file.writeAsString(json.encode(decoded));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_clientUpdatedAtPrefix$userId',
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (e) {
      debugPrint('[StatePersistence] Error saving state: $e');
    }
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
