import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/routine.dart';

class RoutineSharingUtils {
  static const String prefix = 'GYM-TRACKER-';

  /// Encodes a Routine into a base64 string with a custom prefix
  static String encodeRoutine(Routine routine) {
    try {
      final jsonString = jsonEncode(routine.toJson());
      final bytes = utf8.encode(jsonString);
      final base64String = base64Encode(bytes);
      return '$prefix$base64String';
    } catch (e) {
      debugPrint('[RoutineSharingUtils] Error encoding routine: $e');
      return '';
    }
  }

  /// Decodes a string back into a Routine. Returns null if invalid.
  static Routine? decodeRoutine(String sharedString) {
    try {
      if (!sharedString.startsWith(prefix)) return null;
      
      final base64String = sharedString.substring(prefix.length);
      final bytes = base64Decode(base64String);
      final jsonString = utf8.decode(bytes);
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      
      // Ensure we generate a new ID so we don't conflict with existing ones
      jsonMap['id'] = 'routine-${DateTime.now().millisecondsSinceEpoch}';
      
      return Routine.fromJson(jsonMap);
    } catch (e) {
      debugPrint('[RoutineSharingUtils] Error decoding routine: $e');
      return null;
    }
  }
}
