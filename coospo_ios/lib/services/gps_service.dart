import 'dart:async';
import 'package:geolocator/geolocator.dart';

enum GpsSignalQuality {
  noSignal,
  veryWeak,
  weak,
  moderate,
  good,
  excellent
}

class GpsService {
  static final GpsService _instance = GpsService._internal();
  factory GpsService() => _instance; // Singleton
  GpsService._internal();

  final _signalController = StreamController<GpsSignalQuality>.broadcast(); // Stream qualità segnale
  Timer? _updateTimer;
  Stream<GpsSignalQuality> get signalStream => _signalController.stream;

  void startMonitoring() {
    _updateTimer?.cancel(); // Ferma timer precedente
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkSignalQuality(); // Controlla qualità segnale ogni 500 ms
    });
  }

  Future<void> _checkSignalQuality() async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 2), // Timeout 2s
      );

      if (!_signalController.isClosed) {
        // Valuta qualità segnale in base a precisione e velocità
        if (position.accuracy <= 4) {
          _signalController.add(GpsSignalQuality.excellent);
        } else if (position.accuracy <= 6) {
          _signalController.add(GpsSignalQuality.good);
        } else if (position.accuracy <= 10) {
          _signalController.add(GpsSignalQuality.moderate);
        } else if (position.accuracy <= 15) {
          _signalController.add(GpsSignalQuality.weak);
        } else {
          _signalController.add(GpsSignalQuality.veryWeak);
        }
      }
    } catch (e) {
      if (!_signalController.isClosed) {
        _signalController.add(GpsSignalQuality.noSignal); // Nessun segnale
      }
    }
  }

  void dispose() {
    _updateTimer?.cancel(); // Ferma timer
    _signalController.close(); // Chiude stream
  }
}