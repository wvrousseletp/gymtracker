import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

class PremiumCardioSessionView extends StatefulWidget {
  final int setIndex;
  final bool isDone;
  final double? initialDistance;
  final int? initialMinutes;
  final int? goalMinutes;
  final ValueNotifier<int> workoutDurationNotifier;
  final void Function(double dist, int durMinutes, bool done) onChanged;

  const PremiumCardioSessionView({
    super.key,
    required this.setIndex,
    required this.isDone,
    this.initialDistance,
    this.initialMinutes,
    this.goalMinutes,
    required this.workoutDurationNotifier,
    required this.onChanged,
  });

  @override
  State<PremiumCardioSessionView> createState() =>
      _PremiumCardioSessionViewState();
}

class _PremiumCardioSessionViewState extends State<PremiumCardioSessionView>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _distCtrl;
  late final TextEditingController _durCtrl;
  late final AnimationController _pulseController;
  
  Timer? _localTimer;
  int _localSeconds = 0;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _distCtrl = TextEditingController(
      text: widget.initialDistance != null
          ? widget.initialDistance!.toStringAsFixed(widget.initialDistance! ==
                  widget.initialDistance!.truncateToDouble()
              ? 0
              : 1)
          : '',
    );
    _durCtrl = TextEditingController(
      text:
          widget.initialMinutes != null ? widget.initialMinutes.toString() : '',
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _localTimer?.cancel();
    _distCtrl.dispose();
    _durCtrl.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
    });
    _localTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _localSeconds++;
      });
    });
  }

  void _pauseTimer() {
    _localTimer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _stopTimer() {
    _localTimer?.cancel();
    setState(() {
      _isRunning = false;
      // Preencher o input de duração com o tempo que passou (em minutos)
      int minutes = (_localSeconds / 60).ceil(); // Arredonda para cima se passou alguns segundos extras
      if (minutes == 0) minutes = 1;
      _durCtrl.text = minutes.toString();
    });
    _saveSession(false); // Dispara on change sem marcar como concluído, apenas atualiza
  }

  void _saveSession(bool forceDone) {
    final d = double.tryParse(_distCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final t = int.tryParse(_durCtrl.text.trim()) ?? 0;
    widget.onChanged(d, t, forceDone);
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDone = widget.isDone;
    const cardioAccent = Color(0xff00e676);
    final hasGoal = widget.goalMinutes != null && widget.goalMinutes! > 0;
    double progress = 0;
    if (hasGoal) {
      progress = _localSeconds / (widget.goalMinutes! * 60);
      if (progress > 1.0) progress = 1.0;
    }

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ]),
        child: Column(
          children: [
            // Elegant Timer Display
            Stack(
              alignment: Alignment.center,
              children: [
                if (!hasGoal)
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 160 + (_pulseController.value * 20),
                        height: 160 + (_pulseController.value * 20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cardioAccent
                              .withOpacity(0.05 * (1 - _pulseController.value)),
                        ),
                      );
                    },
                  )
                else
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      backgroundColor: Colors.white.withOpacity(0.05),
                      valueColor: AlwaysStoppedAnimation(cardioAccent.withOpacity(0.7)),
                    ),
                  ),
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: cardioAccent.withOpacity(0.3), width: 2),
                    gradient: RadialGradient(
                      colors: [
                        cardioAccent.withOpacity(0.15),
                        Colors.transparent
                      ],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined,
                            color: cardioAccent, size: 24),
                        const SizedBox(height: 8),
                        Text(
                          _formatDuration(_localSeconds > 0 ? _localSeconds : widget.workoutDurationNotifier.value),
                          style: TextStyle(
                            color: _localSeconds > 0 ? Colors.white : Colors.white70,
                            fontSize: 32,
                            fontWeight: FontWeight.w200,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (hasGoal) ...[
                           const SizedBox(height: 4),
                           Text("Meta: ${widget.goalMinutes}m", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        ]
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Player Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isRunning)
                  _buildControlButton(
                    icon: Icons.play_arrow_rounded,
                    color: cardioAccent,
                    onTap: _startTimer,
                  )
                else
                  _buildControlButton(
                    icon: Icons.pause_rounded,
                    color: Colors.orangeAccent,
                    onTap: _pauseTimer,
                  ),
                if (_localSeconds > 0) ...[
                  const SizedBox(width: 16),
                  _buildControlButton(
                    icon: Icons.stop_rounded,
                    color: Colors.redAccent,
                    onTap: _stopTimer,
                  ),
                ]
              ],
            ),

            const SizedBox(height: 24),

            // Modern Input Grid
            Row(
              children: [
                Expanded(
                  child: _buildGlassInput(
                    controller: _distCtrl,
                    label: "Distância",
                    unit: "km",
                    icon: Icons.map_outlined,
                    color: cardioAccent,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildGlassInput(
                    controller: _durCtrl,
                    label: "Duração",
                    unit: "min",
                    icon: Icons.hourglass_empty,
                    color: cardioAccent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Completion Button
            GestureDetector(
              onTap: () {
                _saveSession(!isDone);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDone
                          ? [
                              cardioAccent.withOpacity(0.4),
                              cardioAccent.withOpacity(0.2)
                            ]
                          : [cardioAccent, cardioAccent.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isDone
                        ? []
                        : [
                            BoxShadow(
                              color: cardioAccent.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ]),
                child: Center(
                  child: Text(
                    isDone ? "Registrado" : "Salvar Sessão",
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Center(
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }

  Widget _buildGlassInput({
    required TextEditingController controller,
    required String label,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    _saveSession(widget.isDone);
                  },
                ),
              ),
              Text(
                unit,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
            ],
          )
        ],
      ),
    );
  }
}
