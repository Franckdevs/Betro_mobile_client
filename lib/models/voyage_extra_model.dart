import 'package:flutter/foundation.dart';
import 'gare1_model.dart';

int _parseInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? 0;
}

List<String> _parseBusPhotos(dynamic raw) {
  if (raw == null) return [];
  if (raw is List) return raw.map((e) => e.toString()).toList();
  final s = raw.toString().trim();
  if (s.isEmpty) return [];
  if (s.startsWith('[')) {
    final cleaned = s.replaceAll(RegExp(r'^\[|\]$'), '');
    return cleaned
        .split(',')
        .map((p) => p.trim().replaceAll(RegExp(r'^"|"$'), ''))
        .where((p) => p.isNotEmpty)
        .toList();
  }
  return [s];
}

class VoyageExtra {
  final int id;
  final int compagnieId;
  final int? gareId;
  final int? itineraireId;
  final int infoUserId;
  final int busId;
  final int chauffeurId;
  final int disponibleToujours;
  final double? montant;
  final String heureDepart;
  final String? dateDepart;
  final String status;
  final String createdAt;
  final String updatedAt;
  final int agentsId;
  final Bus bus;
  final Chauffeur chauffeur;
  final Compagnie compagnie;
  final Agent agent;
  final Gare? gare;
  final Gare? gareArrive;

  VoyageExtra({
    required this.id,
    required this.compagnieId,
    this.gareId,
    this.itineraireId,
    required this.infoUserId,
    required this.busId,
    required this.chauffeurId,
    required this.disponibleToujours,
    this.montant,
    required this.heureDepart,
    this.dateDepart,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.agentsId,
    required this.bus,
    required this.chauffeur,
    required this.compagnie,
    required this.agent,
    this.gare,
    this.gareArrive,
  });

  factory VoyageExtra.fromJson(Map<String, dynamic> json) {
    try {
      Map<String, dynamic>? busData = json['bus'] as Map<String, dynamic>?;
      Map<String, dynamic>? chauffeurData = json['chauffeur'] as Map<String, dynamic>?;
      Map<String, dynamic>? compagnieData = json['compagnie'] as Map<String, dynamic>?;
      Map<String, dynamic>? agentData = json['agent'] as Map<String, dynamic>?;

      return VoyageExtra(
        id: _parseInt(json['id']),
        compagnieId: _parseInt(json['compagnie_id']),
        gareId: json['gare_id'] != null ? _parseInt(json['gare_id']) : null,
        itineraireId: json['itineraire_id'] != null ? _parseInt(json['itineraire_id']) : null,
        infoUserId: _parseInt(json['info_user_id']),
        busId: _parseInt(json['bus_id']),
        chauffeurId: _parseInt(json['chauffeur_id']),
        disponibleToujours: _parseInt(json['disponible_toujours']),
        montant: json['montant'] != null ? double.tryParse(json['montant'].toString()) : null,
        heureDepart: json['heure_depart'] as String? ?? '',
        dateDepart: json['date_depart'] as String?,
        status: json['status']?.toString() ?? '',
        createdAt: json['created_at'] as String? ?? '',
        updatedAt: json['updated_at'] as String? ?? '',
        agentsId: json['agents_id'] != null ? _parseInt(json['agents_id']) : 0,
        bus: busData != null ? Bus.fromJson(busData) : Bus.empty(),
        chauffeur: chauffeurData != null ? Chauffeur.fromJson(chauffeurData) : Chauffeur.empty(),
        compagnie: compagnieData != null ? Compagnie.fromJson(compagnieData) : Compagnie.empty(),
        agent: agentData != null ? Agent.fromJson(agentData) : Agent.empty(),
        gare: json['gare'] != null
            ? Gare.fromJson(json['gare'] as Map<String, dynamic>)
            : null,
        gareArrive: json['itineraire'] != null &&
                (json['itineraire'] as Map<String, dynamic>)['gare_arrive'] != null
            ? Gare.fromJson(
                (json['itineraire'] as Map<String, dynamic>)['gare_arrive']
                    as Map<String, dynamic>)
            : null,
      );
    } catch (e) {
      debugPrint('VoyageExtra.fromJson error: $e');
      return VoyageExtra(
        id: 0,
        compagnieId: 0,
        infoUserId: 0,
        busId: 0,
        chauffeurId: 0,
        disponibleToujours: 0,
        heureDepart: '',
        status: '',
        createdAt: '',
        updatedAt: '',
        agentsId: 0,
        bus: Bus.empty(),
        chauffeur: Chauffeur.empty(),
        compagnie: Compagnie.empty(),
        agent: Agent.empty(),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'compagnie_id': compagnieId,
      'gare_id': gareId,
      'itineraire_id': itineraireId,
      'info_user_id': infoUserId,
      'bus_id': busId,
      'chauffeur_id': chauffeurId,
      'disponible_toujours': disponibleToujours,
      'montant': montant,
      'heure_depart': heureDepart,
      'date_depart': dateDepart,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'agents_id': agentsId,
      'bus': bus.toJson(),
      'chauffeur': chauffeur.toJson(),
      'compagnie': compagnie.toJson(),
      'agent': agent.toJson(),
    };
  }
}

class Bus {
  final int id;
  final int infoUserId;
  final int compagniesId;
  final int configurationPlaceBusesId;
  final String nomBus;
  final String marqueBus;
  final String modeleBus;
  final String immatriculationBus;
  final List<String> photoBus;
  final String descriptionBus;
  final String? place;
  final String? localisationBus;
  final String nombrePlaces;
  final String? configurationCar;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? infractions;

