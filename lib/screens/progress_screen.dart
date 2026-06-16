import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tracker_provider.dart';
import '../models/workout_log.dart';
import '../models/medidas.dart';
import '../models/exercise.dart';
import '../widgets/glass_card.dart';
import '../widgets/profile_avatar.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with SingleTickerProviderStateMixin {
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
            Tab(text: "Diário"),
            Tab(text: "Recordes (PRs)"),
            Tab(text: "Medidas"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          HistoryTab(accentColor: accentColor),
          PrsTab(accentColor: accentColor),
          MedidasTab(accentColor: accentColor),
        ],
      ),
    );
  }
}

// ==========================================
// 1. DIÁRIO (HISTORY) TAB
// ==========================================
class HistoryTab extends StatefulWidget {
  final Color accentColor;
  const HistoryTab({Key? key, required this.accentColor}) : super(key: key);

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final Set<String> _expandedLogIds = {};

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final state = provider.state;

    if (state == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final history = state.history;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: history.isEmpty
          ? const Center(
              child: Text(
                "Nenhum treino no diário ainda.",
                style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final log = history[index];
                final isExpanded = _expandedLogIds.contains(log.id);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    borderColor: Colors.white.withOpacity(0.04),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cabeçalho básico (título e data)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedLogIds.remove(log.id);
                              } else {
                                _expandedLogIds.add(log.id);
                              }
                            });
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      log.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    isExpanded ? Icons.expand_less : Icons.expand_more,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    _formatLogDate(log.date),
                                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${(log.duration ~/ 60)} min",
                                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Volume: ${log.totalWeight.toStringAsFixed(0)}kg",
                                    style: TextStyle(color: widget.accentColor.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Detalhes expandidos
                        if (isExpanded) ...[
                          const Divider(color: Colors.white10, height: 20),
                          // Métricas gerais (RPE, Sono, Dores, etc.)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMetricItem("Esforço (RPE)", "${log.rpe}/10"),
                              _buildMetricItem("Séries Concl.", "${log.completedSets}/${log.totalSets}"),
                              _buildMetricItem("Sono", (log.recovery?.sleepOk ?? "ok").toUpperCase()),
                            ],
                          ),
                          if (log.recovery != null && log.recovery!.pain.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Text("Dores: ", style: TextStyle(color: Colors.white38, fontSize: 11)),
                                Wrap(
                                  spacing: 4,
                                  children: log.recovery!.pain.map((p) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      p,
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  )).toList(),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),

