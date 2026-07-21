import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/enums.dart';

class PremiumStrengthSetRow extends StatelessWidget {
  final int setIndex;
  final ActiveExercise ex;
  final bool isDone;
  final bool isActive;
  final Color accentColor;
  final VoidCallback onEditTap;
  final Widget trailingWidget;

  const PremiumStrengthSetRow({
    Key? key,
    required this.setIndex,
    required this.ex,
    required this.isDone,
    required this.isActive,
    required this.accentColor,
    required this.onEditTap,
    required this.trailingWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final reps = (ex.repsPerSet != null && setIndex < ex.repsPerSet!.length) ? ex.repsPerSet![setIndex] : ex.reps;
    final weight = (ex.weightsPerSet != null && setIndex < ex.weightsPerSet!.length) ? ex.weightsPerSet![setIndex] : ex.weight;
    final isTime = ex.measurementType == MeasurementType.time;

    return Opacity(
      opacity: isDone ? 0.65 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive 
            ? accentColor.withOpacity(0.08)
            : Colors.white.withOpacity(isDone ? 0.02 : 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive 
              ? accentColor.withOpacity(0.5) 
              : Colors.white.withOpacity(0.05),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: accentColor.withOpacity(0.15),
              blurRadius: 12,
              spreadRadius: 1,
            )
          ] : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                // Set Number Badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive ? accentColor : Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      "${setIndex + 1}",
                      style: TextStyle(
                        color: isActive ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Value Grid (Reps / Weight)
                Expanded(
                  child: InkWell(
                    onTap: onEditTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildGridValue(
                          value: "$reps",
                          unit: isTime ? "seg" : "reps",
                          isActive: isActive,
                        ),
                        Container(width: 1, height: 24, color: Colors.white.withOpacity(0.1)),
                        _buildGridValue(
                          value: weight > 0 ? weight.toStringAsFixed(1).replaceAll('.0', '') : "-",
                          unit: "kg",
                          isActive: isActive,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                trailingWidget,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridValue({required String value, required String unit, required bool isActive}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
