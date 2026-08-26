const fs = require('fs');
let content = fs.readFileSync('lib/models/planner_state.dart', 'utf8');

const replacement = `class SettingsState {
  final bool sound;
  final bool vibration;
  final int prepSeconds;
  final OrganizationMode organizationMode;
  final int continuousListCurrentIndex;

  SettingsState({
    required this.sound,
    required this.vibration,
    required this.prepSeconds,
    this.organizationMode = OrganizationMode.fixedDays,
    this.continuousListCurrentIndex = 0,
  });

  SettingsState copyWith({
    bool? sound,
    bool? vibration,
    int? prepSeconds,
    OrganizationMode? organizationMode,
    int? continuousListCurrentIndex,
  }) {
    return SettingsState(
      sound: sound ?? this.sound,
      vibration: vibration ?? this.vibration,
      prepSeconds: prepSeconds ?? this.prepSeconds,
      organizationMode: organizationMode ?? this.organizationMode,
      continuousListCurrentIndex: continuousListCurrentIndex ?? this.continuousListCurrentIndex,
    );
  }`;

content = content.replace(/class SettingsState \{[\s\S]*?this\.continuousListCurrentIndex = 0,\n  \}\);/, replacement);
fs.writeFileSync('lib/models/planner_state.dart', content);
