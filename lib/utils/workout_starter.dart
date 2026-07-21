import 'package:flutter/material.dart';
import '../services/watch_service.dart';
import '../providers/workout_provider.dart';
import '../models/routine.dart';
import '../models/planner_state.dart';
import '../models/exercise.dart';
import '../models/workout_log.dart';
import 'dart:async';

class WorkoutStarter {
  static Future<void> startWithCountdown(
    BuildContext context, 
    WorkoutProvider provider, 
    Routine routine, 
    WorkoutRecovery recovery, 
    bool isWarmup,
  ) async {
    // 1. Prepare Watch app (launches it in foreground so it's ready)
    WatchService.instance.prepareWatchApp();

    // 2. Show 3, 2, 1 countdown dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (context) => const _CountdownDialog(),
    );

    // 3. Actually start the workout (Watch app is now awake and will receive the active state instantly)
    provider.startWorkout(routine, recovery, isWarmup);
  }

  static Future<void> startSingleExerciseWithCountdown(
    BuildContext context, 
    WorkoutProvider provider, 
    LibraryExercise exercise,
  ) async {
    WatchService.instance.prepareWatchApp();

    await showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (context) => const _CountdownDialog(),
    );

    provider.startSingleExercise(exercise);
  }
}

class _CountdownDialog extends StatefulWidget {
  const _CountdownDialog({Key? key}) : super(key: key);

  @override
  _CountdownDialogState createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> with SingleTickerProviderStateMixin {
  int _count = 3;
  Timer? _timer;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    
    _controller.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_count == 1) {
        timer.cancel();
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          setState(() {
            _count--;
          });
          _controller.reset();
          _controller.forward();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: (1.0 - _controller.value).clamp(0.2, 1.0),
                child: Text(
                  '$_count',
                  style: const TextStyle(
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFC0FF00), // accentColor
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
