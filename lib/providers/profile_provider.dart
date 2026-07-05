import 'dart:async';
import 'package:flutter/material.dart';
import '../models/profile.dart';
import '../services/state_persistence_service.dart';
import '../services/firebase_sync_service.dart';

class ProfileProvider extends ChangeNotifier {
  final StatePersistenceService _persistence = StatePersistenceService();
  final FirebaseSyncService _firebaseSync = FirebaseSyncService();

  List<Profile> _profiles = [];
  String _currentUserId = '';
  bool _isLoading = true;

  List<Profile> get profiles => _profiles;
  String get currentUserId => _currentUserId;
  bool get isLoading => _isLoading;

  Profile get currentProfile => _profiles.firstWhere(
        (p) => p.id == _currentUserId,
        orElse: () => Profile(
          id: _currentUserId,
          name: 'Usuário',
          avatar: '🏋️',
          colorAccent: 'Branco',
        ),
      );

  Future<void> saveProfilesConfig() async {
    if (_profiles.isEmpty || _currentUserId.isEmpty) return;
    final profile = _profiles.firstWhere((p) => p.id == _currentUserId);
    await _persistence.saveProfileJson(
      _currentUserId,
      _persistence.encodeProfile(profile),
    );
  }

  void setProfiles(List<Profile> val) {
    _profiles = val;
    notifyListeners();
  }

  void setCurrentUserId(String val) {
    _currentUserId = val;
    notifyListeners();
  }

  void setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  Future<void> updateProfile(String id, String name, String avatar, String color) async {
    final idx = _profiles.indexWhere((p) => p.id == id);
    if (idx == -1) return;

    _profiles[idx] = Profile(
      id: id,
      name: name,
      avatar: avatar,
      colorAccent: color,
    );
    await saveProfilesConfig();
    unawaited(_firebaseSync.updateCloudProfile(id, _profiles[idx]));
    notifyListeners();
  }
}
