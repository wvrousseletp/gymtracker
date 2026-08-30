import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/rest_timer_service.dart';
import '../providers/tracker_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_avatar.dart';

class FloatingRestTimer extends StatelessWidget {
  const FloatingRestTimer({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: RestTimerService.instance.isActive,
      builder: (context, isActive, child) {
        if (!isActive) return const SizedBox.shrink();

        return ValueListenableBuilder<int>(
          valueListenable: RestTimerService.instance.secondsRemaining,
          builder: (context, secondsRemaining, child) {
            final isPrep = RestTimerService.instance.isPrep.value;
            final total = RestTimerService.instance.totalSeconds.value;
            final progress = total > 0 ? 1.0 - (secondsRemaining / total) : 0.0;
            
            final color = ThemeUtils.getColor(Provider.of<TrackerProvider>(context).currentProfile.colorAccent);

            return GestureDetector(
              onTap: () {
                // Ao tocar, pode pular o timer
                Provider.of<TrackerProvider>(context, listen: false).clearRestTimer();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xff2c2c2e),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            strokeWidth: 3,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                        Icon(
                          isPrep ? Icons.fitness_center : Icons.timer,
                          size: 20,
                          color: color,
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isPrep ? "Prepare-se..." : "Descanso",
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Text(
                            "\${(secondsRemaining ~/ 60).toString().padLeft(2, '0')}:\${(secondsRemaining % 60).toString().padLeft(2, '0')}",
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () {
                        Provider.of<TrackerProvider>(context, listen: false).clearRestTimer();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
