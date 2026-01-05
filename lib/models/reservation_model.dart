class Reservation {
  final int id;
  final int numeroPlace;
  final String? numeroReservation;
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

  Reservation({
    required this.id,
    required this.numeroPlace,
    this.numeroReservation,
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
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'] as int,
      numeroPlace: json['numero_place'] as int,
      numeroReservation: json['numero_reservation'] as String?,
      status: json['status'] as String,
      dateCreation: DateTime.parse(json['created_at'] as String),
      villeDepart:
          json['arret']['tarification']['ville_depart']['nom_ville'] as String,
      villeArrivee:
          json['arret']['tarification']['ville_arrivee']['nom_ville'] as String,
      marqueBus: json['voyage']['bus']['marque_bus'] as String,
      immatriculationBus:
          json['voyage']['bus']['immatriculation_bus'] as String,
      prix: (json['arret']['montant'] as num).toDouble(),
      nombreTotalPlaces: json['voyage']['bus']['places'] != null
          ? (json['voyage']['bus']['places'] as List).length
          : 0,
      nomComplet: json['nom_complet'] as String?,
      telephoneProprietaire: json['telephone_proprietaire'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numero_place': numeroPlace,
      'numero_reservation': numeroReservation,
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
        'bus': {
          'nom_bus': marqueBus,
          'marque_bus': marqueBus,
          'immatriculation_bus': immatriculationBus,
          'places': List.generate(
            nombreTotalPlaces,
            (index) => {'id': index + 1},
          ),
        },
        'date_depart': dateCreation.toIso8601String().split('T')[0],
        'heure_depart':
            '${dateCreation.hour.toString().padLeft(2, '0')}:${dateCreation.minute.toString().padLeft(2, '0')}:00',
      },
      'gares': {'nom_gare': 'Gare de $villeDepart'},
      'nom_complet': nomComplet,
      'telephone_proprietaire': telephoneProprietaire,
    };
  }
}
