// Import dei pacchetti necessari
import 'package:flutter/material.dart'; // UI di Flutter
import 'package:apple_maps_flutter/apple_maps_flutter.dart'; // Mappa Apple
import 'dart:async'; // Supporto per funzioni asincrone
import '../database/local_db.dart'; // Database locale dell’app

// Widget principale per visualizzare il riepilogo dell’attività
class ActivitySummaryScreen extends StatefulWidget {
  final int activityId; // ID dell’attività da visualizzare

  const ActivitySummaryScreen({Key? key, required this.activityId}) : super(key: key);

  @override
  _ActivitySummaryScreenState createState() => _ActivitySummaryScreenState();
}

// Stato del widget ActivitySummaryScreen
class _ActivitySummaryScreenState extends State<ActivitySummaryScreen> {
  bool isLoading = true; // Stato caricamento
  Map<String, dynamic>? activityData; // Dati dell’attività
  List<Map<String, dynamic>> waypoints = []; // Lista dei punti GPS
  String? errorMessage; // Eventuale messaggio di errore
  
  AppleMapController? mapController; // Controller per la mappa
  Set<Polyline> polylines = {}; // Polilinee da disegnare sulla mappa

  @override
  void initState() {
    super.initState();
    _loadActivityData(); // Carica i dati all’avvio
  }

  // Funzione per caricare i dati dell’attività dal database locale
  Future<void> _loadActivityData() async {
    setState(() => isLoading = true); // Mostra loader

    try {
      print("📥 Caricamento attività ${widget.activityId}...");
      
      // Richiama il database locale
      final localActivity = await LocalDatabase.getActivityWithWaypoints(widget.activityId);
      
      if (localActivity != null) {
        // Debug dei dati caricati
        print("✅ Attività caricata: ${localActivity['id']}");
        print("📦 Dati attività: $localActivity");
        print("📍 Waypoints totali: ${localActivity['waypoints']?.length ?? 0}");
        
        final waypointsList = localActivity['waypoints'] ?? [];
        
        setState(() {
          activityData = localActivity;
          waypoints = List<Map<String, dynamic>>.from(waypointsList); // Assicura tipo corretto
          isLoading = false;
        });
        
        // Se ci sono waypoints costruisce le polilinee
        if (waypoints.isNotEmpty) {
          print("🗺️ Waypoints disponibili, costruisco mappa...");
          _buildPolyline();
        } else {
          print("⚠️ Nessun waypoint disponibile per la mappa");
        }
      } else {
        print("❌ Attività ${widget.activityId} non trovata nel database locale");
        setState(() {
          isLoading = false;
          errorMessage = 'Attività non trovata nel database locale';
        });
      }
    } catch (e, stackTrace) {
      // Gestione errore caricamento
      print("❌ Errore caricamento: $e");
      print("Stack trace: $stackTrace");
      setState(() {
        isLoading = false;
        errorMessage = 'Errore: $e';
      });
    }
  }

  // Funzione per creare le polilinee colorate in base al battito
  void _buildPolyline() {
    if (waypoints.isEmpty) return;

    print("🗺️ Costruzione polyline con ${waypoints.length} waypoints");
    
    Set<Polyline> polylineSet = {};
    
    // Ciclo tra tutti i punti per creare segmenti
    for (int i = 0; i < waypoints.length - 1; i++) {
      final currentWaypoint = waypoints[i];
      final nextWaypoint = waypoints[i + 1];
      
      final currentHR = currentWaypoint['heart_rate'] ?? 0; // Frequenza cardiaca

      // Colore della polyline in base al battito
      Color segmentColor;
      if (currentHR == 0) {
        segmentColor = const Color.fromARGB(255, 255, 210, 31); // Giallo se dati mancanti
      } else if (currentHR < 100) {
        segmentColor = Colors.green;
      } else if (currentHR < 140) {
        segmentColor = Colors.orange;
      } else {
        segmentColor = Colors.red;
      }
      
      // Coordinate della linea tra i due waypoint
      final segmentPoints = [
        LatLng(
          currentWaypoint['latitude'] as double,
          currentWaypoint['longitude'] as double,
        ),
        LatLng(
          nextWaypoint['latitude'] as double,
          nextWaypoint['longitude'] as double,
        ),
      ];
      
      polylineSet.add(
        Polyline(
          polylineId: PolylineId('segment_$i'),
          points: segmentPoints,
          color: segmentColor,
          width: 5,
        ),
      );
    }
    
    print("✅ Creati ${polylineSet.length} segmenti colorati");
    
    // Aggiorna lo stato con le polilinee
    if (mounted) {
      setState(() {
        polylines = polylineSet;
      });
    }
  }

