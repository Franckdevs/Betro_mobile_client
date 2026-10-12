import 'package:flutter/material.dart';
import '../../core/widgets/shimmer_skeleton.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../core/utils/error_helper.dart';
import '../dashboard/dashboard_page.dart';
import '../onboarding/email_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  final String? blockedMessage;
  const LoginPage({super.key, this.blockedMessage});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _apiService = ApiService();
  final _storageService = StorageService();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _usePhone = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _toggleMode(bool usePhone) {
    setState(() => _usePhone = usePhone);
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      Fluttertoast.showToast(
        msg: "Veuillez remplir tous les champs obligatoires",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    if (_usePhone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "La fonctionnalité de connexion par téléphone n'est pas encore disponible"),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      debugPrint('Tentative de connexion...');

      final response = await _apiService.post('connexion', {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });

      debugPrint('Réponse reçue du serveur');

      if (response['success'] == true) {
        final userToken = response['token'];
        final userData = response['user'];

        if (userToken != null) {
          debugPrint('Token utilisateur reçu');
          await _storageService.saveToken(userToken);

          if (userData != null) {
            final userToSave = {
              'nom': userData['nom'],
              'prenom': userData['prenom'],
              'email': userData['email'],
              'telephone': userData['telephone'],
              'id': userData['id'],
              'photo': userData['photo'],
              'photo_url': userData['photo_url'],
              'status': userData['status'],
            };
            debugPrint('Sauvegarde des données utilisateur');
            await _storageService.saveUserData(userToSave);
          } else {
            debugPrint('Aucune donnée utilisateur à sauvegarder');
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Dashboard()),
            );
          }
        } else {
          debugPrint('Aucun token utilisateur trouvé dans la réponse');
          setState(() {
            _errorMessage = 'Erreur: Token utilisateur manquant';
          });
        }
      } else {
        final errorMsg = response['message'] ?? 'Échec de la connexion';
        debugPrint('Erreur de connexion: $errorMsg');
        if (mounted) {
          ErrorHelper.showErrorSnackBar(context, errorMsg);
        }
        setState(() {
          _errorMessage = errorMsg;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors de la connexion: $e');
      if (mounted) {
        ErrorHelper.showErrorSnackBar(
          context,
          'Erreur de connexion. Veuillez réessayer.',
        );
      }
      setState(() {
        _errorMessage = 'Erreur de connexion. Veuillez réessayer.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF757575),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF757575),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    // ── Bandeau compte bloqué ─────────────────────────────
                    if (widget.blockedMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade800.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.block,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Compte désactivé',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.blockedMessage!,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Logo dans cercle blanc ────────────────────────────
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                            width: 96,
                            height: 96,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Titre ─────────────────────────────────────────────
                    const Text(
                      'Connexion',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Connectez-vous pour accéder à votre compte',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // ── Toggle Email / Téléphone ──────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          _toggleTab(
                              'Téléphone', _usePhone, () => _toggleMode(true)),
                          _toggleTab(
                              'Email', !_usePhone, () => _toggleMode(false)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Champ email ou téléphone ──────────────────────────
                    if (_usePhone)
                      _buildPhoneField()
                    else
                      _buildField(
                        controller: _emailController,
                        label: 'Adresse email',
                        icon: Iconsax.sms,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Veuillez entrer votre email';
                          }
                          if (!RegExp(r'^[^@]+@[^\s]+\.[^\s]+$').hasMatch(v)) {
                            return 'Veuillez entrer un email valide';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 14),

                    // ── Champ mot de passe ────────────────────────────────
                    _buildField(
                      controller: _passwordController,
                      label: 'Mot de passe',
                      icon: Iconsax.lock_1,
                      obscureText: _obscurePassword,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Veuillez entrer votre mot de passe';
                        }
                        if (v.length < 6) {
                          return 'Le mot de passe doit contenir au moins 6 caractères';
                        }
                        return null;
                      },
                    ),

                    // ── Mot de passe oublié ───────────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ForgotPasswordPage()),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Mot de passe oublié ?',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    // ── Bannière erreur ───────────────────────────────────
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Bouton Se connecter ───────────────────────────────
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black87,
                          disabledBackgroundColor:
                              Colors.amber.withValues(alpha: 0.5),
                          elevation: 4,
                          shadowColor: Colors.amber.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.black54,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Se connecter',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Bouton Créer un compte ────────────────────────────
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const Email()),
                                ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "Créer un compte",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Champ téléphone avec drapeau CI ───────────────────────────────────────

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      validator: (v) => (v == null || v.isEmpty)
          ? 'Veuillez entrer votre numéro de téléphone'
          : null,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: 'Numéro de téléphone',
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        floatingLabelStyle:
            const TextStyle(color: Colors.black87, fontSize: 13),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: NetImage(
                  'https://flagcdn.com/w40/ci.png',
                  width: 24,
                  height: 16,
                  fit: BoxFit.cover,
                  error: (_) =>
                      const Icon(Icons.phone, size: 20, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '+225',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              Container(width: 1, height: 20, color: Colors.grey.shade300),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.amber, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  // ── Toggle tab ─────────────────────────────────────────────────────────────

  Widget _toggleTab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? Colors.amber : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.black87 : Colors.white70,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // ── Champ de saisie réutilisable ───────────────────────────────────────────

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        floatingLabelStyle:
            const TextStyle(color: Colors.black87, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.amber, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.white, fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }
}
