import 'dart:math';
import 'package:flutter/material.dart';

class CircularProgressTimer extends StatelessWidget {
  final int totalSeconds;
  final int elapsedSeconds;
  final Color progressColor;
  final String title;
  final String subtext;
  final VoidCallback? onSkip;
  final String skipLabel;

  const CircularProgressTimer({
    Key? key,
    required this.totalSeconds,
    required this.elapsedSeconds,
    required this.progressColor,
    required this.title,
    required this.subtext,
    this.onSkip,
    this.skipLabel = "Pular",
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final remaining = max(0, totalSeconds - elapsedSeconds);
    final progress = totalSeconds > 0 ? (elapsedSeconds / totalSeconds) : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: CircularProgressIndicator(
                value: 1.0 - progress,
                strokeWidth: 10,
                backgroundColor: Colors.white.withOpacity(0.05),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$remaining",
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const Text(
                  "segundos",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          subtext,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (onSkip != null) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              backgroundColor: Colors.white.withOpacity(0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
            ),
            child: Text(
              skipLabel,
              style: TextStyle(
                color: progressColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
