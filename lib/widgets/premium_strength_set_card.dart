import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/exercise.dart';
import '../models/enums.dart';

class PremiumStrengthSetCard extends StatefulWidget {
  final int setIndex;
  final ActiveExercise ex;
  final bool isDone;
  final bool isActive;
  final bool isFailure;
  final Color accentColor;
  final VoidCallback onEditTap;
  final VoidCallback onDoneTap;
  final VoidCallback onFailureTap;
  final void Function(double weight, int reps)? onSaveValues;
  final void Function(String type)? onTypeChanged;
  final void Function(int? rir)? onRirChanged;

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
    this.onSaveValues,
    this.onTypeChanged,
    this.onRirChanged,
  });

  @override
  State<PremiumStrengthSetCard> createState() => _PremiumStrengthSetCardState();
}

class _PremiumStrengthSetCardState extends State<PremiumStrengthSetCard> {
  Timer? _timer;
  int _elapsed = 0;
  bool _isRunning = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer(int targetReps) {
    if (_isRunning) {
      _timer?.cancel();
      setState(() {
        _isRunning = false;
      });
      _saveLocalTime();
    } else {
      setState(() {
        _isRunning = true;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() {
          _elapsed++;
        });
        _saveLocalTime();
        if (_elapsed == targetReps) {
          _timer?.cancel();
          setState(() {
            _isRunning = false;
          });
          _playIsometryAlarm();
          widget.onDoneTap();
        }
      });
    }
  }

  void _playIsometryAlarm() async {
    for (int i = 0; i < 4; i++) {
      HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 150));
      HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 150));
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(milliseconds: 700));
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _elapsed = 0;
    });
    _saveLocalTime();
  }

  void _saveLocalTime() {
    if (widget.onSaveValues != null) {
      final weight = (widget.ex.weightsPerSet != null &&
              widget.setIndex < widget.ex.weightsPerSet!.length)
          ? widget.ex.weightsPerSet![widget.setIndex]
          : widget.ex.weight;
      widget.onSaveValues!(weight, _elapsed > 0 ? _elapsed : widget.ex.reps);
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentType = (widget.ex.setTypes != null && widget.setIndex < widget.ex.setTypes!.length) ? widget.ex.setTypes![widget.setIndex] : 'N';
    final currentRir = (widget.ex.rirPerSet != null && widget.setIndex < widget.ex.rirPerSet!.length) ? widget.ex.rirPerSet![widget.setIndex] : null;

    Color getTypeColor(String type) {
      switch (type) {
        case 'W': return Colors.orangeAccent;
        case 'D': return Colors.purpleAccent;
        case 'A': return Colors.redAccent;
        default: return Colors.white54;
      }
    }
    String getTypeLabel(String type) {
      switch (type) {
        case 'W': return "Warm-up";
        case 'D': return "Drop-set";
        case 'A': return "AMRAP";
        default: return "Normal";
      }
    }
    void cycleType() {
      if (widget.onTypeChanged == null) {
        return;
      }
      if (currentType == 'N') {
        widget.onTypeChanged!('W');
      } else if (currentType == 'W') {
        widget.onTypeChanged!('D');
      } else if (currentType == 'D') {
        widget.onTypeChanged!('A');
      } else {
        widget.onTypeChanged!('N');
      }
    }

    final reps = (widget.ex.repsPerSet != null &&
            widget.setIndex < widget.ex.repsPerSet!.length)
        ? widget.ex.repsPerSet![widget.setIndex]
        : widget.ex.reps;
    final weight = (widget.ex.weightsPerSet != null &&
            widget.setIndex < widget.ex.weightsPerSet!.length)
        ? widget.ex.weightsPerSet![widget.setIndex]
        : widget.ex.weight;
    final isTime = widget.ex.measurementType == MeasurementType.time;
    final weightStr = weight > 0
        ? "${weight.toStringAsFixed(1).replaceAll('.0', '')} kg"
        : "- kg";
    final repsStr = isTime ? "$reps s" : "$reps reps";

    // ─── 1. SÉRIE ATIVA: HERO CARD (DESTAQUE TOTAL) ───
    if (widget.isActive) {
      final targetSeconds = reps;
      final progress = targetSeconds > 0 ? _elapsed / targetSeconds : 0.0;
      final cappedProgress = progress.clamp(0.0, 1.0);

      return RepaintBoundary(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: widget.accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.isFailure
                  ? Colors.redAccent.withOpacity(0.7)
                  : widget.accentColor.withOpacity(0.6),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    (widget.isFailure ? Colors.redAccent : widget.accentColor)
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
                            color: widget.accentColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "SÉRIE ${widget.setIndex + 1} DE ${widget.ex.sets}",
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: cycleType,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: currentType == 'N' ? Colors.white.withOpacity(0.1) : getTypeColor(currentType).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: currentType == 'N' ? Colors.transparent : getTypeColor(currentType).withOpacity(0.5)),
                            ),
                            child: Text(
                              currentType == 'N' ? "SÉRIE ATUAL" : getTypeLabel(currentType).toUpperCase(),
                              style: TextStyle(
                                color: currentType == 'N' ? Colors.white70 : getTypeColor(currentType),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.isFailure)
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
                  onTap: widget.onEditTap,
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
                        if (!isTime || weight > 0) ...[
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
                        ],
                        Container(
                          width: 1,
                          height: 48,
                          color: Colors.white.withOpacity(0.12),
                        ),
                        _buildBigValue(
                          value: currentRir?.toString() ?? "-",
                          unit: "RIR",
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

                // ─── CRONÔMETRO INLINE PARA ISOMETRIA ───
                if (isTime) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 50,
                              height: 50,
                              child: CircularProgressIndicator(
                                value: cappedProgress,
                                strokeWidth: 3.5,
                                backgroundColor: Colors.white.withOpacity(0.05),
                                valueColor: AlwaysStoppedAnimation(
                                  _elapsed >= targetSeconds
                                      ? Colors.greenAccent
                                      : widget.accentColor,
                                ),
                              ),
                            ),
                            Text(
                              _formatTime(
                                  _elapsed > 0 ? _elapsed : targetSeconds),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isRunning ? "CRONÔMETRO ATIVO" : "ISOMETRIA",
                                style: TextStyle(
                                  color: _isRunning
                                      ? widget.accentColor
                                      : Colors.white60,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isRunning
                                    ? "Tempo sob tensão correndo..."
                                    : "Toque para cronometrar a série",
                                style: const TextStyle(
                                  color: Colors.white30,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            if (_elapsed > 0) ...[
                              IconButton(
                                onPressed: _resetTimer,
                                icon: const Icon(Icons.refresh_rounded,
                                    color: Colors.white60, size: 20),
                                tooltip: "Reiniciar",
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                              const SizedBox(width: 4),
                            ],
                            IconButton(
                              onPressed: () => _toggleTimer(targetSeconds),
                              icon: Icon(
                                _isRunning
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_filled_rounded,
                                color: _isRunning
                                    ? Colors.orangeAccent
                                    : widget.accentColor,
                                size: 36,
                              ),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    // Failure Button
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        onPressed: widget.onFailureTap,
                        icon: Icon(
                          Icons.whatshot,
                          size: 18,
                          color: widget.isFailure
                              ? Colors.white
                              : Colors.redAccent,
                        ),
                        label: Text(
                          "FALHA",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: widget.isFailure
                                ? Colors.white
                                : Colors.redAccent,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: widget.isFailure
                              ? Colors.redAccent
                              : Colors.redAccent.withOpacity(0.1),
                          side: BorderSide(
                            color: widget.isFailure
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
                        onPressed: () {
                          if (_isRunning) {
                            _timer?.cancel();
                            _isRunning = false;
                          }
                          widget.onDoneTap();
                        },
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
                          backgroundColor: widget.accentColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 6,
                          shadowColor: widget.accentColor.withOpacity(0.5),
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
    if (widget.isDone) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isFailure
                ? Colors.redAccent.withOpacity(0.3)
                : Colors.greenAccent.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Checkmark Icon
            currentType == 'N' ? Icon(
              widget.isFailure ? Icons.whatshot : Icons.check_circle_rounded,
              color: widget.isFailure ? Colors.redAccent : Colors.greenAccent,
              size: 20,
            ) : Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: getTypeColor(currentType).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
              child: Text(currentType, style: TextStyle(color: getTypeColor(currentType), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(width: 10),
            // Set name
            Text(
              "Série ${widget.setIndex + 1}",
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
                      ((!isTime || weight > 0) ? "$repsStr • $weightStr" : repsStr) + (currentRir != null ? " • RIR $currentRir" : ""),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (widget.isFailure) ...[
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
              onPressed: widget.onEditTap,
              icon: const Icon(Icons.edit_outlined,
                  color: Colors.white38, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: "Editar série",
            ),
            const SizedBox(width: 8),
            // Reopen / Undo button
            IconButton(
              onPressed: widget.onDoneTap,
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
      onTap: widget.onEditTap,
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
            currentType == 'N' ? Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white24,
                  width: 1.5,
                ),
              ),
            ) : GestureDetector(
              onTap: cycleType,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: getTypeColor(currentType).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text(currentType, style: TextStyle(color: getTypeColor(currentType), fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            ),
            const SizedBox(width: 10),
            // Set label
            Text(
              "Série ${widget.setIndex + 1}",
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
                (!isTime || weight > 0)
                    ? "$repsStr • $weightStr (planejado)"
                    : "$repsStr (planejado)",
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
