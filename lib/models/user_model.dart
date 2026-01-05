class User {
  final String email;
  final String? nom;
  final String? prenom;
  final String? telephone;
  final String? token;

  User({
    required this.email,
    this.nom,
    this.prenom,
    this.telephone,
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'],
      nom: json['nom'],
      prenom: json['prenom'],
      telephone: json['telephone'],
      token: json['token'],
    );
  }
}
