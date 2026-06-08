// ignore: avoid_classes_with_only_static_members
List<String> _parseBusPhotos(dynamic raw) {
  if (raw == null) return [];
  if (raw is List) return raw.map((e) => e.toString()).toList();
  // String JSON encodée
  try {
    final decoded = (raw.toString().trim().startsWith('['))
        ? List<dynamic>.from(_jsonDecodeList(raw.toString()))
        : [raw.toString()];
    return decoded.map((e) => e.toString()).toList();
  } catch (_) {
    return raw.toString().isNotEmpty ? [raw.toString()] : [];
  }
}

List<dynamic> _jsonDecodeList(String s) {
  // Simple JSON array parser sans import dart:convert
  final result = <dynamic>[];
  final cleaned = s.trim().replaceAll(RegExp(r'^\[|\]$'), '');
  for (final part in cleaned.split(',')) {
    final v = part.trim().replaceAll(RegExp(r'^"|"$'), '');
    if (v.isNotEmpty) result.add(v);
  }
  return result;
}

class Reservation {
  final int id;
  final int numeroPlace;
  final String? numeroReservation;
  final int paiementsId;
  final String status;
  final DateTime dateCreation;
  final String villeDepart;
  final String villeArrivee;
  final String marqueBus;
  final String immatriculationBus;
  final double prix;
  final int nombreTotalPlaces;
  final String? nomComplet;
  final String? telephoneProprietaire;
  // Agent fields
  final int? agentId;
  final String? agentNom;
  final String? agentPrenom;
  final String? agentRole;
  final String? agentEmail;
  final String? agentTelephone;
  final String? agentPhoto;
  // Bus fields
  final List<String> photoBus;
  final String? descriptionBus;
  // Chauffeur fields
  final int? chauffeurId;
  final String? chauffeurNom;
  final String? chauffeurPrenom;
  final String? chauffeurTelephone;
  final String? chauffeurPhoto;
  final String? chauffeurAdresse;
  final String? chauffeurNumerosPermis;
  final String? chauffeurDateNaissance;
  final String? chauffeurStatus;
  final String? chauffeurInfractions;
  final String? busInfractions;
  final String? companyInfractions;
  final int? voyageId;
  final String? dureeVoyage;

  Reservation({
    required this.id,
    required this.numeroPlace,
    this.numeroReservation,
    required this.paiementsId,
    required this.status,
    required this.dateCreation,
    required this.villeDepart,
    required this.villeArrivee,
    required this.marqueBus,
    required this.immatriculationBus,
    required this.prix,
    required this.nombreTotalPlaces,
    this.nomComplet,
    this.telephoneProprietaire,
    this.agentId,
    this.agentNom,
    this.agentPrenom,
    this.agentRole,
    this.agentEmail,
    this.agentTelephone,
    this.agentPhoto,
    this.photoBus = const [],
    this.descriptionBus,
    this.chauffeurId,
    this.chauffeurNom,
    this.chauffeurPrenom,
    this.chauffeurTelephone,
    this.chauffeurPhoto,
    this.chauffeurAdresse,
    this.chauffeurNumerosPermis,
    this.chauffeurDateNaissance,
    this.chauffeurStatus,
    this.chauffeurInfractions,
    this.busInfractions,
    this.companyInfractions,
    this.voyageId,
    this.dureeVoyage,
  });

  static int _i(dynamic v, [int fallback = 0]) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? fallback;

  static int? _iOpt(dynamic v) =>
      v == null ? null : (v is int ? v : int.tryParse(v.toString()));

  static double _d(dynamic v, [double fallback = 0]) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? fallback;

