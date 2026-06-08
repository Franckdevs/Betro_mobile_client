import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../services/api_service.dart';
import 'login_page.dart';

class ResetPasswordPage extends StatefulWidget {
  final String resetToken;
  final String email;
  final String telephone;

  const ResetPasswordPage({
    super.key,
    required this.resetToken,
    required this.email,
    this.telephone = '',
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  final ApiService _api = ApiService();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

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
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final response = await _api.post('reinitialiser-mot-de-passe', {
        'email': widget.email,
        'telephone': widget.telephone,
        'reset_token': widget.resetToken,
        'nouveau_mot_de_passe': _passwordController.text,
        'nouveau_mot_de_passe_confirmation': _confirmController.text,
      });

      if (!mounted) return;

      if (response['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mot de passe réinitialisé avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      } else {
        _showError(response['message'] ?? 'Une erreur est survenue');
      }
    } catch (e) {
      _showError('Erreur de connexion au serveur');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF757575),
      appBar: AppBar(
        backgroundColor: const Color(0xFF757575),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 8),

                          // ── Logo ─────────────────────────────────────
                          Center(
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
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
                          const SizedBox(height: 24),

                          // ── Titre ─────────────────────────────────────
                          const Text(
                            'Nouveau mot de passe',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choisissez un nouveau mot de passe\npour votre compte',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Formulaire ────────────────────────────────
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                _buildPasswordField(
                                  controller: _passwordController,
                                  focusNode: _passwordFocus,
                                  label: 'Nouveau mot de passe',
                                  obscure: _obscurePassword,
                                  onToggle: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                  onFieldSubmitted: (_) =>
                                      _confirmFocus.requestFocus(),
                                  textInputAction: TextInputAction.next,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Veuillez entrer un mot de passe';
                                    }
                                    if (v.length < 8) {
                                      return 'Minimum 8 caractères';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildPasswordField(
                                  controller: _confirmController,
                                  focusNode: _confirmFocus,
                                  label: 'Confirmer le mot de passe',
                                  obscure: _obscureConfirm,
                                  onToggle: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm),
                                  onFieldSubmitted: (_) => _submit(),
                                  textInputAction: TextInputAction.done,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Veuillez confirmer le mot de passe';
                                    }
                                    if (v != _passwordController.text) {
                                      return 'Les mots de passe ne correspondent pas';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Bouton Confirmer ──────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black87,
                                disabledBackgroundColor:
                                    Colors.amber.withOpacity(0.5),
                                elevation: 4,
                                shadowColor: Colors.amber.withOpacity(0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.black54,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Confirmer',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Iconsax.lock_1, size: 18),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required void Function(String) onFieldSubmitted,
    required TextInputAction textInputAction,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        floatingLabelStyle:
            const TextStyle(color: Colors.black87, fontSize: 13),
        prefixIcon:
            const Icon(Iconsax.lock, color: Colors.grey, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Iconsax.eye_slash : Iconsax.eye,
            color: Colors.grey,
            size: 20,
          ),
          onPressed: onToggle,
        ),
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
              const BorderSide(color: Colors.redAccent, width: 1.8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
