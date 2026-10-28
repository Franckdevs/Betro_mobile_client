import 'dart:convert';
import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/compagnie_model.dart';
import '../models/itineraire_model.dart';
import '../models/reservation_model.dart';
import '../core/utils/error_helper.dart';
import '../core/utils/logger.dart';
import 'storage_service.dart';

class ApiService {
  // Serveur de dev interne (réseau BMI / VPN uniquement, http sans TLS).
  static const String baseUrl = "https://betro.ci/api";
  //static const String baseUrl = "https://betro.tresormoney.ci/api";
  //static const String baseUrl = "http://ci-betro-web-v1.dev.bmi.local/api";
  //static const String baseUrl = "http://172.20.10.7:8000/api";

  // ── Logger centralisé ─────────────────────────────────────────────────────

  static void _logReq(String method, Uri url, {dynamic body}) {
    logDebug('┌─ [API] $method $url');
    if (body != null) logDebug('│  BODY    : $body');
  }

  static void _logRes(String method, Uri url, int status, String body) {
    final preview = body.length > 800 ? '${body.substring(0, 800)}…' : body;
    logDebug('└─ [API] $method $url → $status\n   $preview');
  }

  static void _logErr(String method, Uri url, Object e) {
    logDebug('✗  [API] $method $url → ERREUR: $e');
  }

  // ── Vérifier statut compte ────────────────────────────────────────────────

  Future<Map<String, dynamic>> verifierStatutCompte(String token) async {
    final url = Uri.parse('$baseUrl/verifier_statut_compte/$token');
    const method = 'GET';
    try {
      _logReq(method, url);
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));
      _logRes(method, url, response.statusCode, response.body);

