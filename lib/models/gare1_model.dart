int _gareParseInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? 0;
}

class Gare {
  final int id;
  final int infoUserId;
  final int compagnieId;
  final int? jourId;
  final int villeId;
  final int? jourOuvertId;
  final int? jourDeFermetureId;
  final String latitude;
  final String longitude;
  final String heureOuverture;
  final String heureFermeture;
  final bool parkingDisponible;
  final bool wifiDisponible;
  final String? telephone;
  final String? email;
  final String? siteWeb;
  final String? description;
  final String nomGare;
  final String? adresseGare;
  final String? telephoneGare;
  final String? adminNom;
  final String? adminPrenom;
  final String? adminEmail;
  final String? adminTelephone;
  final String status;
  final String createdAt;
  final String updatedAt;
  final Ville? ville;
  final String? infractions;
  final Map<String, dynamic>? jourOuvert;
  final Map<String, dynamic>? jourFermeture;

  String get nomJourOuverture =>
      jourOuvert is Map ? (jourOuvert?['nom_jour'] ?? 'Inconnu') : 'Inconnu';
  String get nomJourFermeture =>
      jourFermeture is Map ? (jourFermeture?['nom_jour'] ?? 'Inconnu') : 'Inconnu';

  // Formate "07:30:00" → "07h30", supporte aussi "07:30"
  static String _fmtHeure(String h) {
    if (h.isEmpty) return '';
    final parts = h.split(':');
    if (parts.length >= 2) return '${parts[0]}h${parts[1]}';
    return h;
  }

  String get heureOuvertureFormatee => _fmtHeure(heureOuverture);
  String get heureFermetureFormatee => _fmtHeure(heureFermeture);

  // Renvoie le numéro de téléphone disponible (telephoneGare ou telephone)
  String get displayTelephone {
    if (telephoneGare != null && telephoneGare!.isNotEmpty) return telephoneGare!;
    if (telephone != null && telephone!.isNotEmpty) return telephone!;
    return '';
  }

  Gare({
    required this.id,
    required this.infoUserId,
    required this.compagnieId,
    this.jourId,
    required this.villeId,
    this.jourOuvertId,
    this.jourDeFermetureId,
    required this.latitude,
    required this.longitude,
    required this.heureOuverture,
    required this.heureFermeture,
    required this.parkingDisponible,
    required this.wifiDisponible,
    this.telephone,
    this.email,
    this.siteWeb,
    this.description,
    required this.nomGare,
    this.adresseGare,
    this.telephoneGare,
    this.adminNom,
    this.adminPrenom,
    this.adminEmail,
    this.adminTelephone,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.ville,
    this.infractions,
    this.jourOuvert,
    this.jourFermeture,
  });

  factory Gare.fromJson(Map<String, dynamic> json) {
    final parking = json['parking_disponible'];
    final wifi = json['wifi_disponible'];
    return Gare(
      id: _gareParseInt(json['id']),
      infoUserId: _gareParseInt(json['info_user_id']),
      compagnieId: _gareParseInt(json['compagnie_id']),
      jourId: json['jour_id'] != null ? _gareParseInt(json['jour_id']) : null,
      villeId: _gareParseInt(json['ville_id']),
      jourOuvertId: json['jour_ouvert_id'] != null ? _gareParseInt(json['jour_ouvert_id']) : null,
      jourDeFermetureId: json['jour_de_fermeture_id'] != null ? _gareParseInt(json['jour_de_fermeture_id']) : null,
      latitude: json['latitude']?.toString() ?? '',
      longitude: json['longitude']?.toString() ?? '',
      heureOuverture: json['heure_ouverture'] as String? ?? '',
      heureFermeture: json['heure_fermeture'] as String? ?? '',
      parkingDisponible: parking == 1 || parking == true || parking == '1',
      wifiDisponible: wifi == 1 || wifi == true || wifi == '1',
      telephone: json['telephone'] as String?,
      email: json['email'] as String?,
      siteWeb: json['site_web'] as String?,
      description: json['description'] as String?,
      nomGare: json['nom_gare'] as String? ?? '',
      adresseGare: json['adresse_gare'] as String?,
      telephoneGare: json['telephone_gare'] as String?,
      adminNom: json['admin_nom'] as String?,
      adminPrenom: json['admin_prenom'] as String?,
      adminEmail: json['admin_email'] as String?,
      adminTelephone: json['admin_telephone'] as String?,
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      ville: json['ville'] != null ? Ville.fromJson(json['ville'] as Map<String, dynamic>) : null,
      infractions: json['infractions'] as String?,
      jourOuvert: json['jour_ouvert'] is Map
          ? Map<String, dynamic>.from(json['jour_ouvert'] as Map)
          : null,
      jourFermeture: json['jour_fermeture'] is Map
          ? Map<String, dynamic>.from(json['jour_fermeture'] as Map)
          : null,
    );
  }

  factory Gare.empty() {
    return Gare(
      id: 0,
      infoUserId: 0,
      compagnieId: 0,
      villeId: 0,
      latitude: '',
      longitude: '',
      heureOuverture: '',
      heureFermeture: '',
      parkingDisponible: false,
      wifiDisponible: false,
      nomGare: '',
      status: '',
      createdAt: '',
      updatedAt: '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'info_user_id': infoUserId,
      'compagnie_id': compagnieId,
      'jour_id': jourId,
      'ville_id': villeId,
      'jour_ouvert_id': jourOuvertId,
      'jour_de_fermeture_id': jourDeFermetureId,
      'latitude': latitude,
      'longitude': longitude,
      'heure_ouverture': heureOuverture,
      'heure_fermeture': heureFermeture,
      'parking_disponible': parkingDisponible ? 1 : 0,
      'wifi_disponible': wifiDisponible ? 1 : 0,
      'telephone': telephone,
      'email': email,
      'site_web': siteWeb,
      'description': description,
      'nom_gare': nomGare,
      'adresse_gare': adresseGare,
      'telephone_gare': telephoneGare,
      'admin_nom': adminNom,
      'admin_prenom': adminPrenom,
      'admin_email': adminEmail,
      'admin_telephone': adminTelephone,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'ville': ville?.toJson(),
    };
  }
}

class Ville {
  final int id;
  final String nomVille;
  final String status;
  final String createdAt;
  final String updatedAt;

  Ville({
    required this.id,
    required this.nomVille,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Ville.fromJson(Map<String, dynamic> json) {
    return Ville(
      id: _gareParseInt(json['id']),
      nomVille: json['nom_ville'] as String? ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom_ville': nomVille,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}