import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker_flutter/services/firebase_sync_service.dart';

void main() {
  group('shouldUploadState', () {
    final t1 = DateTime.utc(2024, 1, 1);
    final t2 = DateTime.utc(2024, 6, 1);

    test('uploads when local is newer', () {
      expect(
        shouldUploadState(
          localUpdatedAt: t2,
          remoteUpdatedAt: t1,
          localHistoryLength: 1,
          remoteHistoryLength: 5,
        ),
        isTrue,
      );
    });

    test('downloads when remote is newer', () {
      expect(
        shouldUploadState(
          localUpdatedAt: t1,
          remoteUpdatedAt: t2,
          localHistoryLength: 10,
          remoteHistoryLength: 1,
        ),
        isFalse,
      );
    });

    test('uses history length as tiebreaker', () {
      expect(
        shouldUploadState(
          localUpdatedAt: t1,
          remoteUpdatedAt: t1,
          localHistoryLength: 5,
          remoteHistoryLength: 3,
        ),
        isTrue,
      );

      expect(
        shouldUploadState(
          localUpdatedAt: t1,
          remoteUpdatedAt: t1,
          localHistoryLength: 2,
          remoteHistoryLength: 8,
        ),
        isFalse,
      );
    });
  });
}
