import 'gare1_model.dart';

class ItineraireResponse {
  final Gare gare;
  final List<Itineraire> itineraires;

  ItineraireResponse({
    required this.gare,
    required this.itineraires,
  });

  factory ItineraireResponse.fromJson(Map<String, dynamic> json) {
    return ItineraireResponse(
      gare: Gare.fromJson(json['gares']),
      itineraires: (json['itineraries'] as List)
          .map((i) => Itineraire.fromJson(i))
          .toList(),
    );
  }
}

class Itineraire {
  final int id;
  final String titre;
  final String estimation;
  final Ville ville;
  final List<Voyage> voyages;

  Itineraire({
    required this.id,
    required this.titre,
    required this.estimation,
    required this.ville,
    required this.voyages,
  });

  factory Itineraire.fromJson(Map<String, dynamic> json) {
    return Itineraire(
      id: json['id'],
      titre: json['titre'],
      estimation: json['estimation'],
      ville: Ville.fromJson(json['ville']),
      voyages: (json['voyages'] as List)
          .map((v) => Voyage.fromJson(v))
          .toList(),
    );
  }
}

class Voyage {
  final int id;
  final String heureDepart;
  final String dateDepart;
  final List<ArretVoyage> arretVoyages;

  Voyage({
    required this.id,
    required this.heureDepart,
    required this.dateDepart,
    required this.arretVoyages,
  });

  factory Voyage.fromJson(Map<String, dynamic> json) {
    return Voyage(
      id: json['id'],
      heureDepart: json['heure_depart'],
      dateDepart: json['date_depart'],
      arretVoyages: (json['arret_voyages'] as List)
          .map((a) => ArretVoyage.fromJson(a))
          .toList(),
    );
  }
}

class ArretVoyage {
  final int id;
  final String montant;
  final Arret arret;

  ArretVoyage({
    required this.id,
    required this.montant,
    required this.arret,
  });

  factory ArretVoyage.fromJson(Map<String, dynamic> json) {
    return ArretVoyage(
      id: json['id'],
      montant: json['montant'],
      arret: Arret.fromJson(json['arret']),
    );
  }
}

class Arret {
  final int id;
  final String? nom;
  final Gare gare;

  Arret({
    required this.id,
    this.nom,
    required this.gare,
  });

  factory Arret.fromJson(Map<String, dynamic> json) {
    return Arret(
      id: json['id'],
      nom: json['nom'],
      gare: Gare.fromJson(json['gare']),
    );
  }
}

class Ville {
  final int id;
  final String nomVille;
  final String status;

  Ville({
    required this.id,
    required this.nomVille,
    required this.status,
  });

  factory Ville.fromJson(Map<String, dynamic> json) {
    return Ville(
      id: json['id'],
      nomVille: json['nom_ville'],
      status: json['status'],
    );
  }
}
