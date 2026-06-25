import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/planner_state.dart';
import '../models/profile.dart';
import 'state_persistence_service.dart';

typedef RemoteStateHandler = Future<void> Function(
  PlannerState state,
  Profile? profile,
);

/// Debounced Firebase sync with timestamp-based conflict resolution.
class FirebaseSyncService {
  FirebaseSyncService({
    FirebaseFirestore? firestore,
    StatePersistenceService? persistence,
    Duration debounceDuration = const Duration(seconds: 15),
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _persistence = persistence ?? StatePersistenceService(),
        _debounceDuration = debounceDuration;

  final FirebaseFirestore _firestore;
  final StatePersistenceService _persistence;
  final Duration _debounceDuration;

  Timer? _debounceTimer;
  String? _pendingUserId;
  PlannerState? _pendingState;
  Profile? _pendingProfile;

  void scheduleSync({
    required String userId,
    required PlannerState state,
    required Profile profile,
  }) {
    _pendingUserId = userId;
    _pendingState = state;
    _pendingProfile = profile;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      final uid = _pendingUserId;
      final pendingState = _pendingState;
      final pendingProfile = _pendingProfile;
      if (uid == null || pendingState == null || pendingProfile == null) return;
      unawaited(_syncNow(
        userId: uid,
        localState: pendingState,
        profile: pendingProfile,
        forceDownload: false,
      ));
    });
  }

  Future<void> flushSync({
    required String userId,
    required PlannerState state,
    required Profile profile,
  }) async {
    _debounceTimer?.cancel();
    _pendingUserId = userId;
    _pendingState = state;
    _pendingProfile = profile;
    await _syncNow(
      userId: userId,
      localState: state,
      profile: profile,
      forceDownload: false,
    );
  }

  Future<PlannerState?> sync({
    required String userId,
    required PlannerState localState,
    required Profile profile,
    required bool forceDownload,
    RemoteStateHandler? onRemoteApplied,
  }) async {
    return _syncNow(
      userId: userId,
      localState: localState,
      profile: profile,
      forceDownload: forceDownload,
      onRemoteApplied: onRemoteApplied,
    );
  }

  /// @deprecated Use [sync] instead.
  Future<PlannerState?> syncOnLoad({
    required String userId,
    required PlannerState localState,
    required Profile profile,
    required RemoteStateHandler onRemoteApplied,
  }) {
    return sync(
      userId: userId,
      localState: localState,
      profile: profile,
      forceDownload: true,
      onRemoteApplied: onRemoteApplied,
    );
  }

  Future<Map<String, dynamic>?> fetchCloudProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null || data['profile'] == null) return null;
      return Map<String, dynamic>.from(data['profile']);
    } catch (e) {
      debugPrint('[FirebaseSync] fetchCloudProfile error: $e');
      return null;
    }
  }

  Future<PlannerState?> _syncNow({
    required String userId,
    required PlannerState localState,
    required Profile profile,
    required bool forceDownload,
    RemoteStateHandler? onRemoteApplied,
  }) async {
    try {
      final docRef = _firestore.collection('users').doc(userId);
      final docSnap = await docRef.get();
      final localUpdatedAt =
          await _persistence.loadClientUpdatedAt(userId) ?? DateTime.fromMillisecondsSinceEpoch(0);

      if (!docSnap.exists) {
        await _upload(docRef, localState, profile, localUpdatedAt);
        return localState;
      }

      final data = docSnap.data();
      if (data == null || data['jsonState'] == null) {
        await _upload(docRef, localState, profile, localUpdatedAt);
        return localState;
      }

      final remoteState =
          PlannerState.fromJson(json.decode(data['jsonState'] as String));
      final remoteUpdatedAt = _readRemoteUpdatedAt(data);

      if (forceDownload) {
        await onRemoteApplied?.call(remoteState, _readRemoteProfile(data));
        return remoteState;
      }

      if (_shouldUpload(localState, remoteState, localUpdatedAt, remoteUpdatedAt)) {
        await _upload(docRef, localState, profile, localUpdatedAt);
        return localState;
      }

      await onRemoteApplied?.call(remoteState, _readRemoteProfile(data));
      return remoteState;
    } catch (e) {
      debugPrint('[FirebaseSync] sync error: $e');
      return localState;
    }
  }

  Future<void> updateCloudProfile(String userId, Profile profile) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'profile': profile.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[FirebaseSync] updateCloudProfile error: $e');
    }
  }

  Future<void> _upload(
    DocumentReference<Map<String, dynamic>> docRef,
    PlannerState state,
    Profile profile,
    DateTime clientUpdatedAt,
  ) async {
    await docRef.set({
      'jsonState': json.encode(state.toJson()),
      'profile': profile.toJson(),
      'clientUpdatedAt': clientUpdatedAt.toUtc().toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Profile? _readRemoteProfile(Map<String, dynamic> data) {
    if (data['profile'] == null) return null;
    return Profile.fromJson(Map<String, dynamic>.from(data['profile']));
  }

  DateTime _readRemoteUpdatedAt(Map<String, dynamic> data) {
    final clientRaw = data['clientUpdatedAt'];
    if (clientRaw is String && clientRaw.isNotEmpty) {
      try {
        return DateTime.parse(clientRaw).toUtc();
      } catch (_) {}
    }

    final serverRaw = data['updatedAt'];
    if (serverRaw is Timestamp) {
      return serverRaw.toDate().toUtc();
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _shouldUpload(
    PlannerState local,
    PlannerState remote,
    DateTime localUpdatedAt,
    DateTime remoteUpdatedAt,
  ) {
    return shouldUploadState(
      localUpdatedAt: localUpdatedAt,
      remoteUpdatedAt: remoteUpdatedAt,
      localHistoryLength: local.history.length,
      remoteHistoryLength: remote.history.length,
    );
  }

  void dispose() {
    _debounceTimer?.cancel();
  }
}

/// Resolves whether local state should overwrite remote state during sync.
bool shouldUploadState({
  required DateTime localUpdatedAt,
  required DateTime remoteUpdatedAt,
  required int localHistoryLength,
  required int remoteHistoryLength,
}) {
  if (localUpdatedAt.isAfter(remoteUpdatedAt)) return true;
  if (remoteUpdatedAt.isAfter(localUpdatedAt)) return false;
  return localHistoryLength >= remoteHistoryLength;
}
