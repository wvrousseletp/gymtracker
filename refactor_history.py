import re

with open('lib/screens/progress_screen.dart', 'r') as f:
    content = f.read()

# 1. Add table_calendar import
content = content.replace("import '../widgets/glass_card.dart';", "import '../widgets/glass_card.dart';\nimport 'package:table_calendar/table_calendar.dart';")

# 2. Add state variables to _HistoryTabState
state_vars = """  bool _loadingHistory = false;
  bool _monthsInitialized = false;
  bool _isCalendarView = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;"""
content = content.replace("  bool _loadingHistory = false;\n  bool _monthsInitialized = false;", state_vars)

# 3. Add helper methods before build
helpers = """  Map<DateTime, List<WorkoutLog>> _groupHistoryByDay(List<WorkoutLog> history) {
    final Map<DateTime, List<WorkoutLog>> grouped = {};
    for (final log in history) {
      final date = DateTime.tryParse(log.date)?.toLocal() ?? DateTime.now();
      final normalizedDate = DateTime.utc(date.year, date.month, date.day);
      grouped.putIfAbsent(normalizedDate, () => []).add(log);
    }
    return grouped;
  }

  Widget _buildCalendarCell(BuildContext context, DateTime date, List<WorkoutLog> logs, Color accent) {
    if (logs.isEmpty) {
      return Center(
        child: Text(
          '${date.day}',
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }

    int totalVolume = 0;
    bool isRest = false;
    for (final log in logs) {
      if (log.name == 'Dia de Descanso' || log.notes.contains('Descanso registrado')) {
        isRest = true;
      }
      totalVolume += log.totalWeight.toInt();
    }

    Color cellColor;
    if (isRest) {
      cellColor = Colors.grey.shade800; 
    } else {
      if (totalVolume > 5000) {
        cellColor = accent; 
      } else if (totalVolume > 2000) {
        cellColor = accent.withOpacity(0.6); 
      } else {
        cellColor = accent.withOpacity(0.3); 
      }
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cellColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '${date.day}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildCalendarView(List<WorkoutLog> history, TrackerProvider provider) {
    final logsByDay = _groupHistoryByDay(history);
    
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
      children: [
        TableCalendar<WorkoutLog>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          eventLoader: (day) {
            return logsByDay[DateTime.utc(day.year, day.month, day.day)] ?? [];
          },
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              final logs = logsByDay[DateTime.utc(day.year, day.month, day.day)] ?? [];
              return _buildCalendarCell(context, day, logs, widget.accentColor);
            },
            selectedBuilder: (context, day, focusedDay) {
              final logs = logsByDay[DateTime.utc(day.year, day.month, day.day)] ?? [];
              return Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  shape: BoxShape.circle,
                ),
                child: _buildCalendarCell(context, day, logs, widget.accentColor),
              );
            },
            todayBuilder: (context, day, focusedDay) {
              final logs = logsByDay[DateTime.utc(day.year, day.month, day.day)] ?? [];
              return Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  border: Border.all(color: widget.accentColor, width: 1),
                  shape: BoxShape.circle,
                ),
                child: _buildCalendarCell(context, day, logs, widget.accentColor),
              );
            },
            outsideBuilder: (context, day, focusedDay) {
              return Center(
                child: Text(
                  '${day.day}',
                  style: const TextStyle(color: Colors.white24),
                ),
              );
            }
          ),
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: true,
            defaultTextStyle: TextStyle(color: Colors.white),
            weekendTextStyle: TextStyle(color: Colors.white70),
          ),
          headerStyle: HeaderStyle(
            titleTextStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            formatButtonVisible: false,
            leftChevronIcon: Icon(Icons.chevron_left, color: widget.accentColor),
            rightChevronIcon: Icon(Icons.chevron_right, color: widget.accentColor),
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: Colors.white70),
            weekendStyle: TextStyle(color: Colors.white54),
          ),
        ),
        const SizedBox(height: 20),
        if (_selectedDay != null && (logsByDay[DateTime.utc(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)]?.isNotEmpty ?? false))
          ...logsByDay[DateTime.utc(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)]!.map((log) => _buildLogCard(log, provider)),
        if (_selectedDay != null && (logsByDay[DateTime.utc(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)]?.isEmpty ?? true))
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'Nenhum treino neste dia.',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          )
      ],
    );
  }

  @override"""

content = content.replace("  @override\n  Widget build(BuildContext context) {", helpers + "\n  Widget build(BuildContext context) {")

# 4. Modify the body inside build
body_original = """      body: RefreshIndicator(
        color: widget.accentColor,
        backgroundColor: const Color(0xff1c1c1e),
        onRefresh: () async {
          await provider.syncAppleWorkouts();
          await provider.loadWorkoutHistory();
        },
        child: monthGroups.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(
                    child: Text(
                      "Nenhum treino no diário ainda.\\nPuxe para sincronizar com o Apple Health.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic, height: 1.4),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
                itemCount: monthGroups.length,
                itemBuilder: (context, groupIndex) {"""

body_new = """      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Seu Histórico",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isCalendarView ? Icons.view_list_rounded : Icons.calendar_month_rounded,
                    color: widget.accentColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _isCalendarView = !_isCalendarView;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: widget.accentColor,
              backgroundColor: const Color(0xff1c1c1e),
              onRefresh: () async {
                await provider.syncAppleWorkouts();
                await provider.loadWorkoutHistory();
              },
              child: _isCalendarView
                  ? _buildCalendarView(history, provider)
                  : (monthGroups.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 200),
                            Center(
                              child: Text(
                                "Nenhum treino no diário ainda.\\nPuxe para sincronizar com o Apple Health.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic, height: 1.4),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
                          itemCount: monthGroups.length,
                          itemBuilder: (context, groupIndex) {"""

content = content.replace(body_original, body_new)

# 5. Extract _buildLogCard logic
match = re.search(r'(                        return Container\(\n                          margin: const EdgeInsets.only\(bottom: 12\),\n                          child: GlassCard\(.*?                        \);\n                      \}\),)', content, re.DOTALL)
if match:
    original_block = match.group(1)
    # We replace the map body to just call _buildLogCard(log, provider)
    content = content.replace(original_block, "                        return _buildLogCard(log, provider);\n                      }),")
    
    # We need to create the _buildLogCard method out of original_block
    # But wait, we need to extract the Container widget from it
    inner_container = re.search(r'return (Container\(.*?\);)', original_block, re.DOTALL).group(1)
    
    build_log_card_method = f"""
  Widget _buildLogCard(WorkoutLog log, TrackerProvider provider) {{
    final isExpanded = _expandedLogIds.contains(log.id);
    return {inner_container}
  }}
"""
    # Insert it right before _buildMetricItem
    content = content.replace("  Widget _buildMetricItem(String label, String val) {", build_log_card_method + "\n  Widget _buildMetricItem(String label, String val) {")

with open('lib/screens/progress_screen.dart', 'w') as f:
    f.write(content)

