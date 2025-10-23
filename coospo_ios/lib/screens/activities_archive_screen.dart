import 'package:flutter/material.dart';
import '../database/local_db.dart';
import 'activity_summary_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';



class ActivitiesArchiveScreen extends StatefulWidget {
  final String? deviceId;

  const ActivitiesArchiveScreen({Key? key, this.deviceId}) : super(key: key);

  @override
  _ActivitiesArchiveScreenState createState() => _ActivitiesArchiveScreenState();
}

class _ActivitiesArchiveScreenState extends State<ActivitiesArchiveScreen> {
  List<Map<String, dynamic>> activities = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  String _getShortId(dynamic id) {
    final idStr = id.toString();
    if (idStr.length <= 4) {
      return idStr;
    }
    return idStr.substring(idStr.length - 4);
  }

  Future<void> _loadActivities() async {
    setState(() => isLoading = true);
    
    try {
      List<Map<String, dynamic>> loadedActivities;
      
      // ⭐ CARICA TUTTE LE ATTIVITÀ COMPLETATE (senza filtrare per device)
      loadedActivities = await _getAllActivities();
      print("📦 Caricate ${loadedActivities.length} attività totali");
      
      setState(() {
        activities = loadedActivities;
        isLoading = false;
      });
    } catch (e) {
      print("❌ Errore caricamento: $e");
      setState(() {
        activities = [];
        isLoading = false;
      });
    }
  }


  Future<List<Map<String, dynamic>>> _getAllActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final activitiesJson = prefs.getString('activities_cache') ?? '[]';
    final allActivities = List<Map<String, dynamic>>.from(json.decode(activitiesJson));
    
    print("🔍 Attività nel database: ${allActivities.length}");
    
    // Filtra solo completate
    final completed = allActivities.where((a) => a['status'] == 'completed').toList();
    
    print("✅ Attività completate: ${completed.length}");
    
    // Ordina per data
    completed.sort((a, b) {
      final dateA = DateTime.parse(a['start_time']);
      final dateB = DateTime.parse(b['start_time']);
      return dateB.compareTo(dateA);
    });
    
    return completed;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        elevation: 0,
        title: const Text(
          'Archivio Attività',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 255, 210, 31),
              ),
            )
          : activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.directions_run, size: 80, color: Colors.white30),
                      SizedBox(height: 20),
                      Text(
                        'Nessuna attività salvata',
                        style: TextStyle(color: Colors.white54, fontSize: 18),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color.fromARGB(255, 255, 210, 31),
                  onRefresh: _loadActivities,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: activities.length,
                    itemBuilder: (context, index) {
                      final activity = activities[index];
                      return _buildActivityCard(activity, index);
                    },
                  ),
                ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity, int index) {
    final startTime = DateTime.parse(activity['start_time']);
    final distance = (activity['distance'] ?? 0.0) / 1000;
    final duration = activity['duration'] ?? 0;
    final calories = activity['calories'] ?? 0.0;

    return GestureDetector(
      onTap: () {
        // ⭐ NAVIGA ALLA SUMMARY
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    // ✅ DOPO
                    '🏃 Attività #${_getShortId(activity['id'])}',
                    style: const TextStyle(
                      color: Color.fromARGB(255, 255, 210, 31),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteActivity(activity['id'], index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatDateTime(startTime),
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('📍', distance.toStringAsFixed(2), 'km'),
                _buildStat('⏱️', _formatDuration(duration), ''),
                _buildStat('🔥', calories.toStringAsFixed(0), 'kcal'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String emoji, String value, String unit) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (unit.isNotEmpty)
          Text(
            unit,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = ['Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  Future<void> _deleteActivity(int activityId, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 30, 30, 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Elimina Attività',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Vuoi eliminare definitivamente questa attività?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULLA', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ELIMINA', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await LocalDatabase.deleteActivity(activityId);
      setState(() {
        activities.removeAt(index);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attività eliminata'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
