import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_profile.dart';

class ProfileDatabase {
  static const String _profilesKey = 'user_profiles';
  static const String _activeProfileKey = 'active_profile_id';

  // Salva profilo
  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    
    final profilesJson = prefs.getString(_profilesKey) ?? '[]';
    final profiles = List<Map<String, dynamic>>.from(json.decode(profilesJson));
    
    // Rimuovi duplicati con stesso ID
    profiles.removeWhere((p) => p['id'] == profile.id);
    profiles.add(profile.toJson());
    
    await prefs.setString(_profilesKey, json.encode(profiles));
    print('✅ Profilo ${profile.name} salvato');
  }

  // Ottieni tutti i profili
  static Future<List<UserProfile>> getAllProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getString(_profilesKey) ?? '[]';
    final profilesList = List<Map<String, dynamic>>.from(json.decode(profilesJson));
    
    return profilesList.map((json) => UserProfile.fromJson(json)).toList();
  }

  // Imposta profilo attivo
  static Future<void> setActiveProfile(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileKey, profileId);
    print('✅ Profilo attivo impostato: $profileId');
  }

  // Ottieni profilo attivo
  static Future<UserProfile?> getActiveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_activeProfileKey);
    
    if (activeId == null) return null;
    
    final profiles = await getAllProfiles();
    try {
      return profiles.firstWhere((p) => p.id == activeId);
    } catch (e) {
      return null;
    }
  }

  // Elimina profilo
  static Future<void> deleteProfile(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    
    final profilesJson = prefs.getString(_profilesKey) ?? '[]';
    final profiles = List<Map<String, dynamic>>.from(json.decode(profilesJson));
    
    profiles.removeWhere((p) => p['id'] == profileId);
    await prefs.setString(_profilesKey, json.encode(profiles));
    
    // Se era il profilo attivo, rimuovilo
    final activeId = prefs.getString(_activeProfileKey);
    if (activeId == profileId) {
      await prefs.remove(_activeProfileKey);
    }
    
    print('✅ Profilo eliminato');
  }
}
