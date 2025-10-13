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
  factory GpsService() => _instance;
  GpsService._internal();

  final _signalController = StreamController<GpsSignalQuality>.broadcast();
  Timer? _updateTimer;
  Stream<GpsSignalQuality> get signalStream => _signalController.stream;

  void startMonitoring() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkSignalQuality();
    });
  }

  Future<void> _checkSignalQuality() async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 2),
      );

      if (!_signalController.isClosed) {
        // Valutazione più dettagliata della qualità del segnale
        if (position.accuracy <= 4 && position.speed != null) {
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
        _signalController.add(GpsSignalQuality.noSignal);
      }
    }
  }

  void dispose() {
    _updateTimer?.cancel();
    _signalController.close();
  }
}