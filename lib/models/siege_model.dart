class Siege {
  final int id;
  final int configurationBusId;
  final int numero;
  final int disponible;
  final String type;
  final String nom;
  final String? createdAt;
  final String? updatedAt;
  final int? laravelThroughKey;

  Siege({
    required this.id,
    required this.configurationBusId,
    required this.numero,
    required this.disponible,
    required this.type,
    required this.nom,
    this.createdAt,
    this.updatedAt,
    this.laravelThroughKey,
  });

  factory Siege.fromJson(Map<String, dynamic> json) {
    return Siege(
      id: json['id'] as int,
      configurationBusId: json['configuration_bus_id'] as int,
      numero: json['numero'] as int,
      disponible: json['disponible'] is bool
          ? (json['disponible'] ? 1 : 0)
          : int.tryParse(json['disponible'].toString()) ?? 0,
      type: json['type'] as String,
      nom: json['nom'] as String,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      laravelThroughKey: json['laravel_through_key'] as int?,
    );
  }
}
