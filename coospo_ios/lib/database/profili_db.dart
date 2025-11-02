import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_profile.dart';

class ProfileDatabase {
  static const String _profilesKey = 'user_profiles';
  static const String _activeProfileKey = 'active_profile_id';

  // Salva o aggiorna un profilo utente
  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Recupera i profili salvati
    final profilesJson = prefs.getString(_profilesKey) ?? '[]';
    final profiles = List<Map<String, dynamic>>.from(json.decode(profilesJson));
    
    // Rimuove eventuali duplicati con lo stesso ID
    profiles.removeWhere((p) => p['id'] == profile.id);
    profiles.add(profile.toJson());
    
    // Salva la lista aggiornata
    await prefs.setString(_profilesKey, json.encode(profiles));
    print('✅ Profilo ${profile.name} salvato');
  }

  // Restituisce tutti i profili salvati
  static Future<List<UserProfile>> getAllProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getString(_profilesKey) ?? '[]';
    final profilesList = List<Map<String, dynamic>>.from(json.decode(profilesJson));
    
    // Converte ogni elemento in un oggetto UserProfile
    return profilesList.map((json) => UserProfile.fromJson(json)).toList();
  }

  // Imposta l’ID del profilo attivo
  static Future<void> setActiveProfile(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileKey, profileId);
    print('✅ Profilo attivo impostato: $profileId');
  }

  // Restituisce il profilo attivo, se presente
  static Future<UserProfile?> getActiveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_activeProfileKey);
    
    if (activeId == null) return null;
    
    final profiles = await getAllProfiles();
    try {
      // Trova il profilo corrispondente all’ID attivo
      return profiles.firstWhere((p) => p.id == activeId);
    } catch (e) {
      return null;
    }
  }

  // Elimina un profilo e aggiorna l’attivo se necessario
  static Future<void> deleteProfile(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Rimuove il profilo dalla lista
    final profilesJson = prefs.getString(_profilesKey) ?? '[]';
    final profiles = List<Map<String, dynamic>>.from(json.decode(profilesJson));
    profiles.removeWhere((p) => p['id'] == profileId);
    await prefs.setString(_profilesKey, json.encode(profiles));
    
    // Se il profilo eliminato era quello attivo, rimuovilo
    final activeId = prefs.getString(_activeProfileKey);
    if (activeId == profileId) {
      await prefs.remove(_activeProfileKey);
    }
    
    print('✅ Profilo eliminato');
  }
}