  Bus({
    required this.id,
    required this.infoUserId,
    required this.compagniesId,
    required this.configurationPlaceBusesId,
    required this.nomBus,
    required this.marqueBus,
    required this.modeleBus,
    required this.immatriculationBus,
    required this.photoBus,
    required this.descriptionBus,
    this.place,
    this.localisationBus,
    required this.nombrePlaces,
    this.configurationCar,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.infractions,
  });

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: _parseInt(json['id']),
      infoUserId: _parseInt(json['info_user_id']),
      compagniesId: _parseInt(json['compagnies_id']),
      configurationPlaceBusesId: _parseInt(json['configuration_place_buses_id']),
      nomBus: json['nom_bus'] as String? ?? '',
      marqueBus: json['marque_bus'] as String? ?? '',
      modeleBus: json['modele_bus'] as String? ?? '',
      immatriculationBus: json['immatriculation_bus'] as String? ?? '',
      photoBus: _parseBusPhotos(json['photo_bus']),
      descriptionBus: json['description_bus'] as String? ?? '',
      place: json['place'] as String?,
      localisationBus: json['localisation_bus'] as String?,
      nombrePlaces: json['nombre_places']?.toString() ?? '0',
      configurationCar: json['configuration_car'] as String?,
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      infractions: json['infractions'] as String?,
    );
  }

  factory Bus.empty() {
    return Bus(
      id: 0,
      infoUserId: 0,
      compagniesId: 0,
      configurationPlaceBusesId: 0,
      nomBus: '',
      marqueBus: '',
      modeleBus: '',
      immatriculationBus: '',
      photoBus: const [],
      descriptionBus: '',
      place: null,
      localisationBus: null,
      nombrePlaces: '0',
      configurationCar: null,
      status: '',
      createdAt: '',
      updatedAt: '',
      infractions: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'info_user_id': infoUserId,
      'compagnies_id': compagniesId,
      'configuration_place_buses_id': configurationPlaceBusesId,
      'nom_bus': nomBus,
      'marque_bus': marqueBus,
      'modele_bus': modeleBus,
      'immatriculation_bus': immatriculationBus,
      'photo_bus': photoBus,
      'description_bus': descriptionBus,
      'place': place,
      'localisation_bus': localisationBus,
      'nombre_places': nombrePlaces,
      'configuration_car': configurationCar,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'infractions': infractions,
    };
  }
}

class Chauffeur {
  final int id;
  final int infoUserId;
  final int compagniesId;
  final String nom;
  final String prenom;
  final String telephone;
  final String? adresse;
  final String numeroPermis;
  final String dateNaissance;
  final String status;
  final String photo;
  final String createdAt;
  final String updatedAt;
  final String? infractions;

  Chauffeur({
    required this.id,
    required this.infoUserId,
    required this.compagniesId,
    required this.nom,
    required this.prenom,
    required this.telephone,
    this.adresse,
    required this.numeroPermis,
    required this.dateNaissance,
    required this.status,
    required this.photo,
    required this.createdAt,
    required this.updatedAt,
    this.infractions,
  });

