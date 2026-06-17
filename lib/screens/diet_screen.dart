import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tracker_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/profile_avatar.dart';

class DietScreen extends StatefulWidget {
  const DietScreen({Key? key}) : super(key: key);

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
    final provider = Provider.of<TrackerProvider>(context);
    final accentColor = ThemeUtils.getColor(provider.currentProfile.colorAccent);

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
  const RefeicoesTab({Key? key, required this.accentColor}) : super(key: key);

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
  const AguaTab({Key? key, required this.accentColor}) : super(key: key);

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
                // Água preenchida proporcionalmente
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 134,
                  height: 194 * waterProgress,
                  decoration: BoxDecoration(
                    color: const Color(0xff0a84ff).withOpacity(0.55),
                    borderRadius: BorderRadius.vertical(
                      bottom: const Radius.circular(16),
                      top: Radius.circular(waterProgress >= 0.98 ? 8 : 4),
                    ),
                  ),
                ),
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
  const JejumTab({Key? key, required this.accentColor}) : super(key: key);

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
      final active = Provider.of<TrackerProvider>(context, listen: false).state?.diet.fasting.active;
      if (active != null) {
        try {
          final start = DateTime.parse(active.startTime);
          final now = DateTime.now().toUtc();
          _elapsedNotifier.value = now.difference(start);
        } catch (e) {
          // parse error
        }
      }
    });
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
                      children: [
                        const Text(
                          "Iniciar Novo Jejum",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const SizedBox(height: 16),

                        // Dropdown horas
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
                              items: [12.0, 14.0, 16.0, 18.0, 20.0, 24.0, 36.0, 48.0]
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
                      
                      // Calcular duração
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
