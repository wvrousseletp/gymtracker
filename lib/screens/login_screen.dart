import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../providers/tracker_provider.dart';
import '../widgets/profile_avatar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isRegistering = false;
  bool _isLoading = false;
  String _selectedAvatar = "🏋️";
  String _selectedColor = "Branco";
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    try {
      if (_isRegistering) {
        // 1. Cadastra no Firebase Auth
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (userCredential.user != null) {
          // Define o nome de exibição no Firebase Auth
          await userCredential.user!.updateDisplayName(name);

          // 2. Cria o perfil remoto e local no Firestore e Provider
          final provider = Provider.of<TrackerProvider>(context, listen: false);
          await provider.createCloudProfile(
            userCredential.user!.uid,
            name,
            _selectedAvatar,
            _selectedColor,
          );
        }
      } else {
        // Login no Firebase Auth
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (userCredential.user != null) {
          final provider = Provider.of<TrackerProvider>(context, listen: false);
          await provider.initializeUser(userCredential.user!.uid);
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _errorMessage = "Nenhuma conta encontrada com este e-mail.";
        } else if (e.code == 'wrong-password') {
          _errorMessage = "Senha incorreta. Tente novamente.";
        } else if (e.code == 'email-already-in-use') {
          _errorMessage = "Este e-mail já está em uso.";
        } else if (e.code == 'weak-password') {
          _errorMessage = "A senha precisa ter no mínimo 6 caracteres.";
        } else if (e.code == 'invalid-email') {
          _errorMessage = "Formato de e-mail inválido.";
        } else {
          _errorMessage = "Erro na autenticação: ${e.message}";
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Erro de conexão: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final provider = Provider.of<TrackerProvider>(context, listen: false);
        final cloudProfile = await provider.checkProfileExistsInCloud(user.uid);
        if (cloudProfile == null) {
          // Cria um novo perfil na nuvem se não existir
          await provider.createCloudProfile(
            user.uid,
            user.displayName ?? "Usuário Google",
            "🏋️",
            "Azul", // Cor padrão para Google
          );
        } else {
          await provider.initializeUser(user.uid);
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = "Erro no Google: ${e.message}";
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Erro de conexão: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAccentColor = ThemeUtils.getColor(_selectedColor);

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xff120822),
                  Colors.black,
                  Colors.black,
                ],
              ),
            ),
          ),
          
          // Glow effect top-right
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeAccentColor.withOpacity(0.08),
              ),
            ),
          ),

          // Scrollable login card
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Logo / Text
                      Text(
                        "Los Mooscles",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1,
                          shadows: [
                            Shadow(
                              color: activeAccentColor.withOpacity(0.4),
                              blurRadius: 15,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isRegistering 
                            ? "Crie sua conta para salvar seus dados com segurança" 
                            : "Faça login para sincronizar seus treinos na nuvem",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Glassmorphism card container
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(24.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.07),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Name Field (Register Only)
                                if (_isRegistering) ...[
                                  TextFormField(
                                    controller: _nameController,
                                    textCapitalization: TextCapitalization.words,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration("Nome Completo", Icons.person_outline, activeAccentColor),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return "Por favor, insira seu nome";
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Email Field
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration("E-mail", Icons.mail_outline, activeAccentColor),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return "Por favor, insira seu e-mail";
                                    }
                                    if (!val.contains('@') || !val.contains('.')) {
                                      return "Por favor, insira um e-mail válido";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Password Field
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration("Senha", Icons.lock_outline, activeAccentColor),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return "Por favor, insira sua senha";
                                    }
                                    if (val.length < 6) {
                                      return "A senha precisa ter pelo menos 6 caracteres";
                                    }
                                    return null;
                                  },
                                ),
                                
                                // Registration customization fields
                                if (_isRegistering) ...[
                                  const SizedBox(height: 24),
                                  const Text(
                                    "Escolha seu Avatar",
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70),
                                  ),
                                  const SizedBox(height: 10),
                                  
                                  // Avatar emojis row
                                  SizedBox(
                                    height: 52,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: ThemeUtils.getAvatarEmojis().map((emoji) {
                                        final isSelected = emoji == _selectedAvatar;
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedAvatar = emoji;
                                            });
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 150),
                                            margin: const EdgeInsets.only(right: 10),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isSelected ? activeAccentColor.withOpacity(0.15) : Colors.transparent,
                                              border: Border.all(
                                                color: isSelected ? activeAccentColor : Colors.white.withOpacity(0.08),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Text(emoji, style: const TextStyle(fontSize: 22)),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),

                                  const SizedBox(height: 20),
                                  const Text(
                                    "Escolha a cor do App",
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70),
                                  ),
                                  const SizedBox(height: 10),

                                  // Accent color names row
                                  SizedBox(
                                    height: 38,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: ThemeUtils.getColorNames().map((colorName) {
                                        final isSelected = colorName == _selectedColor;
                                        final colorValue = ThemeUtils.getColor(colorName);
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedColor = colorName;
                                            });
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 150),
                                            margin: const EdgeInsets.only(right: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(20),
                                              color: isSelected ? colorValue.withOpacity(0.12) : Colors.white.withOpacity(0.03),
                                              border: Border.all(
                                                color: isSelected ? colorValue : Colors.white.withOpacity(0.07),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(shape: BoxShape.circle, color: colorValue),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  colorName,
                                                  style: TextStyle(
                                                    color: isSelected ? Colors.white : Colors.white70,
                                                    fontSize: 12,
                                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 30),

                                // Submit Button
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: activeAccentColor,
                                    foregroundColor: activeAccentColor == Colors.white ? Colors.black : Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                                        )
                                      : Text(
                                          _isRegistering ? "CRIAR CONTA" : "ENTRAR NA CONTA",
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.white.withOpacity(0.08), thickness: 1)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                      child: Text(
                                        "ou",
                                        style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: Colors.white.withOpacity(0.08), thickness: 1)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _signInWithGoogle,
                                  icon: const Icon(Icons.g_mobiledata, color: Colors.white, size: 28),
                                  label: const Text(
                                    "Entrar com o Google",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),

                      // Toggle Register / Login text button
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _isRegistering = !_isRegistering;
                                  _errorMessage = null;
                                });
                              },
                        child: Text(
                          _isRegistering 
                              ? "Já tem uma conta? Faça login" 
                              : "Não tem conta? Cadastre-se agora",
                          style: TextStyle(
                            color: activeAccentColor.withOpacity(0.85),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, Color accentColor) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
      floatingLabelStyle: TextStyle(color: accentColor, fontWeight: FontWeight.w700),
      prefixIcon: Icon(icon, color: Colors.white30, size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.015),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: accentColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}