      if (response.statusCode == 200 || response.statusCode == 403) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final raw = data['est_bloque'];
        final estBloque = raw == true || raw == 1 || raw == '1' || raw == 'true';
        return {...data, 'est_bloque': estBloque};
      }
      return {'success': false, 'est_bloque': false};
    } catch (e) {
      _logErr(method, url, e);
      return {'success': false, 'est_bloque': false};
    }
  }

  // ── Vérifier utilisateur existe ───────────────────────────────────────────

  Future<Map<String, dynamic>> verifierUtilisateurExiste(String token) async {
    final url = Uri.parse('$baseUrl/verifier_utilisateur_existe/$token');
    const method = 'GET';
    try {
      _logReq(method, url);
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      });
      _logRes(method, url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body) as Map<String, dynamic>;
          if (responseData.containsKey('success')) return responseData;
          return {'success': true, 'user': responseData};
        } catch (e) {
          _logErr(method, url, 'Décodage JSON: $e');
          return {'success': false, 'message': 'Format de réponse invalide'};
        }
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': 'Session expirée. Veuillez vous reconnecter.'};
      } else {
        return {'success': false, 'message': 'Erreur vérification utilisateur (${response.statusCode})'};
      }
    } catch (e) {
      _logErr(method, url, e);
      return {'success': false, 'message': 'Erreur de connexion: ${ErrorHelper.cleanErrorMessage(e.toString())}'};
    }
  }

  // ── GET générique ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> get(String endpoint, {String? token}) async {
    final url = Uri.parse('$baseUrl/$endpoint');
    const method = 'GET';
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      _logReq(method, url);
      final response = await http.get(url, headers: headers);
      _logRes(method, url, response.statusCode, response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final errorResponse = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': errorResponse['message'] ?? 'Erreur inconnue du serveur',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      _logErr(method, url, e);
      return {'success': false, 'message': 'Erreur de connexion: ${ErrorHelper.cleanErrorMessage(e.toString())}'};
    }
  }

  // ── POST générique ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data, {
    String? token,
  }) async {
    final url = Uri.parse('$baseUrl/$endpoint');
    const method = 'POST';
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final body = jsonEncode(data);
      _logReq(method, url, body: body);
      final response = await http.post(url, headers: headers, body: body);
      _logRes(method, url, response.statusCode, response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final errorResponse = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': errorResponse['message'] ?? 'Erreur inconnue du serveur',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      _logErr(method, url, e);
      return {'status': false, 'message': 'Erreur de connexion: ${ErrorHelper.cleanErrorMessage(e.toString())}'};
    }
  }

  // ── Mise à jour profil ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> updateProfile({
    required String nom,
    required String prenom,
    required String email,
    required String telephone,
    String? password,
    String? newPassword,
  }) async {
    final url = Uri.parse('$baseUrl/modifier_information_utilisateur');
    const method = 'POST';
    try {
      final token = await StorageService().getToken();
      if (token == null) throw Exception('Utilisateur non connecté');

      final requestData = <String, dynamic>{
        'token': token,
        'nom': nom,
        'prenom': prenom,
        'email': email,
        'telephone': telephone,
      };
      if (password != null && password.isNotEmpty) requestData['current_password'] = password;
      if (newPassword != null && newPassword.isNotEmpty) requestData['new_password'] = newPassword;

      final body = jsonEncode(requestData);
      _logReq(method, url, body: body);
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      );
      _logRes(method, url, response.statusCode, response.body);

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Erreur lors de la mise à jour du profil'};
      }
    } catch (e) {
      _logErr(method, url, e);
      return {'success': false, 'message': 'Erreur de connexion: ${ErrorHelper.cleanErrorMessage(e.toString())}'};
    }
  }

  // ── Initier paiement ──────────────────────────────────────────────────────

  /// [sieges] : un élément par siège du panier, ex.
  /// `{'numero_place': 4, 'nom_complet': '...', 'telephone_proprietaire': '...', 'email_proprietaire': '...'}`.
  /// Les clés bénéficiaire sont facultatives par siège : si absentes, le backend
  /// applique les informations de l'utilisateur connecté par défaut.
  Future<Map<String, dynamic>> initierPaiement({
    required String token,
    required int voyageId,
    required int idArretVoyage,
    required List<Map<String, dynamic>> sieges,
  }) async {
    final url = Uri.parse('$baseUrl/InitiationPaiement');
    const method = 'POST';
    try {
      final requestBody = <String, dynamic>{
        'token': token,
        'voyage_id': voyageId,
        'id_arret_voayage': idArretVoyage,
        'sieges': sieges,
      };

      final body = jsonEncode(requestBody);
      _logReq(method, url, body: body);
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      );
      _logRes(method, url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          _logErr(method, url, 'Décodage JSON: $e');
          return {'success': false, 'message': 'Erreur de format de réponse du serveur', 'raw_response': response.body};
        }
      } else {
        return {'success': false, 'message': 'Erreur HTTP ${response.statusCode}', 'raw_response': response.body};
      }
    } catch (e) {
      _logErr(method, url, e);
      return {'success': false, 'message': 'Erreur de connexion: ${ErrorHelper.cleanErrorMessage(e.toString())}'};
    }
  }

  // ── Liste compagnies ──────────────────────────────────────────────────────

  Future<List<Compagnie>> getCompagnies() async {
    final url = Uri.parse('$baseUrl/listeCompagnie');
    const method = 'GET';
    try {
      _logReq(method, url);
      final response = await http.get(url);
      _logRes(method, url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data.containsKey('listecompagnie')) {
          final List<dynamic> compagniesJson = data['listecompagnie'];
          return compagniesJson.map((json) => Compagnie.fromJson(json)).toList();
        }
        return [];
      } else {
        throw Exception('Échec du chargement des compagnies (${response.statusCode})');
      }
    } catch (e) {
      _logErr(method, url, e);
      throw Exception('Erreur de connexion : ${ErrorHelper.cleanErrorMessage(e.toString())}');
    }
  }

  // ── Itinéraires par gare ──────────────────────────────────────────────────

  Future<ItineraireResponse> getItinerairesParGare(int gareId) async {
    final url = Uri.parse('$baseUrl/listeVoyage_avec_itineraire_avec_ville/$gareId');
    const method = 'GET';
    _logReq(method, url);
    final response = await http.get(url);
    _logRes(method, url, response.statusCode, response.body);

    if (response.statusCode == 200) {
      return ItineraireResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load itineraires for gare');
    }
  }

  // ── Liste réservations ────────────────────────────────────────────────────

  Future<List<Reservation>> getReservations(String token) async {
    final url = Uri.parse('$baseUrl/liste_reservation/$token');
    const method = 'GET';
    try {
      _logReq(method, url);
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      });
      _logRes(method, url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> reservationsJson = data['data'];
          return reservationsJson.map((json) => Reservation.fromJson(json)).toList();
        } else {
          throw Exception(data['message'] ?? 'Erreur lors de la récupération des réservations');
        }
      } else {
        throw Exception('Échec du chargement des réservations');
      }
    } catch (e) {
      _logErr(method, url, e);
      throw Exception('Erreur de connexion : ${ErrorHelper.cleanErrorMessage(e.toString())}');
    }
  }

  // ── Numéros service client ────────────────────────────────────────────────

  Future<Map<String, dynamic>> recupereNumeroTelephone({required String token}) async {
    final url = Uri.parse('$baseUrl/recupere_numero_telephone');
    const method = 'GET';
    try {
      _logReq(method, url);
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 8));
      _logRes(method, url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['telephone'] is Map) {
          return {
            'success': true,
            'lien_whatsapp': data['telephone']['lien_whatsapp'] as String? ?? '',
            'lien_telephone': data['telephone']['lien_telephone'] as String? ?? '',
          };
        }
      }
    } catch (e) {
      _logErr(method, url, e);
    }
    return {'success': false};
  }

  // ── Afficher/masquer le bouton "Supprimer mon compte" ────────────────────

  Future<bool> afficherBoutonSuppressionCompte() async {
    final url = Uri.parse('$baseUrl/parametre-app-mobile/bouton-suppression-compte');
    const method = 'GET';
    try {
      _logReq(method, url);
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 8));
      _logRes(method, url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['afficher_bouton_suppression_compte'] == true;
      }
    } catch (e) {
      _logErr(method, url, e);
    }
    return false;
  }

  // ── FAQ ───────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getFaqs() async {
    final url = Uri.parse('$baseUrl/faq-mobile');
    const method = 'GET';
    try {
      _logReq(method, url);
      final response = await http.get(url, headers: {'Connection': 'keep-alive'}).timeout(const Duration(seconds: 5));
      _logRes(method, url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['data'] is List) {
          return List<Map<String, dynamic>>.from(
            (data['data'] as List).map((e) => Map<String, dynamic>.from(e)),
          );
        }
      }
    } catch (e) {
      _logErr(method, url, e);
    }
    return [];
  }

  // ── Images accueil ────────────────────────────────────────────────────────

  static const _prefKeyImages = 'accueil_images_v2';

  Future<List<String>> getAccueilImages({void Function(List<String> newUrls)? onRefreshed}) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefKeyImages) ?? [];
    _fetchAndSyncImages(prefs, saved, onRefreshed);
    return saved;
  }

  Future<void> _fetchAndSyncImages(
    SharedPreferences prefs,
    List<String> currentUrls,
    void Function(List<String>)? onRefreshed,
  ) async {
    final url = Uri.parse('$baseUrl/config_web_mobile/image_acceuil_mobile');
    const method = 'GET';
    try {
      _logReq(method, url);
      final response = await http.get(url, headers: {'Connection': 'keep-alive'}).timeout(const Duration(seconds: 5));
      _logRes(method, url, response.statusCode, response.body);

      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      List<String> newUrls = [];
      if (data['images'] != null) {
        newUrls = (data['images'] as List)
            .map((e) => e['image_url'] as String)
            .where((u) => u.isNotEmpty)
            .toList();
      } else if (data['image_name'] != null) {
        final s = data['image_name'] as String;
        if (s.isNotEmpty) newUrls = [s];
      }

      if (newUrls.isEmpty) return;

      final removed = currentUrls.where((u) => !newUrls.contains(u)).toList();
      for (final u in removed) {
        try { await DefaultCacheManager().removeFile(u); } catch (_) {}
      }

      final added = newUrls.where((u) => !currentUrls.contains(u)).toList();
      for (final u in added) { DefaultCacheManager().downloadFile(u); }

      await prefs.setStringList(_prefKeyImages, newUrls);

      final changed = newUrls.length != currentUrls.length || newUrls.any((u) => !currentUrls.contains(u));
      if (changed) onRefreshed?.call(newUrls);
    } catch (e) {
      _logErr(method, url, e);
    }
  }

  // ── Photo utilisateur ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> modifierPhotoUtilisateur({
    required String token,
    required File imageFile,
  }) async {
    final url = Uri.parse('$baseUrl/modifier_photo_utilisateur');
    const method = 'POST (multipart)';
    try {
      _logReq(method, url, body: 'token=$token file=${imageFile.path}');
      final request = http.MultipartRequest('POST', url);
      request.headers['Accept'] = 'application/json';
      request.fields['token'] = token;
      request.files.add(await http.MultipartFile.fromPath('photo', imageFile.path));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      _logRes(method, url, response.statusCode, response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, ...data};
      } else {
        return {'success': false, 'message': 'Erreur ${response.statusCode}'};
      }
    } catch (e) {
      _logErr(method, url, e);
      return {'success': false, 'message': 'Erreur de connexion'};
    }
  }

  // ── Signalement ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> envoyerSignalement({
    required String token,
    required String contenu,
  }) async {
    final url = Uri.parse('$baseUrl/signalement');
    const method = 'POST';
    try {
      final body = jsonEncode({'token': token, 'contenu': contenu});
      _logReq(method, url, body: body);
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      );
      _logRes(method, url, response.statusCode, response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      } else {
        return {'success': false, 'message': 'Erreur ${response.statusCode}'};
      }
    } catch (e) {
      _logErr(method, url, e);
      return {'success': false, 'message': 'Erreur de connexion'};
    }
  }
}
