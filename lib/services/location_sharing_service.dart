import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service de partage de position en temps réel via Supabase Realtime.
///
/// Table Supabase requise :
///   create table live_locations (
///     id uuid primary key default uuid_generate_v4(),
///     user_id text unique,
///     latitude double precision,
///     longitude double precision,
///     active boolean default true,
///     updated_at timestamptz default now()
///   );
///   alter publication supabase_realtime add table live_locations;
class LocationSharingService {
  static SupabaseClient get _supabase => Supabase.instance.client;

  static const _keyShareCode = 'loc_share_code';
  static const _keyTrackHistory = 'loc_track_history';
  static const _keyShareHistory = 'loc_share_history';

  StreamSubscription<Position>? _positionSub;
  String? _sessionCode;
  bool _isSharing = false;

  bool get isSharing => _isSharing;
  String? get sessionCode => _sessionCode;

  // ── Persistance code partageur ─────────────────────────────────

  static Future<String?> getSavedShareCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyShareCode);
  }

  static Future<void> _saveShareCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyShareCode, code);
  }

  static Future<void> clearSavedShareCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyShareCode);
  }

  // ── Historique codes suivis ────────────────────────────────────

  /// Retourne la liste des derniers codes suivis [{code, ts}], du plus récent au plus ancien.
  static Future<List<Map<String, dynamic>>> getTrackHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyTrackHistory) ?? [];
    return raw.map((e) {
      final parts = e.split('|');
      return {'code': parts[0], 'ts': int.parse(parts[1])};
    }).toList();
  }

  /// Ajoute un code à l'historique (max 5 entrées, pas de doublon).
  static Future<void> addToTrackHistory(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyTrackHistory) ?? [];
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    // Supprimer le doublon éventuel
    raw.removeWhere((e) => e.startsWith('$code|'));
    raw.insert(0, '$code|$ts');
    if (raw.length > 5) raw.removeLast();
    await prefs.setStringList(_keyTrackHistory, raw);
  }

  static Future<void> removeFromTrackHistory(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyTrackHistory) ?? [];
    raw.removeWhere((e) => e.startsWith('$code|'));
    await prefs.setStringList(_keyTrackHistory, raw);
  }

  // ── Historique codes partagés (partageur) ─────────────────────

  /// Retourne la liste des derniers codes partagés [{code, ts}], du plus récent au plus ancien.
  static Future<List<Map<String, dynamic>>> getShareHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyShareHistory) ?? [];
    return raw.map((e) {
      final parts = e.split('|');
      return {'code': parts[0], 'ts': int.parse(parts[1])};
    }).toList();
  }

  /// Ajoute un code à l'historique des partages (max 5 entrées, pas de doublon).
  static Future<void> addToShareHistory(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyShareHistory) ?? [];
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    raw.removeWhere((e) => e.startsWith('$code|'));
    raw.insert(0, '$code|$ts');
    if (raw.length > 5) raw.removeLast();
    await prefs.setStringList(_keyShareHistory, raw);
  }

  static Future<void> removeFromShareHistory(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyShareHistory) ?? [];
    raw.removeWhere((e) => e.startsWith('$code|'));
    await prefs.setStringList(_keyShareHistory, raw);
  }

  /// Génère un code alphanumérique à 8 caractères
  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Démarre le partage de position.
  /// Retourne le code de session, ou lance une exception en cas d'erreur DB.
  Future<String> startSharing() async {
    if (_isSharing) return _sessionCode!;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw Exception('Permission de localisation refusée.');
    }

    final code = _generateCode();

    // Position initiale — obligatoire : si ça échoue (ex: RLS, table absente), on remonte l'erreur
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    await _upsertLocation(code, pos.latitude, pos.longitude, active: true);

    _sessionCode = code;
    _isSharing = true;
    await _saveShareCode(code);
    await addToShareHistory(code);

    // Stream de mises à jour continues
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((p) {
      _upsertLocation(code, p.latitude, p.longitude, active: true);
    });

    return code;
  }

  /// Arrête le partage et marque la session inactive.
  Future<void> stopSharing() async {
    _positionSub?.cancel();
    _positionSub = null;
    if (_sessionCode != null) {
      try {
        await _supabase
            .from('live_locations')
            .update({
              'active': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', _sessionCode!);
      } catch (e) {
        debugPrint('LocationSharing.stopSharing error: $e');
      }
    }
    _isSharing = false;
    _sessionCode = null;
    await clearSavedShareCode();
  }

  /// Reprend le partage avec un code existant (après redémarrage de l'app).
  Future<String> resumeSharing(String code) async {
    if (_isSharing) return _sessionCode!;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw Exception('Permission de localisation refusée.');
    }

    _sessionCode = code;
    _isSharing = true;
    await _saveShareCode(code);

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    await _upsertLocation(code, pos.latitude, pos.longitude, active: true);

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((p) {
      _upsertLocation(code, p.latitude, p.longitude, active: true);
    });

    return code;
  }

  Future<void> _upsertLocation(String code, double lat, double lng,
      {required bool active}) async {
    await _supabase.from('live_locations').upsert(
      {
        'user_id': code,
        'latitude': lat,
        'longitude': lng,
        'active': active,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id',
    );
  }

  /// Vérifie si un code de suivi existe dans Supabase.
  static Future<bool> codeExists(String code) async {
    final rows = await _supabase
        .from('live_locations')
        .select('user_id')
        .eq('user_id', code)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  /// Stream temps réel de la position d'un partageur (pour le destinataire).
  /// Émet null si le code est introuvable, puis émet à chaque mise à jour Supabase.
  static Stream<LocationData?> watchLocation(String code) {
    return _supabase
        .from('live_locations')
        .stream(primaryKey: ['id'])
        .eq('user_id', code)
        .map((rows) => rows.isEmpty ? null : LocationData.fromJson(rows.first));
  }

  void dispose() {
    _positionSub?.cancel();
  }
}

class LocationData {
  final double lat;
  final double lng;
  final int timestamp;
  final bool active;

  LocationData({
    required this.lat,
    required this.lng,
    required this.timestamp,
    required this.active,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    int ts;
    if (json['updated_at'] != null) {
      try {
        ts = DateTime.parse(json['updated_at'] as String).millisecondsSinceEpoch;
      } catch (_) {
        ts = DateTime.now().millisecondsSinceEpoch;
      }
    } else {
      ts = DateTime.now().millisecondsSinceEpoch;
    }
    return LocationData(
      lat: (json['latitude'] as num).toDouble(),
      lng: (json['longitude'] as num).toDouble(),
      timestamp: ts,
      active: json['active'] == true,
    );
  }

  /// Retourne vrai si la position a été mise à jour il y a moins de 30 secondes
  bool get isRecent {
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age < 30000;
  }
}
