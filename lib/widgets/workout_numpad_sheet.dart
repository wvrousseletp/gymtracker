import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/tracker_provider.dart';
import '../widgets/profile_avatar.dart';

class WorkoutNumpadSheet extends StatefulWidget {
  final double initialWeight;
  final int initialReps;
  final bool isTime;
  final String title;
  final String? ghostText;

  const WorkoutNumpadSheet({
    super.key,
    required this.initialWeight,
    required this.initialReps,
    required this.isTime,
    required this.title,
    this.ghostText,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required double initialWeight,
    required int initialReps,
    required bool isTime,
    required String title,
    String? ghostText,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WorkoutNumpadSheet(
        initialWeight: initialWeight,
        initialReps: initialReps,
        isTime: isTime,
        title: title,
        ghostText: ghostText,
      ),
    );
  }

  @override
  State<WorkoutNumpadSheet> createState() => _WorkoutNumpadSheetState();
}

class _WorkoutNumpadSheetState extends State<WorkoutNumpadSheet> {
  bool _editingWeight = true;
  String _weightStr = "";
  String _repsStr = "";

  @override
  void initState() {
    super.initState();
    _weightStr = widget.initialWeight == 0
        ? ""
        : widget.initialWeight.toStringAsFixed(1).replaceAll('.0', '');
    _repsStr = widget.initialReps == 0 ? "" : widget.initialReps.toString();
  }

  void _onKeyPress(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_editingWeight) {
        if (key == '<') {
          if (_weightStr.isNotEmpty) {
            _weightStr = _weightStr.substring(0, _weightStr.length - 1);
          }
        } else if (key == '.') {
          if (!_weightStr.contains('.')) {
            _weightStr += _weightStr.isEmpty ? "0." : ".";
          }
        } else if (key.startsWith('+') || key.startsWith('-')) {
          double current = double.tryParse(_weightStr) ?? 0;
          double diff = double.parse(key);
          current = (current + diff).clamp(0, 9999);
          _weightStr = current.toStringAsFixed(1).replaceAll('.0', '');
        } else {
          if (_weightStr.length < 6) _weightStr += key;
        }
      } else {
        if (key == '<') {
          if (_repsStr.isNotEmpty) {
            _repsStr = _repsStr.substring(0, _repsStr.length - 1);
          }
        } else if (key == '.') {
          // Reps/seconds do not use decimal
        } else if (key.startsWith('+') || key.startsWith('-')) {
          int current = int.tryParse(_repsStr) ?? 0;
          int diff = int.parse(key);
          current = (current + diff).clamp(0, 9999);
          _repsStr = current.toString();
        } else {
          if (_repsStr.length < 4) _repsStr += key;
        }
      }
    });
  }

  void _submit() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop({
      'weight': double.tryParse(_weightStr) ?? 0.0,
      'reps': int.tryParse(_repsStr) ?? 0,
    });
  }

  Widget _buildNumpadKey(String label, {Color? color, VoidCallback? onTap, IconData? icon}) {
    return Material(
      color: color ?? Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? () => _onKeyPress(label),
        child: Center(
          child: icon != null
              ? Icon(icon, color: Colors.white, size: 22)
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildQuickDeltaPill(String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _onKeyPress(label),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color accentColor = Colors.blue;
    try {
      final tracker = Provider.of<TrackerProvider>(context, listen: false);
      accentColor = ThemeUtils.getColor(tracker.currentProfile.colorAccent);
    } catch (_) {}

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (widget.ghostText != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.ghostText!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Cards Row (Peso vs Reps/Tempo)
          Row(
            children: [
              // Card Peso
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _editingWeight = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: _editingWeight ? accentColor.withOpacity(0.15) : const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _editingWeight ? accentColor : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: _editingWeight
                          ? [
                              BoxShadow(
                                color: accentColor.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.scale_rounded,
                              size: 14,
                              color: _editingWeight ? accentColor : Colors.white54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Peso (kg)",
                              style: TextStyle(
                                color: _editingWeight ? accentColor : Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _weightStr.isEmpty ? "0" : _weightStr,
                          style: TextStyle(
                            color: _editingWeight ? accentColor : Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Card Reps / Segundos
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _editingWeight = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: !_editingWeight ? accentColor.withOpacity(0.15) : const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: !_editingWeight ? accentColor : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: !_editingWeight
                          ? [
                              BoxShadow(
                                color: accentColor.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.isTime ? Icons.timer_outlined : Icons.repeat_rounded,
                              size: 14,
                              color: !_editingWeight ? accentColor : Colors.white54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.isTime ? "Segundos" : "Reps",
                              style: TextStyle(
                                color: !_editingWeight ? accentColor : Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _repsStr.isEmpty ? "0" : _repsStr,
                          style: TextStyle(
                            color: !_editingWeight ? accentColor : Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Quick Delta Buttons Row (-5, -1, +1, +5)
          Row(
            children: [
              _buildQuickDeltaPill("-5"),
              _buildQuickDeltaPill("-1"),
              _buildQuickDeltaPill("+1"),
              _buildQuickDeltaPill("+5"),
            ],
          ),
          const SizedBox(height: 16),

          // Numpad 3x4 Grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _buildNumpadKey("1"),
              _buildNumpadKey("2"),
              _buildNumpadKey("3"),
              _buildNumpadKey("4"),
              _buildNumpadKey("5"),
              _buildNumpadKey("6"),
              _buildNumpadKey("7"),
              _buildNumpadKey("8"),
              _buildNumpadKey("9"),
              _buildNumpadKey("."),
              _buildNumpadKey("0"),
              _buildNumpadKey("<", icon: Icons.backspace_outlined),
            ],
          ),
          const SizedBox(height: 20),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                "Salvar",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
