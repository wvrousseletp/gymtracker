import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/workout_log.dart';

class WorkoutShareCard extends StatelessWidget {
  final WorkoutLog workout;
  final Color accentColor;

  const WorkoutShareCard({
    super.key,
    required this.workout,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    // Generate a sleek shareable card
    final dur = Duration(seconds: workout.duration);
    final hours = dur.inHours;
    final mins = dur.inMinutes.remainder(60);
    final timeStr = hours > 0 ? "${hours}h ${mins}m" : "${mins}m";
    final dateStr = DateFormat("dd/MM/yyyy").format(
        DateTime.tryParse(workout.date) ?? DateTime.now());

    return Container(
      width: 1080 / 3, // Roughly 1080x1920 ratio scaled down
      height: 1920 / 3,
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.black,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Text(
                  workout.name.toUpperCase(),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  dateStr,
                  style: GoogleFonts.outfit(
                    color: accentColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 32),
                _buildStatRow(Icons.timer, "TEMPO", timeStr),
                const SizedBox(height: 16),
                _buildStatRow(Icons.fitness_center, "VOLUME", "${workout.totalWeight.toInt()} kg"),
                const SizedBox(height: 16),
                _buildStatRow(Icons.format_list_numbered, "SÉRIES", "${workout.completedSets}"),
                const Spacer(),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.monitor_weight, color: accentColor, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        "LOS MOOSCLES APP",
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: accentColor, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        )
      ],
    );
  }
}
