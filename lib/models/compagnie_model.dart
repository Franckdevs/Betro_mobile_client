import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'gare1_model.dart';
import '../core/utils/logger.dart';

class Compagnie {
  final int id;
  final String nomComplet;
  final String email;
  final String telephone;
  final String adresse;
  final String? logoUrl;
  final String description;
  final String latitude;
  final String longitude;
  final String status;
  final DateTime? createdAt;
  final List<Gare> gares;

  Compagnie({
    required this.id,
    required this.nomComplet,
    required this.email,
    required this.telephone,
    required this.adresse,
    this.logoUrl,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.createdAt,
    List<Gare>? gares,
  }) : gares = gares ?? [];

  factory Compagnie.fromJson(Map<String, dynamic> json) {
    try {
      if (kDebugMode) {
        logDebug('⚙️ Données JSON reçues pour Compagnie:');
        logDebug(jsonEncode(json));
      }

      final garesJson = json['liste_gares'] as List<dynamic>?;

      // Vérification des champs requis
      final requiredFields = [
        'id',
        'nom_complet_compagnies',
        'email_compagnies',
        'telephone_compagnies',
        'adresse_compagnies',
        'description_compagnies',
        'latitude',
        'longitude',
        'status',
      ];

      for (final field in requiredFields) {
        if (json[field] == null) {
          logDebug('⚠️ Champ manquant ou null dans la réponse API: $field');
        }
      }

      // Récupération des valeurs avec des valeurs par défaut si nécessaire
      final compagnie = Compagnie(
        id: json['id'] as int? ?? 0,
        nomComplet:
            (json['nom_complet_compagnies'] as String?) ?? 'Nom non fourni',
        email: (json['email_compagnies'] as String?) ?? 'email@non-fourni.com',
        telephone: (json['telephone_compagnies'] as String?) ?? 'Non fourni',
        adresse:
            (json['adresse_compagnies'] as String?) ?? 'Adresse non fournie',
        logoUrl: json['logo_url'] as String? ?? json['logo_path'] as String?,
        description:
            (json['description_compagnies'] as String?) ?? 'Aucune description',
        latitude: (json['latitude']?.toString() ?? '0.0'),
        longitude: (json['longitude']?.toString() ?? '0.0'),
        status: (json['status']?.toString() ?? '1'),
        createdAt:
            json['created_at'] != null &&
                json['created_at'].toString().isNotEmpty
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
        gares:
            garesJson?.map<Gare>((gare) => Gare.fromJson(gare)).toList() ?? [],
      );

      if (kDebugMode) {
        logDebug('✅ Compagnie créée avec succès:');
        logDebug('   - ID: ${compagnie.id}');
        logDebug('   - Nom: ${compagnie.nomComplet}');
        logDebug('   - Email: ${compagnie.email}');
        logDebug('   - Téléphone: ${compagnie.telephone}');
        logDebug('   - Nombre de gares: ${compagnie.gares.length}');
      }

      return compagnie;
    } catch (e, stackTrace) {
      logDebug('❌ Erreur lors de la création d\'une Compagnie depuis le JSON:');
      logDebug('   - Erreur: $e');
      logDebug('   - StackTrace: $stackTrace');
      logDebug('   - Données problématiques: ${jsonEncode(json)}');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom_complet_compagnies': nomComplet,
      'email_compagnies': email,
      'telephone_compagnies': telephone,
      'adresse_compagnies': adresse,
      'logo_url': logoUrl,
      'description_compagnies': description,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      // Ne pas inclure les gares dans le toJson pour éviter les références circulaires
      // 'liste_gares': gares.map((gare) => gare.toJson()).toList(),
    };
  }
}