  // Costruzione interfaccia utente
  @override
  Widget build(BuildContext context) {
    // Mostra loader se ancora caricamento
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color.fromARGB(255, 255, 210, 31),
          ),
        ),
      );
    }

    // Mostra messaggio di errore se presente
    if (errorMessage != null || activityData == null) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 0, 0, 0),
          title: const Text('Errore', style: TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  errorMessage ?? 'Attività non trovata',
                  style: const TextStyle(color: Colors.white54, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 255, 210, 31),
                  foregroundColor: Colors.black,
                ),
                child: const Text('INDIETRO', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    // Calcolo dati principali
    final distance = (activityData!['distance'] ?? 0.0) / 1000; // km
    final duration = activityData!['duration'] ?? 0; // secondi
    final calories = activityData!['calories'] ?? 0.0; // kcal

    // Calcola passo (min/km)
    String pace = '--:--';
    if (distance > 0.01 && duration > 0) {  // almeno 10 metri
      final paceMinutes = duration / 60 / distance;
      
      if (paceMinutes < 100) {
        final minutes = paceMinutes.floor();
        final seconds = ((paceMinutes - minutes) * 60).round();
        pace = '$minutes:${seconds.toString().padLeft(2, '0')}';
      } else {
        pace = '--:--';
      }
    }

    // Lista dei battiti validi
    final heartRates = waypoints
        .where((w) => w['heart_rate'] != null && w['heart_rate'] > 0)
        .map((w) => w['heart_rate'] as int)
        .toList();
    
    // Media, max e min del battito
    final avgHeartRate = heartRates.isNotEmpty
        ? (heartRates.reduce((a, b) => a + b) / heartRates.length).round()
        : 0;
    final maxHeartRate = heartRates.isNotEmpty ? heartRates.reduce((a, b) => a > b ? a : b) : 0;
    final minHeartRate = heartRates.isNotEmpty ? heartRates.reduce((a, b) => a < b ? a : b) : 0;

    print("📊 Stats - Distance: $distance km, Duration: $duration s, Waypoints: ${waypoints.length}");

    // Inizio costruzione Scaffold principale
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        elevation: 0,
        title: const Text(
          'Riepilogo Attività',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [

            // MAPPA
            if (waypoints.length >= 2)
              Stack(
                children: [
                  Container(
                    height: 300,
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(255, 255, 210, 31).withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AbsorbPointer( // Disabilita interazioni mappa
                        child: AppleMap(
                          onMapCreated: (controller) {
                            mapController = controller;
                            Future.delayed(const Duration(milliseconds: 500), () {
                              _fitMapToBounds();
                            });
                          },
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              waypoints.first['latitude'] as double,
                              waypoints.first['longitude'] as double,
                            ),
                            zoom: 15.0,
                          ),
                          polylines: polylines,
                          myLocationEnabled: false,
                          compassEnabled: false,
                        ),
                      ),
                    ),
                  ),
                  // bottone fullscreen
                  Positioned(
                    top: 30,
                    right: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 255, 210, 31),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(255, 255, 210, 31).withOpacity(0.6),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.fullscreen, color: Colors.black),
                        iconSize: 24,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => _FullScreenMap(
                                waypoints: waypoints,
                                polylines: polylines,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                height: 200,
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 30, 30, 30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map_outlined, size: 60, color: Colors.white30),
                      const SizedBox(height: 10),
                      Text(
                        waypoints.length == 1 
                            ? 'Attività troppo breve\nMuoviti per registrare il percorso'
                            : 'Nessun percorso registrato',
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

            // Legenda BPM
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              child: Text(
                'B P M',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),

            // LEGENDA COLORI
            if (waypoints.isNotEmpty && heartRates.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem('< 100', Colors.green),
                    const SizedBox(width: 16),
                    _buildLegendItem('100-140', Colors.orange),
                    const SizedBox(width: 16),
                    _buildLegendItem('> 140', Colors.red),
                  ],
                ),
              ),

            // STATISTICHE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.route,
                          label: 'Distanza',
                          value: distance.toStringAsFixed(2),
                          unit: 'km',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.timer,
                          label: 'Durata',
                          value: _formatDuration(duration),
                          unit: '',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.local_fire_department,
                          label: 'Calorie',
                          value: calories.toStringAsFixed(0),
                          unit: 'kcal',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.speed,
                          label: 'Velocità Media',
                          value: pace,
                          unit: 'min/km',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // BATTITO CARDIACO
            if (heartRates.isNotEmpty) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color.fromARGB(255, 255, 210, 31).withOpacity(0.1),
                        const Color.fromARGB(255, 0, 0, 0).withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color.fromARGB(255, 255, 210, 31).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '❤️ Frequenza Cardiaca',
                        style: TextStyle(
                          color: Color.fromARGB(255, 255, 210, 31),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildHeartStat('Media', avgHeartRate),
                          _buildHeartStat('Max', maxHeartRate),
                          _buildHeartStat('Min', minHeartRate),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),

      // BOTTONE CHIUDI
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 0, 0, 0),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Torna alla prima schermata
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'CHIUDI',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ),
      ),  

    );
    
  }

  // Widget per le card statistiche
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color.fromARGB(255, 255, 210, 31).withOpacity(0.1),
            const Color.fromARGB(255, 0, 0, 0).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color.fromARGB(255, 255, 210, 31).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color.fromARGB(255, 255, 210, 31), size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Widget per statistiche battito
  Widget _buildHeartStat(String label, int value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Text('BPM', style: TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  // Legenda colore battito
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
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  // Formatta durata in h/m/s
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '${seconds}s';
    }
  }

  // Centra la mappa in base ai waypoints
  void _fitMapToBounds() {
    if (waypoints.isEmpty || mapController == null) return;

    double minLat = waypoints.first['latitude'] as double;
    double maxLat = waypoints.first['latitude'] as double;
    double minLng = waypoints.first['longitude'] as double;
    double maxLng = waypoints.first['longitude'] as double;

    for (var waypoint in waypoints) {
      final lat = waypoint['latitude'] as double;
      final lng = waypoint['longitude'] as double;
      
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    
    print("🗺️ Centrando mappa su: $center");
    
    mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: center, zoom: 14.0),
      ),
    );
  }
  
}

