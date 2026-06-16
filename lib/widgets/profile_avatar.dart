import 'package:flutter/material.dart';

class ThemeUtils {
  static Color getColor(String name) {
    switch (name.toLowerCase()) {
      case 'azul':
        return const Color(0xff0a84ff);
      case 'verde':
        return const Color(0xff30d158);
      case 'laranja':
        return const Color(0xffff9f0a);
      case 'vermelho':
        return const Color(0xffff453a);
      case 'roxo':
        return const Color(0xffbf5af2);
      case 'rosa':
        return const Color(0xffff375f);
      case 'branco':
      default:
        return Colors.white;
    }
  }

  static List<String> getColorNames() {
    return ["Branco", "Azul", "Verde", "Laranja", "Vermelho", "Roxo", "Rosa"];
  }

  static List<String> getAvatarEmojis() {
    return ["🏋️", "⚡", "✨", "🦁", "🥑", "🦾", "🤸", "🏃", "🧘", "🏆", "🍉", "🔥", "🍕", "❤️", "👑"];
  }
}

class ProfileAvatar extends StatelessWidget {
  final String avatar;
  final String colorName;
  final double size;
  final double fontSize;

  const ProfileAvatar({
    Key? key,
    required this.avatar,
    required this.colorName,
    this.size = 40.0,
    this.fontSize = 20.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeColor = ThemeUtils.getColor(colorName);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: themeColor.withOpacity(0.12),
        border: Border.all(
          color: themeColor.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        avatar,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.0,
        ),
      ),
    );
  }
}
