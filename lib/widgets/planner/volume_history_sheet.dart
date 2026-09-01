import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/tracker_provider.dart';

class VolumeHistorySheet extends StatefulWidget {
  final Color accentColor;
  const VolumeHistorySheet({super.key, required this.accentColor});

  @override
  State<VolumeHistorySheet> createState() => _VolumeHistorySheetState();
}

class _VolumeHistorySheetState extends State<VolumeHistorySheet> {
  List<String> _muscles = [];
  Map<String, double> _avgSetsPerWeek = {};
  
  @override
  void initState() {
    super.initState();
    _calculateHistory();
  }
  
  void _calculateHistory() {
    final provider = Provider.of<TrackerProvider>(context, listen: false);
    final history = provider.state?.history ?? [];
    
    // We will look at the last 28 days (4 weeks)
    final now = DateTime.now();
    final Map<String, int> totalSets = {};
    
    for (var log in history) {
      final logDate = DateTime.tryParse(log.date);
      if (logDate == null) continue;
      
      final daysAgo = now.difference(logDate).inDays;
      if (daysAgo <= 28 && daysAgo >= 0) {
        for (var ex in log.exercises) {
          if (ex.muscle.toLowerCase().contains("cardio") || ex.muscle.toLowerCase().contains("outros")) continue;
          
          totalSets[ex.muscle] = (totalSets[ex.muscle] ?? 0) + ex.completedSets;
        }
      }
    }
    
    _avgSetsPerWeek = {};
    totalSets.forEach((key, value) {
      _avgSetsPerWeek[key] = value / 4.0;
    });
    
    _muscles = _avgSetsPerWeek.keys.toList();
    _muscles.sort((a, b) => (_avgSetsPerWeek[b] ?? 0).compareTo(_avgSetsPerWeek[a] ?? 0));
    
    if (_muscles.length > 7) {
      _muscles = _muscles.sublist(0, 7); // Show top 7 muscles in radar to avoid clutter
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const Text("Histórico de Volume", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text("Média semanal (Últimas 4 semanas)", style: TextStyle(color: Colors.white54, fontSize: 13)),
          
          const SizedBox(height: 24),
          
          if (_muscles.isEmpty)
            const Expanded(
              child: Center(
                child: Text("Sem dados suficientes de treinos recentes.", style: TextStyle(color: Colors.white54)),
              ),
            )
          else ...[
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: RadarChart(
                  RadarChartData(
                    radarBackgroundColor: Colors.transparent,
                    radarBorderData: const BorderSide(color: Colors.white12, width: 1),
                    tickBorderData: const BorderSide(color: Colors.white12, width: 1),
                    gridBorderData: const BorderSide(color: Colors.white12, width: 1),
                    ticksTextStyle: const TextStyle(color: Colors.transparent),
                    tickCount: 3,
                    getTitle: (index, angle) {
                      return RadarChartTitle(
                        text: _muscles[index],
                        angle: 0,
                      );
                    },
                    dataSets: [
                      RadarDataSet(
                        fillColor: widget.accentColor.withOpacity(0.3),
                        borderColor: widget.accentColor,
                        entryRadius: 3,
                        dataEntries: _muscles.map((m) => RadarEntry(value: _avgSetsPerWeek[m]!)).toList(),
                      ),
                      // Ideal target zone (20 sets) as a background reference
                      RadarDataSet(
                        fillColor: Colors.green.withOpacity(0.05),
                        borderColor: Colors.green.withOpacity(0.3),
                        entryRadius: 0,
                        dataEntries: _muscles.map((m) => const RadarEntry(value: 20)).toList(),
                      ),
                      // Ideal target zone (10 sets) as a background reference
                      RadarDataSet(
                        fillColor: const Color(0xFF141414), // Mask the center
                        borderColor: Colors.green.withOpacity(0.3),
                        entryRadius: 0,
                        dataEntries: _muscles.map((m) => const RadarEntry(value: 10)).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(Icons.circle, color: Colors.green, size: 12),
                  SizedBox(width: 8),
                  Text("Zona Ideal (10 a 20 séries/semana)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(Icons.circle, color: widget.accentColor, size: 12),
                  const SizedBox(width: 8),
                  const Text("Sua Média Real", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            Expanded(
              flex: 2,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _muscles.length,
                itemBuilder: (ctx, i) {
                  final m = _muscles[i];
                  final val = _avgSetsPerWeek[m]!;
                  Color c = Colors.orangeAccent;
                  if (val >= 10 && val <= 20) c = Colors.greenAccent;
                  if (val > 20) c = Colors.redAccent;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(m, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        Text("${val.toStringAsFixed(1)} séries/sem", style: TextStyle(color: c, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ]
        ],
      ),
    );
  }
}