                          // Lista de exercícios concluídos
                          const Text(
                            "Exercícios Executados:",
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Column(
                            children: log.exercises.map((ex) {
                              final isCardio = ex.muscle.toLowerCase().contains('cardio');
                              final done = ex.completedSets;
                              
                              String subtitle = "";
                              if (isCardio) {
                                final doneCardios = (ex.performedCardios ?? []).where((c) => c != null).toList();
                                if (doneCardios.isNotEmpty) {
                                  subtitle = doneCardios.map((c) => "${c!.distanceKm.toStringAsFixed(1)}km em ${c.durationSeconds ~/ 60}m").join(', ');
                                } else {
                                  subtitle = "${ex.weight}km em ${ex.reps}min";
                                }
                              } else {
                                subtitle = "${ex.sets} séries x ${ex.reps} reps @ ${ex.weight.toStringAsFixed(1).replaceAll('.0', '')}kg";
                              }

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ex.name,
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            subtitle,
                                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: widget.accentColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "FEITO $done",
                                        style: TextStyle(color: widget.accentColor, fontSize: 9, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),

                          if (log.notes.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Notas da Sessão:", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    log.notes,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Excluir registro
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                _confirmDeleteLog(context, provider, log);
                              },
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                              label: const Text("Excluir Registro", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMetricItem(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }

  String _formatLogDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return isoString;
    }
  }

  void _confirmDeleteLog(BuildContext context, TrackerProvider provider, WorkoutLog log) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xff1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text("Excluir Log de Treino?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text("Deseja realmente deletar este registro de treino do seu histórico?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final state = provider.state!;
              final list = List<WorkoutLog>.from(state.history)..removeWhere((h) => h.id == log.id);
              provider.state!.history.clear();
              provider.state!.history.addAll(list);
              provider.saveState();
              Navigator.pop(dialogCtx);
              setState(() {});
            },
            child: const Text("Excluir", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 2. PRs (RECORDES PESSOAIS) TAB
// ==========================================
class PrsTab extends StatelessWidget {
  final Color accentColor;
  const PrsTab({Key? key, required this.accentColor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final state = provider.state;

    if (state == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final prs = state.prs;

    // Obter lista dos PRs com os nomes dos exercícios correspondentes
    final prItems = <Map<String, dynamic>>[];
    prs.forEach((exId, pr) {
      final ex = state.library.firstWhere(
        (l) => l.id == exId,
        orElse: () => LibraryExercise(id: '', name: 'Exercício Deletado', muscle: '', measurementType: 'reps'),
      );
      prItems.add({
        'exerciseName': ex.name,
        'muscle': ex.muscle,
        'measurementType': ex.measurementType,
        'weight': pr.weight,
        'reps': pr.reps,
        'date': pr.date,
        'routine': pr.routineName,
      });
    });

    // Ordenar PRs por nome do exercício
    prItems.sort((a, b) => a['exerciseName'].toLowerCase().compareTo(b['exerciseName'].toLowerCase()));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: prItems.isEmpty
          ? const Center(
              child: Text(
                "Nenhum recorde pessoal registrado ainda.",
                style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: prItems.length,
              itemBuilder: (context, index) {
                final item = prItems[index];
                final isCardio = item['muscle'].toLowerCase().contains('cardio');
                final dateStr = _formatPrDate(item['date']);

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
                              Text(
                                item['exerciseName'],
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${item['muscle']} • Conquistado em ${item['routine']}",
                                style: const TextStyle(color: Colors.white38, fontSize: 10),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Data: $dateStr",
                                style: const TextStyle(color: Colors.white24, fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: accentColor.withOpacity(0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isCardio
                                    ? "${item['weight'].toStringAsFixed(1)} km"
                                    : "${item['weight'].toStringAsFixed(1).replaceAll('.0', '')} kg",
                                style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 14),
                              ),
                              Text(
                                isCardio ? "${item['reps']} min" : "${item['reps']} reps",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatPrDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    } catch (e) {
      return isoString;
    }
  }
}

// ==========================================
// 3. MEDIDAS TAB
// ==========================================
class MedidasTab extends StatefulWidget {
  final Color accentColor;
  const MedidasTab({Key? key, required this.accentColor}) : super(key: key);

  @override
  State<MedidasTab> createState() => _MedidasTabState();
}

class _MedidasTabState extends State<MedidasTab> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final state = provider.state;

    if (state == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final measurements = List<BodyMeasurement>.from(state.medidas)
      ..sort((a, b) => b.date.compareTo(a.date)); // Mais recente primeiro

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _openAddMeasurementDialog(context, provider);
        },
        backgroundColor: widget.accentColor,
        mini: true,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: measurements.isEmpty
          ? const Center(
              child: Text(
                "Nenhum registro de medidas ainda.",
                style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: measurements.length,
              itemBuilder: (context, index) {
                final m = measurements[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    padding: const EdgeInsets.all(14),
                    borderColor: Colors.white.withOpacity(0.04),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatMedidaDate(m.date),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                provider.deleteMeasurement(m.id);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Grade de Medidas
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 3,
                          childAspectRatio: 2.2,
                          children: [
                            _buildMeasurementCell("Peso", "${m.peso} kg"),
                            _buildMeasurementCell("Gordura", "${m.gordura}%"),
                            _buildMeasurementCell("Pescoço", "${m.pescoco} cm"),
                            _buildMeasurementCell("Ombros", "${m.ombros} cm"),
                            _buildMeasurementCell("Peito", "${m.peito} cm"),
                            _buildMeasurementCell("Cintura", "${m.cintura} cm"),
                            _buildMeasurementCell("Quadril", "${m.quadril} cm"),
                            _buildMeasurementCell("Braço Dir/Esq", "${m.bracoDir}/${m.bracoEsq} cm"),
                            _buildMeasurementCell("Coxa Dir/Esq", "${m.coxaDir}/${m.coxaEsq} cm"),
                            _buildMeasurementCell("Pant. Dir/Esq", "${m.panturrilhaDir}/${m.panturrilhaEsq} cm"),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMeasurementCell(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 1),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatMedidaDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return "${parts[2]}/${parts[1]}/${parts[0]}";
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  void _openAddMeasurementDialog(BuildContext context, TrackerProvider provider) {
    final weightCtrl = TextEditingController();
    final fatCtrl = TextEditingController();
    final neckCtrl = TextEditingController();
    final shouldersCtrl = TextEditingController();
    final chestCtrl = TextEditingController();
    final waistCtrl = TextEditingController();
    final hipsCtrl = TextEditingController();
    final bEsqCtrl = TextEditingController();
    final bDirCtrl = TextEditingController();
    final cEsqCtrl = TextEditingController();
    final cDirCtrl = TextEditingController();
    final pEsqCtrl = TextEditingController();
    final pDirCtrl = TextEditingController();

    final dateStr = DateTime.now().toLocal().toString().substring(0, 10); // "YYYY-MM-DD"

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xff1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text("Registrar Medidas", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFormInput("Peso (kg)", weightCtrl),
                _buildFormInput("Gordura (%)", fatCtrl),
                _buildFormInput("Pescoço (cm)", neckCtrl),
                _buildFormInput("Ombros (cm)", shouldersCtrl),
                _buildFormInput("Peito (cm)", chestCtrl),
                _buildFormInput("Cintura (cm)", waistCtrl),
                _buildFormInput("Quadril (cm)", hipsCtrl),
                Row(
                  children: [
                    Expanded(child: _buildFormInput("Braço Esq (cm)", bEsqCtrl)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFormInput("Braço Dir (cm)", bDirCtrl)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildFormInput("Coxa Esq (cm)", cEsqCtrl)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFormInput("Coxa Dir (cm)", cDirCtrl)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildFormInput("Pant. Esq (cm)", pEsqCtrl)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFormInput("Pant. Dir (cm)", pDirCtrl)),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final m = BodyMeasurement(
                id: "med-${DateTime.now().millisecondsSinceEpoch}",
                date: dateStr,
                peso: double.tryParse(weightCtrl.text.trim()) ?? 0.0,
                gordura: double.tryParse(fatCtrl.text.trim()) ?? 0.0,
                pescoco: double.tryParse(neckCtrl.text.trim()) ?? 0.0,
                ombros: double.tryParse(shouldersCtrl.text.trim()) ?? 0.0,
                peito: double.tryParse(chestCtrl.text.trim()) ?? 0.0,
                cintura: double.tryParse(waistCtrl.text.trim()) ?? 0.0,
                quadril: double.tryParse(hipsCtrl.text.trim()) ?? 0.0,
                bracoEsq: double.tryParse(bEsqCtrl.text.trim()) ?? 0.0,
                bracoDir: double.tryParse(bDirCtrl.text.trim()) ?? 0.0,
                coxaEsq: double.tryParse(cEsqCtrl.text.trim()) ?? 0.0,
                coxaDir: double.tryParse(cDirCtrl.text.trim()) ?? 0.0,
                panturrilhaEsq: double.tryParse(pEsqCtrl.text.trim()) ?? 0.0,
                panturrilhaDir: double.tryParse(pDirCtrl.text.trim()) ?? 0.0,
              );
              provider.addMeasurement(m);
              Navigator.pop(dialogCtx);
              setState(() {});
            },
            child: Text("Registrar", style: TextStyle(color: widget.accentColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFormInput(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
        ),
      ),
    );
  }
}
