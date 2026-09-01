import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/tracker_provider.dart';

class WeekData {
  final String title;
  final String shortTitle;
  final String dateRange;
  final DateTime start;
  final DateTime end;
  final Map<String, int> muscleSets;

  WeekData({
    required this.title,
    required this.shortTitle,
    required this.dateRange,
    required this.start,
    required this.end,
    required this.muscleSets,
  });
}

class VolumeHistorySheet extends StatefulWidget {
  final Color accentColor;
  const VolumeHistorySheet({super.key, required this.accentColor});

  @override
  State<VolumeHistorySheet> createState() => _VolumeHistorySheetState();
}

class _VolumeHistorySheetState extends State<VolumeHistorySheet> {
  // -1 means "Média 4 sem", 0 = Semana Atual, 1 = Sem. Passada, 2 = 2 sem atrás, 3 = 3 sem atrás
  int _selectedWeekIndex = -1;

  List<String> _allMuscles = [];
  Map<String, double> _avgSetsPerWeek = {};
  List<WeekData> _weeks = [];

  @override
  void initState() {
    super.initState();
    _calculateHistory();
  }

  void _calculateHistory() {
    final provider = Provider.of<TrackerProvider>(context, listen: false);
    final history = provider.state?.history ?? [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Monday of current week
    final mondayThisWeek = today.subtract(Duration(days: (now.weekday - 1)));

    _weeks = [];
    final labels = [
      {"title": "Semana Atual", "short": "Atual"},
      {"title": "Semana Passada", "short": "Sem -1"},
      {"title": "2 Semanas Atrás", "short": "Sem -2"},
      {"title": "3 Semanas Atrás", "short": "Sem -3"},
    ];

    for (int i = 0; i < 4; i++) {
      final start = mondayThisWeek.subtract(Duration(days: i * 7));
      final end = start.add(const Duration(days: 7));
      final endDisplay = start.add(const Duration(days: 6));

      final dateRangeStr =
          "${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')} a ${endDisplay.day.toString().padLeft(2, '0')}/${endDisplay.month.toString().padLeft(2, '0')}";

      _weeks.add(
        WeekData(
          title: labels[i]["title"]!,
          shortTitle: labels[i]["short"]!,
          dateRange: dateRangeStr,
          start: start,
          end: end,
          muscleSets: {},
        ),
      );
    }

    final Map<String, int> totalSets4Weeks = {};

    for (var log in history) {
      final logDate = DateTime.tryParse(log.date);
      if (logDate == null) continue;

      for (int i = 0; i < 4; i++) {
        final w = _weeks[i];
        if (logDate.isAfter(w.start.subtract(const Duration(seconds: 1))) &&
            logDate.isBefore(w.end)) {
          for (var ex in log.exercises) {
            final m = ex.muscle.trim();
            if (m.isEmpty ||
                m.toLowerCase().contains("cardio") ||
                m.toLowerCase().contains("outros")) {
              continue;
            }

            w.muscleSets[m] = (w.muscleSets[m] ?? 0) + ex.completedSets;
            totalSets4Weeks[m] = (totalSets4Weeks[m] ?? 0) + ex.completedSets;
          }
        }
      }
    }

    _avgSetsPerWeek = {};
    totalSets4Weeks.forEach((key, value) {
      _avgSetsPerWeek[key] = value / 4.0;
    });

    _allMuscles = totalSets4Weeks.keys.toList();
    _allMuscles.sort(
      (a, b) => (_avgSetsPerWeek[b] ?? 0).compareTo(_avgSetsPerWeek[a] ?? 0),
    );

    // Limit top muscles for radar readability
    if (_allMuscles.length > 7) {
      _allMuscles = _allMuscles.sublist(0, 7);
    }
  }

  Map<String, double> _getCurrentDisplayValues() {
    final Map<String, double> values = {};
    if (_selectedWeekIndex == -1) {
      for (var m in _allMuscles) {
        values[m] = _avgSetsPerWeek[m] ?? 0.0;
      }
    } else {
      final week = _weeks[_selectedWeekIndex];
      for (var m in _allMuscles) {
        values[m] = (week.muscleSets[m] ?? 0).toDouble();
      }
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final currentValues = _getCurrentDisplayValues();
    final String currentSubtitle = _selectedWeekIndex == -1
        ? "Média semanal dos últimos 28 dias"
        : "Período: ${_weeks[_selectedWeekIndex].dateRange}";

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title & subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Histórico de Volume",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentSubtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.accentColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _selectedWeekIndex == -1
                        ? "Média 4 sem"
                        : _weeks[_selectedWeekIndex].title,
                    style: TextStyle(
                      color: widget.accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Horizontal week selector chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip("Média 4 sem", -1),
                const SizedBox(width: 8),
                _buildFilterChip("Atual (${_weeks.isNotEmpty ? _weeks[0].shortTitle : 'Atual'})", 0),
                const SizedBox(width: 8),
                _buildFilterChip(_weeks.length > 1 ? _weeks[1].title : 'Sem -1', 1),
                const SizedBox(width: 8),
                _buildFilterChip(_weeks.length > 2 ? _weeks[2].title : 'Sem -2', 2),
                const SizedBox(width: 8),
                _buildFilterChip(_weeks.length > 3 ? _weeks[3].title : 'Sem -3', 3),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (_allMuscles.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  "Sem dados suficientes de treinos recentes.",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else ...[
            // Radar Chart with High Visibility
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RadarChart(
                  RadarChartData(
                    radarBackgroundColor: Colors.transparent,
                    radarBorderData: const BorderSide(
                      color: Colors.white24,
                      width: 1.5,
                    ),
                    tickBorderData: const BorderSide(
                      color: Colors.white12,
                      width: 1,
                    ),
                    gridBorderData: const BorderSide(
                      color: Colors.white24,
                      width: 1,
                    ),
                    ticksTextStyle: const TextStyle(color: Colors.transparent),
                    tickCount: 3,
                    titleTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    titlePositionPercentageOffset: 0.22,
                    getTitle: (index, angle) {
                      return RadarChartTitle(
                        text: _allMuscles[index],
                        angle: 0,
                      );
                    },
                    dataSets: [
                      // User Data
                      RadarDataSet(
                        fillColor: widget.accentColor.withOpacity(0.35),
                        borderColor: widget.accentColor,
                        borderWidth: 2.5,
                        entryRadius: 4,
                        dataEntries: _allMuscles
                            .map((m) => RadarEntry(value: currentValues[m] ?? 0))
                            .toList(),
                      ),
                      // Ideal target zone (20 sets) as a background reference
                      RadarDataSet(
                        fillColor: Colors.green.withOpacity(0.08),
                        borderColor: Colors.green.withOpacity(0.4),
                        borderWidth: 1.5,
                        entryRadius: 0,
                        dataEntries: _allMuscles
                            .map((m) => const RadarEntry(value: 20))
                            .toList(),
                      ),
                      // Ideal target zone (10 sets) as a background reference
                      RadarDataSet(
                        fillColor: const Color(0xFF141414), // Mask center
                        borderColor: Colors.green.withOpacity(0.4),
                        borderWidth: 1.5,
                        entryRadius: 0,
                        dataEntries: _allMuscles
                            .map((m) => const RadarEntry(value: 10))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Legend
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.circle, color: Colors.greenAccent, size: 10),
                  const SizedBox(width: 6),
                  const Text(
                    "Alvo (10-20 séries)",
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(width: 20),
                  Icon(Icons.circle, color: widget.accentColor, size: 10),
                  const SizedBox(width: 6),
                  Text(
                    _selectedWeekIndex == -1 ? "Sua Média" : "Real da Semana",
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 16),

            // Muscle Breakdown List with Week-by-Week matrix
            Expanded(
              flex: 4,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                itemCount: _allMuscles.length,
                itemBuilder: (ctx, i) {
                  final m = _allMuscles[i];
                  final currentVal = currentValues[m] ?? 0;

                  Color statusColor = Colors.orangeAccent;
                  if (currentVal >= 10 && currentVal <= 20) {
                    statusColor = Colors.greenAccent;
                  } else if (currentVal > 20) {
                    statusColor = Colors.redAccent;
                  }

                  final String valText = _selectedWeekIndex == -1
                      ? "${currentVal.toStringAsFixed(1)} séries/sem"
                      : "${currentVal.toInt()} séries";

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              m,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                valText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Week by Week Mini Badges (Sem -3, Sem -2, Sem -1, Atual)
                        Row(
                          children: List.generate(4, (weekIdx) {
                            // Reverse to show Chronological left-to-right (Sem -3 -> Atual)
                            final chronIdx = 3 - weekIdx;
                            final w = _weeks[chronIdx];
                            final sets = w.muscleSets[m] ?? 0;
                            final isCurrentSelection =
                                _selectedWeekIndex == chronIdx;

                            Color badgeColor = Colors.white30;
                            Color badgeBg = Colors.white.withOpacity(0.03);

                            if (sets >= 10 && sets <= 20) {
                              badgeColor = Colors.greenAccent;
                              badgeBg = Colors.greenAccent.withOpacity(0.12);
                            } else if (sets > 20) {
                              badgeColor = Colors.redAccent;
                              badgeBg = Colors.redAccent.withOpacity(0.12);
                            } else if (sets > 0) {
                              badgeColor = Colors.orangeAccent;
                              badgeBg = Colors.orangeAccent.withOpacity(0.12);
                            }

                            return Expanded(
                              child: Container(
                                margin: EdgeInsets.only(
                                  right: weekIdx < 3 ? 6 : 0,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isCurrentSelection
                                        ? widget.accentColor
                                        : Colors.white.withOpacity(0.08),
                                    width: isCurrentSelection ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      w.shortTitle,
                                      style: TextStyle(
                                        color: isCurrentSelection
                                            ? Colors.white
                                            : Colors.white54,
                                        fontSize: 9,
                                        fontWeight: isCurrentSelection
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "$sets s",
                                      style: TextStyle(
                                        color: badgeColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedWeekIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedWeekIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? widget.accentColor : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? widget.accentColor
                : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
