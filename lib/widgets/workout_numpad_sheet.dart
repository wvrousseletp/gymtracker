import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    _weightStr = widget.initialWeight == 0 ? "" : widget.initialWeight.toStringAsFixed(1).replaceAll('.0', '');
    _repsStr = widget.initialReps == 0 ? "" : widget.initialReps.toString();
  }

  void _onKeyPress(String key) {
    HapticFeedback.lightImpact();
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
          if (_weightStr.length < 5) _weightStr += key;
        }
      } else {
        if (key == '<') {
          if (_repsStr.isNotEmpty) {
            _repsStr = _repsStr.substring(0, _repsStr.length - 1);
          }
        } else if (key == '.') {
          // reps cant have decimal
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
    if (_editingWeight) {
      setState(() {
        _editingWeight = false;
      });
    } else {
      Navigator.of(context).pop({
        'weight': double.tryParse(_weightStr) ?? 0.0,
        'reps': int.tryParse(_repsStr) ?? 0,
      });
    }
  }

  Widget _buildKey(String label, {Color? color, VoidCallback? onTap, int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Material(
          color: color ?? Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap ?? () => _onKeyPress(label),
            child: Center(
              child: label == '<' 
                  ? const Icon(Icons.backspace_outlined, color: Colors.white, size: 20)
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
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
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xff1c1c1e),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (widget.ghostText != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.ghostText!,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _editingWeight = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _editingWeight ? Colors.blue.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _editingWeight ? Colors.blue : Colors.white.withOpacity(0.1),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text("Peso (kg)", style: TextStyle(color: _editingWeight ? Colors.blue : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          _weightStr.isEmpty ? "0" : _weightStr,
                          style: TextStyle(color: _editingWeight ? Colors.blue : Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _editingWeight = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: !_editingWeight ? Colors.blue.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: !_editingWeight ? Colors.blue : Colors.white.withOpacity(0.1),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(widget.isTime ? "Segundos" : "Reps", style: TextStyle(color: !_editingWeight ? Colors.blue : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          _repsStr.isEmpty ? "0" : _repsStr,
                          style: TextStyle(color: !_editingWeight ? Colors.blue : Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Botões de atalho
          Row(
            children: [
              _buildKey("-5", color: Colors.white.withOpacity(0.05)),
              _buildKey("-1", color: Colors.white.withOpacity(0.05)),
              _buildKey("+1", color: Colors.white.withOpacity(0.05)),
              _buildKey("+5", color: Colors.white.withOpacity(0.05)),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2,
            mainAxisSpacing: 0,
            crossAxisSpacing: 0,
            children: [
              _buildKey("1"), _buildKey("2"), _buildKey("3"),
              _buildKey("4"), _buildKey("5"), _buildKey("6"),
              _buildKey("7"), _buildKey("8"), _buildKey("9"),
              _buildKey("."), _buildKey("0"), _buildKey("<"),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                _editingWeight ? "Próximo" : "Salvar",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
