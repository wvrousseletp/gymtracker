import 'package:flutter/material.dart';
import 'dart:ui';

class PremiumCardioSessionView extends StatefulWidget {
  final int setIndex;
  final bool isDone;
  final double? initialDistance;
  final int? initialMinutes;
  final ValueNotifier<int> workoutDurationNotifier;
  final void Function(double dist, int durMinutes, bool done) onChanged;

  const PremiumCardioSessionView({
    Key? key,
    required this.setIndex,
    required this.isDone,
    this.initialDistance,
    this.initialMinutes,
    required this.workoutDurationNotifier,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<PremiumCardioSessionView> createState() => _PremiumCardioSessionViewState();
}

class _PremiumCardioSessionViewState extends State<PremiumCardioSessionView> with SingleTickerProviderStateMixin {
  late final TextEditingController _distCtrl;
  late final TextEditingController _durCtrl;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _distCtrl = TextEditingController(
      text: widget.initialDistance != null
          ? widget.initialDistance!.toStringAsFixed(widget.initialDistance! == widget.initialDistance!.truncateToDouble() ? 0 : 1)
          : '',
    );
    _durCtrl = TextEditingController(
      text: widget.initialMinutes != null ? widget.initialMinutes.toString() : '',
    );
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _distCtrl.dispose();
    _durCtrl.dispose();
    _pulseController.dispose();
    super.dispose();
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

    return Container(
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
        ]
      ),
      child: Column(
        children: [
          // Elegant Timer Display
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 160 + (_pulseController.value * 20),
                    height: 160 + (_pulseController.value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cardioAccent.withOpacity(0.05 * (1 - _pulseController.value)),
                    ),
                  );
                },
              ),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: cardioAccent.withOpacity(0.3), width: 2),
                  gradient: RadialGradient(
                    colors: [cardioAccent.withOpacity(0.15), Colors.transparent],
                  ),
                ),
                child: Center(
                  child: ValueListenableBuilder<int>(
                    valueListenable: widget.workoutDurationNotifier,
                    builder: (context, seconds, child) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, color: cardioAccent, size: 24),
                          const SizedBox(height: 8),
                          Text(
                            _formatDuration(seconds),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w200,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
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
              final d = double.tryParse(_distCtrl.text.replaceAll(',', '.')) ?? 0.0;
              final t = int.tryParse(_durCtrl.text.trim()) ?? 0;
              widget.onChanged(d, t, !isDone);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDone 
                    ? [cardioAccent.withOpacity(0.4), cardioAccent.withOpacity(0.2)]
                    : [cardioAccent, cardioAccent.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDone ? [] : [
                  BoxShadow(
                    color: cardioAccent.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              ),
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
          )
        ],
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
                style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    final d = double.tryParse(_distCtrl.text.replaceAll(',', '.')) ?? 0.0;
                    final t = int.tryParse(_durCtrl.text.trim()) ?? 0;
                    widget.onChanged(d, t, widget.isDone);
                  },
                ),
              ),
              Text(
                unit,
                style: const TextStyle(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          )
        ],
      ),
    );
  }
}