// MAPPA SCHERMO INTERO
class _FullScreenMap extends StatefulWidget {
  final List<Map<String, dynamic>> waypoints;
  final Set<Polyline> polylines;

  const _FullScreenMap({
    Key? key,
    required this.waypoints,
    required this.polylines,
  }) : super(key: key);

  @override
  _FullScreenMapState createState() => _FullScreenMapState();
}

class _FullScreenMapState extends State<_FullScreenMap> {
  AppleMapController? mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          AppleMap(
            onMapCreated: (controller) {
              mapController = controller;
              Future.delayed(const Duration(milliseconds: 500), () {
                _fitMapToBounds();
              });
            },
            initialCameraPosition: CameraPosition(
              target: LatLng(
                widget.waypoints.first['latitude'] as double,
                widget.waypoints.first['longitude'] as double,
              ),
              zoom: 15.0,
            ),
            polylines: widget.polylines,
            myLocationEnabled: false,
            compassEnabled: true,
            minMaxZoomPreference: const MinMaxZoomPreference(10, 20),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      iconSize: 28,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 255, 210, 31),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.my_location, color: Colors.black),
                      iconSize: 24,
                      onPressed: () => _fitMapToBounds(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _fitMapToBounds() {
    if (widget.waypoints.isEmpty || mapController == null) return;
    double minLat = widget.waypoints.first['latitude'] as double;
    double maxLat = minLat;
    double minLng = widget.waypoints.first['longitude'] as double;
    double maxLng = minLng;

    for (var w in widget.waypoints) {
      final lat = w['latitude'] as double;
      final lng = w['longitude'] as double;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
          zoom: 14.0,
        ),
      ),
    );
  }
}