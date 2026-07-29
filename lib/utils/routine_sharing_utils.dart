import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/routine.dart';
import '../models/exercise.dart';

class SharedRoutineData {
  final Routine routine;
  final List<LibraryExercise> exerciseDefinitions;

  SharedRoutineData({
    required this.routine,
    required this.exerciseDefinitions,
  });
}

class RoutineSharingUtils {
  static const String prefix = 'GYM-TRACKER-';

  /// Encodes a Routine AND its exercise definitions from the library into a base64 string
  static String encodeRoutine(Routine routine, List<LibraryExercise> library) {
    try {
      final definitions = <Map<String, dynamic>>[];
      for (final re in routine.exercises) {
        final libEx = library.where((l) => l.id == re.exerciseId).firstOrNull;
        if (libEx != null) {
          definitions.add(libEx.toJson());
        }
      }

      final payload = {
        'routine': routine.toJson(),
        'exerciseDefinitions': definitions,
      };

      final jsonString = jsonEncode(payload);
      final bytes = utf8.encode(jsonString);
      final base64String = base64Encode(bytes);
      return '$prefix$base64String';
    } catch (e) {
      debugPrint('[RoutineSharingUtils] Error encoding routine: $e');
      return '';
    }
  }

  /// Decodes a string back into a SharedRoutineData object. Supports legacy formats too.
  static SharedRoutineData? decodeRoutine(String sharedString) {
    try {
      if (!sharedString.startsWith(prefix)) return null;
      
      final base64String = sharedString.substring(prefix.length);
      final bytes = base64Decode(base64String);
      final jsonString = utf8.decode(bytes);
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      
      Map<String, dynamic> routineJson;
      List<LibraryExercise> definitions = [];

      if (jsonMap.containsKey('routine')) {
        routineJson = Map<String, dynamic>.from(jsonMap['routine']);
        if (jsonMap['exerciseDefinitions'] != null) {
          definitions = (jsonMap['exerciseDefinitions'] as List)
              .map((e) => LibraryExercise.fromJson(e))
              .toList();
        }
      } else {
        // Legacy format (just the routine JSON)
        routineJson = jsonMap;
      }
      
      // Ensure a unique ID
      routineJson['id'] = 'routine-${DateTime.now().millisecondsSinceEpoch}';
      
      final routine = Routine.fromJson(routineJson);
      return SharedRoutineData(
        routine: routine,
        exerciseDefinitions: definitions,
      );
    } catch (e) {
      debugPrint('[RoutineSharingUtils] Error decoding routine: $e');
      return null;
    }
  }
}
