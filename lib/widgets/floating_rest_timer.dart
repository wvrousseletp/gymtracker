import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/rest_timer_service.dart';
import '../services/watch_service.dart';
import '../providers/tracker_provider.dart';
import '../widgets/profile_avatar.dart';

class FloatingRestTimer extends StatelessWidget {
  const FloatingRestTimer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = context.select<TrackerProvider, Color>(
      (p) => ThemeUtils.getAdaptiveColor(
        p.currentProfile.colorAccent,
        isDark: isDark,
      ),
    );
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final mutedColor = isDark ? Colors.white70 : const Color(0xFF6E6E73);

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

            return GestureDetector(
              onTap: () => WatchService.instance.onNavigateToWorkout?.call(),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                height: 56,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff2c2c2e) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: color.withOpacity(isDark ? 0.35 : 0.45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 38,
                          height: 38,
                          child: CircularProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            strokeWidth: 3,
                            backgroundColor:
                                (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                        Icon(
                          isPrep ? Icons.fitness_center : Icons.timer_outlined,
                          size: 18,
                          color: color,
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isPrep ? "Prepare-se..." : "Descanso • Voltar ao treino",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: mutedColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "${(secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(secondsRemaining % 60).toString().padLeft(2, '0')}",
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Botão -15s
                    InkWell(
                      onTap: () {
                        Provider.of<TrackerProvider>(context, listen: false)
                            .adjustRestTimer(-15);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withOpacity(0.1)),
                        ),
                        child: Text(
                          "-15s",
                          style: TextStyle(
                              color: mutedColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Botão +15s
                    InkWell(
                      onTap: () {
                        Provider.of<TrackerProvider>(context, listen: false)
                            .adjustRestTimer(15);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color.withOpacity(0.4)),
                        ),
                        child: Text(
                          "+15s",
                          style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Botão de fechar (cancelar/pular)
                    IconButton(
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.close_rounded,
                          color: mutedColor, size: 20),
                      onPressed: () {
                        Provider.of<TrackerProvider>(context, listen: false)
                            .clearRestTimer();
                      },
                    ),
                    const SizedBox(width: 4),
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
