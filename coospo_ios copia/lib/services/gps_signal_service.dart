import 'dart:async';
import 'package:geolocator/geolocator.dart';

enum GpsSignalStrength {
  none,
  weak,
  moderate,
  strong,
  excellent
}

class GpsSignalService {
  static final GpsSignalService _instance = GpsSignalService._internal();
  factory GpsSignalService() => _instance;
  GpsSignalService._internal();

  final _controller = StreamController<GpsSignalStrength>.broadcast();
  Timer? _updateTimer;
  Stream<GpsSignalStrength> get signalStream => _controller.stream;

  void startMonitoring() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateGpsSignal();
    });
  }

  Future<void> _updateGpsSignal() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 2),
      ).timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('GPS timeout'),
      );

      if (!_controller.isClosed) {
        // Valuta la qualità del segnale basandosi sull'accuratezza
        if (position.accuracy <= 4) {
          _controller.add(GpsSignalStrength.excellent);
        } else if (position.accuracy <= 8) {
          _controller.add(GpsSignalStrength.strong);
        } else if (position.accuracy <= 12) {
          _controller.add(GpsSignalStrength.moderate);
        } else {
          _controller.add(GpsSignalStrength.weak);
        }
      }
    } catch (e) {
      if (!_controller.isClosed) {
        _controller.add(GpsSignalStrength.none);
      }
    }
  }

  void dispose() {
    _updateTimer?.cancel();
    _controller.close();
  }
}