import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/compagnie_model.dart';
import '../models/itineraire_model.dart';
import '../models/reservation_model.dart';

class ApiService {
  // Vérifie si l'utilisateur existe avec le token fourni
  Future<Map<String, dynamic>> verifierUtilisateurExiste(String token) async {
    final url = Uri.parse('$baseUrl/verifier_utilisateur_existe/$token');
    try {
      print('Vérification du token utilisateur...');
      print('URL: $url');
      print('Token: ${token.substring(0, 10)}...');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print(
        'Réponse de vérification: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200) {
        try {
          final responseData =
              jsonDecode(response.body) as Map<String, dynamic>;
          // Si la réponse contient déjà un champ 'success', on la retourne telle quelle
          if (responseData.containsKey('success')) {
            return responseData;
          }
          // Sinon, on l'encapsule dans le format attendu
          return {'success': true, 'user': responseData};
        } catch (e) {
          print('Erreur lors du décodage de la réponse: $e');
          return {'success': false, 'message': 'Format de réponse invalide'};
        }
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Session expirée. Veuillez vous reconnecter.',
        };
      } else {
        return {
          'success': false,
          'message':
              'Erreur lors de la vérification de l\'utilisateur (${response.statusCode})',
        };
      }
    } catch (e) {
      print('Erreur lors de la vérification de l\'utilisateur: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion: ${e.toString()}',
      };
    }
  }

  // final String baseUrl = "http://192.168.40.34:8000/api";
  final String baseUrl = "http://192.168.95.83:8000/api";

  Future<Map<String, dynamic>> get(String endpoint, {String? token}) async {
    final url = Uri.parse("$baseUrl/$endpoint");
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      print('Envoi de la requête GET à: $url');
      print('En-têtes: $headers');

      final response = await http.get(url, headers: headers);

      print('Réponse reçue - Statut: ${response.statusCode}');
      print('Corps de la réponse: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final errorResponse = jsonDecode(response.body) as Map<String, dynamic>;
        print('Erreur de l\'API: $errorResponse');
        return {
          'success': false,
          'message': errorResponse['message'] ?? 'Erreur inconnue du serveur',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('Erreur lors de la requête GET: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion: ${e.toString()}',
      };
    }
  }

  //
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data, {
    String? token,
  }) async {
    final url = Uri.parse("$baseUrl/$endpoint");
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      print('Envoi de la requête POST à: $url');
      print('En-têtes: $headers');
      print('Données: $data');

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(data),
      );

      print('Réponse reçue - Statut: ${response.statusCode}');
      print('Corps de la réponse: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final errorResponse = jsonDecode(response.body) as Map<String, dynamic>;
        print('Erreur de l\'API: $errorResponse');
        return {
          'success': false,
          'message': errorResponse['message'] ?? 'Erreur inconnue du serveur',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {"status": false, "message": "Erreur de connexion : $e"};
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String token,
    required String nom,
    required String prenom,
    required String email,
    required String telephone,
    String? password,
    String? newPassword,
  }) async {
    final url = Uri.parse('$baseUrl/modifier_information_utilisateur');
    try {
      final Map<String, dynamic> requestData = {
        'token': token,
        'nom': nom,
        'prenom': prenom,
        'email': email,
        'telephone': telephone,
      };

      // Ajouter les champs de mot de passe uniquement s'ils sont fournis
      if (password != null && password.isNotEmpty) {
        requestData['current_password'] = password;
      }
      if (newPassword != null && newPassword.isNotEmpty) {
        requestData['new_password'] = newPassword;
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestData),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {
          'success': false,
          'message':
              responseData['message'] ??
              'Erreur lors de la mise à jour du profil',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion: $e'};
    }
  }

  Future<Map<String, dynamic>> initierPaiement({
    required String token,
    required int voyageId,
    required int idArretVoyage,
    required int numeroPlace,
    String? telephoneProprietaire,
    String? nomComplet,
  }) async {
    final url = Uri.parse('$baseUrl/InitiationPaiement');
    try {
      print('URL de l\'API: $url');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final Map<String, dynamic> requestBody = {
        'token': token,
        'voyage_id': voyageId,
        'id_arret_voayage': idArretVoyage,
        'numero_place': numeroPlace,
      };

      // Ajouter les champs optionnels s'ils sont fournis
      if (telephoneProprietaire != null && telephoneProprietaire.isNotEmpty) {
        requestBody['telephone_proprietaire'] = telephoneProprietaire;
      }
      if (nomComplet != null && nomComplet.isNotEmpty) {
        requestBody['nom_complet'] = nomComplet;
      }

      final body = jsonEncode(requestBody);

      print('En-têtes: $headers');
      print('Corps de la requête: $body');

      final response = await http.post(url, headers: headers, body: body);

      print('Code de statut: ${response.statusCode}');
      print('Réponse brute: ${response.body}');

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          print('Erreur de décodage JSON: $e');
          return {
            'success': false,
            'message': 'Erreur de format de réponse du serveur',
            'raw_response': response.body,
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Erreur HTTP ${response.statusCode}',
          'raw_response': response.body,
        };
      }
    } catch (e) {
      print('Erreur lors de l\'appel API: $e');
      return {'success': false, 'message': 'Erreur de connexion: $e'};
    }
  }

  Future<List<Compagnie>> getCompagnies() async {
    final url = Uri.parse("$baseUrl/listeCompagnie");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> compagniesJson = data['listecompagnie'];
        return compagniesJson.map((json) => Compagnie.fromJson(json)).toList();
      } else {
        throw Exception('Échec du chargement des compagnies');
      }
    } catch (e) {
      throw Exception('Erreur de connexion : $e');
    }
  }

  Future<Compagnie> getCompagnieWithGares(int compagnieId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/compagnie-with-gares/$compagnieId'),
    );

    if (response.statusCode == 200) {
      return Compagnie.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load compagnie with gares');
    }
  }

  Future<ItineraireResponse> getItinerairesParGare(int gareId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/listeVoyage_avec_itineraire_avec_ville/$gareId'),
    );

    if (response.statusCode == 200) {
      return ItineraireResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load itineraires for gare');
    }
  }

  // Récupérer la liste des réservations d'un utilisateur
  Future<List<Reservation>> getReservations(String token) async {
    final url = Uri.parse('$baseUrl/liste_reservation/$token');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> reservationsJson = data['data'];

          // Afficher les données brutes reçues pour le débogage
          print('=== DONNÉES BRUTES DES RÉSERVATIONS ===');
          print(response.body);
          print('======================================');

          // Afficher les clés de chaque réservation
          if (reservationsJson.isNotEmpty) {
            print('=== CLÉS DISPONIBLES DANS LA PREMIÈRE RÉSERVATION ===');
            print(reservationsJson.first.keys);
            print('==================================================');
          }

          return reservationsJson
              .map((json) => Reservation.fromJson(json))
              .toList();
        } else {
          throw Exception(
            data['message'] ??
                'Erreur lors de la récupération des réservations',
          );
        }
      } else {
        throw Exception('Échec du chargement des réservations');
      }
    } catch (e) {
      throw Exception('Erreur de connexion : $e');
    }
  }
}
