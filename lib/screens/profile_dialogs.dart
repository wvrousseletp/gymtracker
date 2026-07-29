import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/tracker_provider.dart';
import '../models/profile.dart';
import '../widgets/profile_avatar.dart';
import 'badges_screen.dart';

void showProfileManagerDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const ProfileManagerSheet(),
  );
}

class ProfileManagerSheet extends StatefulWidget {
  const ProfileManagerSheet({super.key});

  @override
  State<ProfileManagerSheet> createState() => _ProfileManagerSheetState();
}

class _ProfileManagerSheetState extends State<ProfileManagerSheet> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedAvatar = "🏋️";
  String _selectedColor = "Branco";
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _initForm(Profile profile) {
    _nameController.text = profile.name;
    _selectedAvatar = profile.avatar;
    _selectedColor = profile.colorAccent;
  }

  Future<void> _saveProfile(TrackerProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final name = _nameController.text.trim();

    try {
      // 1. Atualiza no Firebase Auth
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name);

      // 2. Atualiza no Provider e Firestore
      await provider.updateProfile(
        provider.currentUserId,
        name,
        _selectedAvatar,
        _selectedColor,
      );

      setState(() {
        _isEditing = false;
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Perfil updated com sucesso!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao salvar alterações: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeProfile = context.select<TrackerProvider, Profile>((p) => p.currentProfile);
    final accentColor = ThemeUtils.getColor(activeProfile.colorAccent);
    final provider = Provider.of<TrackerProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;

    if (!_isEditing && _nameController.text.isEmpty) {
      _initForm(activeProfile);
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff1c1c1e).withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
              margin: const EdgeInsets.symmetric(vertical: 12),
            ),

            if (!_isEditing) ...[
              // ACCOUNT VIEW MODE
              const Text(
                "Minha Conta",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              
              // Profile Avatar
              ProfileAvatar(
                avatar: activeProfile.avatar,
                colorName: activeProfile.colorAccent,
                size: 72,
                fontSize: 36,
              ),
              const SizedBox(height: 12),
              
              // Profile Name
              Text(
                activeProfile.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              
              // User Email
              Text(
                user?.email ?? "Sem e-mail",
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 30),

              // Edit Profile Button
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                      _initForm(activeProfile);
                    });
                  },
                  icon: Icon(Icons.edit_outlined, color: accentColor),
                  label: Text(
                    "Editar Perfil",
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Badges Button
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // close dialog
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BadgesScreen(accentColor: accentColor),
                      ),
                    );
                  },
                  icon: Icon(Icons.military_tech, color: accentColor),
                  label: Text(
                    "Minhas Conquistas",
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),



              // Force Sync Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context); // Fecha o dialog
                    final tracker = Provider.of<TrackerProvider>(context, listen: false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sincronizando com a nuvem...')),
                    );
                    await tracker.forceCloudSync();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sincronização concluída!')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                    foregroundColor: Colors.blueAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.blueAccent.withOpacity(0.15)),
                    ),
                  ),
                  icon: const Icon(Icons.cloud_download, size: 18),
                  label: const Text(
                    "FORÇAR DOWNLOAD DA NUVEM",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context); // Fecha o dialog
                    await provider.logout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.redAccent.withOpacity(0.15)),
                    ),
                  ),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text(
                    "SAIR DA CONTA",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
            ] else ...[
              // PROFILE EDIT MODE
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Editar Perfil",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : () {
                      setState(() {
                        _isEditing = false;
                      });
                    },
                    child: const Text(
                      "Voltar",
                      style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome
                    const Text(
                      "Nome",
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        hintText: "Seu nome",
                        hintStyle: const TextStyle(color: Colors.white30),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Por favor, digite seu nome.";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Avatar (Emoji)
                    const Text(
                      "Escolha o Avatar",
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: ThemeUtils.getAvatarEmojis().map((emoji) {
                          final isSelected = _selectedAvatar == emoji;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedAvatar = emoji;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isSelected ? accentColor.withOpacity(0.15) : Colors.white.withOpacity(0.03),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? accentColor : Colors.white.withOpacity(0.08),
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cor do Tema
                    const Text(
                      "Escolha a Cor do Tema",
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: ThemeUtils.getColorNames().map((colorName) {
                          final isSelected = _selectedColor == colorName;
                          final cValue = ThemeUtils.getColor(colorName);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedColor = colorName;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: isSelected ? cValue.withOpacity(0.15) : Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? cValue : Colors.white.withOpacity(0.08),
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                colorName,
                                style: TextStyle(
                                  color: isSelected ? cValue : Colors.white70,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Salvar Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _saveProfile(provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: accentColor == Colors.white ? Colors.black : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                              )
                            : const Text(
                                "SALVAR ALTERAÇÕES",
                                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
