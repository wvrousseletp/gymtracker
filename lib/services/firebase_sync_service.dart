import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/planner_state.dart';
import '../models/profile.dart';
import '../models/workout_log.dart';
import '../models/routine.dart';
import '../models/exercise.dart';
import 'state_persistence_service.dart';
import 'sync_queue_service.dart';

typedef RemoteStateHandler = Future<void> Function(
  PlannerState state,
  Profile? profile,
);

/// Debounced Firebase sync with timestamp-based conflict resolution and incremental subcollections sync.
class FirebaseSyncService {
  FirebaseSyncService({
    FirebaseFirestore? firestore,
    StatePersistenceService? persistence,
    SyncQueueService? syncQueue,
    Duration debounceDuration = const Duration(seconds: 15),
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _persistence = persistence ?? StatePersistenceService(),
        _syncQueue = syncQueue ?? SyncQueueService(),
        _debounceDuration = debounceDuration {
    // Enable offline persistence explicitly
    try {
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (_) {
      // settings can only be set once, ignore if already set
    }
  }

  final FirebaseFirestore _firestore;
  final StatePersistenceService _persistence;
  final SyncQueueService _syncQueue;
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

  // --- INCREMENTAL FIREBASE WORKOUTS AND ROUTINES ---

  Future<void> syncWorkoutLog(String userId, WorkoutLog log) async {
    if (userId.isEmpty || userId.length > 128 || log.id.isEmpty || log.id.length > 128) {
      debugPrint('[FirebaseSync] syncWorkoutLog rejected: invalid IDs');
      return;
    }
    final sanitizedLog = _sanitizeWorkoutLog(log);
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('workouts')
          .doc(sanitizedLog.id)
          .set({
        ...sanitizedLog.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Sucesso: tenta drenar fila pendente em background
      unawaited(drainQueue(userId));
    } catch (e) {
      debugPrint('[FirebaseSync] syncWorkoutLog error (offline?): $e');
      await _syncQueue.enqueue(SyncOp(
        type: SyncOpType.syncWorkoutLog,
        userId: userId,
        payload: sanitizedLog.toJson(),
        enqueuedAt: DateTime.now().toUtc(),
      ));
    }
  }

  Future<void> deleteWorkoutLog(String userId, String logId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('workouts')
          .doc(logId)
          .delete();
      unawaited(drainQueue(userId));
    } catch (e) {
      debugPrint('[FirebaseSync] deleteWorkoutLog error (offline?): $e');
      await _syncQueue.enqueue(SyncOp(
        type: SyncOpType.deleteWorkoutLog,
        userId: userId,
        payload: {'id': logId},
        enqueuedAt: DateTime.now().toUtc(),
      ));
    }
  }

  Future<void> syncRoutine(String userId, Routine routine) async {
    if (userId.isEmpty || userId.length > 128 || routine.id.isEmpty || routine.id.length > 128) {
      debugPrint('[FirebaseSync] syncRoutine rejected: invalid IDs');
      return;
    }
    final sanitizedRoutine = _sanitizeRoutine(routine);
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('routines')
          .doc(sanitizedRoutine.id)
          .set({
        ...sanitizedRoutine.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      unawaited(drainQueue(userId));
    } catch (e) {
      debugPrint('[FirebaseSync] syncRoutine error (offline?): $e');
      await _syncQueue.enqueue(SyncOp(
        type: SyncOpType.syncRoutine,
        userId: userId,
        payload: sanitizedRoutine.toJson(),
        enqueuedAt: DateTime.now().toUtc(),
      ));
    }
  }

  Future<void> deleteRoutine(String userId, String routineId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('routines')
          .doc(routineId)
          .delete();
      unawaited(drainQueue(userId));
    } catch (e) {
      debugPrint('[FirebaseSync] deleteRoutine error (offline?): $e');
      await _syncQueue.enqueue(SyncOp(
        type: SyncOpType.deleteRoutine,
        userId: userId,
        payload: {'id': routineId},
        enqueuedAt: DateTime.now().toUtc(),
      ));
    }
  }

  // --- OFFLINE SYNC QUEUE ---

  bool _isDraining = false;

  /// Drena todas as operações pendentes na fila para o usuário especificado.
  /// É chamado automaticamente após cada operação bem-sucedida.
  /// Protegido contra execuções concorrentes com [_isDraining].
  Future<void> drainQueue(String userId) async {
    if (_isDraining) return;
    _isDraining = true;
    try {
      final pending = await _syncQueue.pendingFor(userId);
      if (pending.isEmpty) return;
      debugPrint('[SyncQueue] Draining ${pending.length} pending op(s) for user $userId');

      final completed = <SyncOp>[];
      for (final op in pending) {
        try {
          switch (op.type) {
            case SyncOpType.syncWorkoutLog:
              final log = WorkoutLog.fromJson(op.payload);
              await _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('workouts')
                  .doc(log.id)
                  .set({...log.toJson(), 'updatedAt': FieldValue.serverTimestamp()});
              completed.add(op);
            case SyncOpType.deleteWorkoutLog:
              final id = op.payload['id'] as String;
              await _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('workouts')
                  .doc(id)
                  .delete();
              completed.add(op);
            case SyncOpType.syncRoutine:
              final routine = Routine.fromJson(op.payload);
              await _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('routines')
                  .doc(routine.id)
                  .set({...routine.toJson(), 'updatedAt': FieldValue.serverTimestamp()});
              completed.add(op);
            case SyncOpType.deleteRoutine:
              final id = op.payload['id'] as String;
              await _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('routines')
                  .doc(id)
                  .delete();
              completed.add(op);
          }
        } catch (e) {
          // Falhou novamente — para o drain (ainda offline). Tenta no próximo ciclo.
          debugPrint('[SyncQueue] Drain failed for ${op.type.name}: $e');
          break;
        }
      }

      if (completed.isNotEmpty) {
        await _syncQueue.removeCompleted(completed);
        debugPrint('[SyncQueue] Drained ${completed.length} op(s) successfully.');
      }
    } finally {
      _isDraining = false;
    }
  }

  /// Retorna o número de operações pendentes na fila (para diagnóstico/UI).
  Future<int> get pendingQueueSize => _syncQueue.queueSize;

  /// Limpa a fila do usuário (ex: logout).
  Future<void> clearQueueFor(String userId) => _syncQueue.clearFor(userId);

  Future<List<WorkoutLog>> fetchCloudWorkouts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('workouts')
          .get();
      return snapshot.docs
          .map((doc) => WorkoutLog.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[FirebaseSync] fetchCloudWorkouts error: $e');
      return [];
    }
  }

  Future<List<Routine>> fetchCloudRoutines(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('routines')
          .get();
      return snapshot.docs
          .map((doc) => Routine.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[FirebaseSync] fetchCloudRoutines error: $e');
      return [];
    }
  }

  // --- CORE SYNC LOGIC ---

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
        for (final routine in localState.routines) {
          unawaited(syncRoutine(userId, routine));
        }
        for (final log in localState.history) {
          unawaited(syncWorkoutLog(userId, log));
        }
        return localState;
      }

      final data = docSnap.data();
      if (data == null || data['jsonState'] == null) {
        await _upload(docRef, localState, profile, localUpdatedAt);
        for (final routine in localState.routines) {
          unawaited(syncRoutine(userId, routine));
        }
        for (final log in localState.history) {
          unawaited(syncWorkoutLog(userId, log));
        }
        return localState;
      }

      final remoteState =
          PlannerState.fromJson(json.decode(data['jsonState'] as String));
      final remoteUpdatedAt = _readRemoteUpdatedAt(data);

      // CRITICAL SAFETY SHIELD: If local state is empty/new but remote has data, 
      // do NOT allow uploading/overwriting the remote state. Force download instead.
      final isLocalEmpty = localState.routines.isEmpty && localState.history.isEmpty;
      final isRemoteNotEmpty = remoteState.routines.isNotEmpty || remoteState.history.isNotEmpty;
      
      if (isLocalEmpty && isRemoteNotEmpty) {
        debugPrint('[FirebaseSync] Empty local state detected. Safety shield triggered: forcing download from remote cloud.');
        final cloudWorkouts = await fetchCloudWorkouts(userId);
        final cloudRoutines = await fetchCloudRoutines(userId);
        
        final combinedState = remoteState.copyWith(
          library: remoteState.library,
          history: cloudWorkouts.isNotEmpty ? cloudWorkouts : remoteState.history,
          routines: cloudRoutines.isNotEmpty ? cloudRoutines : remoteState.routines,
        );

        await onRemoteApplied?.call(combinedState, _readRemoteProfile(data));
        return combinedState;
      }

      if (forceDownload) {
        // Fetch incremental workouts and routines on clean install
        final cloudWorkouts = await fetchCloudWorkouts(userId);
        final cloudRoutines = await fetchCloudRoutines(userId);
        
        final combinedState = remoteState.copyWith(
          library: remoteState.library,
          history: cloudWorkouts.isNotEmpty ? cloudWorkouts : remoteState.history,
          routines: cloudRoutines.isNotEmpty ? cloudRoutines : remoteState.routines,
          deletedHealthWorkoutIds: {...localState.deletedHealthWorkoutIds, ...remoteState.deletedHealthWorkoutIds}.toList(),
        );

        await onRemoteApplied?.call(combinedState, _readRemoteProfile(data));
        return combinedState;
      }

      if (_shouldUpload(localState, remoteState, localUpdatedAt, remoteUpdatedAt)) {
        await _upload(docRef, localState, profile, localUpdatedAt);
        for (final routine in localState.routines) {
          unawaited(syncRoutine(userId, routine));
        }
        for (final log in localState.history) {
          unawaited(syncWorkoutLog(userId, log));
        }
        return localState;
      }

      // Merge and apply remote state (but read workouts/routines incrementally too)
      final cloudWorkouts = await fetchCloudWorkouts(userId);
      final cloudRoutines = await fetchCloudRoutines(userId);

      // Merge local and cloud workouts to prevent data loss
      // Keep both local and cloud workouts, deduplicating by ID
      final cloudWorkoutIds = cloudWorkouts.map((w) => w.id).toSet();
      final mergedWorkouts = <WorkoutLog>[];
      
      // Add cloud workouts first
      mergedWorkouts.addAll(cloudWorkouts.isNotEmpty ? cloudWorkouts : remoteState.history);
      
      // Add local workouts that aren't in cloud (to preserve unsynced data)
      for (final log in localState.history) {
        if (!cloudWorkoutIds.contains(log.id)) {
          mergedWorkouts.add(log);
          // Upload local workout to cloud in background
          unawaited(syncWorkoutLog(userId, log));
        }
      }
      
      // Sort by date descending
      mergedWorkouts.sort((a, b) => b.date.compareTo(a.date));

      // Merge routines similarly to prevent data loss
      final cloudRoutineIds = cloudRoutines.map((r) => r.id).toSet();
      final mergedRoutines = <Routine>[];
      
      // Add cloud routines first
      mergedRoutines.addAll(cloudRoutines.isNotEmpty ? cloudRoutines : remoteState.routines);
      
      // Add local routines that aren't in cloud
      for (final routine in localState.routines) {
        if (!cloudRoutineIds.contains(routine.id)) {
          mergedRoutines.add(routine);
          // Upload local routine to cloud in background
          unawaited(syncRoutine(userId, routine));
        }
      }

      // Merge exercise libraries to prevent preset catalog or custom exercises from being wiped
      final localLibraryIds = localState.library.map((l) => l.id).toSet();
      final mergedLibrary = List<LibraryExercise>.from(localState.library);
      for (final ex in remoteState.library) {
        if (!localLibraryIds.contains(ex.id)) {
          mergedLibrary.add(ex);
        }
      }

      final combinedState = remoteState.copyWith(
        library: mergedLibrary,
        history: mergedWorkouts,
        routines: mergedRoutines,
        deletedHealthWorkoutIds: {...localState.deletedHealthWorkoutIds, ...remoteState.deletedHealthWorkoutIds}.toList(),
      );

      await onRemoteApplied?.call(combinedState, _readRemoteProfile(data));
      return combinedState;
    } catch (e) {
      debugPrint('[FirebaseSync] sync error: $e');
      return localState;
    }
  }

  Future<void> updateCloudProfile(String userId, Profile profile) async {
    if (userId.isEmpty || userId.length > 128 || profile.id.isEmpty || profile.id.length > 128) {
      debugPrint('[FirebaseSync] updateCloudProfile rejected: invalid IDs');
      return;
    }
    final sanitizedProfile = _sanitizeProfile(profile);
    try {
      await _firestore.collection('users').doc(userId).update({
        'profile': sanitizedProfile.toJson(),
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
    // Strip history and routines from main JSON state to keep it light
    final cleanState = state.copyWith(history: [], routines: []);
    
    await docRef.set({
      'jsonState': json.encode(cleanState.toJson()),
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
    // Rely on timestamps for lightweight state conflict resolution
    return localUpdatedAt.isAfter(remoteUpdatedAt);
  }

  void dispose() {
    _debounceTimer?.cancel();
  }

  // --- DATA SANITIZATION & VALIDATION HELPERS ---

  WorkoutLog _sanitizeWorkoutLog(WorkoutLog log) {
    String name = log.name.trim();
    if (name.length > 100) name = name.substring(0, 100);

    final exercises = log.exercises.map((ex) {
      String exName = ex.name.trim();
      if (exName.length > 100) exName = exName.substring(0, 100);
      return LogExercise(
        name: exName,
        muscle: ex.muscle,
        sets: ex.sets.clamp(0, 100),
        completedSets: ex.completedSets.clamp(0, 100),
        reps: ex.reps.clamp(0, 1000),
        weight: ex.weight.clamp(0.0, 1000.0),
        performedCardios: ex.performedCardios,
        rpe: ex.rpe.clamp(0, 10),
        failureReport: ex.failureReport,
        failureReps: ex.failureReps,
        executionType: ex.executionType,
      );
    }).toList();

    return WorkoutLog(
      id: log.id,
      name: name,
      date: log.date,
      duration: log.duration.clamp(0, 86400),
      completedSets: log.completedSets.clamp(0, 1000),
      totalSets: log.totalSets.clamp(0, 1000),
      totalWeight: log.totalWeight.clamp(0.0, 1000000.0),
      rpe: log.rpe.clamp(0, 10),
      notes: log.notes.trim().substring(0, log.notes.length > 500 ? 500 : log.notes.length),
      recovery: log.recovery,
      exercises: exercises,
      warmupDurationSeconds: log.warmupDurationSeconds,
      avgHeartRate: log.avgHeartRate,
      activeCalories: log.activeCalories,
    );
  }

  Routine _sanitizeRoutine(Routine routine) {
    String name = routine.name.trim();
    if (name.length > 100) name = name.substring(0, 100);

    final exercises = routine.exercises.map((ex) {
      return RoutineExercise(
        id: ex.id,
        exerciseId: ex.exerciseId,
        sets: ex.sets.clamp(0, 100),
        reps: ex.reps.clamp(0, 1000),
        rest: ex.rest.clamp(0, 3600),
        weight: ex.weight.clamp(0.0, 1000.0),
        weightsPerSet: ex.weightsPerSet,
        repsPerSet: ex.repsPerSet,
      );
    }).toList();

    return Routine(
      id: routine.id,
      name: name,
      defaultRest: routine.defaultRest.clamp(0, 3600),
      exercises: exercises,
      isDynamicExercise: routine.isDynamicExercise,
    );
  }

  Profile _sanitizeProfile(Profile profile) {
    String name = profile.name.trim();
    if (name.length > 50) name = name.substring(0, 50);
    String avatar = profile.avatar.trim();
    if (avatar.length > 10) avatar = avatar.substring(0, 10);
    return Profile(
      id: profile.id,
      name: name,
      avatar: avatar,
      colorAccent: profile.colorAccent,
    );
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