  factory Reservation.fromJson(Map<String, dynamic> json) {
    final agent = json['voyage']?['agent'];
    final chauffeur = json['voyage']?['chauffeur'];
    final bus = json['voyage']?['bus'];
    final voyage = json['voyage'];
    final arret = json['arret'];

    return Reservation(
      id: _i(json['id']),
      paiementsId: _i(json['paiements_id']),
      numeroPlace: _i(json['numero_place']),
      numeroReservation: json['numero_reservation']?.toString(),
      status: json['status']?.toString() ?? '0',
      dateCreation: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      villeDepart: arret?['tarification']?['ville_depart']?['nom_ville']?.toString() ?? '',
      villeArrivee: arret?['tarification']?['ville_arrivee']?['nom_ville']?.toString() ?? '',
      marqueBus: bus?['marque_bus']?.toString() ?? '',
      immatriculationBus: bus?['immatriculation_bus']?.toString() ?? '',
      prix: _d(arret?['montant']),
      nombreTotalPlaces: bus?['places'] is List ? (bus!['places'] as List).length : 0,
      nomComplet: json['nom_complet']?.toString(),
      telephoneProprietaire: json['telephone_proprietaire']?.toString(),
      agentId: _iOpt(agent?['id']),
      agentNom: agent?['nom']?.toString(),
      agentPrenom: agent?['prenom']?.toString(),
      agentRole: agent?['role_personnel']?.toString(),
      agentEmail: agent?['email']?.toString(),
      agentTelephone: agent?['telephone']?.toString(),
      agentPhoto: agent?['photo']?.toString(),
      photoBus: _parseBusPhotos(bus?['photo_bus']),
      descriptionBus: bus?['description_bus']?.toString(),
      chauffeurId: _iOpt(chauffeur?['id']),
      chauffeurNom: chauffeur?['nom']?.toString(),
      chauffeurPrenom: chauffeur?['prenom']?.toString(),
      chauffeurTelephone: chauffeur?['telephone']?.toString(),
      chauffeurPhoto: chauffeur?['photo']?.toString(),
      chauffeurAdresse: chauffeur?['adresse']?.toString(),
      chauffeurNumerosPermis: chauffeur?['numeros_permis']?.toString(),
      chauffeurDateNaissance: chauffeur?['date_naissance']?.toString(),
      chauffeurStatus: chauffeur?['status']?.toString(),
      chauffeurInfractions: chauffeur?['infractions']?.toString(),
      busInfractions: bus?['infractions']?.toString(),
      companyInfractions: voyage?['compagnie']?['infractions']?.toString(),
      voyageId: _iOpt(voyage?['id']),
      dureeVoyage: voyage?['duree_voyage']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numero_place': numeroPlace,
      'numero_reservation': numeroReservation,
      'paiements_id': paiementsId,
      'status': status,
      'created_at': dateCreation.toIso8601String(),
      'arret': {
        'tarification': {
          'ville_depart': {'nom_ville': villeDepart},
          'ville_arrivee': {'nom_ville': villeArrivee},
          'montant': prix,
        },
        'montant': prix,
      },
      'voyage': {
        if (voyageId != null) 'id': voyageId,
        'bus': {
          'nom_bus': marqueBus,
          'marque_bus': marqueBus,
          'immatriculation_bus': immatriculationBus,
          if (busInfractions != null) 'infractions': busInfractions,
          'places': List.generate(
            nombreTotalPlaces,
            (index) => {'id': index + 1},
          ),
        },
        if (companyInfractions != null) 'compagnie': {'infractions': companyInfractions},
        'date_depart': dateCreation.toIso8601String().split('T')[0],
        'heure_depart':
            '${dateCreation.hour.toString().padLeft(2, '0')}:${dateCreation.minute.toString().padLeft(2, '0')}:00',
        if (dureeVoyage != null) 'duree_voyage': dureeVoyage,
        'agent': agentId != null ? {
          'id': agentId,
          'nom': agentNom,
          'prenom': agentPrenom,
          'role_personnel': agentRole,
          'email': agentEmail,
          'telephone': agentTelephone,
          'photo': agentPhoto,
        } : null,
      },
      'gares': {'nom_gare': 'Gare de $villeDepart'},
      'nom_complet': nomComplet,
      'telephone_proprietaire': telephoneProprietaire,
      if (voyageId != null) 'voyage_id': voyageId,
    };
  }
}

