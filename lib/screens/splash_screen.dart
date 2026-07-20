import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/tracker_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndInitialize();
  }

  Future<void> _checkAuthAndInitialize() async {
    // Small delay to show splash screen
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;

    if (user != null) {
      final provider = Provider.of<TrackerProvider>(context, listen: false);
      await provider.initializeUser(user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSplashContent();
        }

        if (snapshot.hasData && snapshot.data != null) {
          // Navigate to main app - this will be handled by the parent widget
          return const SizedBox.shrink();
        }

        // Navigate to login - this will be handled by the parent widget
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSplashContent() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo/Icon
            _SplashLogo(),
            SizedBox(height: 32),
            // App Name
            Text(
              'Los Mooscles',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            SizedBox(height: 48),
            // Loading Indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: const Center(
        child: Text(
          '🏋️',
          style: TextStyle(fontSize: 64),
        ),
      ),
    );
  }
}
