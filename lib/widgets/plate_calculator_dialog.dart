import 'package:flutter/material.dart';

class PlateCalculatorDialog extends StatefulWidget {
  final Color accentColor;

  const PlateCalculatorDialog({super.key, required this.accentColor});

  @override
  State<PlateCalculatorDialog> createState() => _PlateCalculatorDialogState();
}

class _PlateCalculatorDialogState extends State<PlateCalculatorDialog> {
  final _targetWeightController = TextEditingController();
  final _barWeightController = TextEditingController(text: "20"); // Barra olímpica padrão

  // Anilhas disponíveis (em kg)
  final List<double> availablePlates = [25, 20, 15, 10, 5, 2.5, 1.25];
  List<double> platesNeededPerSide = [];
  bool hasError = false;

  void _calculatePlates() {
    final target = double.tryParse(_targetWeightController.text.trim()) ?? 0;
    final bar = double.tryParse(_barWeightController.text.trim()) ?? 0;

    if (target <= bar) {
      setState(() {
        platesNeededPerSide = [];
        hasError = true;
      });
      return;
    }

    double weightPerSide = (target - bar) / 2;
    List<double> needed = [];

    for (var plate in availablePlates) {
      while (weightPerSide >= plate) {
        needed.add(plate);
        weightPerSide -= plate;
        // Float precision fix
        weightPerSide = double.parse(weightPerSide.toStringAsFixed(2));
      }
    }

    setState(() {
      platesNeededPerSide = needed;
      hasError = false;
    });
  }

  Color _getPlateColor(double weight) {
    if (weight >= 25) return Colors.redAccent;
    if (weight >= 20) return Colors.blueAccent;
    if (weight >= 15) return Colors.yellow[700]!;
    if (weight >= 10) return Colors.green;
    if (weight >= 5) return Colors.white;
    return Colors.grey;
  }

  double _getPlateHeight(double weight) {
    if (weight >= 20) return 100;
    if (weight >= 15) return 80;
    if (weight >= 10) return 60;
    if (weight >= 5) return 40;
    return 30;
  }

  double _getPlateWidth(double weight) {
    if (weight >= 10) return 16;
    return 10;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08)),
      ),
      title: Text("Calculadora de Anilhas",
          style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontSize: 18, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Alvo (kg)", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)), fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _targetWeightController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          hintText: "Ex: 100",
                          hintStyle: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white24 : const Color(0xFFC7C7CC))),
                        ),
                        onChanged: (_) => _calculatePlates(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Barra (kg)", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)), fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _barWeightController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E))),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        onChanged: (_) => _calculatePlates(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (hasError)
              const Text("O peso alvo deve ser maior que a barra.", style: TextStyle(color: Colors.redAccent, fontSize: 13))
            else if (platesNeededPerSide.isNotEmpty) ...[
              Text("Coloque DE CADA LADO:", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF3C3C43)), fontSize: 12)),
              const SizedBox(height: 16),
              Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Representação visual da barra interna
                      Container(
                        width: 40,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)),
                        ),
                      ),
                      // Stopper
                      Container(
                        width: 8,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Anilhas
                      ...platesNeededPerSide.map((plate) {
                        return Container(
                          margin: const EdgeInsets.only(left: 2),
                          width: _getPlateWidth(plate),
                          height: _getPlateHeight(plate),
                          decoration: BoxDecoration(
                            color: _getPlateColor(plate),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.black45, width: 1),
                          ),
                          child: Center(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Text(
                                plate.toString().replaceAll('.0', ''),
                                style: TextStyle(
                                  color: plate >= 5 ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      // Fim da barra (ponta)
                      Container(
                        width: 60,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: platesNeededPerSide.map((p) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text("${p.toString().replaceAll('.0', '')} kg", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E)), fontWeight: FontWeight.bold)),
                )).toList(),
              )
            ] else
              Text("Digite os valores para calcular.", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF8E8E93)), fontSize: 13, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Fechar", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6E6E73)))),
        ),
      ],
    );
  }
}
