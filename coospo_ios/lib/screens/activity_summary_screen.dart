import 'dart:async';
import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../database/local_db.dart';

class ActivitySummaryScreen extends StatefulWidget {
  final int activityId;

  const ActivitySummaryScreen({Key? key, required this.activityId}) : super(key: key);

  @override
  _ActivitySummaryScreenState createState() => _ActivitySummaryScreenState();
}

class _ActivitySummaryScreenState extends State<ActivitySummaryScreen> {
  AppleMapController? mapController;
  bool isLoading = true;
  
  Map<String, dynamic> activityData = {};
  List<LatLng> routePoints = [];
  List<int> heartRates = [];
  
  final String serverUrl = 'https://heart-rate-monitor-hu47.onrender.com';

  @override
  void initState() {
    super.initState();
    _loadActivityData();
  }

  Future<void> _loadActivityData() async {
    try {
      print("📡 Caricamento attività ${widget.activityId}...");
      
      // STEP 1: Prova dal database locale
      final localActivity = await LocalDatabase.getActivityWithWaypoints(widget.activityId);
      
      if (localActivity != null) {
        print("✅ Attività caricata da cache locale");
        setState(() {
          activityData = localActivity;
          
          // Estrai waypoints
          for (var wp in localActivity['waypoints']) {
            routePoints.add(LatLng(wp['latitude'], wp['longitude']));
            heartRates.add(wp['heart_rate'] ?? 0);
          }
          
          isLoading = false;
        });
      }
      
      // STEP 2: Sincronizza con server
      try {
        final response = await http.get(
          Uri.parse('$serverUrl/api/activity/${widget.activityId}'),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          print("✅ Attività aggiornata dal server");
          
          // Salva in locale
          await LocalDatabase.saveActivity({
            'id': data['id'],
            'device_id': data['device_id'],
            'start_time': data['start_time'],
            'end_time': data['end_time'],
            'distance_km': data['distance_km'],
            'avg_speed': data['avg_speed'],
            'avg_heart_rate': data['avg_heart_rate'],
            'calories': data['calories'],
            'status': data['status'],
          });
          
          await LocalDatabase.saveWaypoints(
            data['id'],
            List<Map<String, dynamic>>.from(data['waypoints']),
          );
          
          setState(() {
            activityData = data;
            routePoints.clear();
            heartRates.clear();
            
            for (var wp in data['waypoints']) {
              routePoints.add(LatLng(wp['latitude'], wp['longitude']));
              heartRates.add(wp['heart_rate'] ?? 0);
            }
            
            isLoading = false;
          });
        }
      } catch (e) {
        print("⚠️ Server non raggiungibile, uso cache locale: $e");
        // Continua con i dati locali già caricati
      }
      
    } catch (e) {
      print("❌ Errore caricamento attività: $e");
      setState(() => isLoading = false);
    }
  }


  Color _getHRColor(int hr) {
    if (hr < 100) return const Color(0xFF00C853); // Verde - basso
    if (hr < 140) return const Color(0xFFFF9800); // Arancione - medio
    return const Color(0xFFFF1744); // Rosso - alto
  }

  List<Polyline> _buildColoredPolylines() {
    List<Polyline> polylines = [];
    
    for (int i = 0; i < routePoints.length - 1; i++) {
      final color = _getHRColor(heartRates[i]);
      
      polylines.add(
        Polyline(
          polylineId: PolylineId('segment_$i'),
          points: [routePoints[i], routePoints[i + 1]],
          color: color,
          width: 6,
        ),
      );
    }
    
    return polylines;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: Color(0xFFFC5200)),
              SizedBox(height: 20),
              Text(
                'Caricamento attività...',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        elevation: 0,
        title: const Text(
          'Riepilogo Attività',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFamily: 'SF Pro Display',
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // MAPPA CON PERCORSO COLORATO
            Container(
              height: 350,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(255, 255, 210, 31).withOpacity(0.6),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: routePoints.isEmpty
                    ? const Center(child: Text('Nessun percorso registrato', 
                        style: TextStyle(color: Colors.white)))
                    : AppleMap(
                        onMapCreated: (controller) {
                          mapController = controller;
                          
                          // Centra sulla rotta
                          if (routePoints.isNotEmpty) {
                            controller.animateCamera(
                              CameraUpdate.newLatLngBounds(
                                _calculateBounds(routePoints),
                                50,
                              ),
                            );
                          }

                          if (routePoints.isNotEmpty) {
                            controller.animateCamera(
                              CameraUpdate.newLatLngBounds(
                                _calculateBounds(routePoints),
                                50,
                              ), 
                            );
                          }
                        },
                        initialCameraPosition: CameraPosition(
                          target: routePoints.isNotEmpty 
                            ? routePoints.first 
                            : const LatLng(45.4642, 9.19),
                          zoom: 15,
                        ),
                        polylines: Set.from(_buildColoredPolylines()),
                        myLocationEnabled: false,
                        rotateGesturesEnabled: true,
                        scrollGesturesEnabled: true,
                        zoomGesturesEnabled: true,
                      ),
              ),
            ),
            
            // LEGENDA COLORI
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem('Basso', const Color(0xFF00C853)),
                  const SizedBox(width: 20),
                  _buildLegendItem('Medio', const Color(0xFFFF9800)),
                  const SizedBox(width: 20),
                  _buildLegendItem('Alto', const Color(0xFFFF1744)),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // STATISTICHE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                children: [
                  _buildStatCard(
                    '📍 DISTANZA',
                    '${activityData['distance_km']?.toStringAsFixed(2) ?? '0'} km',
                    const Color(0xFF6366F1),
                  ),
                  _buildStatCard(
                    '⏱️ TEMPO',
                    '${activityData['duration_minutes']?.toStringAsFixed(0) ?? '0'} min',
                    const Color(0xFF8B5CF6),
                  ),
                  _buildStatCard(
                    '🏃 V. MEDIA',
                    '${activityData['avg_speed']?.toStringAsFixed(1) ?? '0'} min/km',
                    const Color(0xFFEC4899),
                  ),
                  _buildStatCard(
                    '❤️ BPM MEDIO',
                    '${activityData['avg_heart_rate'] ?? 0}',
                    const Color(0xFFFF1744),
                  ),
                  _buildStatCard(
                    '🔥 CALORIE',
                    '${activityData['calories']?.toStringAsFixed(0) ?? '0'} kcal',
                    const Color(0xFFFF9800),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // BOTTONE CHIUDI
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 255, 210, 31),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'CHIUDI',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      fontFamily: 'SF Pro Display',
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'SF Pro Display',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                fontFamily: 'SF Pro Display',
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),

    );
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
