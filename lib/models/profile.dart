class Profile {
  final String id;
  final String name;
  final String avatar; // Emoji
  final String colorAccent; // Nome da cor ou valor hex
  final String password; // Senha em texto/número, ou vazia
  final bool hasPassword;

  Profile({
    required this.id,
    required this.name,
    required this.avatar,
    required this.colorAccent,
    required this.password,
    required this.hasPassword,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
    'colorAccent': colorAccent,
    'password': password,
    'hasPassword': hasPassword,
  };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    avatar: json['avatar'] ?? '🏋️',
    colorAccent: json['colorAccent'] ?? 'Branco',
    password: json['password'] ?? '',
    hasPassword: json['hasPassword'] ?? false,
  );
}
