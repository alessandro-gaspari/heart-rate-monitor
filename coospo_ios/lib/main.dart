import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/device_list_screen.dart';
import 'screens/welcome_profile_screen.dart';
import 'database/profili_db.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        print('📱 APP IN FOREGROUND');
        break;
      case AppLifecycleState.inactive:
        print('📱 APP INACTIVE (menu a tendina)');
        break;
      case AppLifecycleState.paused:
        print('📱 APP IN BACKGROUND');
        break;
      case AppLifecycleState.detached:
        print('📱 APP CHIUSA');
        break;
      case AppLifecycleState.hidden:
        print('📱 APP HIDDEN');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Scanner',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF2C2C2C),
          titleTextStyle: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        textTheme: GoogleFonts.montserratTextTheme(
          ThemeData.dark().textTheme,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const DeviceListScreen(),
        '/welcome': (context) => WelcomeProfileScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    await Future.delayed(const Duration(milliseconds: 800));
    final profiles = await ProfileDatabase.getAllProfiles();
    
    if (mounted) {
      if (profiles.isEmpty) {
        Navigator.pushReplacementNamed(context, '/welcome');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
              ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.05).animate(_controller),
                child: Image.asset(
                  'assets/craiyon_105658_image.png',
                  height: 200,
                ),
              ),
            const SizedBox(height: 50),
            // Linear Progress Bar iniziale
            SizedBox(
              width: 150, 
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  minHeight: 8, // Più spessa
                  color: const Color.fromARGB(255, 255, 210, 31), 
                  backgroundColor: Colors.white.withOpacity(0.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

