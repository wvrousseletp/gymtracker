import 'dart:math';
import 'package:flutter/material.dart';

class CircularProgressTimer extends StatefulWidget {
  final int totalSeconds;
  final int elapsedSeconds;
  final Color progressColor;
  final String title;
  final String subtext;
  final VoidCallback? onSkip;
  final String skipLabel;

  const CircularProgressTimer({
    super.key,
    required this.totalSeconds,
    required this.elapsedSeconds,
    required this.progressColor,
    required this.title,
    required this.subtext,
    this.onSkip,
    this.skipLabel = "Pular",
  });

  @override
  State<CircularProgressTimer> createState() => _CircularProgressTimerState();
}

class _CircularProgressTimerState extends State<CircularProgressTimer> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 8.0, end: 22.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = max(0, widget.totalSeconds - widget.elapsedSeconds);
    final progress = widget.totalSeconds > 0 ? (widget.elapsedSeconds / widget.totalSeconds) : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Glowing background circle
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.progressColor.withOpacity(0.15),
                        blurRadius: _glowAnimation.value,
                        spreadRadius: _glowAnimation.value * 0.15,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: 1.0 - progress,
                    strokeWidth: 10,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(widget.progressColor),
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
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          widget.subtext,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (widget.onSkip != null) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.onSkip,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              backgroundColor: Colors.white.withOpacity(0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
            ),
            child: Text(
              widget.skipLabel,
              style: TextStyle(
                color: widget.progressColor,
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
