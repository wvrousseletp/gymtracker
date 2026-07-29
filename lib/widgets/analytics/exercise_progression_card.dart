import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/tracker_provider.dart';
import '../../../models/workout_log.dart';
import '../../glass_card.dart';
import 'exercise_progression_chart.dart';

class ExerciseProgressionCard extends StatefulWidget {
  final List<WorkoutLog> history;
  final Color accentColor;

  const ExerciseProgressionCard({
    super.key,
    required this.history,
    required this.accentColor,
  });

  @override
  State<ExerciseProgressionCard> createState() => _ExerciseProgressionCardState();
}

class _ExerciseProgressionCardState extends State<ExerciseProgressionCard> {
  String? _selectedExercise;

  @override
  Widget build(BuildContext context) {
    // Extract unique exercise names from history
    final Set<String> exercises = {};
    for (var log in widget.history) {
      for (var ex in log.exercises) {
        if (ex.completedSets > 0) {
          exercises.add(ex.name);
        }
      }
    }
    
    final sortedExercises = exercises.toList()..sort();
    
    if (sortedExercises.isEmpty) {
      return const SizedBox.shrink(); // Hide if no exercises recorded
    }
    
    if (_selectedExercise == null || !sortedExercises.contains(_selectedExercise)) {
      _selectedExercise = sortedExercises.first;
    }

    return GlassCard(
      useBlur: true,
      borderColor: Colors.white.withOpacity(0.08),
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Evolução por Exercício",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Icon(Icons.show_chart, color: widget.accentColor.withOpacity(0.8), size: 20),
            ],
          ),
          const SizedBox(height: 16),
          // Dropdown for selecting exercise
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedExercise,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E1E1E),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedExercise = newValue;
                    });
                  }
                },
                items: sortedExercises.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: ExerciseProgressionChart(
              exerciseName: _selectedExercise!,
              history: widget.history,
              accentColor: widget.accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
