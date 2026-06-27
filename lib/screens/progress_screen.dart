import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/tracker_provider.dart';
import '../models/workout_log.dart';
import '../models/medidas.dart';
import '../models/exercise.dart';
import '../widgets/glass_card.dart';
import '../widgets/profile_avatar.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

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
            Tab(text: "Histórico"),
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
  const HistoryTab({super.key, required this.accentColor});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class MonthGroup {
  final String key;
  final String name;
  final List<WorkoutLog> logs;

  MonthGroup({required this.key, required this.name, required this.logs});
}

class _HistoryTabState extends State<HistoryTab> {
  final Set<String> _expandedLogIds = {};
  final Set<String> _expandedMonths = {};
  bool _loadingHistory = false;
  bool _monthsInitialized = false;

  static const Map<int, String> _monthNames = {
    1: 'Janeiro',
    2: 'Fevereiro',
    3: 'Março',
    4: 'Abril',
    5: 'Maio',
    6: 'Junho',
    7: 'Julho',
    8: 'Agosto',
    9: 'Setembro',
    10: 'Outubro',
    11: 'Novembro',
    12: 'Dezembro',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
    });
    final provider = Provider.of<TrackerProvider>(context, listen: false);
    await provider.loadWorkoutHistory();
    if (mounted) {
      setState(() {
        _loadingHistory = false;
      });
      _initializeExpandedMonths(provider.state?.history ?? []);
    }
  }

  void _initializeExpandedMonths(List<WorkoutLog> history) {
    if (_monthsInitialized || history.isEmpty) return;
    final sortedHistory = List<WorkoutLog>.from(history)
      ..sort((a, b) {
        final ad = DateTime.tryParse(a.date) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = DateTime.tryParse(b.date) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
    if (sortedHistory.isNotEmpty) {
      final firstLog = sortedHistory.first;
      final date = DateTime.tryParse(firstLog.date)?.toLocal() ?? DateTime.now();
      final mostRecentKey = "${date.year}-${date.month.toString().padLeft(2, '0')}";
      _expandedMonths.add(mostRecentKey);
      _monthsInitialized = true;
    }
  }

  List<MonthGroup> _groupHistory(List<WorkoutLog> history) {
    final Map<String, List<WorkoutLog>> grouped = {};
    final sortedHistory = List<WorkoutLog>.from(history)
      ..sort((a, b) {
        final ad = DateTime.tryParse(a.date) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = DateTime.tryParse(b.date) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

    for (final log in sortedHistory) {
      final date = DateTime.tryParse(log.date)?.toLocal() ?? DateTime.now();
      final key = "${date.year}-${date.month.toString().padLeft(2, '0')}";
      grouped.putIfAbsent(key, () => []).add(log);
    }

    final List<MonthGroup> groups = [];
    grouped.forEach((key, logs) {
      final parts = key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final monthName = _monthNames[month] ?? '';
      groups.add(MonthGroup(
        key: key,
        name: "$monthName de $year",
        logs: logs,
      ));
    });

    // Sort chronologically descending
    groups.sort((a, b) => b.key.compareTo(a.key));
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final state = provider.state;

    if (state == null || _loadingHistory) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final history = state.history;
    if (!_monthsInitialized && history.isNotEmpty) {
      _initializeExpandedMonths(history);
    }
    final monthGroups = _groupHistory(history);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton(
          onPressed: () {
            _openAddManualLogDialog(context, provider);
          },
          backgroundColor: widget.accentColor,
          mini: true,
          child: const Icon(Icons.add_task, color: Colors.black),
        ),
      ),
      body: monthGroups.isEmpty
          ? const Center(
              child: Text(
                "Nenhum treino no diário ainda.",
                style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
              itemCount: monthGroups.length,
              itemBuilder: (context, groupIndex) {
                final group = monthGroups[groupIndex];
                final isMonthExpanded = _expandedMonths.contains(group.key);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabeçalho do Mês
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isMonthExpanded) {
                            _expandedMonths.remove(group.key);
                          } else {
                            _expandedMonths.add(group.key);
                          }
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        margin: const EdgeInsets.only(top: 8, bottom: 8),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  group.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: widget.accentColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "${group.logs.length} ${group.logs.length == 1 ? 'treino' : 'treinos'}",
                                    style: TextStyle(
                                      color: widget.accentColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              isMonthExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: Colors.white54,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (isMonthExpanded) ...[
                      ...group.logs.map((log) {
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
                                          if (log.avgHeartRate != null) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              "❤️ ${log.avgHeartRate} bpm",
                                              style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                          if (log.activeCalories != null) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              "🔥 ${log.activeCalories} kcal",
                                              style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ],
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
                                  if (log.avgHeartRate != null || log.activeCalories != null) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (log.avgHeartRate != null)
                                          _buildMetricItem("Média Cardíaca", "${log.avgHeartRate} bpm")
                                        else
                                          const SizedBox(width: 80),
                                        if (log.activeCalories != null)
                                          _buildMetricItem("Calorias Ativas", "${log.activeCalories} kcal")
                                        else
                                          const SizedBox(width: 80),
                                        const SizedBox(width: 80), // Alinhador para manter 3 colunas
                                      ],
                                    ),
                                  ],
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

                                      final failedSets = <String>[];
                                      if (ex.failureReport != null) {
                                        for (int i = 0; i < ex.failureReport!.length; i++) {
                                          if (ex.failureReport![i]) {
                                            final rep = (ex.failureReps != null && ex.failureReps!.length > i) ? ex.failureReps![i] : null;
                                            failedSets.add("S${i+1}${rep != null ? ' (Rep $rep)' : ''}");
                                          }
                                        }
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
                                                  RichText(
                                                    text: TextSpan(
                                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                                      children: [
                                                        TextSpan(text: subtitle),
                                                        if (failedSets.isNotEmpty) ...[
                                                          const TextSpan(text: " • "),
                                                          TextSpan(
                                                            text: "Falha: ${failedSets.join(', ')}",
                                                            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
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
                      }),
                    ],
                  ],
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
              provider.deleteWorkoutLog(log.id);
              Navigator.pop(dialogCtx);
              setState(() {});
            },
            child: const Text("Excluir", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openAddManualLogDialog(BuildContext context, TrackerProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ManualWorkoutLogSheet(provider: provider),
    );
  }
}

// ==========================================
// FORMULÁRIO DE LOG MANUAL (SHEET)
// ==========================================
class ManualWorkoutLogSheet extends StatefulWidget {
  final TrackerProvider provider;
  const ManualWorkoutLogSheet({super.key, required this.provider});

  @override
  State<ManualWorkoutLogSheet> createState() => _ManualWorkoutLogSheetState();
}

class _ManualWorkoutLogSheetState extends State<ManualWorkoutLogSheet> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  LibraryExercise? _selectedExercise;
  
  int _setsCount = 3;
  int _repsCount = 10;
  double _weightVal = 0.0;
  int _rpe = 8;
  final _notesCtrl = TextEditingController();

  List<bool> _setsCompleted = List.filled(3, true);
  List<double> _setsWeights = List.filled(3, 0.0);
  List<int> _setsReps = List.filled(3, 10);
  List<bool> _setsFailures = List.filled(3, false);
  List<int?> _setsFailureReps = List.filled(3, null);

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _updateSetsLists(int newCount) {
    if (newCount <= 0) return;
    setState(() {
      _setsCount = newCount;
      _setsCompleted = List.generate(newCount, (i) => i < _setsCompleted.length ? _setsCompleted[i] : true);
      _setsWeights = List.generate(newCount, (i) => i < _setsWeights.length ? _setsWeights[i] : _weightVal);
      _setsReps = List.generate(newCount, (i) => i < _setsReps.length ? _setsReps[i] : _repsCount);
      _setsFailures = List.generate(newCount, (i) => i < _setsFailures.length ? _setsFailures[i] : false);
      _setsFailureReps = List.generate(newCount, (i) => i < _setsFailureReps.length ? _setsFailureReps[i] : null);
    });
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: ThemeUtils.getColor(widget.provider.currentProfile.colorAccent),
            surface: const Color(0xff1c1c1e),
          ),
        ),
        child: child!,
      ),
    );
    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
        builder: (context, child) => Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: ThemeUtils.getColor(widget.provider.currentProfile.colorAccent),
              surface: const Color(0xff1c1c1e),
            ),
          ),
          child: child!,
        ),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = widget.provider.state!.library;
    final sortedLibrary = List<LibraryExercise>.from(library)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final accentColor = ThemeUtils.getColor(widget.provider.currentProfile.colorAccent);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff1c1c1e).withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  margin: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const Text(
                "Registrar Exercício Externo",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 16),

              // Data/Hora
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Data e Hora", style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(
                        "${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year} ${_selectedDate.hour.toString().padLeft(2, '0')}:${_selectedDate.minute.toString().padLeft(2, '0')}",
                        style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Exercício Dropdown
              const Text("Exercício da Biblioteca", style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<LibraryExercise>(
                    value: _selectedExercise,
                    hint: const Text("Selecione um exercício...", style: TextStyle(color: Colors.white30, fontSize: 13)),
                    dropdownColor: const Color(0xff1c1c1e),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    isExpanded: true,
                    onChanged: (val) {
                      setState(() {
                        _selectedExercise = val;
                        if (val != null) {
                          _repsCount = val.measurementType == 'time' ? 45 : 10;
                          _updateSetsLists(_setsCount);
                        }
                      });
                    },
                    items: sortedLibrary
                        .map((ex) => DropdownMenuItem(
                              value: ex,
                              child: Text("${ex.name} (${ex.muscle})"),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (_selectedExercise != null) ...[
                // Config Gerais
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Séries", style: TextStyle(color: Colors.white54, fontSize: 10)),
                          const SizedBox(height: 4),
                          TextFormField(
                            initialValue: _setsCount.toString(),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                            onChanged: (val) {
                              final count = int.tryParse(val) ?? 3;
                              _updateSetsLists(count);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedExercise!.measurementType == 'time' ? "Tempo (s)" : "Reps Padrão",
                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            initialValue: _repsCount.toString(),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                            onChanged: (val) {
                              final reps = int.tryParse(val) ?? 10;
                              setState(() {
                                _repsCount = reps;
                                for (int i = 0; i < _setsReps.length; i++) {
                                  _setsReps[i] = reps;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (!_selectedExercise!.muscle.toLowerCase().contains('cardio'))
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Carga Padrão (kg)", style: TextStyle(color: Colors.white54, fontSize: 10)),
                            const SizedBox(height: 4),
                            TextFormField(
                              initialValue: _weightVal.toString(),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                              onChanged: (val) {
                                final w = double.tryParse(val) ?? 0.0;
                                setState(() {
                                  _weightVal = w;
                                  for (int i = 0; i < _setsWeights.length; i++) {
                                    _setsWeights[i] = w;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Lista de Séries Customizadas
                const Text("Detalhamento por Série:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _setsCount,
                  itemBuilder: (context, idx) {
                    final isCardio = _selectedExercise!.muscle.toLowerCase().contains('cardio');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          Text("S${idx + 1}", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          
                          // Input Reps / Tempo
                          Expanded(
                            child: TextFormField(
                              initialValue: _setsReps[idx].toString(),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.04),
                                isDense: true,
                                contentPadding: const EdgeInsets.all(6),
                                labelText: isCardio ? "Minutos" : (_selectedExercise!.measurementType == 'time' ? "Segs" : "Reps"),
                                labelStyle: const TextStyle(fontSize: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                              ),
                              onChanged: (val) {
                                final r = int.tryParse(val) ?? 10;
                                _setsReps[idx] = r;
                              },
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Input Carga (Musculação) ou Distância (Cardio)
                          Expanded(
                            child: TextFormField(
                              initialValue: isCardio ? "0.0" : _setsWeights[idx].toString(),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.04),
                                isDense: true,
                                contentPadding: const EdgeInsets.all(6),
                                labelText: isCardio ? "Km" : "Carga",
                                labelStyle: const TextStyle(fontSize: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                              ),
                              onChanged: (val) {
                                final w = double.tryParse(val) ?? 0.0;
                                _setsWeights[idx] = w;
                              },
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Falha (apenas musculação)
                          if (!isCardio) ...[
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _setsFailures[idx] = !_setsFailures[idx];
                                  if (!_setsFailures[idx]) {
                                    _setsFailureReps[idx] = null;
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _setsFailures[idx] ? Colors.redAccent.withOpacity(0.15) : Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _setsFailures[idx] ? Colors.redAccent : Colors.white.withOpacity(0.08)),
                                ),
                                child: const Text(
                                  "Falha",
                                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            if (_setsFailures[idx]) ...[
                              const SizedBox(width: 4),
                              Container(
                                width: 28,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: TextFormField(
                                  initialValue: _setsFailureReps[idx]?.toString() ?? "",
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    isDense: true,
                                    hintText: "-",
                                    hintStyle: TextStyle(color: Colors.white24),
                                  ),
                                  onChanged: (val) {
                                    _setsFailureReps[idx] = int.tryParse(val);
                                  },
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(width: 4),

                          // Checkbox Concluída
                          Checkbox(
                            value: _setsCompleted[idx],
                            activeColor: accentColor,
                            onChanged: (val) {
                              setState(() {
                                _setsCompleted[idx] = val ?? true;
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // RPE e Notas
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Esforço (RPE 1-10)", style: TextStyle(color: Colors.white54, fontSize: 11)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _rpe,
                                dropdownColor: const Color(0xff1c1c1e),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                isExpanded: true,
                                onChanged: (val) {
                                  if (val != null) setState(() => _rpe = val);
                                },
                                items: List.generate(10, (i) => i + 1)
                                    .map((v) => DropdownMenuItem(value: v, child: Text("$v / 10")))
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    hintText: "Observações / Notas do Treino (opcional)",
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),

                // Botão Salvar
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate() && _selectedExercise != null) {
                        final isCardio = _selectedExercise!.muscle.toLowerCase().contains('cardio');
                        final completedCount = _setsCompleted.where((s) => s).length;
                        if (completedCount == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Marque pelo menos uma série como concluída!"),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        // Construir as sub-séries feitas
                        List<PerformedCardio?>? cardios;
                        if (isCardio) {
                          cardios = [];
                          for (int i = 0; i < _setsCount; i++) {
                            if (_setsCompleted[i]) {
                              cardios.add(PerformedCardio(
                                distanceKm: _setsWeights[i],
                                durationSeconds: _setsReps[i] * 60,
                              ));
                            } else {
                              cardios.add(null);
                            }
                          }
                        }

                        double totalWeight = 0.0;
                        int repsVal = 0;
                        double weightVal = 0.0;
                        int sumReps = 0;
                        double sumWeight = 0.0;
                        int countSets = 0;

                        for (int i = 0; i < _setsCount; i++) {
                          if (_setsCompleted[i]) {
                            countSets++;
                            sumReps += _setsReps[i];
                            sumWeight += _setsWeights[i];
                            if (!isCardio) {
                              totalWeight += _setsWeights[i] * _setsReps[i];
                            }
                          }
                        }

                        if (countSets > 0) {
                          repsVal = sumReps ~/ countSets;
                          weightVal = sumWeight / countSets;
                        }

                        final logExercise = LogExercise(
                          name: _selectedExercise!.name,
                          muscle: _selectedExercise!.muscle,
                          sets: _setsCount,
                          completedSets: completedCount,
                          reps: repsVal,
                          weight: weightVal,
                          performedCardios: cardios,
                          rpe: _rpe,
                          failureReport: _setsFailures,
                          failureReps: _setsFailureReps,
                          executionType: _selectedExercise!.executionType,
                        );

                        final manualLog = WorkoutLog(
                          id: "manual-${DateTime.now().millisecondsSinceEpoch}",
                          name: "${_selectedExercise!.name} (Externo)",
                          date: _selectedDate.toUtc().toIso8601String(),
                          duration: isCardio ? (sumReps * 60) : 1800, // 30 mins para musculação por padrão
                          completedSets: completedCount,
                          totalSets: _setsCount,
                          totalWeight: totalWeight,
                          rpe: _rpe,
                          notes: _notesCtrl.text.trim(),
                          exercises: [logExercise],
                        );

                        widget.provider.addManualWorkoutLog(manualLog);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Registrar no Histórico", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      "Selecione um exercício acima para configurar as séries.",
                      style: TextStyle(color: Colors.white24, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. PRs (RECORDES PESSOAIS) TAB
// ==========================================
class PrsTab extends StatefulWidget {
  final Color accentColor;
  const PrsTab({super.key, required this.accentColor});

  @override
  State<PrsTab> createState() => _PrsTabState();
}

class _PrsTabState extends State<PrsTab> {
  String? _selectedExerciseId;
  bool _showVolume = false; // false = 1RM, true = Volume

  void _showDeletePrDialog(BuildContext context, TrackerProvider provider, String exerciseId, String exerciseName) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xff1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text("Excluir Recorde?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("Deseja realmente excluir o recorde pessoal de '$exerciseName'?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              provider.deletePersonalRecord(exerciseId);
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Recorde de '$exerciseName' excluído."),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            child: const Text("Excluir", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
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

  Widget _buildTabButton(String label, bool active) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showVolume = (label == "Volume");
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? widget.accentColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? widget.accentColor : Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? widget.accentColor : Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard(
    BuildContext context, 
    List<LibraryExercise> strengthExercises, 
    List<Map<String, dynamic>> chartData, 
    List<FlSpot> spots
  ) {
    final selectedEx = strengthExercises.firstWhere(
      (e) => e.id == _selectedExerciseId,
      orElse: () => LibraryExercise(id: '', name: '', muscle: '', measurementType: 'reps'),
    );

    return GlassCard(
      borderColor: Colors.white.withOpacity(0.04),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "ANÁLISE DE EVOLUÇÃO",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              Row(
                children: [
                  _buildTabButton("1RM", !_showVolume),
                  const SizedBox(width: 4),
                  _buildTabButton("Volume", _showVolume),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedExerciseId,
                dropdownColor: const Color(0xff1c1c1e),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                isExpanded: true,
                onChanged: (val) {
                  setState(() {
                    _selectedExerciseId = val;
                  });
                },
                items: strengthExercises.map((ex) => DropdownMenuItem<String>(
                  value: ex.id,
                  child: Text(ex.name),
                )).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          if (spots.isEmpty)
            Container(
              height: 130,
              alignment: Alignment.center,
              child: Text(
                "Sem histórico registrado para '${selectedEx.name}'",
                style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 130,
                  child: LineChart(
                    LineChartData(
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          tooltipBgColor: const Color(0xff2c2c2e),
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final dataPoint = chartData[spot.x.toInt()];
                              final date = dataPoint['date'] as DateTime;
                              final val = spot.y.toStringAsFixed(1);
                              final suffix = _showVolume ? " kg" : " kg (1RM)";
                              return LineTooltipItem(
                                "${date.day}/${date.month}\n$val$suffix",
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        drawHorizontalLine: true,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.white.withOpacity(0.03),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        ),
                        getDrawingVerticalLine: (value) => FlLine(
                          color: Colors.white.withOpacity(0.03),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        ),
                      ),
                      titlesData: const FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: widget.accentColor,
                          barWidth: 4,
                          isStrokeCapRound: true,
                          shadow: Shadow(
                            color: widget.accentColor.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                              radius: 3.5,
                              color: widget.accentColor,
                              strokeColor: Colors.white,
                              strokeWidth: 1.5,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                widget.accentColor.withOpacity(0.22),
                                widget.accentColor.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Antigo",
                      style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _showVolume ? "Evolução do Volume Total" : "Evolução da Força Máxima (1RM)",
                      style: TextStyle(color: widget.accentColor.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      "Recente",
                      style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

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
        'exerciseId': exId,
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

    // Filtrar exercícios de força da biblioteca
    final strengthExercises = state.library.where((e) => !e.muscle.toLowerCase().contains('cardio')).toList();

    if (_selectedExerciseId == null && strengthExercises.isNotEmpty) {
      _selectedExerciseId = strengthExercises.first.id;
    }

    final selectedEx = _selectedExerciseId != null
        ? strengthExercises.firstWhere((e) => e.id == _selectedExerciseId, orElse: () => strengthExercises.first)
        : null;

    final chartData = <Map<String, dynamic>>[];
    final List<FlSpot> spots = [];

    if (selectedEx != null) {
      final chronologicalHistory = state.history.reversed.toList();
      for (final log in chronologicalHistory) {
        final logExs = log.exercises.where((e) => e.name == selectedEx.name);
        for (final ex in logExs) {
          if (ex.completedSets > 0 && ex.reps > 0 && ex.weight > 0) {
            final double oneRepMax = ex.weight / (1.0278 - (0.0278 * ex.reps));
            final double totalVolume = ex.weight * ex.reps * ex.completedSets;
            
            chartData.add({
              'date': DateTime.tryParse(log.date) ?? DateTime.now(),
              '1rm': oneRepMax,
              'volume': totalVolume,
            });
          }
        }
      }

      for (int i = 0; i < chartData.length; i++) {
        final double val = _showVolume ? chartData[i]['volume'] : chartData[i]['1rm'];
        spots.add(FlSpot(i.toDouble(), val));
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
        children: [
          if (strengthExercises.isNotEmpty) ...[
            _buildChartCard(context, strengthExercises, chartData, spots),
            const SizedBox(height: 16),
          ],
          
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              "SEUS RECORDES PESSOAIS",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          
          if (prItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  "Nenhum recorde pessoal registrado ainda.",
                  style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            ...prItems.map((item) {
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: widget.accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: widget.accentColor.withOpacity(0.25)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  isCardio
                                      ? "${item['weight'].toStringAsFixed(1)} km"
                                      : "${item['weight'].toStringAsFixed(1).replaceAll('.0', '')} kg",
                                  style: TextStyle(color: widget.accentColor, fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                                Text(
                                  isCardio ? "${item['reps']} min" : "${item['reps']} reps",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () {
                              _showDeletePrDialog(context, provider, item['exerciseId'], item['exerciseName']);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ==========================================
// 3. MEDIDAS TAB
// ==========================================
class MedidasTab extends StatefulWidget {
  final Color accentColor;
  const MedidasTab({super.key, required this.accentColor});

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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton(
          onPressed: () {
            _openAddMeasurementDialog(context, provider);
          },
          backgroundColor: widget.accentColor,
          mini: true,
          child: const Icon(Icons.add, color: Colors.black),
        ),
      ),
      body: measurements.isEmpty
          ? const Center(
              child: Text(
                "Nenhum registro de medidas ainda.",
                style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
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
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit_outlined, color: widget.accentColor, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    _openEditMeasurementDialog(context, provider, m);
                                  },
                                ),
                                const SizedBox(width: 12),
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
                            _buildMeasurementCell("Abdômen", "${m.abdomen} cm"),
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
    final abdomenCtrl = TextEditingController();
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
                _buildFormInput("Abdômen (cm)", abdomenCtrl),
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
                abdomen: double.tryParse(abdomenCtrl.text.trim()) ?? 0.0,
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

  void _openEditMeasurementDialog(BuildContext context, TrackerProvider provider, BodyMeasurement measurement) {
    String valStr(double val) => val == 0.0 ? "" : val.toString();

    final weightCtrl = TextEditingController(text: valStr(measurement.peso));
    final fatCtrl = TextEditingController(text: valStr(measurement.gordura));
    final neckCtrl = TextEditingController(text: valStr(measurement.pescoco));
    final shouldersCtrl = TextEditingController(text: valStr(measurement.ombros));
    final chestCtrl = TextEditingController(text: valStr(measurement.peito));
    final waistCtrl = TextEditingController(text: valStr(measurement.cintura));
    final abdomenCtrl = TextEditingController(text: valStr(measurement.abdomen));
    final hipsCtrl = TextEditingController(text: valStr(measurement.quadril));
    final bEsqCtrl = TextEditingController(text: valStr(measurement.bracoEsq));
    final bDirCtrl = TextEditingController(text: valStr(measurement.bracoDir));
    final cEsqCtrl = TextEditingController(text: valStr(measurement.coxaEsq));
    final cDirCtrl = TextEditingController(text: valStr(measurement.coxaDir));
    final pEsqCtrl = TextEditingController(text: valStr(measurement.panturrilhaEsq));
    final pDirCtrl = TextEditingController(text: valStr(measurement.panturrilhaDir));

    final dateCtrl = TextEditingController(text: measurement.date);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xff1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text("Editar Medidas", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFormInput("Data (AAAA-MM-DD)", dateCtrl),
                _buildFormInput("Peso (kg)", weightCtrl),
                _buildFormInput("Gordura (%)", fatCtrl),
                _buildFormInput("Pescoço (cm)", neckCtrl),
                _buildFormInput("Ombros (cm)", shouldersCtrl),
                _buildFormInput("Peito (cm)", chestCtrl),
                _buildFormInput("Cintura (cm)", waistCtrl),
                _buildFormInput("Abdômen (cm)", abdomenCtrl),
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
                id: measurement.id,
                date: dateCtrl.text.trim().isNotEmpty ? dateCtrl.text.trim() : measurement.date,
                peso: double.tryParse(weightCtrl.text.trim()) ?? 0.0,
                gordura: double.tryParse(fatCtrl.text.trim()) ?? 0.0,
                pescoco: double.tryParse(neckCtrl.text.trim()) ?? 0.0,
                ombros: double.tryParse(shouldersCtrl.text.trim()) ?? 0.0,
                peito: double.tryParse(chestCtrl.text.trim()) ?? 0.0,
                cintura: double.tryParse(waistCtrl.text.trim()) ?? 0.0,
                abdomen: double.tryParse(abdomenCtrl.text.trim()) ?? 0.0,
                quadril: double.tryParse(hipsCtrl.text.trim()) ?? 0.0,
                bracoEsq: double.tryParse(bEsqCtrl.text.trim()) ?? 0.0,
                bracoDir: double.tryParse(bDirCtrl.text.trim()) ?? 0.0,
                coxaEsq: double.tryParse(cEsqCtrl.text.trim()) ?? 0.0,
                coxaDir: double.tryParse(cDirCtrl.text.trim()) ?? 0.0,
                panturrilhaEsq: double.tryParse(pEsqCtrl.text.trim()) ?? 0.0,
                panturrilhaDir: double.tryParse(pDirCtrl.text.trim()) ?? 0.0,
              );
              provider.updateMeasurement(m);
              Navigator.pop(dialogCtx);
              setState(() {});
            },
            child: Text("Salvar", style: TextStyle(color: widget.accentColor, fontWeight: FontWeight.bold)),
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
