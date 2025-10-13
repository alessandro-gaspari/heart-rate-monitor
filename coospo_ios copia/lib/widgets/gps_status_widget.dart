import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gps_service.dart';

class GpsStatusWidget extends StatefulWidget {
  const GpsStatusWidget({Key? key}) : super(key: key);

  @override
  State<GpsStatusWidget> createState() => _GpsStatusWidgetState();
}

class _GpsStatusWidgetState extends State<GpsStatusWidget> {
  final GpsService _gpsService = GpsService();
  StreamSubscription<GpsSignalQuality>? _subscription;
  GpsSignalQuality _currentQuality = GpsSignalQuality.noSignal;

  @override
  void initState() {
    super.initState();
    _gpsService.startMonitoring();
    _subscription = _gpsService.signalStream.listen((quality) {
      if (mounted) {
        setState(() => _currentQuality = quality);
      }
    });
  }

  Color _getStatusColor() {
    switch (_currentQuality) {
      case GpsSignalQuality.excellent:
        return const Color(0xFF00E676); // Verde brillante
      case GpsSignalQuality.good:
        return const Color(0xFF69F0AE); // Verde chiaro
      case GpsSignalQuality.moderate:
        return const Color(0xFFFFEB3B); // Giallo
      case GpsSignalQuality.weak:
        return const Color(0xFFFFB74D); // Arancione
      case GpsSignalQuality.veryWeak:
        return const Color(0xFFFF9100); // Arancione scuro
      case GpsSignalQuality.noSignal:
        return const Color(0xFFFF5252); // Rosso
    }
  }

  String _getStatusText() {
    switch (_currentQuality) {
      case GpsSignalQuality.excellent:
        return 'Eccellente';
      case GpsSignalQuality.good:
        return 'Buono';
      case GpsSignalQuality.moderate:
        return 'Discreto';
      case GpsSignalQuality.weak:
        return 'Debole';
      case GpsSignalQuality.veryWeak:
        return 'Molto debole';
      case GpsSignalQuality.noSignal:
        return 'No GPS';
    }
  }

  IconData _getStatusIcon() {
    switch (_currentQuality) {
      case GpsSignalQuality.excellent:
      case GpsSignalQuality.good:
        return Icons.satellite_alt;
      case GpsSignalQuality.moderate:
        return Icons.satellite;
      case GpsSignalQuality.weak:
      case GpsSignalQuality.veryWeak:
        return Icons.gps_not_fixed;
      case GpsSignalQuality.noSignal:
        return Icons.gps_off;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor().withOpacity(0.15),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(),
            size: 20,
            color: _getStatusColor(),
          ),
          const SizedBox(width: 8),
          Text(
            'GPS: ',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStatusColor(),
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor().withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _getStatusText(),
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _getStatusColor(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _gpsService.dispose();
    super.dispose();
  }
}