import 'dart:convert';

enum HydrationAggressiveness {
  aggressive, // 1h
  standard, // 2h
  relaxed, // 4h
  disabled, // None
}

enum RestTimerMode {
  all, // Standard notification banner for every set
  liveActivityOnly, // No banner, just keep live activity updated
}

class NotificationPreferences {
  final HydrationAggressiveness hydrationAggressiveness;
  final bool silenceHydrationAtNight;
  final RestTimerMode restTimerMode;
  final bool motivationRemindersEnabled;
  final String silentNightStartHour; // Format: "22" for 10 PM
  final String silentNightEndHour; // Format: "08" for 8 AM

  const NotificationPreferences({
    this.hydrationAggressiveness = HydrationAggressiveness.standard,
    this.silenceHydrationAtNight = true,
    this.restTimerMode = RestTimerMode.all,
    this.motivationRemindersEnabled = true,
    this.silentNightStartHour = "22",
    this.silentNightEndHour = "08",
  });

  NotificationPreferences copyWith({
    HydrationAggressiveness? hydrationAggressiveness,
    bool? silenceHydrationAtNight,
    RestTimerMode? restTimerMode,
    bool? motivationRemindersEnabled,
    String? silentNightStartHour,
    String? silentNightEndHour,
  }) {
    return NotificationPreferences(
      hydrationAggressiveness: hydrationAggressiveness ?? this.hydrationAggressiveness,
      silenceHydrationAtNight: silenceHydrationAtNight ?? this.silenceHydrationAtNight,
      restTimerMode: restTimerMode ?? this.restTimerMode,
      motivationRemindersEnabled: motivationRemindersEnabled ?? this.motivationRemindersEnabled,
      silentNightStartHour: silentNightStartHour ?? this.silentNightStartHour,
      silentNightEndHour: silentNightEndHour ?? this.silentNightEndHour,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hydrationAggressiveness': hydrationAggressiveness.name,
      'silenceHydrationAtNight': silenceHydrationAtNight,
      'restTimerMode': restTimerMode.name,
      'motivationRemindersEnabled': motivationRemindersEnabled,
      'silentNightStartHour': silentNightStartHour,
      'silentNightEndHour': silentNightEndHour,
    };
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      hydrationAggressiveness: HydrationAggressiveness.values.firstWhere(
        (e) => e.name == map['hydrationAggressiveness'],
        orElse: () => HydrationAggressiveness.standard,
      ),
      silenceHydrationAtNight: map['silenceHydrationAtNight'] ?? true,
      restTimerMode: RestTimerMode.values.firstWhere(
        (e) => e.name == map['restTimerMode'],
        orElse: () => RestTimerMode.all,
      ),
      motivationRemindersEnabled: map['motivationRemindersEnabled'] ?? true,
      silentNightStartHour: map['silentNightStartHour'] ?? "22",
      silentNightEndHour: map['silentNightEndHour'] ?? "08",
    );
  }

  String toJson() => json.encode(toMap());

  factory NotificationPreferences.fromJson(String source) => NotificationPreferences.fromMap(json.decode(source));
}
