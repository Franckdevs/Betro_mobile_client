class Ville {
  final int id;
  final String nomVille;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Ville({
    required this.id,
    required this.nomVille,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Ville.fromJson(Map<String, dynamic> json) {
    return Ville(
      id: json['id'] as int,
      nomVille: json['nom_ville'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom_ville': nomVille,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
