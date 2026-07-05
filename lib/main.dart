import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'providers/profile_provider.dart';
import 'providers/workout_provider.dart';
import 'providers/diet_provider.dart';
import 'providers/tracker_provider.dart';
import 'screens/main_navigation.dart';
import 'screens/login_screen.dart';
import 'widgets/offline_banner_wrapper.dart';
import 'services/analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ProfileProvider()),
        ChangeNotifierProxyProvider<ProfileProvider, WorkoutProvider>(
          create: (context) => WorkoutProvider(),
          update: (context, profile, workout) => workout!..updateProfile(profile),
        ),
        ChangeNotifierProxyProvider<ProfileProvider, DietProvider>(
          create: (context) => DietProvider(),
          update: (context, profile, diet) => diet!..updateProfile(profile),
        ),
        ChangeNotifierProxyProvider3<ProfileProvider, WorkoutProvider, DietProvider, TrackerProvider>(
          create: (context) => TrackerProvider(),
          update: (context, profile, workout, diet, tracker) =>
              tracker!..update(profile, workout, diet),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Los Mooscles',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [AnalyticsService.observer],
      builder: (context, child) => OfflineBannerWrapper(child: child ?? const SizedBox()),
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          background: Colors.black,
          surface: Color(0xff1c1c1e),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            final provider = Provider.of<TrackerProvider>(context, listen: false);
            if (provider.currentUserId != snapshot.data!.uid) {
              Future.microtask(() {
                provider.initializeUser(snapshot.data!.uid);
              });
            }
            return const MainNavigation();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
