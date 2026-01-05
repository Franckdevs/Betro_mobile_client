import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/helpers.dart';
import '../../services/api_service.dart';

class Otp extends StatefulWidget {
  const Otp({super.key});

  @override
  State<Otp> createState() => _OtpPageState();
}

class _OtpPageState extends State<Otp> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final ApiService _api = ApiService();
  bool _isResending = false;
  bool _isVerifying = false;
  String? _email;
  String? token;
  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   _email = ModalRoute.of(context)!.settings.arguments as String?;
  // }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // On récupère la Map passée depuis la page Email
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _email = args["email"];
      token = args['token']; // ← utiliser 'token' directement
      var otherData = args["otherData"];
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  void _handleOtpChange(String value, int index) {
    if (value.length == 1 && index < 5) {
      FocusScope.of(context).requestFocus(_otpFocusNodes[index + 1]);
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_otpFocusNodes[index - 1]);
    }
  }

  Future<void> _resendOtp() async {
    if (_email == null) return;

    setState(() => _isResending = true);
    try {
      final response = await _api.post('generate-otp', {'email': _email});

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nouveau code OTP envoyé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          _showError(response['message'] ?? 'Erreur lors de l\'envoi du code');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Erreur de connexion');
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  // Fonction pour ouvrir l'application d'appel
  Future<void> _makePhoneCall() async {
    final Uri phoneNumber = Uri.parse(
      'tel:+2250700000000',
    ); // Remplacez par le numéro de téléphone souhaité
    if (await canLaunchUrl(phoneNumber)) {
      await launchUrl(phoneNumber);
    } else {
      if (mounted) {
        _showError('Impossible d\'ouvrir l\'application d\'appel');
      }
    }
  }

  // Fonction pour ouvrir WhatsApp
  Future<void> _openWhatsApp() async {
    final Uri whatsappUrl = Uri.parse(
      'https://wa.me/2250700000000',
    ); // Remplacez par le numéro WhatsApp souhaité
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl);
    } else {
      if (mounted) {
        _showError('Impossible d\'ouvrir WhatsApp');
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (_email == null) return;

    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 6) {
      showError(context, "Veuillez entrer un code OTP complet");
      return;
    }

    final tokens = await _getToken();

    setState(() => _isVerifying = true);
    print('testsgesfgegstegsregrsegrgbra');
    print('code otp' + otp);
    try {
      final response = await _api.post("verifier-otp", {
        // "token": token,
        "token": tokens,
        "code": otp,
      });
      print("token" + ' ' + token!);
      if (response['status'] == true) {
        final token = response['utilisateur']?['token'];
        if (token != null) {
          showSuccess(context, "Code OTP vérifié !");
          Navigator.pushNamed(context, '/register', arguments: token);
        } else {
          showError(context, "Erreur : token manquant.");
        }
      } else {
        showError(context, response['message'] ?? "Code OTP invalide.");
      }
    } catch (e, stackTrace) {
      // Affiche l'erreur à l'utilisateur
      showError(context, "Erreur de connexion au serveur");

      // Capture et envoi des détails de l'erreur et de la pile
      final FlutterErrorDetails errorDetails = FlutterErrorDetails(
        exception: e,
        stack: stackTrace,
        library: 'OtpController',
        context: ErrorDescription('dans _verifyOtp()'),
      );
      FlutterError.reportError(errorDetails);
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) controller.dispose();
    for (var node in _otpFocusNodes) node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF757575),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            height: MediaQuery.of(context).size.height - 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset('assets/images/logo.png', height: 100, width: 100),
                const SizedBox(height: 40),
                const Text(
                  "Vérification du code OTP",
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Code envoyé à $_email",
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Saisissez le code à 6 chiffres",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    return Container(
                      width: 45,
                      height: 55,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _otpFocusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          counterText: "",
                          border: InputBorder.none,
                        ),
                        onChanged: (value) => _handleOtpChange(value, index),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                // Bouton Vérifier
                SizedBox(
                  width: 200,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Vérifier",
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
                // Bouton Renvoyer le code
                SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: (_isResending || _isVerifying)
                        ? null
                        : _resendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isResending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Renvoyer le code',
                            style: TextStyle(fontSize: 14),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                // Boutons d'appel et WhatsApp
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Bouton Appel
                    SizedBox(
                      width: 120,
                      child: ElevatedButton.icon(
                        onPressed: _isVerifying ? null : _makePhoneCall,
                        icon: const Icon(
                          Icons.phone,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'Appeler',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Bouton WhatsApp
                    SizedBox(
                      width: 120,
                      child: ElevatedButton.icon(
                        onPressed: _isVerifying ? null : _openWhatsApp,
                        icon: const Icon(
                          Icons.chat,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'WhatsApp',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF25D366,
                          ), // Vert WhatsApp
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
