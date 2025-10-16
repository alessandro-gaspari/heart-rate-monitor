import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/device_list_screen.dart';

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
      home: const DeviceListScreen(),
    );
  }
}
