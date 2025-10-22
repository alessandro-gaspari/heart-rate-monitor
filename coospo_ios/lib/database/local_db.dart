import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LocalDatabase {
  static const String _activitiesKey = 'activities_cache';
  static const String _waypointsKey = 'waypoints_cache';
  
  // Salva attività in locale
  static Future<void> saveActivity(Map<String, dynamic> activity) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Carica attività esistenti
    final activitiesJson = prefs.getString(_activitiesKey) ?? '[]';
    final activities = List<Map<String, dynamic>>.from(json.decode(activitiesJson));
    
    // Rimuovi duplicati (stesso ID)
    activities.removeWhere((a) => a['id'] == activity['id']);
    
    // Aggiungi nuova attività
    activities.add(activity);
    
    // Salva
    await prefs.setString(_activitiesKey, json.encode(activities));
    
    print('✅ Attività ${activity['id']} salvata in cache');
  }
  
  // Salva waypoints in locale
  static Future<void> saveWaypoints(int activityId, List<Map<String, dynamic>> waypoints) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Carica waypoints esistenti
    final waypointsJson = prefs.getString(_waypointsKey) ?? '{}';
    final allWaypoints = Map<String, dynamic>.from(json.decode(waypointsJson));
    
    // Salva waypoints per questa attività
    allWaypoints[activityId.toString()] = waypoints;
    
    // Salva
    await prefs.setString(_waypointsKey, json.encode(allWaypoints));
    
    print('✅ ${waypoints.length} waypoints salvati per attività $activityId');
  }
  
  // Ottieni attività dal locale per device_id
  static Future<List<Map<String, dynamic>>> getActivitiesByDevice(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    
    final activitiesJson = prefs.getString(_activitiesKey) ?? '[]';
    final allActivities = List<Map<String, dynamic>>.from(json.decode(activitiesJson));
    
    // Filtra per device_id
    final filtered = allActivities.where((a) => 
      a['device_id'] == deviceId && a['status'] == 'completed'
    ).toList();
    
    // Ordina per data (più recenti prima)
    filtered.sort((a, b) {
      final dateA = DateTime.parse(a['start_time']);
      final dateB = DateTime.parse(b['start_time']);
      return dateB.compareTo(dateA);
    });
    
    return filtered;
  }
  
  // Ottieni waypoints per attività
  static Future<List<Map<String, dynamic>>> getWaypoints(int activityId) async {
    final prefs = await SharedPreferences.getInstance();
    
    final waypointsJson = prefs.getString(_waypointsKey) ?? '{}';
    final allWaypoints = Map<String, dynamic>.from(json.decode(waypointsJson));
    
    if (allWaypoints.containsKey(activityId.toString())) {
      return List<Map<String, dynamic>>.from(allWaypoints[activityId.toString()]);
    }
    
    return [];
  }
  
  // Ottieni singola attività con waypoints
  static Future<Map<String, dynamic>?> getActivityWithWaypoints(int activityId) async {
    final prefs = await SharedPreferences.getInstance();
    
    final activitiesJson = prefs.getString(_activitiesKey) ?? '[]';
    final allActivities = List<Map<String, dynamic>>.from(json.decode(activitiesJson));
    
    try {
      final activity = allActivities.firstWhere((a) => a['id'] == activityId);
      final waypoints = await getWaypoints(activityId);
      
      activity['waypoints'] = waypoints;
      
      return activity;
    } catch (e) {
      return null;
    }
  }
  
  // NUOVO: Elimina attività
  static Future<void> deleteActivity(int activityId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Rimuovi attività
    final activitiesJson = prefs.getString(_activitiesKey) ?? '[]';
    final activities = List<Map<String, dynamic>>.from(json.decode(activitiesJson));
    activities.removeWhere((a) => a['id'] == activityId);
    await prefs.setString(_activitiesKey, json.encode(activities));
    
    // Rimuovi waypoints
    final waypointsJson = prefs.getString(_waypointsKey) ?? '{}';
    final allWaypoints = Map<String, dynamic>.from(json.decode(waypointsJson));
    allWaypoints.remove(activityId.toString());
    await prefs.setString(_waypointsKey, json.encode(allWaypoints));
    
    print('✅ Attività $activityId eliminata dalla cache');
  }
  
  // Pulisci cache (opzionale)
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activitiesKey);
    await prefs.remove(_waypointsKey);
    print('✅ Cache pulita');
  }
}
