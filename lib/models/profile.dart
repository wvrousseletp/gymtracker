class Profile {
  final String id;
  final String name;
  final String avatar; // Emoji
  final String colorAccent; // Nome da cor ou valor hex

  Profile({
    required this.id,
    required this.name,
    required this.avatar,
    required this.colorAccent,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'colorAccent': colorAccent,
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        avatar: json['avatar'] ?? '🏋️',
        colorAccent: json['colorAccent'] ?? 'Branco',
      );
}
