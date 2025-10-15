import 'package:flutter/widgets.dart';

class BackgroundService with WidgetsBindingObserver {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  Function? onAppInBackground;
  Function? onAppInForeground;
  bool _isInBackground = false;

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App in foreground
        print('📱 APP IN FOREGROUND');
        _isInBackground = false;
        onAppInForeground?.call();
        break;
      case AppLifecycleState.inactive:
        // App transitorio (menu a tendina, switch app)
        print('📱 APP INACTIVE');
        break;
      case AppLifecycleState.paused:
        // App in background
        print('📱 APP IN BACKGROUND');
        _isInBackground = true;
        onAppInBackground?.call();
        break;
      case AppLifecycleState.detached:
        // App sta per chiudersi
        print('📱 APP DETACHED');
        break;
      case AppLifecycleState.hidden:
        print('📱 APP HIDDEN');
        break;
    }
  }

  bool get isInBackground => _isInBackground;

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
