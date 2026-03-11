import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  static const String _usersKey = 'users';
  static const String _medicationsKey = 'medications';
  static const String _currentUserKey = 'currentUser';

  // ==================== USUÁRIOS ====================
  
  Future<void> saveProfile(Map<String, dynamic> profile) async {
    await saveUser(profile);
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    final users = await getUsers();
    
    final userIndex = users.indexWhere((u) => u['uid'] == user['uid']);
    if (userIndex >= 0) {
      users[userIndex] = user;
    } else {
      users.add(user);
    }
    
    await prefs.setString(_usersKey, json.encode(users));
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersString = prefs.getString(_usersKey);
    
    if (usersString == null) return [];
    
    try {
      final List<dynamic> usersList = json.decode(usersString);
      return usersList.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final users = await getUsers();
    try {
      return users.firstWhere((user) => user['email'] == email);
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserById(String uid) async {
    final users = await getUsers();
    try {
      return users.firstWhere((user) => user['uid'] == uid);
    } catch (e) {
      return null;
    }
  }

  // ==================== MEDICAMENTOS ====================

  Future<void> saveMedication(Map<String, dynamic> medication) async {
    final prefs = await SharedPreferences.getInstance();
    final medications = await getMedications();
    
    if (medication['id'] != null && (medication['id'] as String).isNotEmpty) {
      final index = medications.indexWhere((m) => m['id'] == medication['id']);
      if (index >= 0) {
        medications[index] = medication;
      } else {
        medications.add(medication);
      }
    } else {
      medication['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      medications.add(medication);
    }
    
    await prefs.setString(_medicationsKey, json.encode(medications));
  }

  Future<void> saveAllMedications(List<Map<String, dynamic>> medications) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_medicationsKey, json.encode(medications));
  }

  Future<List<Map<String, dynamic>>> getMedications({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final medicationsString = prefs.getString(_medicationsKey);
    
    if (medicationsString == null) return [];
    
    try {
      final List<dynamic> medsList = json.decode(medicationsString);
      final allMeds = medsList.cast<Map<String, dynamic>>();
      
      if (userId != null) {
        return allMeds.where((med) => med['userId'] == userId).toList();
      }
      
      return allMeds;
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteMedication(String medicationId) async {
    final prefs = await SharedPreferences.getInstance();
    final medications = await getMedications();
    
    final updatedMeds = medications.where((m) => m['id'] != medicationId).toList();
    await prefs.setString(_medicationsKey, json.encode(updatedMeds));
  }

  // ==================== SESSÃO ATUAL ====================

  Future<void> setCurrentUser(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId == null) {
      await prefs.remove(_currentUserKey);
    } else {
      await prefs.setString(_currentUserKey, userId);
    }
  }

  Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserKey);
  }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}