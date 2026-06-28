import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/tracker_provider.dart';
import '../models/profile.dart';
import '../services/watch_service.dart';
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

  final List<Widget> _screens = const [
    WorkoutScreen(),
    RoutinesScreen(),
    ProgressScreen(),
    DietScreen(),
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

    final activeProfile = context.select<TrackerProvider, Profile>(
      (p) => p.currentProfile,
    );
    final accentColor = ThemeUtils.getColor(activeProfile.colorAccent);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Efeito de brilho de fundo radial no estilo iOS premium
          Positioned(
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
          ),
          
          // Container do conteúdo principal
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Cabeçalho Global
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
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
                        _buildNavItem(0, Icons.fitness_center_outlined, "Treino", accentColor),
                        _buildNavItem(1, Icons.calendar_today_outlined, "Rotinas", accentColor),
                        _buildNavItem(2, Icons.bar_chart_outlined, "Progresso", accentColor),
                        _buildNavItem(3, Icons.restaurant_outlined, "Dieta", accentColor),
                      ],
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

  Widget _buildNavItem(int index, IconData icon, String label, Color accentColor) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? accentColor : const Color(0xff8e8e93);

    return GestureDetector(
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
    );
  }

  void _checkWhatsNew() async {
    final prefs = await SharedPreferences.getInstance();
    const currentBuild = 71;
    final lastSeenBuild = prefs.getInt('last_seen_whats_new_build') ?? 0;
    
    if (lastSeenBuild < currentBuild) {
      if (!mounted) return;
      _showWhatsNewDialog(context);
      await prefs.setInt('last_seen_whats_new_build', currentBuild);
    }
  }

  void _showWhatsNewDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xff1c1c1e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber, size: 24),
              SizedBox(width: 8),
              Text(
                "O que há de novo! 🌟",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Preparamos atualizações incríveis para você atingir seus objetivos de forma ainda mais inteligente!",
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                _whatsNewItem(
                  Icons.psychology_outlined,
                  Colors.purpleAccent,
                  "Banco de Alimentos com IA",
                  "Consulte e estime macros e calorias de qualquer alimento com o Gemini.",
                ),
                const SizedBox(height: 12),
                _whatsNewItem(
                  Icons.star_outline_rounded,
                  Colors.amber,
                  "Favoritos Personalizados",
                  "Salve porções recorrentes de alimentos e registre-os com um só toque.",
                ),
                const SizedBox(height: 12),
                _whatsNewItem(
                  Icons.local_cafe_outlined,
                  Colors.blueAccent,
                  "Combos de Alimentos (Presets)",
                  "Salve grupos (como seu shake diário) para inserir de uma vez só.",
                ),
                const SizedBox(height: 12),
                _whatsNewItem(
                  Icons.database_outlined,
                  Colors.greenAccent,
                  "100+ Alimentos Pré-carregados",
                  "Base de dados inicial completa para buscas locais offline ultrarrápidas.",
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.only(bottom: 20, right: 24, left: 24),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                "Começar a Usar! 🚀",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _whatsNewItem(IconData icon, Color color, String title, String description) {
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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.3),
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

class _FadeIndexedStackState extends State<FadeIndexedStack> with SingleTickerProviderStateMixin {
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
