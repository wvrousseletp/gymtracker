import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tracker_provider.dart';
import '../models/profile.dart';
import '../widgets/profile_avatar.dart';

void showProfileManagerDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const ProfileManagerSheet(),
  );
}

class ProfileManagerSheet extends StatefulWidget {
  const ProfileManagerSheet({Key? key}) : super(key: key);

  @override
  State<ProfileManagerSheet> createState() => _ProfileManagerSheetState();
}

class _ProfileManagerSheetState extends State<ProfileManagerSheet> {
  bool _isEditing = false;
  String? _editingProfileId;

  // Form states
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedAvatar = "🏋️";
  String _selectedColor = "Branco";

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _nameController.clear();
    _passwordController.clear();
    _selectedAvatar = "🏋️";
    _selectedColor = "Branco";
    _isEditing = false;
    _editingProfileId = null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final profiles = provider.profiles;
    final activeProfile = provider.currentProfile;
    final accentColor = ThemeUtils.getColor(activeProfile.colorAccent);

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
              // LIST PROFILES VIEW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Gerenciar Perfis",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: accentColor),
                    onPressed: () {
                      setState(() {
                        _resetForm();
                        _isEditing = true; // Mode create
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: profiles.length,
                itemBuilder: (context, index) {
                  final profile = profiles[index];
                  final isCurrent = profile.id == provider.currentUserId;
                  final pColor = ThemeUtils.getColor(profile.colorAccent);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(isCurrent ? 0.06 : 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent ? pColor.withOpacity(0.35) : Colors.white.withOpacity(0.05),
                        width: 1.2,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: ProfileAvatar(
                        avatar: profile.avatar,
                        colorName: profile.colorAccent,
                        size: 40,
                      ),
                      title: Row(
                        children: [
                          Text(
                            profile.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          if (profile.hasPassword) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.lock_outline, color: Colors.white38, size: 14),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 20),
                            onPressed: () {
                              setState(() {
                                _isEditing = true;
                                _editingProfileId = profile.id;
                                _nameController.text = profile.name;
                                _passwordController.text = profile.password;
                                _selectedAvatar = profile.avatar;
                                _selectedColor = profile.colorAccent;
                              });
                            },
                          ),
                          if (profiles.length > 1 && !isCurrent)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () {
                                _confirmDelete(context, provider, profile.id, profile.name);
                              },
                            ),
                        ],
                      ),
                      onTap: isCurrent
                          ? null
                          : () {
                              _handleSwitchProfile(context, provider, profile);
                            },
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    _showImportProfileDialog(context, provider);
                  },
                  icon: Icon(Icons.cloud_download_outlined, color: accentColor),
                  label: Text(
                    "Importar Perfil da Nuvem",
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ] else ...[
              // CREATE OR EDIT PROFILE FORM
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _editingProfileId == null ? "Criar Perfil" : "Editar Perfil",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
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
                        hintText: "Nome do usuário",
                        hintStyle: const TextStyle(color: Colors.white30),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Por favor, digite o nome.";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Senha (Opcional)
                    const Text(
                      "Senha de Acesso (Opcional - Deixe vazio se não quiser senha)",
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      style: const TextStyle(color: Colors.white),
                      obscureText: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        hintText: "Senha numérica ou texto",
                        hintStyle: const TextStyle(color: Colors.white30),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
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
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            final name = _nameController.text.trim();
                            final pwd = _passwordController.text.trim();
                            final id = provider.generateProfileId(name);
                            
                            if (_editingProfileId == null) {
                              // Validar duplicidade local
                              if (provider.profiles.any((p) => p.id == id)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Já existe um perfil com este nome neste aparelho!"),
                                    backgroundColor: Colors.orangeAccent,
                                  ),
                                );
                                return;
                              }
                              
                              // Validar duplicidade na nuvem
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (loadingCtx) => const Center(
                                  child: CircularProgressIndicator(color: Colors.blueAccent),
                                ),
                              );
                              
                              final cloudProfile = await provider.checkProfileExistsInCloud(id);
                              Navigator.pop(context); // Fechar indicador de carregamento
                              
                              if (cloudProfile != null) {
                                // Existe na nuvem, sugerir importação
                                showDialog(
                                  context: context,
                                  builder: (confirmCtx) => AlertDialog(
                                    backgroundColor: const Color(0xff1c1c1e),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(color: Colors.white.withOpacity(0.08)),
                                    ),
                                    title: const Text("Perfil já existente", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                                    content: Text("O perfil '$name' já possui dados salvos na nuvem. Deseja importá-lo em vez de criar um novo?", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(confirmCtx),
                                        child: const Text("Escolher outro nome", style: TextStyle(color: Colors.white54)),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(confirmCtx);
                                          _showImportProfileDialog(context, provider);
                                        },
                                        child: const Text("Importar", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                // Criar normalmente
                                await provider.createProfile(name, _selectedAvatar, _selectedColor, pwd);
                                setState(() {
                                  _isEditing = false;
                                });
                              }
                            } else {
                              // Edit profile
                              await provider.updateProfile(_editingProfileId!, name, _selectedAvatar, _selectedColor, pwd);
                              setState(() {
                                _isEditing = false;
                              });
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _editingProfileId == null ? "Criar Perfil" : "Salvar Alterações",
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
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

  void _handleSwitchProfile(BuildContext context, TrackerProvider provider, Profile profile) {
    if (profile.hasPassword) {
      final pinController = TextEditingController();
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: const Color(0xff1c1c1e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          title: Text(
            "Digite a senha de ${profile.name}",
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: pinController,
            obscureText: true,
            keyboardType: TextInputType.text,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              hintText: "Senha",
              hintStyle: const TextStyle(color: Colors.white30),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () async {
                final success = await provider.switchProfile(profile.id, pinController.text);
                if (success) {
                  Navigator.pop(dialogCtx); // Close dialog
                  Navigator.pop(context); // Close sheet
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Senha incorreta!"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: const Text("Entrar", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } else {
      provider.switchProfile(profile.id, "");
      Navigator.pop(context); // Close sheet
    }
  }

  void _confirmDelete(BuildContext context, TrackerProvider provider, String profileId, String profileName) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xff1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text(
          "Excluir Perfil?",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Text(
          "Tem certeza que deseja excluir o perfil '$profileName'? Esta ação é irreversível.",
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              await provider.deleteProfile(profileId);
              Navigator.pop(dialogCtx);
            },
            child: const Text("Excluir", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showImportProfileDialog(BuildContext context, TrackerProvider provider) {
    final nameController = TextEditingController();
    final pinController = TextEditingController();
    bool isSearching = false;
    bool showPinField = false;
    String? foundProfileId;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xff1c1c1e),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              title: const Text(
                "Importar Perfil",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!showPinField) ...[
                    const Text(
                      "Digite o nome exato do perfil que deseja importar da nuvem:",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        hintText: "Nome do perfil",
                        hintStyle: const TextStyle(color: Colors.white30),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      "Perfil encontrado! Digite a senha para continuar:",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pinController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        hintText: "Senha",
                        hintStyle: const TextStyle(color: Colors.white30),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                  if (isSearching) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: isSearching ? null : () async {
                    if (!showPinField) {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;
                      
                      setState(() {
                        isSearching = true;
                      });
                      
                      final id = provider.generateProfileId(name);
                      final profileData = await provider.checkProfileExistsInCloud(id);
                      
                      setState(() {
                        isSearching = false;
                      });
                      
                      if (profileData != null) {
                        final hasPassword = profileData['hasPassword'] ?? false;
                        if (hasPassword) {
                          setState(() {
                            showPinField = true;
                            foundProfileId = id;
                          });
                        } else {
                          // Importa direto se não tiver senha
                          setState(() {
                            isSearching = true;
                          });
                          final success = await provider.importProfileFromCloud(id, "");
                          setState(() {
                            isSearching = false;
                          });
                          if (success) {
                            Navigator.pop(dialogCtx);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Perfil importado com sucesso!"),
                                backgroundColor: Colors.green,
                              ),
                            ); 
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Erro ao importar perfil!"),
                                backgroundColor: Colors.redAccent,
                              ),
                            ); 
                          }
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Perfil não encontrado na nuvem!"),
                            backgroundColor: Colors.orangeAccent,
                          ),
                        );
                      }
                    } else {
                      final pin = pinController.text.trim();
                      setState(() {
                        isSearching = true;
                      });
                      
                      final success = await provider.importProfileFromCloud(foundProfileId!, pin);
                      
                      setState(() { 
                        isSearching = false;
                      });
                      
                      if (success) {
                        Navigator.pop(dialogCtx);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Perfil importado com sucesso!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Senha incorreta ou erro ao importar!"),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    showPinField ? "Confirmar" : "Buscar",
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        );
      },
    ); 
  }
}
