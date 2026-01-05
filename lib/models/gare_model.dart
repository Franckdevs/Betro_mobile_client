class Gare {
  final int id;
  final String nomGare;
  final String adresseGare;
  final String telephoneGare;
  final String email;
  final String siteWeb;
  final String description;
  final String heureOuverture;
  final String heureFermeture;
  final bool parkingDisponible;
  final bool wifiDisponible;
  final String ville;
  final Map<String, dynamic>? jourOuvert;
  final Map<String, dynamic>? jourFermeture;
  final double latitude;
  final double longitude;

  String get nomJourOuverture {
    if (jourOuvert is Map) {
      return jourOuvert?['nom_jour'] ?? 'Inconnu';
    }
    return jourOuvert?.toString() ?? 'Inconnu';
  }

  String get nomJourFermeture {
    if (jourFermeture is Map) {
      return jourFermeture?['nom_jour'] ?? 'Inconnu';
    }
    return jourFermeture?.toString() ?? 'Inconnu';
  }

  Gare({
    required this.id,
    required this.nomGare,
    required this.adresseGare,
    required this.telephoneGare,
    required this.email,
    required this.siteWeb,
    required this.description,
    required this.heureOuverture,
    required this.heureFermeture,
    required this.parkingDisponible,
    required this.wifiDisponible,
    required this.ville,
    this.jourOuvert,
    this.jourFermeture,
    required this.latitude,
    required this.longitude,
  });

  factory Gare.fromJson(Map<String, dynamic> json) {
    return Gare(
      id: json['id'] as int? ?? 0,
      nomGare: json['nom_gare'] as String? ?? '',
      adresseGare: json['adresse_gare'] as String? ?? '',
      telephoneGare: json['telephone_gare'] as String? ?? '',
      email: json['email'] as String? ?? '',
      siteWeb: json['site_web'] as String? ?? '',
      description: json['description'] as String? ?? '',
      heureOuverture: json['heure_ouverture'] as String? ?? '',
      heureFermeture: json['heure_fermeture'] as String? ?? '',
      parkingDisponible: (json['parking_disponible'] as int?) == 1,
      wifiDisponible: (json['wifi_disponible'] as int?) == 1,
      ville: json['ville'] is Map
          ? (json['ville']?['nom_ville'] as String?) ?? 'Inconnue'
          : 'Inconnue',
      jourOuvert: json['jour_ouvert'] is Map
          ? Map<String, dynamic>.from(json['jour_ouvert'] as Map)
          : null,
      jourFermeture: json['jour_fermeture'] is Map
          ? Map<String, dynamic>.from(json['jour_fermeture'] as Map)
          : null,
      latitude: double.tryParse((json['latitude']?.toString() ?? '0')) ?? 0.0,
      longitude: double.tryParse((json['longitude']?.toString() ?? '0')) ?? 0.0,
    );
  }
}
