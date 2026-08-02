import 'package:flutter/material.dart';
import '../services/watch_service.dart';
import '../providers/workout_provider.dart';
import '../models/routine.dart';
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
    final bool? completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (context) => const _CountdownDialog(),
    );

    // 3. Actually start the workout if countdown completed
    if (completed == true) {
      provider.startWorkout(routine, recovery, isWarmup);
    }
  }

  static Future<void> startSingleExerciseWithCountdown(
    BuildContext context, 
    WorkoutProvider provider, 
    LibraryExercise exercise,
  ) async {
    WatchService.instance.prepareWatchApp();

    final bool? completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (context) => const _CountdownDialog(),
    );

    if (completed == true) {
      provider.startSingleExercise(exercise);
    }
  }
}

class _CountdownDialog extends StatefulWidget {
  const _CountdownDialog();

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
          Navigator.of(context).pop(true);
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
      body: Stack(
        children: [
          Center(
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
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 20,
            child: TextButton.icon(
              onPressed: () {
                _timer?.cancel();
                Navigator.of(context).pop(false);
              },
              icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
              label: const Text("Cancelar", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
