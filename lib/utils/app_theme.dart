import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_avatar.dart';

extension AppThemeExtension on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get scaffoldBg =>
      isDark ? Colors.black : const Color(0xFFF2F2F7);

  Color get cardBg =>
      isDark ? const Color(0xFF1C1C1E) : Colors.white;

  Color get sheetBg =>
      isDark ? const Color(0xFF1C1C1E) : Colors.white;

  Color get elevatedBg =>
      isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

  Color get subtleBg =>
      isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04);

  Color get subtleBorder =>
      isDark ? Colors.white.withOpacity(0.09) : Colors.black.withOpacity(0.08);

  Color get textPrimary =>
      isDark ? Colors.white : const Color(0xFF1C1C1E);

  Color get textSecondary =>
      isDark ? Colors.white70 : const Color(0xFF3C3C43);

  Color get textMuted =>
      isDark ? Colors.white54 : const Color(0xFF6E6E73);

  Color get textFaint =>
      isDark ? Colors.white38 : const Color(0xFF8E8E93);

  Color get adaptiveAccent {
    final colorName =
        Provider.of<ProfileProvider>(this, listen: false).currentProfile.colorAccent;
    return ThemeUtils.getAdaptiveColor(colorName, isDark: isDark);
  }
}
