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
    final weightStr = weight > 0
        ? "${weight.toStringAsFixed(1).replaceAll('.0', '')} kg"
        : "- kg";
    final repsStr = isTime ? "$reps s" : "$reps reps";

    // ─── 1. SÉRIE ATIVA: HERO CARD (DESTAQUE TOTAL) ───
    if (isActive) {
      return RepaintBoundary(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isFailure
                  ? Colors.redAccent.withOpacity(0.7)
                  : accentColor.withOpacity(0.6),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: (isFailure ? Colors.redAccent : accentColor)
                    .withOpacity(0.20),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Série X de Y)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "SÉRIE ${setIndex + 1} DE ${ex.sets}",
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "SÉRIE ATUAL",
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isFailure)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.2),
                          border: Border.all(
                              color: Colors.redAccent.withOpacity(0.6)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.whatshot,
                                color: Colors.redAccent, size: 14),
                            SizedBox(width: 4),
                            Text(
                              "FALHA",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Reps and Weight Values (Tap to Edit)
                InkWell(
                  onTap: onEditTap,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildBigValue(
                          value: "$reps",
                          unit: isTime ? "segundos" : "repetições",
                          isActive: true,
                        ),
                        Container(
                          width: 1,
                          height: 48,
                          color: Colors.white.withOpacity(0.12),
                        ),
                        _buildBigValue(
                          value: weight > 0
                              ? weight.toStringAsFixed(1).replaceAll('.0', '')
                              : "-",
                          unit: "quilogramas (kg)",
                          isActive: true,
                        ),
                        Icon(
                          Icons.edit_outlined,
                          color: Colors.white.withOpacity(0.3),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    // Failure Button
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        onPressed: onFailureTap,
                        icon: Icon(
                          Icons.whatshot,
                          size: 18,
                          color: isFailure ? Colors.white : Colors.redAccent,
                        ),
                        label: Text(
                          "FALHA",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: isFailure ? Colors.white : Colors.redAccent,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isFailure
                              ? Colors.redAccent
                              : Colors.redAccent.withOpacity(0.1),
                          side: BorderSide(
                            color: isFailure
                                ? Colors.redAccent
                                : Colors.redAccent.withOpacity(0.5),
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Done Button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: onDoneTap,
                        icon: const Icon(
                          Icons.check_circle_rounded,
                          size: 22,
                          color: Colors.black,
                        ),
                        label: const Text(
                          "CONCLUIR SÉRIE",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: Colors.black,
                            letterSpacing: 0.8,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 6,
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

    // ─── 2. SÉRIE CONCLUÍDA: LINHA COMPACTA ELEGANTE ───
    if (isDone) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFailure
                ? Colors.redAccent.withOpacity(0.3)
                : Colors.greenAccent.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Checkmark Icon
            Icon(
              isFailure ? Icons.whatshot : Icons.check_circle_rounded,
              color: isFailure ? Colors.redAccent : Colors.greenAccent,
              size: 20,
            ),
            const SizedBox(width: 10),
            // Set name
            Text(
              "Série ${setIndex + 1}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 10),
            // Values summary
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "$repsStr • $weightStr",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (isFailure) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "Falha",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Edit button
            IconButton(
              onPressed: onEditTap,
              icon: const Icon(Icons.edit_outlined,
                  color: Colors.white38, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: "Editar série",
            ),
            const SizedBox(width: 8),
            // Reopen / Undo button
            IconButton(
              onPressed: onDoneTap,
              icon: const Icon(Icons.undo_rounded,
                  color: Colors.white38, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: "Reabrir série",
            ),
          ],
        ),
      );
    }

    // ─── 3. SÉRIE FUTURA: PRÉVIA COMPACTA E DISCRETA ───
    return InkWell(
      onTap: onEditTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.015),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.04),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Hollow bullet
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white24,
                  width: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Set label
            Text(
              "Série ${setIndex + 1}",
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 10),
            // Planned stats
            Expanded(
              child: Text(
                "$repsStr • $weightStr (planejado)",
                style: const TextStyle(
                  color: Colors.white30,
                  fontSize: 12,
                ),
              ),
            ),
            // Edit action
            const Icon(
              Icons.edit_outlined,
              color: Colors.white24,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBigValue({
    required String value,
    required String unit,
    required bool isActive,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontSize: 36,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          unit.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
