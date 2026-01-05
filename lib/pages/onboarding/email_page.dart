import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/custom_input.dart';
import '../../services/api_service.dart';
import 'terms_conditions_page.dart';
import 'license_agreement_page.dart';
import 'privacy_policy_page.dart';
import 'auth_choice_page.dart';
import '../auth/login_page.dart';

class Email extends StatefulWidget {
  const Email({super.key});

  @override
  State<Email> createState() => _EmailPageState();
}

class _EmailPageState extends State<Email> {
  final TextEditingController _emailController = TextEditingController();
  final ApiService _api = ApiService();
  bool _loading = false;

  //Methode pour sauvegarder en persistance le token
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  // 🔹 Envoi de l'OTP
  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      // Afficher l'erreur avant toute navigation ou setState
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez entrer un email valide")),
      );
      return;
    }

    if (!mounted) return; // sécurité

    setState(() => _loading = true);

    try {
      final response = await _api.post("inscription_via_mail", {
        "email": email,
      });

      if (!mounted) return; // sécurité après l'appel API

      if (response['status'] == true) {
        // Affiche le message avant la navigation
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response['message'])));

        final token = response['token'] ?? "";

        // 🔹 Sauvegarde du token localement
        await _saveToken(token);
        // Préparer les données à passer
        final dataToPass = {
          "email": email,
          "token": response['token'] ?? "",
          "otherData": response['otherData'] ?? "",
        };

        await _saveToken(response['token'] ?? "");

        // print('dbdbfbfdsfgfss');
        // print(dataToPass.toString());
        // Navigation sécurisée après le frame courant
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushNamed(context, '/otp', arguments: dataToPass);
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response['message'])));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur de connexion au serveur")),
        );
      }
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF757575),
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset("assets/images/logo.png", width: 120),
                            const SizedBox(height: 30),
                            const Text(
                              "Recevez votre code OTP",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 30),
                            CustomTextField(
                              controller: _emailController,
                              hint: "Votre adresse email",
                              icon: Icons.email_outlined,
                              type: TextInputType.emailAddress,
                              validator: (v) {
                                return null;
                              },
                              isPassword: false,
                            ),
                            const SizedBox(height: 25),
                            ElevatedButton(
                              onPressed: _loading ? null : _sendOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                foregroundColor: Colors.black87,
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      "Suivant",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 20),

                            // Bouton de connexion avec icône
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFD700),
                                    Color(0xFFFFA000),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.yellow.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LoginPage(),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "J'ai déjà un compte",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          Iconsax.arrow_right,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 20.0,
                                top: 10,
                              ),
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text:
                                          "En continuant, je reconnais accepter les conditions de\n",
                                    ),
                                    WidgetSpan(
                                      child: GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const TermsConditionsPage(),
                                          ),
                                        ),
                                        child: Text(
                                          "Conditions d'utilisation",
                                          style: TextStyle(
                                            decoration:
                                                TextDecoration.underline,
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const TextSpan(text: " et "),
                                    WidgetSpan(
                                      child: GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const LicenseAgreementPage(),
                                          ),
                                        ),
                                        child: Text(
                                          "Contrat de licence Betro",
                                          style: TextStyle(
                                            decoration:
                                                TextDecoration.underline,
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const TextSpan(text: ", et\n"),
                                    const TextSpan(
                                      text:
                                          "j'accepte que mes données soient traitées conformément\n",
                                    ),
                                    const TextSpan(text: "aux conditions de "),
                                    WidgetSpan(
                                      child: GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const PrivacyPolicyPage(),
                                          ),
                                        ),
                                        child: Text(
                                          "Politique de confidentialité",
                                          style: TextStyle(
                                            decoration:
                                                TextDecoration.underline,
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
