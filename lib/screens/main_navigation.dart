import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/tracker_provider.dart';
import '../models/profile.dart';
import '../services/watch_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/profile_avatar.dart';
import 'workout_screen.dart';
import 'routines_screen.dart';
import 'progress_screen.dart';
import 'diet_screen.dart';
import 'profile_dialogs.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // Lazy loading - screens are only built when accessed
  final List<Widget> _screens = [
    const _KeepAliveScreen(child: WorkoutScreen()),
    const _KeepAliveScreen(child: RoutinesScreen()),
    const _KeepAliveScreen(child: ProgressScreen()),
    const _KeepAliveScreen(child: DietScreen()),
  ];

  @override
  void initState() {
    super.initState();
    // When native sends 'navigateToWorkout' (rest timer notification tapped), go to Workout tab
    WatchService.instance.onNavigateToWorkout = () {
      if (mounted) setState(() => _currentIndex = 0);
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWhatsNew();
      _checkWeeklyReport();
    });
  }

  @override
  void dispose() {
    WatchService.instance.onNavigateToWorkout = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<TrackerProvider, bool>((p) => p.isLoading);
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // Optimize provider selects - only rebuild when profile colorAccent changes
    final accentColor = context.select<TrackerProvider, Color>(
      (p) => ThemeUtils.getColor(p.currentProfile.colorAccent),
    );
    final activeProfile = context.select<TrackerProvider, Profile>(
      (p) => p.currentProfile,
    );

    final hasActiveWorkout = context.select<TrackerProvider, bool>(
      (p) => p.state?.activeWorkout != null,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Efeito de brilho de fundo radial no estilo iOS premium
          _BackgroundGlowEffect(accentColor: accentColor),

          // Container do conteúdo principal
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Cabeçalho Global (oculto quando em treino ativo na aba de Treino para maximizar o foco na série)
                if (!(hasActiveWorkout && _currentIndex == 0))
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Los Mooscles",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),

                        // Seletor de Perfil
                        GestureDetector(
                          onTap: () {
                            showProfileManagerDialog(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.06)),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  activeProfile.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ProfileAvatar(
                                  avatar: activeProfile.avatar,
                                  colorName: activeProfile.colorAccent,
                                  size: 28,
                                  fontSize: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Tela Principal Ativa
                Expanded(
                  child: FadeIndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),
                ),
              ],
            ),
          ),

          // Dock de Navegação Flutuante
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: RepaintBoundary(
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xff141416).withOpacity(0.4),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNavItem(0, Icons.fitness_center_outlined,
                              "Treino", accentColor),
                          _buildNavItem(1, Icons.calendar_today_outlined,
                              "Rotinas", accentColor),
                          _buildNavItem(2, Icons.bar_chart_outlined,
                              "Progresso", accentColor),
                          _buildNavItem(3, Icons.restaurant_outlined, "Dieta",
                              accentColor),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData icon, String label, Color accentColor) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? accentColor : const Color(0xff8e8e93);

    return Semantics(
      label: label,
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: Icon(
                  icon,
                  color: color,
                  size: 21,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 4,
                width: isSelected ? 4 : 0,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.8),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _checkWeeklyReport() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReportStr = prefs.getString('lastWeeklyReportDate');
    
    final now = DateTime.now();
    
    // We want to show the report on Monday (weekday == 1)
    if (now.weekday == 1) {
      final todayStr = '${now.year}-${now.month}-${now.day}';
      
      if (lastReportStr != todayStr) {
        // Prepare the report for the previous week
        final provider = context.read<TrackerProvider>().workoutProvider;
        if (provider != null) {
          final history = provider.history;
          
          DateTime startOfLastWeek = DateTime(now.year, now.month, now.day - 7);
          DateTime endOfLastWeek = DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
          
          int totalWorkouts = 0;
          double totalTonnage = 0.0;
          int totalDuration = 0;
          
          for (final log in history) {
            try {
              final logDate = DateTime.parse(log.date).toLocal();
              if (logDate.isAfter(startOfLastWeek) && logDate.isBefore(endOfLastWeek)) {
                totalWorkouts++;
                totalTonnage += log.totalWeight;
                totalDuration += log.duration;
              }
            } catch (_) {}
          }
          
          // Textos Dinâmicos baseados no Weekly Goal
          final int goal = provider.streak.weeklyGoal > 0 ? provider.streak.weeklyGoal : 1;
          String title = "Resumo da Semana";
          String message = "Bom trabalho! Continue mantendo o ritmo nessa nova semana.";
          
          if (totalWorkouts >= goal) {
            title = "Semana Impecável 🏆";
            message = "Meta atingida com sucesso! Você ganhou +1 Congelamento de Ofensiva ❄️";
          } else if (totalWorkouts == goal - 1) {
            title = "Quase lá! 💪";
            message = "Faltou só 1 treino para a meta! Bora esmagar nessa semana!";
          } else if (totalWorkouts == 0) {
            title = "Descanso Estratégico 🔋";
            message = "Semana de deload? Sua ofensiva foi salva por um Freeze ❄️";
          }

          // Show report dialog
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1E1E1E),
                title: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                    const SizedBox(width: 8),
                    Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18))),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    if (totalWorkouts > 0) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildReportStat(Icons.fitness_center, "$totalWorkouts", "Treinos"),
                          _buildReportStat(Icons.timer, "${totalDuration ~/ 60}m", "Tempo"),
                          if (totalTonnage > 0) _buildReportStat(Icons.monitor_weight, "${(totalTonnage / 1000).toStringAsFixed(1)}t", "Volume"),
                        ],
                      ),
                    ]
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Bora para a próxima!", style: TextStyle(color: Colors.greenAccent)),
                  ),
                ],
              ),
            );
          }
        }
        await prefs.setString('lastWeeklyReportDate', todayStr);
      }
    }
  }

  Widget _buildReportStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
  void _checkWhatsNew() async {
    final prefs = await SharedPreferences.getInstance();
    const currentBuild = 255;
    final lastSeenBuild = prefs.getInt('last_seen_whats_new_build') ?? 0;

    if (lastSeenBuild < currentBuild) {
      if (!mounted) return;
      
      final notesToShow = lastSeenBuild == 0
          ? _releaseNotesHistory.where((n) => n.buildNumber == currentBuild).toList()
          : _releaseNotesHistory.where((n) => n.buildNumber > lastSeenBuild && n.buildNumber <= currentBuild).toList();

      if (notesToShow.isNotEmpty) {
        _showWhatsNewDialog(context, notesToShow);
      }
      await prefs.setInt('last_seen_whats_new_build', currentBuild);
    }
  }

  void _showWhatsNewDialog(BuildContext context, List<_ReleaseNote> notes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassCard(
            useBlur: true,
            borderColor: Colors.white.withOpacity(0.08),
            borderRadius: 24,
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.amber, size: 24),
                      SizedBox(width: 8),
                      Text(
                        "O que há de novo! 🌟",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Veja o que preparamos para você nesta atualização:",
                    style: TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: notes.map((note) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: _whatsNewItem(
                              note.icon,
                              note.color,
                              note.title,
                              note.description,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      "Começar a Usar! 🚀",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _whatsNewItem(
      IconData icon, Color color, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2), width: 0.5),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _KeepAliveScreen extends StatefulWidget {
  final Widget child;
  const _KeepAliveScreen({required this.child});

  @override
  State<_KeepAliveScreen> createState() => _KeepAliveScreenState();
}

class _KeepAliveScreenState extends State<_KeepAliveScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _BackgroundGlowEffect extends StatelessWidget {
  final Color accentColor;
  const _BackgroundGlowEffect({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -150,
      left: 50,
      right: 50,
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              blurRadius: 100,
              spreadRadius: 50,
            ),
          ],
        ),
      ),
    );
  }
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.forward();
  }

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: IndexedStack(
        index: widget.index,
        children: widget.children,
      ),
    );
  }
}

