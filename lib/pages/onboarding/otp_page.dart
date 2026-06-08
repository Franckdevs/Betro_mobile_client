import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

class Otp extends StatefulWidget {
  const Otp({super.key});

  @override
  State<Otp> createState() => _OtpPageState();
}

class _OtpPageState extends State<Otp> with SingleTickerProviderStateMixin {
  // Un seul contrôleur pour les 6 chiffres
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  final ApiService _api = ApiService();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool _isResending = false;
  bool _isVerifying = false;
  String? _email;
  String? token;
  String? _phoneNumber;
  String? _whatsappNumber;

  Timer? _countdownTimer;
  int _secondsLeft = 600; // 10 minutes

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

    _otpFocusNode.addListener(() => setState(() {}));
    _loadContactNumbers();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _secondsLeft = 600);
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

  Future<void> _loadContactNumbers() async {
    try {
      final response = await _api.get('recupere_numero_telephone');
      if (response['success'] == true) {
        final tel = response['telephone'];
        if (mounted) {
          setState(() {
            _phoneNumber = (tel['lien_telephone'] as String?)
                ?.replaceAll(' ', '');
            _whatsappNumber = (tel['lien_whatsapp'] as String?)
                ?.replaceAll(' ', '');
          });
        }
      }
    } catch (_) {
      // Garde les numéros null, les boutons restent désactivés
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _email = args["email"];
      token = args['token'];
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _resendOtp() async {
    if (_email == null) return;

    // Relancer le compte à rebours immédiatement au clic
    _startCountdown();
    setState(() => _isResending = true);

    try {
      final response = await _api.post('generate-otp', {'email': _email});
      final isSuccess =
          response['success'] == true || response['status'] == true;
      if (isSuccess) {
        // Vider le champ pour que l'utilisateur saisisse le nouveau code
        _otpController.clear();
        _showSuccess('Nouveau code OTP envoyé avec succès');
      } else {
        _showError(response['message'] ?? 'Erreur lors de l\'envoi du code');
      }
    } catch (e) {
      _showError('Erreur de connexion');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _makePhoneCall() async {
    if (_phoneNumber == null) return;
    final Uri uri = Uri.parse('tel:$_phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showError('Impossible d\'ouvrir l\'application d\'appel');
    }
  }

  Future<void> _openWhatsApp() async {
    if (_whatsappNumber == null) return;
    final Uri uri = Uri.parse('https://wa.me/$_whatsappNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showError('Impossible d\'ouvrir WhatsApp');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _verifyOtp() async {
    if (_email == null) return;
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      _showError("Veuillez entrer un code OTP complet");
      return;
    }
    final tokens = await _getToken();
    setState(() => _isVerifying = true);
    try {
      final response = await _api.post("verifier-otp", {
        "token": tokens,
        "code": otp,
      });
      if (response['status'] == true) {
        final tok = response['utilisateur']?['token'];
        if (tok != null) {
          _showSuccess("Code OTP vérifié !");
          Navigator.pushNamed(context, '/register', arguments: tok);
        } else {
          _showError("Erreur : token manquant.");
        }
      } else {
        _showError(response['message'] ?? "Code OTP invalide.");
      }
    } catch (e, stackTrace) {
      _showError("Erreur de connexion au serveur");
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stackTrace,
        library: 'OtpController',
        context: ErrorDescription('dans _verifyOtp()'),
      ));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  // ── Boîte d'affichage d'un chiffre ────────────────────────────────────────

  Widget _buildOtpBox(int index) {
    final text = _otpController.text;
    final char = index < text.length ? text[index] : '';
    final isActive = _otpFocusNode.hasFocus && index == text.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 46,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isActive
            ? Border.all(color: Colors.amber, width: 2)
            : Border.all(color: Colors.transparent, width: 2),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? Colors.amber.withOpacity(0.3)
                : Colors.black.withOpacity(0.08),
            blurRadius: isActive ? 10 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: char.isNotEmpty
            ? Text(
                char,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              )
            : isActive
                ? Container(
                    width: 2,
                    height: 24,
                    color: Colors.amber,
                  )
                : null,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF757575),
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

                          // ── Logo dans cercle blanc ─────────────────────
                          Center(
                            child: Container(
                              width: 100,
                              height: 100,
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
                                  "assets/images/logo.png",
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Titre ──────────────────────────────────────
                          const Text(
                            "Vérification du code OTP",
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
                            "Code envoyé à ${_email ?? '...'}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Saisissez le code à 6 chiffres",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // ── Cases OTP + TextField caché ────────────────
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              // Boîtes d'affichage
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                    6, (i) => _buildOtpBox(i)),
                              ),
                              // TextField invisible pleine largeur qui capte la saisie
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 0,
                                  child: TextField(
                                    controller: _otpController,
                                    focusNode: _otpFocusNode,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ),
                              // Icône vider tout
                              if (_otpController.text.isNotEmpty)
                                Positioned(
                                  right: -4,
                                  top: -10,
                                  child: GestureDetector(
                                    onTap: () {
                                      _otpController.clear();
                                      _otpFocusNode.requestFocus();
                                      setState(() {});
                                    },
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── Compte à rebours ───────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Iconsax.timer_1,
                                size: 16,
                                color: _secondsLeft <= 60
                                    ? Colors.redAccent
                                    : Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _secondsLeft > 0
                                    ? 'Code valide pendant $_countdownLabel'
                                    : 'Code expiré — renvoyez un nouveau code',
                                style: TextStyle(
                                  color: _secondsLeft <= 60
                                      ? Colors.redAccent
                                      : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: _secondsLeft <= 60
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── Bouton Vérifier ────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: (_isVerifying || _secondsLeft == 0)
                                  ? null
                                  : _verifyOtp,
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
                              child: _isVerifying
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
                                          "Vérifier",
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

                          // ── Bouton Renvoyer le code ────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              onPressed: (_isResending || _isVerifying || _secondsLeft > 0)
                                  ? null
                                  : _resendOtp,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                    color: Colors.white.withOpacity(
                                        _secondsLeft > 0 ? 0.2 : 0.5)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isResending
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white60,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Iconsax.refresh,
                                            size: 16,
                                            color: _secondsLeft > 0
                                                ? Colors.white38
                                                : Colors.white),
                                        const SizedBox(width: 8),
                                        Text(
                                          _secondsLeft > 0
                                              ? "Renvoyer dans $_countdownLabel"
                                              : "Renvoyer le code",
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: _secondsLeft > 0
                                                ? Colors.white38
                                                : Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Séparateur ─────────────────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                    color: Colors.white.withOpacity(0.3),
                                    thickness: 1),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                child: Text(
                                  "Besoin d'aide ?",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                    color: Colors.white.withOpacity(0.3),
                                    thickness: 1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── Boutons Appel / WhatsApp ───────────────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: (_isVerifying || _phoneNumber == null)
                                          ? null
                                          : _makePhoneCall,
                                      icon: const Icon(Iconsax.call,
                                          color: Colors.white, size: 16),
                                      label: const Text(
                                        'Appeler',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(
                                            double.infinity, 48),
                                        backgroundColor:
                                            Colors.black.withOpacity(0.25),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          side: BorderSide(
                                              color: Colors.white
                                                  .withOpacity(0.2)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _phoneNumber ?? '—',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: (_isVerifying || _whatsappNumber == null)
                                          ? null
                                          : _openWhatsApp,
                                      icon: const Icon(Iconsax.message,
                                          color: Colors.white, size: 16),
                                      label: const Text(
                                        'WhatsApp',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(
                                            double.infinity, 48),
                                        backgroundColor:
                                            const Color(0xFF25D366),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _whatsappNumber ?? '—',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
}
