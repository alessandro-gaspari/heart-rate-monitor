import 'dart:async';
import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_profile.dart';
import '../database/profili_db.dart';

class ActivityScreen extends StatefulWidget {
  final int activityId;
  final Function(int activityId, double calories) onStopActivity;
  final Stream<int> heartRateStream;
  final Stream<LatLng> positionStream;

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

  DateTime startTime = DateTime.now();
  double totalDistance = 0.0;
  int currentHeartRate = 0;
  double avgSpeed = 0.0;
  double calories = 0.0;
  LatLng? currentPosition;

  List<LatLng> routePoints = [];
  LatLng? lastPosition;

  StreamSubscription<int>? hrSubscription;
  StreamSubscription<LatLng>? posSubscription;
  Timer? caloriesTimer;

  bool hasCenteredMap = false;
  UserProfile? activeProfile;

  @override
  void initState() {
    super.initState();
    _loadActiveProfile();
    _getInitialPosition();
    _startListening();
    _startCaloriesCalculation();
  }

  Future<void> _loadActiveProfile() async {
    final profile = await ProfileDatabase.getActiveProfile();
    if (mounted) {
      setState(() {
        activeProfile = profile;
      });
    }
    if (profile == null) {
      print('⚠️ Nessun profilo attivo - calorie non verranno calcolate');
    } else {
      print('✅ Profilo attivo caricato: ${profile.name}');
    }
  }

  Future<void> _getInitialPosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      currentPosition = LatLng(position.latitude, position.longitude);

      if (mapController != null && mounted) {
        mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: currentPosition!,
              zoom: 17,
            ),
          ),
        );
      }
      setState(() {});
    } catch (e) {
      print('❌ Errore nel prendere posizione iniziale: $e');
    }
  }

  @override
  void dispose() {
    hrSubscription?.cancel();
    posSubscription?.cancel();
    caloriesTimer?.cancel();
    super.dispose();
  }

  void _startListening() {
    hrSubscription = widget.heartRateStream.listen((hr) {
      if (mounted) {
        setState(() {
          currentHeartRate = hr;
        });
      }
    });

    posSubscription = widget.positionStream.listen((pos) {
      if (mounted) {
        setState(() {
          routePoints.add(pos);

          if (lastPosition != null) {
            final distance = Geolocator.distanceBetween(
              lastPosition!.latitude,
              lastPosition!.longitude,
              pos.latitude,
              pos.longitude,
            );
            totalDistance += distance / 1000; // in km

            final elapsed = DateTime.now().difference(startTime).inSeconds;
            if (totalDistance > 0 && elapsed > 0) {
              avgSpeed = (elapsed / 60) / totalDistance; // min/km
            }
          }

          lastPosition = pos;

          if (mapController != null) {
            if (!hasCenteredMap) {
              mapController!.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: pos, zoom: 17),
                ),
              );
              hasCenteredMap = true;
            } else {
              mapController!.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: pos, zoom: 17),
                ),
              );
            }
          }
        });
      }
    });
  }

  void _startCaloriesCalculation() {
    caloriesTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _calculateCalories();
    });
  }

  void _calculateCalories() {
    if (activeProfile == null || totalDistance == 0) return;

    final elapsed = DateTime.now().difference(startTime).inSeconds;
    if (elapsed == 0) return;

    // Velocità media in km/h
    final avgSpeedKmh = (totalDistance / (elapsed / 3600));

    // Formula: calorie = Distanza(km) * peso(kg) * ((0.035+0.029*(v.media/10))*Fs*Fe)
    final calculatedCalories = activeProfile!.calculateCalories(totalDistance, avgSpeedKmh);

    if (mounted) {
      setState(() {
        calories = calculatedCalories;
      });
    }
  }

  String _formatDuration() {
    final elapsed = DateTime.now().difference(startTime);
    final hours = elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _stopActivity() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pause_circle_outline, color: Color.fromARGB(255, 255, 255, 255), size: 60),
              const SizedBox(height: 20),
              const Text(
                'VUOI FERMARE\nL\'ATTIVITÀ?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'SF Pro Display',
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF1744),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'NO',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _calculateCalories(); // Calcolo finale
                        Navigator.pop(context);
                        widget.onStopActivity(widget.activityId, calories);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'SÌ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: Stack(
        children: [
          AppleMap(
            onMapCreated: (controller) {
              mapController = controller;

              if (currentPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: currentPosition!, zoom: 17),
                  ),
                );
              } else if (lastPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: lastPosition!, zoom: 17),
                  ),
                );
                hasCenteredMap = true;
              }
            },
            initialCameraPosition: CameraPosition(
              target: currentPosition ?? lastPosition ?? const LatLng(45.4642, 9.19),
              zoom: 17,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: false,
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
          
          // Header con stats
          Positioned(
            top: 60,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color.fromARGB(255, 255, 210, 31), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(255, 255, 210, 31).withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Column(
                children: [
                  Text(
                    _formatDuration(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'SF Pro Display',
                      letterSpacing: -2,
                    ),
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
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Bottone STOP
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _stopActivity,
                child: Container(
                  width: 200,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.stop_rounded, color: Colors.white, size: 32),
                      SizedBox(width: 12),
                      Text(
                        'STOP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          fontFamily: 'SF Pro Display',
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String emoji, String value, String unit) {
    return Column(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 24),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFamily: 'SF Pro Display',
            letterSpacing: -0.5,
          ),
        ),
        Text(
          unit,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        )
      ],
    );
  }
}
