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
  bool isSelectionMode = false;
  Set<int> selectedActivities = {};
  
  final String serverUrl = 'https://heart-rate-monitor-hu47.onrender.com';

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _uploadLocalActivity(Map<String, dynamic> activity) async {
    try {
      print("⬆️ Carico attività locale ID ${activity['id']} sul server...");
      final response = await http.post(
        Uri.parse('$serverUrl/api/activity/import'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(activity),
      );
      if (response.statusCode == 200) {
        print("✅ Attività ${activity['id']} inviata correttamente");
      } else {
        print("⚠️ Errore durante l'invio (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      print("❌ Errore in _uploadLocalActivity: $e");
    }
  }

  Future<void> _loadActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('last_device_id');

      if (deviceId == null) {
        print("⚠️ Nessun dispositivo collegato");
        setState(() => isLoading = false);
        return;
      }

      setState(() => isLoading = true);

      // ===============================
      // 1️⃣ Prima carica dalla CACHE
      // ===============================
      print("📂 Caricamento attività locali...");
      final localActivities = await LocalDatabase.getActivitiesByDevice(deviceId);

      if (localActivities.isNotEmpty) {
        print("✅ ${localActivities.length} attività trovate in cache");
        setState(() {
          activities = localActivities;
          isLoading = false;
        });
      } else {
        print("📭 Nessuna attività locale trovata");
      }

      // ===============================
      // 2️⃣ Poi carica dal SERVER
      // ===============================
      print("📡 Contatto il server per aggiornare...");
      final response = await http
          .get(Uri.parse('$serverUrl/api/activities?device_id=$deviceId'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print("⚠️ Nessuna risposta valida dal server (${response.statusCode})");
        setState(() => isLoading = false);
        return;
      }

      final serverActivities =
          List<Map<String, dynamic>>.from(json.decode(response.body));
      print("✅ Server ha restituito ${serverActivities.length} attività");

      // ===============================
      // 3️⃣ SINCRONIZZAZIONE CACHE → SERVER
      // ===============================

      // 🔹 Aggiungi le attività locali che non esistono sul server
      for (final localActivity in localActivities) {
        final exists = serverActivities.any((s) => s['id'] == localActivity['id']);
        if (!exists) {
          await _uploadLocalActivity(localActivity);
        }
      }

      // 🔹 Aggiungi in CACHE quelle presenti sul server ma assenti in locale
      for (final serverActivity in serverActivities) {
        final exists =
            localActivities.any((l) => l['id'] == serverActivity['id']);
        if (!exists) {
          await LocalDatabase.saveActivity(serverActivity);
        }
      }

      // ===============================
      // 4️⃣ AGGIORNA UI con la cache aggiornata
      // ===============================
      final updatedActivities = await LocalDatabase.getActivitiesByDevice(deviceId);
      setState(() {
        activities = updatedActivities;
        isLoading = false;
        isOnline = true;
      });

      print("✅ Sincronizzazione completata: ${activities.length} attività finali");

    } catch (e) {
      print("❌ Errore in _loadActivities(): $e");
      setState(() {
        isLoading = false;
        isOnline = false;
      });
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
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 30, 30, 30),
        elevation: 0,
        title: isSelectionMode
            ? Text(
                '${selectedActivities.length} selezionate',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'SF Pro Display',
                ),
              )
            : const Text(
                'Registro Attività',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'SF Pro Display',
                ),
              ),
        centerTitle: true,
        leading: isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    isSelectionMode = false;
                    selectedActivities.clear();
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
        actions: isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all, color: Colors.white),
                  tooltip: 'Seleziona tutto',
                  onPressed: () {
                    setState(() {
                      if (selectedActivities.length == activities.length) {
                        selectedActivities.clear();
                      } else {
                        selectedActivities = activities.map((a) => a['id'] as int).toSet();
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Elimina',
                  onPressed: _deleteSelectedActivities,
                ),
                const SizedBox(width: 8),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.white),
                  tooltip: 'Seleziona per eliminare',
                  onPressed: () {
                    setState(() {
                      isSelectionMode = true;
                    });
                  },
                ),
                const SizedBox(width: 8),
              ],
      ),


      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color.fromARGB(255, 255, 210, 31)),
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
                  color: const Color.fromARGB(255, 255, 210, 31),
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
  final bool isSelected = selectedActivities.contains(activity['id']);
  
  return GestureDetector(
    onTap: () {
      if (isSelectionMode) {
        setState(() {
          if (isSelected) {
            selectedActivities.remove(activity['id']);
          } else {
            selectedActivities.add(activity['id']);
          }
        });
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActivitySummaryScreen(
              activityId: activity['id'],
            ),
          ),
        );
      }
    },
    onLongPress: () {
      if (!isSelectionMode) {
        setState(() {
          isSelectionMode = true;
          selectedActivities.add(activity['id']);
        });
      }
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isSelected
              ? [
                  const Color(0xFFFF1744).withOpacity(0.3),
                  const Color(0xFF0A0E21).withOpacity(0.8),
                ]
              : [
                  const Color(0xFFFC5200).withOpacity(0.15),
                  const Color(0xFF0A0E21).withOpacity(0.8),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFFF1744)
              : const Color(0xFFFC5200).withOpacity(0.3),
          width: isSelected ? 3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFFFF1744).withOpacity(0.3)
                : const Color(0xFFFC5200).withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
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
                          color: isSelected
                              ? const Color(0xFFFF1744).withOpacity(0.3)
                              : const Color(0xFFFC5200).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isSelected ? Icons.check_circle : Icons.directions_run,
                          color: isSelected ? const Color(0xFFFF1744) : const Color(0xFFFC5200),
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
                  Icon(
                    isSelectionMode ? Icons.more_vert : Icons.chevron_right,
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
        ],
      ),
    ),
  );
}

  Future<void> _deleteSelectedActivities() async {
    if (selectedActivities.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Elimina attività',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        content: Text(
          'Vuoi eliminare definitivamente ${selectedActivities.length} attività?\n\nQuesta operazione non può essere annullata.',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'ANNULLA',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'ELIMINA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Mostra loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFFC5200)),
      ),
    );

    int deletedCount = 0;
    int failedCount = 0;

    for (int activityId in selectedActivities) {
      try {
        // 1. Elimina dal SERVER
        final response = await http.delete(
          Uri.parse('$serverUrl/api/activity/$activityId'),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          print("✅ Attività $activityId eliminata dal server");
          deletedCount++;
        } else {
          print("⚠️ Errore eliminazione server (${response.statusCode}): ${response.body}");
          failedCount++;
        }
      } catch (e) {
        print("❌ Errore connessione server per attività $activityId: $e");
        failedCount++;
      }

      // 2. Elimina dalla CACHE locale
      await LocalDatabase.deleteActivity(activityId);
    }

    // Chiudi loading
    if (mounted) Navigator.pop(context);

    // Ricarica lista
    setState(() {
      activities.removeWhere((a) => selectedActivities.contains(a['id']));
      selectedActivities.clear();
      isSelectionMode = false;
    });

    // Mostra risultato
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failedCount > 0
                ? '✅ $deletedCount eliminate, ⚠️ $failedCount errori'
                : '✅ $deletedCount attività eliminate con successo',
          ),
          backgroundColor: failedCount > 0 ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
