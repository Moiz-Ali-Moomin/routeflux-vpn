
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/proxy_profile.dart';

class PreferencesService {
  static const String _keyProfiles = 'proxy_profiles';
  static const String _keySelectedId = 'selected_profile_id';

  Future<void> saveProfile(ProxyProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    List<ProxyProfile> profiles = await getProfiles();
    
    // update if exists, else add
    int index = profiles.indexWhere((p) => p.id == profile.id);
    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }
    
    await _saveList(prefs, profiles);
  }

  Future<List<ProxyProfile>> getProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonStr = prefs.getString(_keyProfiles);
    if (jsonStr == null) return [];
    
    try {
      List<dynamic> list = jsonDecode(jsonStr);
      return list.map((e) => ProxyProfile.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteProfile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<ProxyProfile> profiles = await getProfiles();
    profiles.removeWhere((p) => p.id == id);
    await _saveList(prefs, profiles);
  }
  
  Future<void> _saveList(SharedPreferences prefs, List<ProxyProfile> list) async {
    String jsonStr = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_keyProfiles, jsonStr);
  }

  Future<void> setSelectedProfileId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      prefs.remove(_keySelectedId);
    } else {
      prefs.setString(_keySelectedId, id);
    }
  }

  Future<String?> getSelectedProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedId);
  }
}
