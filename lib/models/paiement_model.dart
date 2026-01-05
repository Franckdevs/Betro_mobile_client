class Paiement {
  final int id;
  final int utilisateurId;
  final int voyageId;
  final String numeroPlace;
  final String montant;
  final String moyenPaiement;
  final String codePaiement;
  final String statut;
  final DateTime datePaiement;
  final String referencePaiement;

  Paiement({
    required this.id,
    required this.utilisateurId,
    required this.voyageId,
    required this.numeroPlace,
    required this.montant,
    required this.moyenPaiement,
    required this.codePaiement,
    required this.statut,
    required this.datePaiement,
    required this.referencePaiement,
  });

  factory Paiement.fromJson(Map<String, dynamic> json) {
    return Paiement(
      id: json['id'] ?? 0,
      utilisateurId: json['utilisateur_id'] ?? 0,
      voyageId: json['voyages_id'] ?? 0,
      numeroPlace: json['numero_place'] ?? 'N/A',
      montant: json['montant']?.toString() ?? '0',
      moyenPaiement: json['moyenPaiement'] ?? 'Inconnu',
      codePaiement: json['code_paiement'] ?? '',
      statut: json['status']?.toString() ?? 'Inconnu',
      datePaiement: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      referencePaiement: json['referencePaiement'] ?? '',
    );
  }
}
