import '../core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static const String _tokenKey = 'token';
  static const String _userDataKey = 'user_data';
  static const String _isRegisteredKey = 'isRegistered';

  // 🔹 Sauvegarde le token JWT
  Future<bool> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.setString(_tokenKey, token);
      logDebug('💾 Token enregistré avec succès: ${result ? 'oui' : 'non'}');
      return result;
    } catch (e) {
      logDebug('❌ Erreur lors de l\'enregistrement du token: $e');
      return false;
    }
  }

  // 🔹 Récupère le token
  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      logDebug('🔑 Token récupéré: ${token != null ? 'existant' : 'null'}');
      return token;
    } catch (e) {
      logDebug('❌ Erreur lors de la récupération du token: $e');
      return null;
    }
  }

  // 🔹 Supprime le token (déconnexion)
  Future<bool> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.remove(_tokenKey);
      logDebug('🗑️ Token supprimé avec succès');
      return result;
    } catch (e) {
      logDebug('❌ Erreur lors de la suppression du token: $e');
      return false;
    }
  }

  // 🔹 Vérifie si l’utilisateur est déjà inscrit
  Future<bool> saveIsRegistered(bool status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.setBool(_isRegisteredKey, status);
      logDebug('💾 Statut d\'inscription enregistré: $status');
      return result;
    } catch (e) {
      logDebug('❌ Erreur lors de l\'enregistrement du statut d\'inscription: $e');
      return false;
    }
  }

  Future<bool> getIsRegistered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isRegistered = prefs.getBool(_isRegisteredKey) ?? false;
      logDebug('🔍 Statut d\'inscription récupéré: $isRegistered');
      return isRegistered;
    } catch (e) {
      logDebug('❌ Erreur lors de la récupération du statut d\'inscription: $e');
      return false;
    }
  }

  // 🔹 Récupère les données de l'utilisateur connecté
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userData = prefs.getString(_userDataKey);

      if (userData != null) {
        logDebug('📋 Données utilisateur récupérées');
        return Map<String, dynamic>.from(json.decode(userData));
      }
      logDebug('ℹ️ Aucune donnée utilisateur trouvée');
      return null;
    } catch (e) {
      logDebug('❌ Erreur lors de la récupération des données utilisateur: $e');
      return null;
    }
  }

  // 🔹 Sauvegarde les données de l'utilisateur
  Future<bool> saveUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.setString(_userDataKey, json.encode(userData));
      logDebug('💾 Données utilisateur enregistrées avec succès');
      return result;
    } catch (e) {
      logDebug('❌ Erreur lors de l\'enregistrement des données utilisateur: $e');
      return false;
    }
  }

  // 🔹 Supprime toutes les données utilisateur (déconnexion complète)
  Future<bool> clearAllUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userDataKey);
      logDebug('🗑️ Toutes les données utilisateur ont été supprimées');
      return true;
    } catch (e) {
      logDebug('❌ Erreur lors de la suppression des données utilisateur: $e');
      return false;
    }
  }
}
