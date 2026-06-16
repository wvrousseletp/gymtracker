import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tracker_provider.dart';
import '../widgets/profile_avatar.dart';
import 'workout_screen.dart';
import 'planner_screen.dart';
import 'routines_screen.dart';
import 'progress_screen.dart';
import 'diet_screen.dart';
import 'profile_dialogs.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    WorkoutScreen(),
    PlannerScreen(),
    RoutinesScreen(),
    ProgressScreen(),
    DietScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    if (provider.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final activeProfile = provider.currentProfile;
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "LOS MOOSCLES",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Shapeup Tracker",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
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
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 96), // Espaço para a dock flutuante
                    child: IndexedStack(
                      index: _currentIndex,
                      children: _screens,
                    ),
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
                color: const Color(0xff141416).withOpacity(0.4),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.fitness_center_outlined, "Treino", accentColor),
                    _buildNavItem(1, Icons.calendar_today_outlined, "Planejar", accentColor),
                    _buildNavItem(2, Icons.list_alt_outlined, "Treinos", accentColor),
                    _buildNavItem(3, Icons.bar_chart_outlined, "Progresso", accentColor),
                    _buildNavItem(4, Icons.restaurant_outlined, "Dieta", accentColor),
                  ],
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
