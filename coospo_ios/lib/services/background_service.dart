import 'package:flutter/widgets.dart';

class BackgroundService with WidgetsBindingObserver {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  Function? onAppInBackground; // Callback background
  Function? onAppInForeground; // Callback foreground
  bool _isInBackground = false; // Stato background

  void initialize() {
    WidgetsBinding.instance.addObserver(this); // Aggiunge osservatore ciclo vita app
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App in foreground
        print('📱 APP IN FOREGROUND');
        _isInBackground = false;
        onAppInForeground?.call(); // Chiama callback foreground
        break;
      case AppLifecycleState.inactive:
        // App inattiva (menu o cambio app)
        print('📱 APP INACTIVE');
        break;
      case AppLifecycleState.paused:
        // App in background
        print('📱 APP IN BACKGROUND');
        _isInBackground = true;
        onAppInBackground?.call(); // Chiama callback background
        break;
      case AppLifecycleState.detached:
        // App sta per chiudersi
        print('📱 APP DETACHED');
        break;
      case AppLifecycleState.hidden:
        // App nascosta
        print('📱 APP HIDDEN');
        break;
    }
  }

  bool get isInBackground => _isInBackground; // Stato corrente

  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Rimuove osservatore
  }
}