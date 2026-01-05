import 'gare_model.dart';

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
    final garesJson = json['liste_gares'] as List<dynamic>?;
    return Compagnie(
      id: json['id'],
      nomComplet: json['nom_complet_compagnies'],
      email: json['email_compagnies'],
      telephone: json['telephone_compagnies'],
      adresse: json['adresse_compagnies'],
      logoUrl: json['logo_url'],
      description: json['description_compagnies'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      status: json['status'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      gares: garesJson?.map((gare) => Gare.fromJson(gare)).toList() ?? [],
    );
  }
}