class _ReleaseNote {
  final int buildNumber;
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  _ReleaseNote(this.buildNumber, this.icon, this.color, this.title, this.description);
}

// Histórico de notas de atualização.
final List<_ReleaseNote> _releaseNotesHistory = [
  _ReleaseNote(243, Icons.directions_run_rounded, const Color(0xff00e676), "Cardio Premium & Live Timer 🏃‍♂️", "Cronômetro dedicado para cardio com meta, preenchimento automático do tempo e cálculo de pace."),
  _ReleaseNote(243, Icons.sort_rounded, Colors.amberAccent, "Biblioteca Inteligente & Busca 🔍", "Busca por nome instantânea e exercícios ordenados automaticamente por quais você mais treina."),
  _ReleaseNote(243, Icons.watch, Colors.blueAccent, "Sincronização Veloz no Watch ⚡️", "Reescrevemos o motor de transferência para o Apple Watch. O app no relógio agora espelha seu treino perfeitamente e sem engasgos!"),
  _ReleaseNote(248, Icons.auto_awesome, Colors.deepPurpleAccent, "Melhorias no Treinador IA 🤖", "A IA agora tem digitação em tempo real, mostra erros de rede sem travar, e ganhou uma barra de rolagem exclusiva para não engolir sua tela!"),
  _ReleaseNote(253, Icons.psychology_rounded, Colors.cyanAccent, "IA Completa no Exercício 🧠", "A análise de cada exercício agora entrega respostas 100% completas, sem cortes de texto, com raciocínio focado em hipertrofia e consolidação de carga."),
  _ReleaseNote(254, Icons.auto_awesome, Colors.amberAccent, "Treinador IA Sem Limite de Texto 🚀", "Aumentamos o limite de tokens da IA para gerar pareceres longos, profundos e totalmente finalizados sobre sua sobrecarga e hipertrofia."),
  _ReleaseNote(255, Icons.navigation_rounded, Colors.greenAccent, "Navegação e Botões Aprimorados 🧭", "Padronizamos todos os botões de voltar e fechar nas telas, modais e contadores, facilitando a navegação no app."),
];
