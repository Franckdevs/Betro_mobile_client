class InscriptionModel {
  final String? token;
  final String nom;
  final String prenom;
  final String telephone;
  final String password;

  InscriptionModel({
    this.token,
    required this.nom,
    required this.prenom,
    required this.password,
    required this.telephone,
  });

  Map<String, dynamic> toJson() {
    return {
      "token": token,
      "nom": nom,
      "prenom": prenom,
      "telephone": telephone,
      "password": password,
    };
  }
}