  factory Chauffeur.fromJson(Map<String, dynamic> json) {
    return Chauffeur(
      id: _parseInt(json['id']),
      infoUserId: _parseInt(json['info_user_id']),
      compagniesId: _parseInt(json['compagnies_id']),
      nom: json['nom'] as String? ?? '',
      prenom: json['prenom'] as String? ?? '',
      telephone: json['telephone'] as String? ?? '',
      adresse: json['adresse'] as String?,
      numeroPermis: json['numeros_permis'] as String? ?? '',
      dateNaissance: json['date_naissance'] as String? ?? '',
      status: json['status']?.toString() ?? '',
      photo: json['photo'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      infractions: json['infractions'] as String?,
    );
  }

  factory Chauffeur.empty() {
    return Chauffeur(
      id: 0,
      infoUserId: 0,
      compagniesId: 0,
      nom: '',
      prenom: '',
      telephone: '',
      adresse: null,
      numeroPermis: '',
      dateNaissance: '',
      status: '',
      photo: '',
      createdAt: '',
      updatedAt: '',
      infractions: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'info_user_id': infoUserId,
      'compagnies_id': compagniesId,
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'adresse': adresse,
      'numeros_permis': numeroPermis,
      'date_naissance': dateNaissance,
      'status': status,
      'photo': photo,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'infractions': infractions,
    };
  }
}

class Compagnie {
  final int id;
  final int infoUserId;
  final int villesId;
  final String nomCompletCompagnies;
  final String emailCompagnies;
  final String telephoneCompagnies;
  final String? adresseCompagnies;
  final String logoCompagnies;
  final String? descriptionCompagnies;
  final String latitude;
  final String longitude;
  final String adresse;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? infractions;

  Compagnie({
    required this.id,
    required this.infoUserId,
    required this.villesId,
    required this.nomCompletCompagnies,
    required this.emailCompagnies,
    required this.telephoneCompagnies,
    this.adresseCompagnies,
    required this.logoCompagnies,
    this.descriptionCompagnies,
    required this.latitude,
    required this.longitude,
    required this.adresse,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.infractions,
  });

  factory Compagnie.fromJson(Map<String, dynamic> json) {
    return Compagnie(
      id: _parseInt(json['id']),
      infoUserId: _parseInt(json['info_user_id']),
      villesId: _parseInt(json['villes_id']),
      nomCompletCompagnies: json['nom_complet_compagnies'] as String? ?? '',
      emailCompagnies: json['email_compagnies'] as String? ?? '',
      telephoneCompagnies: json['telephone_compagnies'] as String? ?? '',
      adresseCompagnies: json['adresse_compagnies'] as String?,
      logoCompagnies: json['logo_compagnies'] as String? ?? '',
      descriptionCompagnies: json['description_compagnies'] as String?,
      latitude: json['latitude']?.toString() ?? '',
      longitude: json['longitude']?.toString() ?? '',
      adresse: json['adresse'] as String? ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      infractions: json['infractions'] as String?,
    );
  }

  factory Compagnie.empty() {
    return Compagnie(
      id: 0,
      infoUserId: 0,
      villesId: 0,
      nomCompletCompagnies: '',
      emailCompagnies: '',
      telephoneCompagnies: '',
      adresseCompagnies: null,
      logoCompagnies: '',
      descriptionCompagnies: null,
      latitude: '',
      longitude: '',
      adresse: '',
      status: '',
      createdAt: '',
      updatedAt: '',
      infractions: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'info_user_id': infoUserId,
      'villes_id': villesId,
      'nom_complet_compagnies': nomCompletCompagnies,
      'email_compagnies': emailCompagnies,
      'telephone_compagnies': telephoneCompagnies,
      'adresse_compagnies': adresseCompagnies,
      'logo_compagnies': logoCompagnies,
      'description_compagnies': descriptionCompagnies,
      'latitude': latitude,
      'longitude': longitude,
      'adresse': adresse,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'infractions': infractions,
    };
  }
}

class Agent {
  final int id;
  final int compagnieId;
  final int? gareId;
  final String rolePersonnel;
  final String nom;
  final String prenom;
  final String email;
  final String token;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String photo;
  final String? infractions;

  Agent({
    required this.id,
    required this.compagnieId,
    this.gareId,
    required this.rolePersonnel,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.token,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.photo,
    this.infractions,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: _parseInt(json['id']),
      compagnieId: _parseInt(json['compagnie_id']),
      gareId: json['gare_id'] != null ? _parseInt(json['gare_id']) : null,
      rolePersonnel: json['role_personnel'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      prenom: json['prenom'] as String? ?? '',
      email: json['email'] as String? ?? '',
      token: json['token'] as String? ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      photo: json['photo'] as String? ?? '',
      infractions: json['infractions'] as String?,
    );
  }

  factory Agent.empty() {
    return Agent(
      id: 0,
      compagnieId: 0,
      gareId: null,
      rolePersonnel: '',
      nom: '',
      prenom: '',
      email: '',
      token: '',
      status: '',
      createdAt: '',
      updatedAt: '',
      photo: '',
      infractions: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'compagnie_id': compagnieId,
      'gare_id': gareId,
      'role_personnel': rolePersonnel,
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'token': token,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'photo': photo,
      'infractions': infractions,
    };
  }
}
