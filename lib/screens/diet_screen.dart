import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tracker_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/profile_avatar.dart';
import '../models/diet.dart';

class DietScreen extends StatefulWidget {
  const DietScreen({super.key});

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.select<TrackerProvider, Color>(
      (p) => ThemeUtils.getColor(p.currentProfile.colorAccent),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: TabBar(
          controller: _tabController,
          indicatorColor: accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: "Refeições"),
            Tab(text: "Água"),
            Tab(text: "Jejum"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefeicoesTab(accentColor: accentColor),
          AguaTab(accentColor: accentColor),
          JejumTab(accentColor: accentColor),
        ],
      ),
    );
  }
}

// ==========================================
// 1. REFEIÇÕES TAB
// ==========================================
class RefeicoesTab extends StatelessWidget {
  final Color accentColor;
  const RefeicoesTab({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final diet = provider.state?.diet;

    if (diet == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    // Cálculos
    int totalCals = diet.meals.fold<int>(0, (sum, m) => sum + m.calories);
    double totalProt = diet.meals.fold<double>(0, (sum, m) => sum + m.protein);
    double totalCarbs = diet.meals.fold<double>(0, (sum, m) => sum + m.carbs);
    double totalFat = diet.meals.fold<double>(0, (sum, m) => sum + m.fat);

    final calProgress = diet.caloriesGoal > 0 ? (totalCals / diet.caloriesGoal).clamp(0.0, 1.0) : 0.0;
    final protProgress = diet.proteinGoal > 0 ? (totalProt / diet.proteinGoal).clamp(0.0, 1.0) : 0.0;
    final carbsProgress = diet.carbsGoal > 0 ? (totalCarbs / diet.carbsGoal).clamp(0.0, 1.0) : 0.0;
    final fatProgress = diet.fatGoal > 0 ? (totalFat / diet.fatGoal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _openAddMealDialog(context, provider);
        },
        backgroundColor: accentColor,
        mini: true,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumo de Calorias & Macros
            GlassCard(
              padding: const EdgeInsets.all(16),
              borderColor: Colors.white.withOpacity(0.04),
              child: Column(
                children: [
                  // Linha Calorias
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Calorias", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            "$totalCals / ${diet.caloriesGoal} kcal",
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      Text(
                        "${(calProgress * 100).toStringAsFixed(0)}%",
                        style: TextStyle(color: accentColor, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: calProgress,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 16),

                  // Linhas Macros (Proteína, Carbo, Gordura)
                  Row(
                    children: [
                      Expanded(child: _buildMacroBar("Proteínas", totalProt, diet.proteinGoal, protProgress, const Color(0xffff453a))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMacroBar("Carboidratos", totalCarbs, diet.carbsGoal, carbsProgress, const Color(0xffbf5af2))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMacroBar("Gorduras", totalFat, diet.fatGoal, fatProgress, const Color(0xffff9f0a))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Lista de Refeições
            const Text(
              "Refeições do Dia",
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),

            diet.meals.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        "Nenhuma refeição registrada hoje.",
                        style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: diet.meals.length,
                    itemBuilder: (context, index) {
                      final meal = diet.meals[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          borderColor: Colors.white.withOpacity(0.04),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          meal.name,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Text(
                                          meal.time,
                                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        _buildMiniMacroLabel("P", meal.protein, const Color(0xffff453a)),
                                        const SizedBox(width: 8),
                                        _buildMiniMacroLabel("C", meal.carbs, const Color(0xffbf5af2)),
                                        const SizedBox(width: 8),
                                        _buildMiniMacroLabel("G", meal.fat, const Color(0xffff9f0a)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Row(
                                children: [
                                  Text(
                                    "${meal.calories} kcal",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      provider.deleteMeal(meal.id);
                                    },
                                    child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBar(String name, double val, double goal, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(
          "${val.toStringAsFixed(1)}/${goal.toStringAsFixed(0)}g",
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white.withOpacity(0.05),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          borderRadius: BorderRadius.circular(2),
          minHeight: 4,
        ),
      ],
    );
  }

  Widget _buildMiniMacroLabel(String letter, double val, Color color) {
    return Row(
      children: [
        Text(
          letter,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 2),
        Text(
          "${val.toStringAsFixed(1)}g",
          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  void _openAddMealDialog(BuildContext context, TrackerProvider provider) {
    final nameCtrl = TextEditingController();
    final calsCtrl = TextEditingController();
    final protCtrl = TextEditingController();
    final carbsCtrl = TextEditingController();
    final fatCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xff1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text("Registrar Refeição", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _dialogInputDeco("Nome da Refeição (ex: Café da manhã)"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: calsCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _dialogInputDeco("Calorias (kcal)"),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: protCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: _dialogInputDeco("Prot (g)"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: carbsCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: _dialogInputDeco("Carb (g)"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: _dialogInputDeco("Gord (g)"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                final now = DateTime.now();
                final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
                provider.addMeal(
                  name,
                  int.tryParse(calsCtrl.text.trim()) ?? 0,
                  double.tryParse(protCtrl.text.trim()) ?? 0.0,
                  double.tryParse(carbsCtrl.text.trim()) ?? 0.0,
                  double.tryParse(fatCtrl.text.trim()) ?? 0.0,
                  timeStr,
                );
                Navigator.pop(dialogCtx);
              }
            },
            child: Text("Adicionar", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  InputDecoration _dialogInputDeco(String hint) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    );
  }
}

// ==========================================
// 2. ÁGUA TAB
// ==========================================
class AguaTab extends StatelessWidget {
  final Color accentColor;
  const AguaTab({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final diet = provider.state?.diet;

    if (diet == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final waterProgress = diet.waterGoalMl > 0 ? (diet.waterIntakeMl / diet.waterGoalMl).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Copo/Medidor visual
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Container de fundo que imita o copo
                Container(
                  width: 140,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20), top: Radius.circular(8)),
                    border: Border.all(color: Colors.white.withOpacity(0.12), width: 3),
                  ),
                ),
                // Água preenchida proporcionalmente (WaveCupWidget animado)
                WaveCupWidget(progress: waterProgress),
                // Texto central
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${diet.waterIntakeMl} ml",
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Meta: ${diet.waterGoalMl} ml",
                          style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Botões Rápidos
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.5,
              children: [
                _buildWaterAddBtn(provider, diet.waterIntakeMl, 150),
                _buildWaterAddBtn(provider, diet.waterIntakeMl, 250),
                _buildWaterAddBtn(provider, diet.waterIntakeMl, 350),
                _buildWaterAddBtn(provider, diet.waterIntakeMl, 500),
              ],
            ),
            const SizedBox(height: 24),

            // Resetar
            TextButton.icon(
              onPressed: () {
                provider.updateWaterIntake(0);
              },
              icon: const Icon(Icons.refresh, color: Colors.white54, size: 16),
              label: const Text("Zerar Consumo", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterAddBtn(TrackerProvider provider, int current, int val) {
    return ElevatedButton(
      onPressed: () {
        provider.updateWaterIntake(current + val);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        elevation: 0,
      ),
      child: Text(
        "+$val ml",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
      ),
    );
  }
}

// ==========================================
// 3. JEJUM TAB
// ==========================================
class JejumTab extends StatefulWidget {
  final Color accentColor;
  const JejumTab({super.key, required this.accentColor});

  @override
  State<JejumTab> createState() => _JejumTabState();
}

class _JejumTabState extends State<JejumTab> {
  Timer? _timer;
  late final ValueNotifier<Duration> _elapsedNotifier;
  double _selectedGoalHours = 16.0;

  @override
  void initState() {
    super.initState();
    _elapsedNotifier = ValueNotifier<Duration>(Duration.zero);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsedNotifier.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final provider = Provider.of<TrackerProvider>(context, listen: false);
      final active = provider.state?.diet.fasting.active;
      if (active != null) {
        try {
          final start = DateTime.parse(active.startTime);
          final now = DateTime.now().toUtc();
          _elapsedNotifier.value = now.difference(start);
        } catch (e) {
          // parse error
        }
      }
      if (provider.state?.diet.abstinence.isNotEmpty ?? false) {
        setState(() {});
      }
    });
  }

  Widget _buildFastingStageCard(Duration elapsed) {
    final hours = elapsed.inSeconds / 3600;
    String stageTitle = "";
    String stageDesc = "";
    Color stageColor = Colors.amber;

    if (hours < 2) {
      stageTitle = "Absorção de Nutrientes";
      stageDesc = "Seu corpo está digerindo a última refeição. Nível de açúcar sobe.";
      stageColor = Colors.blueAccent;
    } else if (hours < 12) {
      stageTitle = "Queda de Insulina";
      stageDesc = "A glicose diminui e o pâncreas reduz a liberação de insulina.";
      stageColor = Colors.cyan;
    } else if (hours < 18) {
      stageTitle = "Início de Cetose";
      stageDesc = "O glicogênio hepático se esgota. O corpo começa a queimar gordura.";
      stageColor = Colors.orangeAccent;
    } else if (hours < 24) {
      stageTitle = "Queima de Gordura Ativa";
      stageDesc = "A queima de gordura acelera. O hormônio do crescimento (GH) sobe.";
      stageColor = Colors.amber;
    } else {
      stageTitle = "Autofagia";
      stageDesc = "O corpo inicia a reciclagem de células velhas ou danificadas.";
      stageColor = Colors.greenAccent;
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        borderColor: stageColor.withOpacity(0.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: stageColor),
                ),
                const SizedBox(width: 8),
                Text(
                  "Fase: $stageTitle",
                  style: TextStyle(color: stageColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              stageDesc,
              style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularProtocols(Function(double) onSelected) {
    final protocols = [
      {"name": "12h Leve", "hours": 12.0},
      {"name": "14h Moderado", "hours": 14.0},
      {"name": "16h Padrão", "hours": 16.0},
      {"name": "18h Avançado", "hours": 18.0},
      {"name": "24h Completo", "hours": 24.0},
      {"name": "OMAD (23h)", "hours": 23.0},
    ];

    return Container(
      height: 32,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: protocols.length,
        itemBuilder: (context, idx) {
          final p = protocols[idx];
          final name = p["name"] as String;
          final h = p["hours"] as double;
          final isSel = _selectedGoalHours == h;

          return Container(
            margin: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(name),
              selected: isSel,
              selectedColor: widget.accentColor.withOpacity(0.2),
              disabledColor: Colors.transparent,
              backgroundColor: Colors.white.withOpacity(0.04),
              labelStyle: TextStyle(
                color: isSel ? widget.accentColor : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              onSelected: (selected) {
                if (selected) {
                  onSelected(h);
                }
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final diet = provider.state?.diet;

    if (diet == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final active = diet.fasting.active;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (active != null) ...[
              // JEJUM ATIVO
              GlassCard(
                padding: const EdgeInsets.all(20),
                borderColor: Colors.amber.withOpacity(0.25),
                child: Column(
                  children: [
                    const Text(
                      "Jejum em Andamento 🔥",
                      style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 20),

                    // Relógio e Barra de Progresso reativos
                    ValueListenableBuilder<Duration>(
                      valueListenable: _elapsedNotifier,
                      builder: (context, elapsed, child) {
                        final goalSecs = active.goalDurationHours * 3600;
                        final elapsedSecs = elapsed.inSeconds;
                        final progress = goalSecs > 0 ? (elapsedSecs / goalSecs).clamp(0.0, 1.0) : 0.0;

                        return Column(
                          children: [
                            Text(
                              _formatDuration(elapsed),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Meta: ${active.goalDurationHours.toStringAsFixed(0)} horas",
                              style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 16),

                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withOpacity(0.05),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                              borderRadius: BorderRadius.circular(4),
                              minHeight: 8,
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                "${(progress * 100).toStringAsFixed(0)}% concluído",
                                style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            _buildFastingStageCard(elapsed),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Botão Finalizar
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () {
                          provider.endFasting();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Jejum finalizado com sucesso!"),
                              backgroundColor: Colors.amber,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Finalizar Jejum",
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // CONFIGURAR JEJUM
              StatefulBuilder(
                builder: (context, setDialogState) {
                  return GlassCard(
                    padding: const EdgeInsets.all(20),
                    borderColor: Colors.white.withOpacity(0.04),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            "Iniciar Novo Jejum",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          "Protocolos Sugeridos",
                          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        _buildPopularProtocols((h) {
                          setDialogState(() {
                            _selectedGoalHours = h;
                          });
                        }),

                        const Text(
                          "Duração Meta",
                          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<double>(
                              value: _selectedGoalHours,
                              dropdownColor: const Color(0xff1c1c1e),
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              isExpanded: true,
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    _selectedGoalHours = val;
                                  });
                                }
                              },
                              items: [12.0, 14.0, 16.0, 18.0, 20.0, 23.0, 24.0, 36.0, 48.0]
                                  .map((h) => DropdownMenuItem(value: h, child: Text("$h horas")))
                                  .toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Botão Iniciar
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {
                              provider.startFasting(_selectedGoalHours);
                              _elapsedNotifier.value = Duration.zero;
                              _startTimer();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.accentColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Iniciar Jejum",
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 24),

            // SEÇÃO DE ABSTINÊNCIAS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Abstinências Ativas",
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                TextButton.icon(
                  onPressed: () => _showAddAbstinenceDialog(context, provider),
                  icon: Icon(Icons.add_circle_outline, color: widget.accentColor, size: 16),
                  label: Text("Nova", style: TextStyle(color: widget.accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                ),
              ],
            ),
            const SizedBox(height: 10),

            diet.abstinence.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        "Nenhuma abstinência registrada.",
                        style: TextStyle(color: Colors.white24, fontStyle: FontStyle.italic, fontSize: 12),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: diet.abstinence.length,
                    itemBuilder: (context, index) {
                      final a = diet.abstinence[index];
                      
                      Duration elapsed = Duration.zero;
                      try {
                        final start = DateTime.parse(a.startTime);
                        final now = DateTime.now().toUtc();
                        elapsed = now.difference(start);
                      } catch (e) {
                        // ignore
                      }

                      final days = elapsed.inDays;
                      final hours = elapsed.inHours.remainder(24);
                      final minutes = elapsed.inMinutes.remainder(60);
                      final seconds = elapsed.inSeconds.remainder(60);

                      String timeStr = "";
                      if (days > 0) {
                        timeStr += "$days ${days == 1 ? 'dia' : 'dias'}, ";
                      }
                      timeStr += "${hours}h ${minutes}m ${seconds}s";

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.all(12),
                          borderColor: Colors.white.withOpacity(0.04),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.title,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Tempo: $timeStr",
                                      style: TextStyle(color: widget.accentColor, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    if (a.notes != null && a.notes!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        a.notes!,
                                        style: const TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.refresh, color: Colors.amber, size: 18),
                                    tooltip: "Reiniciar contador",
                                    onPressed: () => _confirmResetAbstinence(context, provider, a),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                    tooltip: "Excluir rastreador",
                                    onPressed: () => provider.deleteAbstinence(a.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 24),

            // HISTÓRICO DE JEJUNS
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Histórico de Jejuns",
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 10),

            diet.fasting.history.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        "Nenhum jejum concluído no histórico.",
                        style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: diet.fasting.history.length,
                    itemBuilder: (context, index) {
                      final f = diet.fasting.history[index];
                      
                      Duration diff = Duration.zero;
                      try {
                        final start = DateTime.parse(f.startTime);
                        final end = DateTime.parse(f.endTime ?? '');
                        diff = end.difference(start);
                      } catch (e) {
                        // ignore
                      }

                      final goalHours = f.goalDurationHours;
                      final reached = diff.inSeconds >= (goalHours * 3600);
                      final startLocal = DateTime.tryParse(f.startTime)?.toLocal();
                      final dateStr = startLocal != null
                          ? "${startLocal.day.toString().padLeft(2, '0')}/${startLocal.month.toString().padLeft(2, '0')}"
                          : "";

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.all(12),
                          borderColor: reached ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        reached ? "Meta Cumprida 🎉" : "Jejum Incompleto ⚠️",
                                        style: TextStyle(
                                          color: reached ? Colors.green : Colors.redAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Data: $dateStr",
                                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Fasting de ${goalHours.toStringAsFixed(0)}h",
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                              Text(
                                _formatDurationShort(diff),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  void _showAddAbstinenceDialog(BuildContext context, TrackerProvider provider) {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xff1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text("Nova Abstinência", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                hintText: "O que você vai parar? (ex: Açúcar)",
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                hintText: "Notas / Motivação (Opcional)",
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final title = titleCtrl.text.trim();
              if (title.isNotEmpty) {
                provider.addAbstinence(title, notesCtrl.text.trim());
                Navigator.pop(dialogCtx);
              }
            },
            child: Text("Iniciar", style: TextStyle(color: widget.accentColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmResetAbstinence(BuildContext context, TrackerProvider provider, AbstinenceRecord a) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xff1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text("Zerar Contador?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        content: Text(
          "Deseja realmente reiniciar o tempo de '${a.title}'? O contador recomeçará do zero.",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              provider.resetAbstinence(a.id);
              Navigator.pop(dialogCtx);
            },
            child: const Text("Zerar", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  String _formatDurationShort(Duration d) {
    if (d.inHours > 0) {
      return "${d.inHours}h ${d.inMinutes.remainder(60)}m";
    }
    return "${d.inMinutes}m";
  }
}

// ==========================================
// WAVE CUP WIDGET & PAINTER
// ==========================================
class WaveCupWidget extends StatefulWidget {
  final double progress;
  const WaveCupWidget({super.key, required this.progress});

  @override
  State<WaveCupWidget> createState() => _WaveCupWidgetState();
}

class _WaveCupWidgetState extends State<WaveCupWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(134, 194),
          painter: WavePainter(
            progress: widget.progress,
            waveValue: _controller.value,
          ),
        );
      },
    );
  }
}

class WavePainter extends CustomPainter {
  final double progress;
  final double waveValue;

  WavePainter({required this.progress, required this.waveValue});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xff0a84ff).withOpacity(0.75),
          const Color(0xff30a2ff).withOpacity(0.50),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Altura base da água baseada no progresso
    final baseHeight = size.height * (1.0 - progress);
    
    // Desenhar a onda senoidal superior da água
    path.moveTo(0, size.height);
    path.lineTo(0, baseHeight);

    // Frequência e amplitude da onda
    const waveFrequency = 1.8 * 3.14159;
    final waveAmplitude = progress > 0.0 && progress < 1.0 ? 4.5 : 0.0;

    for (double x = 0; x <= size.width; x++) {
      final y = baseHeight + 
          waveAmplitude * 
          math.sin((x / size.width) * waveFrequency + (waveValue * 2 * math.pi));
      path.lineTo(x, y);
    }
    
    path.lineTo(size.width, size.height);
    path.close();

    // Recortar no formato arredondado inferior do copo
    final clipPath = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, 0, size.width, size.height),
          bottomLeft: const Radius.circular(16),
          bottomRight: const Radius.circular(16),
          topLeft: Radius.circular(progress >= 0.98 ? 8 : 4),
          topRight: Radius.circular(progress >= 0.98 ? 8 : 4),
        ),
      );

    canvas.save();
    canvas.clipPath(clipPath);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.waveValue != waveValue;
  }
}
