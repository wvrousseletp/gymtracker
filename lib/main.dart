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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'utils/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase in background to avoid blocking startup
  unawaited(Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ));
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
        ChangeNotifierProvider(create: (_) => DietProvider()),
        ChangeNotifierProxyProvider3<ProfileProvider, WorkoutProvider, DietProvider, TrackerProvider>(
          create: (context) => TrackerProvider(),
          update: (context, profile, workout, diet, tracker) {
            tracker?.update(profile, workout, diet);
            return tracker!;
          },
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
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      builder: (context, child) => OfflineBannerWrapper(child: child ?? const SizedBox()),
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xfff2f2f7),
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          background: Color(0xfff2f2f7),
          surface: Colors.white,
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
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
      themeMode: ThemeMode.system,
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
            Future.microtask(() {
              if (provider.currentUserId != snapshot.data!.uid) {
                provider.initializeUser(snapshot.data!.uid);
              }
            });
            return const MainNavigation();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
