import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tracker_provider.dart';
import '../models/badge.dart';
import '../services/badges_service.dart';
import '../widgets/glass_card.dart';

class BadgesScreen extends StatelessWidget {
  final Color accentColor;
  const BadgesScreen({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<TrackerProvider>(context).state;
    if (state == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final unlockedIds = state.unlockedBadgeIds;
    final unlocked = BadgesService.getUnlockedBadges(unlockedIds);
    final locked = BadgesService.getLockedBadges(unlockedIds);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Conquistas"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Header
            GlassCard(
              useBlur: true,
              borderRadius: 24,
              borderColor: Colors.white.withOpacity(0.05),
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: unlocked.length / BadgesService.allBadges.length,
                          strokeWidth: 8,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          color: accentColor,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Text(
                        "${unlocked.length}/${BadgesService.allBadges.length}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    ],
                  ),
                  const SizedBox(width: 24),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Seu Progresso",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Continue treinando para desbloquear todas as medalhas!",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Unlocked Badges
            if (unlocked.isNotEmpty) ...[
              const Text(
                "Desbloqueadas",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: unlocked.length,
                itemBuilder: (context, index) {
                  final badge = unlocked[index];
                  return _BadgeItem(badge: badge, isLocked: false, accentColor: accentColor);
                },
              ),
              const SizedBox(height: 32),
            ],

            // Locked Badges
            if (locked.isNotEmpty) ...[
              const Text(
                "Ainda Bloqueadas",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: locked.length,
                itemBuilder: (context, index) {
                  final badge = locked[index];
                  return _BadgeItem(badge: badge, isLocked: true, accentColor: accentColor);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BadgeItem extends StatelessWidget {
  final AppBadge badge;
  final bool isLocked;
  final Color accentColor;

  const _BadgeItem({
    required this.badge,
    required this.isLocked,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isLocked ? Colors.white.withOpacity(0.02) : accentColor.withOpacity(0.15);
    final borderColor = isLocked ? Colors.white.withOpacity(0.05) : accentColor.withOpacity(0.3);

    return GestureDetector(
      onTap: () {
        // Show details dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      badge.icon,
                      style: TextStyle(
                        fontSize: 40,
                        color: isLocked ? Colors.white24 : Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  badge.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isLocked ? Colors.white54 : Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  badge.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isLocked) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 14, color: Colors.white54),
                        SizedBox(width: 6),
                        Text("Bloqueada", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  )
                ]
              ],
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLocked ? Colors.white.withOpacity(0.05) : accentColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Text(
                badge.icon,
                style: TextStyle(
                  fontSize: 28,
                  color: isLocked ? Colors.white24 : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              badge.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isLocked ? Colors.white54 : Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
