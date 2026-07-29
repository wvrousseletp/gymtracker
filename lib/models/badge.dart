class AppBadge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String category; // e.g. "consistency", "volume", "milestone", "special"
  final String tier; // e.g. "bronze", "silver", "gold", "platinum"

  const AppBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    this.tier = 'bronze',
  });
}
