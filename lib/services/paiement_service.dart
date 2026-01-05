import '../models/paiement_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

class PaiementService {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  Future<List<Map<String, dynamic>>> getPaiements() async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Utilisateur non connecté');
      }

      final response = await _apiService.get(
        'liste_detail_paiement/$token',
        token: token,
      );

      if (response['success'] == true) {
        return List<Map<String, dynamic>>.from(response['paiements'] ?? []);
      } else {
        throw Exception(
          response['message'] ?? 'Erreur lors de la récupération des paiements',
        );
      }
    } catch (e) {
      throw Exception(
        'Erreur lors de la récupération des paiements: ${e.toString()}',
      );
    }
  }

  Future<Map<String, dynamic>> getPaiementDetails(int paiementId) async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Utilisateur non connecté');
      }

      final response = await _apiService.get(
        'liste_detail_paiement/$token',
        token: token,
      );

      if (response['success'] == true) {
        final paiements = List<Map<String, dynamic>>.from(
          response['paiements'] ?? [],
        );
        final paiement = paiements.firstWhere(
          (p) => p['paiement']?['id'] == paiementId,
          orElse: () => throw Exception('Paiement non trouvé'),
        );
        return paiement;
      } else {
        throw Exception(
          response['message'] ??
              'Erreur lors de la récupération des détails du paiement',
        );
      }
    } catch (e) {
      throw Exception('Erreur: ${e.toString()}');
    }
  }
}
