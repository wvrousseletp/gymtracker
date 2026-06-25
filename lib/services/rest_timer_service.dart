import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Global singleton that manages the rest/prep timer independently of any
/// screen widget. This ensures the countdown survives navigation between tabs.
///
/// Usage:
///   RestTimerService.instance.start(seconds: 60, endTime: endEpochMs,
///     isPrep: false, nextExName: 'Agachamento', nextSetNum: 2);
///   RestTimerService.instance.clear();
class RestTimerService {
  static final RestTimerService instance = RestTimerService._internal();
  RestTimerService._internal();

  final MethodChannel _channel =
      const MethodChannel('com.vicente.losmooscles/watch');

  Timer? _timer;

  // Public reactive state (listen with ValueListenableBuilder)
  final ValueNotifier<int> secondsRemaining = ValueNotifier<int>(0);
  final ValueNotifier<bool> isActive = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPrep = ValueNotifier<bool>(false);
  final ValueNotifier<String> nextExName = ValueNotifier<String>('');
  final ValueNotifier<int> nextSetNum = ValueNotifier<int>(0);
  final ValueNotifier<int> totalSeconds = ValueNotifier<int>(0);

  // Callback called when the timer naturally reaches zero
  VoidCallback? onTimerCompleted;

  /// Start (or restart) the timer.
  /// [endTime] is the epoch-ms timestamp when the timer should end.
  void start({
    required int endTimeMs,
    required int seconds,
    required bool prep,
    required String exName,
    required int setNum,
    VoidCallback? onCompleted,
  }) {
    _timer?.cancel();

    isActive.value = true;
    isPrep.value = prep;
    nextExName.value = exName;
    nextSetNum.value = setNum;
    totalSeconds.value = seconds;
    onTimerCompleted = onCompleted;

    final remaining =
        ((endTimeMs - DateTime.now().millisecondsSinceEpoch) / 1000).round();
    secondsRemaining.value = remaining > 0 ? remaining : 0;

    if (remaining <= 0) {
      _handleCompleted();
      return;
    }

    // Notify native side: update Live Activity rest timer + schedule local notification
    _notifyNativeStart(endTimeMs: endTimeMs, seconds: seconds, prep: prep, exName: exName);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final rem = ((endTimeMs - now) / 1000).round();
      if (rem > 0) {
        secondsRemaining.value = rem;
      } else {
        secondsRemaining.value = 0;
        _timer?.cancel();
        _handleCompleted();
      }
    });
  }

  /// Cancel the timer (user skipped rest).
  void clear() {
    _timer?.cancel();
    _timer = null;
    isActive.value = false;
    isPrep.value = false;
    secondsRemaining.value = 0;
    nextExName.value = '';
    nextSetNum.value = 0;
    totalSeconds.value = 0;
    onTimerCompleted = null;
    _notifyNativeClear();
  }

  void _handleCompleted() {
    isActive.value = false;
    isPrep.value = false;
    totalSeconds.value = 0;
    final cb = onTimerCompleted;
    onTimerCompleted = null;
    cb?.call();
    // Clear native side (notification was already fired by the OS)
    _notifyNativeClear();
  }

  Future<void> _notifyNativeStart({
    required int endTimeMs,
    required int seconds,
    required bool prep,
    required String exName,
  }) async {
    try {
      await _channel.invokeMethod('startRestTimer', {
        'endTime': endTimeMs.toDouble(),
        'totalSeconds': seconds,
        'isPrep': prep,
        'nextExName': exName,
      });
    } on PlatformException catch (e) {
      // Non-fatal – Dynamic Island just won't show rest timer on this device
      debugPrint('[RestTimerService] startRestTimer channel error: $e');
    }
  }

  Future<void> _notifyNativeClear() async {
    try {
      await _channel.invokeMethod('clearRestTimer');
    } on PlatformException catch (e) {
      debugPrint('[RestTimerService] clearRestTimer channel error: $e');
    }
  }
}
