import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'activity_summary_screen.dart';
import '../database/local_db.dart';

class ActivitiesArchiveScreen extends StatefulWidget {
  const ActivitiesArchiveScreen({Key? key}) : super(key: key);

  @override
  _ActivitiesArchiveScreenState createState() => _ActivitiesArchiveScreenState();
}

class _ActivitiesArchiveScreenState extends State<ActivitiesArchiveScreen> {
  List<dynamic> activities = [];
  bool isLoading = true;
  bool isOnline = true;
  
  final String serverUrl = 'https://heart-rate-monitor-hu47.onrender.com';

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('last_device_id');
      
      if (deviceId == null) {
        print("⚠️ Nessun dispositivo connesso");
        setState(() => isLoading = false);
        return;
      }
      
      // STEP 1: Carica da locale (cache)
      print("📂 Caricamento da cache locale...");
      final localActivities = await LocalDatabase.getActivitiesByDevice(deviceId);
      
      if (localActivities.isNotEmpty) {
        setState(() {
          activities = localActivities;
          isLoading = false;
        });
        print("✅ ${localActivities.length} attività caricate da cache");
      }
      
      // STEP 2: Sincronizza con server
      print("📡 Sincronizzazione con server...");
      
      try {
        final response = await http.get(
          Uri.parse('$serverUrl/api/activities?device_id=$deviceId'),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final serverActivities = json.decode(response.body);
          print("✅ ${serverActivities.length} attività dal server");
          
          // Salva in locale
          for (var activity in serverActivities) {
            await LocalDatabase.saveActivity(activity);
            
            // Scarica e salva waypoints
            final waypointsResponse = await http.get(
              Uri.parse('$serverUrl/api/activity/${activity['id']}'),
            ).timeout(const Duration(seconds: 5));
            
            if (waypointsResponse.statusCode == 200) {
              final activityData = json.decode(waypointsResponse.body);
              await LocalDatabase.saveWaypoints(
                activity['id'],
                List<Map<String, dynamic>>.from(activityData['waypoints']),
              );
            }
          }
          
          setState(() {
            activities = serverActivities;
            isOnline = true;
          });
          
          print("✅ Sincronizzazione completata");
        }
      } catch (e) {
        print("⚠️ Server non raggiungibile: $e");
        setState(() => isOnline = false);
        
        // Usa solo cache locale
        if (activities.isEmpty) {
          final localActivities = await LocalDatabase.getActivitiesByDevice(deviceId);
          setState(() {
            activities = localActivities;
          });
        }
      }
      
      setState(() => isLoading = false);
      
    } catch (e) {
      print("❌ Errore: $e");
      setState(() => isLoading = false);
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDuration(String startStr, String? endStr) {
    if (endStr == null) return '--';
    try {
      final start = DateTime.parse(startStr);
      final end = DateTime.parse(endStr);
      final duration = end.difference(start);
      return '${duration.inMinutes} min';
    } catch (e) {
      return '--';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Registro Attività',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                fontFamily: 'SF Pro Display',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isOnline ? 'ONLINE' : 'OFFLINE',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFC5200)),
            )
          : activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.directions_run, size: 80, color: Colors.white30),
                      SizedBox(height: 20),
                      Text(
                        'Nessuna attività registrata',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadActivities,
                  color: const Color(0xFFFC5200),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: activities.length,
                    itemBuilder: (context, index) {
                      final activity = activities[index];
                      return _buildActivityCard(activity);
                    },
                  ),
                ),
    );
  }

  Widget _buildActivityCard(dynamic activity) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActivitySummaryScreen(
              activityId: activity['id'],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFC5200).withOpacity(0.15),
              const Color(0xFF0A0E21).withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFC5200).withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFC5200).withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFC5200).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.directions_run,
                        color: Color(0xFFFC5200),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(activity['start_time']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'SF Pro Display',
                          ),
                        ),
                        Text(
                          _formatDuration(activity['start_time'], activity['end_time']),
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white30,
                  size: 28,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat('📍', '${activity['distance_km']?.toStringAsFixed(2) ?? '0'} km'),
                _buildMiniStat('❤️', '${activity['avg_heart_rate'] ?? 0} bpm'),
                _buildMiniStat('🔥', '${activity['calories']?.toStringAsFixed(0) ?? '0'} kcal'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String emoji, String value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'SF Pro Display',
          ),
        ),
      ],
    );
  }
}
