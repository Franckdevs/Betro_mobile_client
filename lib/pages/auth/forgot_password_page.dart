import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import '../../services/api_service.dart';
import 'reset_password_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final ApiService _api = ApiService();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  final _otpController = TextEditingController();
  final _otpFocus = FocusNode();

  bool _loading = false;
  bool _usePhone = true;
  bool _sent = false;
  bool _verifying = false;
  String? _sentTo;
  String? _sentEmail;
  String? _sentPhone;

  Timer? _countdownTimer;
  int _secondsLeft = 120;

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
    _countdownTimer?.cancel();
    _animController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _otpController.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _secondsLeft = 120);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          t.cancel();
        }
      });
    });
  }

  String get _countdownLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _toggleMode(bool usePhone) {
    FocusScope.of(context).unfocus();
    setState(() {
      _usePhone = usePhone;
      _sent = false;
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (usePhone) {
        _phoneFocus.requestFocus();
      } else {
        _emailFocus.requestFocus();
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final email = _usePhone ? '' : _emailController.text.trim();
      final telephone = _usePhone ? _phoneController.text.trim() : '';

      final response = await _api.post('mot-de-passe-oublie', {
        'email': email,
        'telephone': telephone,
      });

      if (!mounted) return;

      if (response['status'] == true) {
        setState(() {
          _sent = true;
          _sentEmail = email;
          _sentPhone = telephone;
          _sentTo = response['email'] ?? email;
        });
        _startCountdown();
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _otpFocus.requestFocus());
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

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      _showError('Veuillez entrer le code à 6 chiffres');
      return;
    }

    setState(() => _verifying = true);

    try {
      final response = await _api.post('verifier-otp-reset', {
        'email': _sentEmail ?? '',
        'telephone': _sentPhone ?? '',
        'code': code,
      });

      if (!mounted) return;

      if (response['status'] == true) {
        final resetToken = response['reset_token'] as String? ?? '';
        final email = response['email'] as String? ?? _sentEmail ?? '';
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordPage(
              resetToken: resetToken,
              email: email,
              telephone: _sentPhone ?? '',
            ),
          ),
        );
      } else {
        _showError(response['message'] ?? 'Code OTP invalide ou expiré.');
      }
    } catch (e) {
      _showError('Erreur de connexion au serveur');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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

                          // ── Logo ───────────────────────────────────────
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

                          // ── Titre ──────────────────────────────────────
                          const Text(
                            'Mot de passe oublié',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              _sent
                                  ? 'Entrez le code reçu sur\n$_sentTo'
                                  : _usePhone
                                      ? 'Entrez votre numéro de téléphone\npour réinitialiser votre mot de passe'
                                      : 'Entrez votre adresse e-mail\npour réinitialiser votre mot de passe',
                              key: ValueKey('$_usePhone$_sent'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          if (_sent) ...[
                            // ── Bannière succès ────────────────────────
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: Colors.green.withOpacity(0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Iconsax.tick_circle,
                                      color: Colors.greenAccent, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Code envoyé à $_sentTo',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── Saisie OTP ─────────────────────────────
                            TextFormField(
                              controller: _otpController,
                              focusNode: _otpFocus,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 6,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _verifyOtp(),
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 8,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                hintText: '------',
                                hintStyle: TextStyle(
                                  color: Colors.grey.withOpacity(0.5),
                                  letterSpacing: 8,
                                  fontSize: 22,
                                ),
                                counterText: '',
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
                                  borderSide: const BorderSide(
                                      color: Colors.amber, width: 1.8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 18),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // ── Compte à rebours ───────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Iconsax.timer_1,
                                  size: 16,
                                  color: _secondsLeft <= 30
                                      ? Colors.redAccent
                                      : Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _secondsLeft > 0
                                      ? 'Code valide pendant $_countdownLabel'
                                      : 'Code expiré — renvoyez un nouveau code',
                                  style: TextStyle(
                                    color: _secondsLeft <= 30
                                        ? Colors.redAccent
                                        : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: _secondsLeft <= 30
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // ── Bouton Vérifier ────────────────────────
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: (_verifying || _secondsLeft == 0)
                                    ? null
                                    : _verifyOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black87,
                                  disabledBackgroundColor:
                                      Colors.amber.withOpacity(0.5),
                                  elevation: 4,
                                  shadowColor:
                                      Colors.amber.withOpacity(0.35),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _verifying
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
                                            'Vérifier le code',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Iconsax.shield_tick, size: 18),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ── Retour connexion ───────────────────────
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                      color: Colors.white.withOpacity(0.5)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Retour à la connexion',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            // ── Toggle Email / Téléphone ───────────────
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Row(
                                children: [
                                  _toggleTab('Téléphone', _usePhone,
                                      () => _toggleMode(true)),
                                  _toggleTab('Email', !_usePhone,
                                      () => _toggleMode(false)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ── Formulaire ─────────────────────────────
                            Form(
                              key: _formKey,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: _usePhone
                                    ? _buildField(
                                        key: const ValueKey('phone'),
                                        controller: _phoneController,
                                        label: 'Numéro de téléphone',
                                        icon: Iconsax.call,
                                        focusNode: _phoneFocus,
                                        keyboardType: TextInputType.phone,
                                        validator: (v) =>
                                            (v == null || v.isEmpty)
                                                ? 'Veuillez entrer votre numéro'
                                                : null,
                                      )
                                    : _buildField(
                                        key: const ValueKey('email'),
                                        controller: _emailController,
                                        label: 'Adresse email',
                                        icon: Iconsax.sms,
                                        focusNode: _emailFocus,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Veuillez entrer votre email';
                                          }
                                          if (!RegExp(
                                                  r'^[^@]+@[^\s]+\.[^\s]+$')
                                              .hasMatch(v)) {
                                            return 'Email invalide';
                                          }
                                          return null;
                                        },
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── Bouton Envoyer ─────────────────────────
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
                                  shadowColor:
                                      Colors.amber.withOpacity(0.35),
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
                                            'Envoyer le code',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Iconsax.send_1, size: 18),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ── Retour connexion ───────────────────────
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                      color: Colors.white.withOpacity(0.5)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Retour à la connexion',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                      color: Colors.amber.withOpacity(0.3),
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

  // ── Champ de saisie ────────────────────────────────────────────────────────

  Widget _buildField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    FocusNode? focusNode,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      validator: validator,
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        floatingLabelStyle:
            const TextStyle(color: Colors.black87, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
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
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
