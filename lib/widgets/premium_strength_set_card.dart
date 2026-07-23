import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/enums.dart';

class PremiumStrengthSetCard extends StatelessWidget {
  final int setIndex;
  final ActiveExercise ex;
  final bool isDone;
  final bool isActive;
  final bool isFailure;
  final Color accentColor;
  final VoidCallback onEditTap;
  final VoidCallback onDoneTap;
  final VoidCallback onFailureTap;

  const PremiumStrengthSetCard({
    super.key,
    required this.setIndex,
    required this.ex,
    required this.isDone,
    required this.isActive,
    required this.isFailure,
    required this.accentColor,
    required this.onEditTap,
    required this.onDoneTap,
    required this.onFailureTap,
  });

  @override
  Widget build(BuildContext context) {
    final reps = (ex.repsPerSet != null && setIndex < ex.repsPerSet!.length)
        ? ex.repsPerSet![setIndex]
        : ex.reps;
    final weight =
        (ex.weightsPerSet != null && setIndex < ex.weightsPerSet!.length)
            ? ex.weightsPerSet![setIndex]
            : ex.weight;
    final isTime = ex.measurementType == MeasurementType.time;

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive
              ? accentColor.withOpacity(0.08)
              : Colors.white.withOpacity(isDone ? 0.02 : 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive
                ? accentColor.withOpacity(0.5)
                : isFailure
                    ? Colors.redAccent.withOpacity(0.5)
                    : isDone
                        ? Colors.greenAccent.withOpacity(0.3)
                        : Colors.white.withOpacity(0.05),
            width: isActive || isFailure || isDone ? 1.5 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.15),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header (Série X)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive
                              ? accentColor
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "SÉRIE ${setIndex + 1}",
                          style: TextStyle(
                            color: isActive ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      if (isFailure) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.2),
                            border: Border.all(
                                color: Colors.redAccent.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "FALHA",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                        )
                      ]
                    ],
                  ),
                  if (isDone)
                    Icon(
                      Icons.check_circle,
                      color: isFailure ? Colors.redAccent : accentColor,
                      size: 28,
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Reps and Weight Values
              InkWell(
                onTap: onEditTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBigValue(
                        value: "$reps",
                        unit: isTime ? "segundos" : "reps",
                        isActive: isActive,
                      ),
                      Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.1)),
                      _buildBigValue(
                        value: weight > 0
                            ? weight.toStringAsFixed(1).replaceAll('.0', '')
                            : "-",
                        unit: "kg",
                        isActive: isActive,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  // Failure Button
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      onPressed: onFailureTap,
                      icon: const Icon(Icons.whatshot, size: 20),
                      label: const Text(
                        "FALHA",
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isFailure ? Colors.white : Colors.redAccent,
                        backgroundColor: isFailure
                            ? Colors.redAccent
                            : Colors.redAccent.withOpacity(0.1),
                        side: BorderSide(
                            color: isFailure
                                ? Colors.redAccent
                                : Colors.redAccent.withOpacity(0.5),
                            width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Done Button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: onDoneTap,
                      icon: Icon(
                        isDone ? Icons.undo : Icons.check_circle_outline,
                        size: 24,
                      ),
                      label: Text(
                        isDone ? "DESFAZER" : "CONCLUIR",
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1),
                      ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: isDone ? Colors.white : Colors.black,
                        backgroundColor: isDone
                            ? Colors.white.withOpacity(0.2)
                            : accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: isActive ? 8 : 0,
                        shadowColor: accentColor.withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBigValue(
      {required String value, required String unit, required bool isActive}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontSize: 42,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          unit.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
