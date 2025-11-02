import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LocalDatabase {
  static const String _activitiesKey = 'activities_cache';
  static const String _waypointsKey = 'waypoints_cache';

  // Salva o aggiorna un’attività nella cache locale
  static Future<void> saveActivity(Map<String, dynamic> activity) async {
    final prefs = await SharedPreferences.getInstance();

    // Recupera la lista di attività salvate
    final activitiesJson = prefs.getString(_activitiesKey) ?? '[]';
    final activities = List<Map<String, dynamic>>.from(json.decode(activitiesJson));

    // Rimuove l’attività esistente (se già presente) e la aggiunge aggiornata
    activities.removeWhere((a) => a['id'] == activity['id']);
    activities.add(activity);

    // Salva nuovamente la lista aggiornata
    await prefs.setString(_activitiesKey, json.encode(activities));
    print('✅ Attività ${activity['id']} salvata in cache');
  }

  // Salva i waypoints di una specifica attività
  static Future<void> saveWaypoints(int activityId, List<Map<String, dynamic>> waypoints) async {
    final prefs = await SharedPreferences.getInstance();

    // Recupera tutti i waypoints salvati
    final waypointsJson = prefs.getString(_waypointsKey) ?? '{}';
    final allWaypoints = Map<String, dynamic>.from(json.decode(waypointsJson));

    // Aggiunge o aggiorna i waypoints dell’attività indicata
    allWaypoints[activityId.toString()] = waypoints;

    await prefs.setString(_waypointsKey, json.encode(allWaypoints));
    print('✅ ${waypoints.length} waypoints salvati per attività $activityId');
  }

  // Restituisce le attività completate di un device, ordinate per data (dalla più recente)
  static Future<List<Map<String, dynamic>>> getActivitiesByDevice(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();

    final activitiesJson = prefs.getString(_activitiesKey) ?? '[]';
    final allActivities = List<Map<String, dynamic>>.from(json.decode(activitiesJson));

    // Filtra le attività per device e stato completato
    final filtered = allActivities.where((a) =>
      a['device_id'] == deviceId && a['status'] == 'completed'
    ).toList();

    // Ordina per data di inizio (decrescente)
    filtered.sort((a, b) {
      final dateA = DateTime.parse(a['start_time']);
      final dateB = DateTime.parse(b['start_time']);
      return dateB.compareTo(dateA);
    });

    return filtered;
  }

  // Restituisce i waypoints di una specifica attività
  static Future<List<Map<String, dynamic>>> getWaypoints(int activityId) async {
    final prefs = await SharedPreferences.getInstance();

    final waypointsJson = prefs.getString(_waypointsKey) ?? '{}';
    final allWaypoints = Map<String, dynamic>.from(json.decode(waypointsJson));

    // Se l’attività ha waypoints salvati, li restituisce
    if (allWaypoints.containsKey(activityId.toString())) {
      return List<Map<String, dynamic>>.from(allWaypoints[activityId.toString()]);
    }

    return [];
  }

  // Restituisce un’attività completa dei suoi waypoints
  static Future<Map<String, dynamic>?> getActivityWithWaypoints(int activityId) async {
    final prefs = await SharedPreferences.getInstance();

    final activitiesJson = prefs.getString(_activitiesKey) ?? '[]';
    final allActivities = List<Map<String, dynamic>>.from(json.decode(activitiesJson));

    try {
      // Trova l’attività e aggiunge i waypoints corrispondenti
      final activity = allActivities.firstWhere((a) => a['id'] == activityId);
      final waypoints = await getWaypoints(activityId);
      activity['waypoints'] = waypoints;
      return activity;
    } catch (e) {
      return null;
    }
  }

  // Aggiorna calorie, orario di fine e stato di un’attività
  static Future<void> updateActivityCalories(int activityId, double calories) async {
    final prefs = await SharedPreferences.getInstance();

    final activitiesJson = prefs.getString(_activitiesKey) ?? '[]';
    final activities = List<Map<String, dynamic>>.from(json.decode(activitiesJson));

    for (var activity in activities) {
      if (activity['id'] == activityId) {
        activity['calories'] = calories;
        activity['end_time'] = DateTime.now().toIso8601String();
        activity['status'] = 'completed';
        break;
      }
    }

    await prefs.setString(_activitiesKey, json.encode(activities));
    print('✅ Calorie aggiornate per attività $activityId: ${calories.toStringAsFixed(1)} kcal');
  }

  // Elimina un’attività e i suoi waypoints associati
  static Future<void> deleteActivity(int activityId) async {
    final prefs = await SharedPreferences.getInstance();

    // Rimuove l’attività
    final activitiesJson = prefs.getString(_activitiesKey) ?? '[]';
    final activities = List<Map<String, dynamic>>.from(json.decode(activitiesJson));
    activities.removeWhere((a) => a['id'] == activityId);
    await prefs.setString(_activitiesKey, json.encode(activities));

    // Rimuove i waypoints associati
    final waypointsJson = prefs.getString(_waypointsKey) ?? '{}';
    final allWaypoints = Map<String, dynamic>.from(json.decode(waypointsJson));
    allWaypoints.remove(activityId.toString());
    await prefs.setString(_waypointsKey, json.encode(allWaypoints));

    print('✅ Attività $activityId eliminata dalla cache');
  }

  // Cancella completamente cache di attività e waypoints
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activitiesKey);
    await prefs.remove(_waypointsKey);
    print('✅ Cache pulita');
  }
}