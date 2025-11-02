import 'dart:async';
import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_profile.dart';
import '../database/profili_db.dart';

// Schermata principale dell’attività (tracking in tempo reale)
class ActivityScreen extends StatefulWidget {
  final int activityId; // ID dell’attività corrente
  final Function(int, double) onStopActivity; // Callback per quando si ferma l’attività
  final Stream<int> heartRateStream; // Stream frequenza cardiaca
  final Stream<LatLng> positionStream; // Stream posizione GPS

  const ActivityScreen({
    Key? key,
    required this.activityId,
    required this.onStopActivity,
    required this.heartRateStream,
    required this.positionStream,
  }) : super(key: key);

  @override
  _ActivityScreenState createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  AppleMapController? mapController;

  // Variabili principali dell’attività
  DateTime startTime = DateTime.now();
  double totalDistance = 0.0;
  int currentHeartRate = 0;
  double avgSpeed = 0.0;
  double calories = 0.0;
  LatLng? currentPosition;

  // Percorso e posizione
  List<LatLng> routePoints = [];
  LatLng? lastPosition;

  // Stream e timer
  StreamSubscription<int>? hrSubscription;
  StreamSubscription<LatLng>? posSubscription;
  Timer? caloriesTimer;

  bool hasCenteredMap = false;
  UserProfile? activeProfile;

  @override
  void initState() {
    super.initState();
    _loadActiveProfile();      // Carica profilo attivo
    _getInitialPosition();     // Ottiene posizione iniziale
    _startListening();         // Avvia ascolto di battiti e posizione
    _startCaloriesCalculation(); // Calcola calorie periodicamente
  }

  // Carica il profilo utente attivo dal DB
  Future<void> _loadActiveProfile() async {
    final profile = await ProfileDatabase.getActiveProfile();
    if (mounted) setState(() => activeProfile = profile);
  }

  // Ottiene e centra la mappa sulla posizione iniziale
  Future<void> _getInitialPosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      currentPosition = LatLng(position.latitude, position.longitude);
      if (mapController != null && mounted) {
        mapController!.animateCamera(
          CameraUpdate.newCameraPosition(CameraPosition(target: currentPosition!, zoom: 17)),
        );
      }
      setState(() {});
    } catch (e) {
      print('❌ Errore nel prendere la posizione iniziale: $e');
    }
  }

  @override
  void dispose() {
    hrSubscription?.cancel();
    posSubscription?.cancel();
    caloriesTimer?.cancel();
    super.dispose();
  }

  // Ascolta frequenza cardiaca e posizione
  void _startListening() {
    // Frequenza cardiaca
    hrSubscription = widget.heartRateStream.listen((hr) {
      if (mounted) setState(() => currentHeartRate = hr);
    });

    // Posizione GPS
    posSubscription = widget.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() {
        routePoints.add(pos);
        // Calcolo distanza
        if (lastPosition != null) {
          final distance = Geolocator.distanceBetween(
            lastPosition!.latitude, lastPosition!.longitude,
            pos.latitude, pos.longitude,
          );
          totalDistance += distance / 1000; // km
          final elapsed = DateTime.now().difference(startTime).inSeconds;
          if (totalDistance > 0 && elapsed > 0) {
            avgSpeed = (elapsed / 60) / totalDistance; // min/km
          }
        }
        lastPosition = pos;

        // Centra la mappa
        if (mapController != null) {
          mapController!.animateCamera(
            CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: 17)),
          );
          hasCenteredMap = true;
        }
      });
    });
  }

  // Timer per aggiornare calorie ogni 5s
  void _startCaloriesCalculation() {
    caloriesTimer = Timer.periodic(const Duration(seconds: 5), (_) => _calculateCalories());
  }

  // Calcola calorie consumate
  void _calculateCalories() {
    if (activeProfile == null || totalDistance == 0) return;
    final elapsed = DateTime.now().difference(startTime).inSeconds;
    if (elapsed == 0) return;

    final avgSpeedKmh = totalDistance / (elapsed / 3600);
    final calculated = activeProfile!.calculateCalories(totalDistance, avgSpeedKmh);
    if (mounted) setState(() => calories = calculated);
  }

  // Formatta durata attività (hh:mm:ss)
  String _formatDuration() {
    final elapsed = DateTime.now().difference(startTime);
    return '${elapsed.inHours.toString().padLeft(2, '0')}:'
           '${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}:'
           '${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  // Dialog per confermare lo stop
  void _stopActivity() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _buildStopDialog(),
      ),
    );
  }

  // Widget dialog di conferma STOP
  Widget _buildStopDialog() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, spreadRadius: 5)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pause_circle_outline, color: Colors.white, size: 60),
          const SizedBox(height: 20),
          const Text(
            'VUOI FERMARE\nL\'ATTIVITÀ?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.2),
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              // NO
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF1744),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('NO', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 16),
              // SÌ
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _calculateCalories();
                    Navigator.pop(context);
                    widget.onStopActivity(widget.activityId, calories);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('SÌ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // UI principale
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: Stack(
        children: [
          // Mappa Apple
          AppleMap(
            onMapCreated: (controller) {
              mapController = controller;
              if (currentPosition != null) {
                controller.animateCamera(CameraUpdate.newCameraPosition(
                  CameraPosition(target: currentPosition!, zoom: 17),
                ));
              }
            },
            initialCameraPosition: CameraPosition(
              target: currentPosition ?? lastPosition ?? const LatLng(45.4642, 9.19),
              zoom: 17,
            ),
            myLocationEnabled: true,
            polylines: {
              if (routePoints.length > 1)
                Polyline(
                  polylineId: PolylineId('route'),
                  points: routePoints,
                  color: const Color(0xFFFC5200),
                  width: 6,
                )
            },
          ),

          // Header statistiche
          Positioned(
            top: 60,
            left: 16,
            right: 16,
            child: _buildHeader(),
          ),

          // Bottone STOP
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: _buildStopButton(),
          ),
        ],
      ),
    );
  }

  // Header con durata, distanza, bpm, velocità e calorie
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color.fromARGB(255, 255, 210, 31), width: 2),
      ),
      child: Column(
        children: [
          Text(
            _formatDuration(),
            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('📍', totalDistance.toStringAsFixed(2), 'km'),
              _buildStat('❤️', '$currentHeartRate', 'bpm'),
              _buildStat('⚡', avgSpeed > 0 ? avgSpeed.toStringAsFixed(1) : '--', 'min/km'),
              _buildStat('🔥', calories.toStringAsFixed(0), 'kcal'),
            ],
          ),
          if (activeProfile != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '👤 ${activeProfile!.name}',
                style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  // Statistica (emoji + valore + unità)
  Widget _buildStat(String emoji, String value, String unit) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        Text(unit, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  // Bottone rosso STOP
  Widget _buildStopButton() {
    return Center(
      child: GestureDetector(
        onTap: _stopActivity,
        child: Container(
          width: 200,
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF1744), Color(0xFFD50000)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF1744).withOpacity(0.6),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stop_rounded, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Text(
                'STOP',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}