import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/custom_input.dart';
import '../../models/inscription_model.dart';
import '../../services/api_service.dart';

class Inscription extends StatefulWidget {
  const Inscription({super.key});

  @override
  State<Inscription> createState() => _InscriptionPageState();
}

class _InscriptionPageState extends State<Inscription> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();

  // 🔹 Champs du formulaire
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _loading = false;
  String? _token;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Récupération du token passé via arguments
    _token = ModalRoute.of(context)!.settings.arguments as String?;
  }

  // 🔹 Récupération du token stocké localement
  Future<String?> _getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // 🔹 Sauvegarde du token pour usage futur
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      showError(context, "Les mots de passe ne correspondent pas.");
      return;
    }

    setState(() => _loading = true);

    try {
      // 🔹 Récupère le token existant ou celui du contexte
      final localToken = await _getStoredToken() ?? _token;

      print("🔹=== DÉBUT INSCRIPTION ===");
      print("✅ Token utilisé : $localToken");
      print("✅ Nom : ${_nameController.text.trim()}");
      print("✅ Prénom : ${_prenomController.text.trim()}");
      print("✅ Téléphone : ${_telephoneController.text.trim()}");
      print("✅ Password : ${_passwordController.text.trim()}");
      print("✅ Confirm Password : ${_confirmPasswordController.text.trim()}");

      final inscriptionData = InscriptionModel(
        token: localToken,
        nom: _nameController.text.trim(),
        prenom: _prenomController.text.trim(),
        telephone: _telephoneController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // 🔹 Affichage du corps de la requête
      print("📦 Corps envoyé à l'API : ${inscriptionData.toJson()}");

      final response = await _api.post(
        "inscription_finalisation",
        inscriptionData.toJson(),
      );

      // 🔹 Affichage de la réponse brute
      print("📩 Réponse complète du serveur : $response");

      // 🔹 Vérifie le message de la réponse
      if (response['message']?.toLowerCase().contains('réussie') == true ||
          response['utilisateur'] != null) {
        print("✅ Inscription réussie, sauvegarde du token...");

        // Sauvegarde du token de l'utilisateur
        final userToken = response['utilisateur']?['token'];
        if (userToken != null) {
          await _saveToken(userToken);
          print("💾 Token sauvegardé localement : $userToken");
        } else if (localToken != null) {
          await _saveToken(localToken);
          print("💾 Token initial sauvegardé localement : $localToken");
        }

        if (mounted) {
          // Afficher le message de succès
          final successMessage = response['message'] ?? 'Inscription réussie !';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // Attendre un court instant avant la navigation
          await Future.delayed(const Duration(milliseconds: 1500));

          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/dashboard',
              (route) => false,
            );
          }
        }
      } else {
        print("⚠️ Échec de l'inscription : ${response['message']}");
        showError(context, response['message'] ?? "Erreur d'inscription");
      }
    } catch (e, stackTrace) {
      showError(context, "Erreur de connexion au serveur");
      print("❌ Exception attrapée : $e");
      print("🧱 StackTrace : $stackTrace");
    }

    setState(() => _loading = false);
    print("🔹=== FIN INSCRIPTION ===");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF757575),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo et titre
                    Center(
                      child: Image.asset('assets/images/logo.png', width: 100),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Créer un compte',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Veuillez renseigner vos informations',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 20),

                    // Champs du formulaire
                    CustomTextField(
                      controller: _nameController,
                      hint: "Nom",
                      icon: Icons.person_outline,
                      isPassword: false,
                      validator: (v) =>
                          v!.isEmpty ? "Veuillez entrer votre nom" : null,
                    ),
                    const SizedBox(height: 15),

                    CustomTextField(
                      controller: _prenomController,
                      hint: "Prénom",
                      icon: Icons.person,
                      isPassword: false,
                      validator: (v) =>
                          v!.isEmpty ? "Veuillez entrer votre prénom" : null,
                    ),
                    const SizedBox(height: 15),

                    // Champ de téléphone avec indicateur de pays
                    Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey, width: 1.0),
                      ),
                      child: Row(
                        children: [
                          // Indicateur de pays
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 15,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: Colors.grey,
                                  width: 1.0,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    image: const DecorationImage(
                                      image: NetworkImage(
                                        'https://flagcdn.com/w40/ci.png',
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '+225',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Champ de saisie
                          Expanded(
                            child: TextFormField(
                              controller: _telephoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(
                                  10,
                                ), // Limite à 10 chiffres
                              ],
                              style: const TextStyle(color: Colors.black),
                              decoration: const InputDecoration(
                                hintText: 'Votre numéro',
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 15,
                                ),
                                errorStyle: TextStyle(height: 0.8),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez entrer votre numéro';
                                }
                                final phoneRegex = RegExp(r'^\d{10}$');
                                if (!phoneRegex.hasMatch(value)) {
                                  return 'Le numéro doit contenir 10 chiffres';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Mot de passe
                    CustomTextField(
                      controller: _passwordController,
                      hint: "Mot de passe",
                      icon: Icons.lock_outline,
                      isPassword: true,
                      validator: (v) => v!.length < 6
                          ? "Le mot de passe doit contenir au moins 6 caractères"
                          : null,
                    ),
                    const SizedBox(height: 15),

                    // Confirmation du mot de passe
                    CustomTextField(
                      controller: _confirmPasswordController,
                      hint: "Confirmer le mot de passe",
                      icon: Icons.lock,
                      isPassword: true,
                      validator: (v) => v!.isEmpty
                          ? "Veuillez confirmer votre mot de passe"
                          : v != _passwordController.text
                          ? "Les mots de passe ne correspondent pas"
                          : null,
                    ),
                    const SizedBox(height: 25),

                    // Bouton de soumission
                    ElevatedButton(
                      onPressed: _loading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 40,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Finaliser",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
