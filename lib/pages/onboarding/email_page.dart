import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../auth/login_page.dart';

class Email extends StatefulWidget {
  const Email({super.key});

  @override
  State<Email> createState() => _EmailPageState();
}

class _EmailPageState extends State<Email>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final ApiService _api = ApiService();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool _loading = false;
  bool _usePhone = false;

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
    _phoneController.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  void _toggleMode(bool usePhone) {
    FocusScope.of(context).unfocus();
    setState(() => _usePhone = usePhone);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (usePhone) {
        _phoneFocusNode.requestFocus();
      } else {
        _emailFocusNode.requestFocus();
      }
    });
  }

  Future<void> _sendOtp() async {
    if (_usePhone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "L'inscription par téléphone n'est pas encore disponible"),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final input = _usePhone ? phone : email;

    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_usePhone
              ? "Veuillez entrer un numéro de téléphone valide"
              : "Veuillez entrer un email valide"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final response = await _api.post(
        "inscription_via_mail",
        _usePhone ? {"phone": phone} : {"email": email},
      );

      if (!mounted) return;

      if (response['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'])),
        );

        final token = response['token'] ?? "";
        await _saveToken(token);

        final dataToPass = {
          _usePhone ? "phone" : "email": input,
          "token": response['token'] ?? "",
          "otherData": response['otherData'] ?? "",
          "usePhone": _usePhone,
        };

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushNamed(context, '/otp', arguments: dataToPass);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'])),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erreur de connexion au serveur"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() => _loading = false);
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

                          // ── Logo dans cercle blanc ────────────────────
                          Center(
                            child: Container(
                              width: 100,
                              height: 100,
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
                                  "assets/images/logo.png",
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Titre ─────────────────────────────────────
                          const Text(
                            "Recevez votre code OTP",
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
                              _usePhone
                                  ? "Entrez votre numéro de téléphone\npour recevoir le code"
                                  : "Entrez votre adresse email\npour recevoir le code",
                              key: ValueKey(_usePhone),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Toggle Email / Téléphone ──────────────────
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.15),
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

                          // ── Champ de saisie ───────────────────────────
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _usePhone
                                ? _buildField(
                                    key: const ValueKey('phone'),
                                    controller: _phoneController,
                                    label: 'Numéro de téléphone',
                                    icon: Iconsax.call,
                                    focusNode: _phoneFocusNode,
                                    keyboardType: TextInputType.phone,
                                  )
                                : _buildField(
                                    key: const ValueKey('email'),
                                    controller: _emailController,
                                    label: 'Adresse email',
                                    icon: Iconsax.sms,
                                    focusNode: _emailFocusNode,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                          ),
                          const SizedBox(height: 24),

                          // ── Bouton Suivant ────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _sendOtp,
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
                                          "Suivant",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Iconsax.arrow_right,
                                            size: 18),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // ── Lien "J'ai déjà un compte" ────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginPage()),
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
                                "J'ai déjà un compte",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Conditions d'utilisation ──────────────────
                          _buildTermsText(),
                          const SizedBox(height: 16),
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

  // ── Champ de saisie ────────────────────────────────────────────────────────

  Widget _buildField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required FocusNode focusNode,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  // ── Ouverture politique via API ────────────────────────────────────────────

  Future<void> _openPolicy(String type) async {
    // Affiche un loader immédiatement
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PolicyLoadingSheet(),
    );

    try {
      final response = await _api.get('regle-utilisation-mobile');
      if (!mounted) return;
      Navigator.pop(context); // ferme le loader

      if (response['status'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contenu non disponible'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final htmlContent = response[type] as String?;
      if (htmlContent == null || htmlContent.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contenu non disponible pour le moment'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        builder: (_) => _PolicySheet(htmlContent: htmlContent),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur de connexion au serveur'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ── Texte des conditions ──────────────────────────────────────────────────

  Widget _buildTermsText() {
    final linkStyle = TextStyle(
      decoration: TextDecoration.underline,
      color: Colors.amber.shade200,
      fontSize: 12,
    );
    const baseStyle = TextStyle(
      color: Colors.white70,
      fontSize: 12,
      height: 1.6,
    );

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(
              text: "En continuant, j'accepte les "),
          WidgetSpan(
            child: GestureDetector(
              onTap: () => _openPolicy('conditions_utilisation'),
              child: Text("Conditions d'utilisation", style: linkStyle),
            ),
          ),
          const TextSpan(text: " et la "),
          WidgetSpan(
            child: GestureDetector(
              onTap: () => _openPolicy('confidentialite'),
              child: Text("Politique de confidentialité", style: linkStyle),
            ),
          ),
          const TextSpan(text: "."),
        ],
      ),
    );
  }
}

// ── Bottom sheet chargement ────────────────────────────────────────────────

class _PolicyLoadingSheet extends StatelessWidget {
  const _PolicyLoadingSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: const BoxDecoration(
        color: Color(0xFF616161),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.amber, strokeWidth: 2.5),
            SizedBox(height: 16),
            Text(
              'Chargement…',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheet contenu HTML ──────────────────────────────────────────────

class _PolicySheet extends StatelessWidget {
  final String htmlContent;
  const _PolicySheet({required this.htmlContent});

  // Découpe le HTML en blocs (h2, p, hr) et les rend en widgets Flutter
  List<Widget> _parseBlocks(String html) {
    final blocks = <Widget>[];

    // Nettoie les attributs data-* et class inutiles
    String clean = html
        .replaceAll(RegExp(r' data-[^=]+="[^"]*"'), '')
        .replaceAll(RegExp(r' class="[^"]*"'), '')
        .replaceAll(RegExp(r' dir="[^"]*"'), '')
        .replaceAll(RegExp(r' tabindex="[^"]*"'), '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    // Extrait les blocs h2, p, hr dans l'ordre
    final tagPattern = RegExp(
      r'<(h2|p|hr)[^>]*>([\s\S]*?)<\/\1>|<hr[^>]*\/?>',
      caseSensitive: false,
    );

    for (final m in tagPattern.allMatches(clean)) {
      final tag = m.group(1)?.toLowerCase();
      final inner = _stripTags(m.group(2) ?? '').trim();

      if (tag == 'hr') {
        blocks.add(const Divider(height: 24, thickness: 1, color: Color(0xFFE0E0E0)));
      } else if (tag == 'h2' && inner.isNotEmpty) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Text(
            inner,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
              height: 1.4,
            ),
          ),
        ));
      } else if (tag == 'p' && inner.isNotEmpty) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            inner,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF424242),
              height: 1.7,
            ),
          ),
        ));
      }
    }

    return blocks;
  }

  String _stripTags(String html) => html
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .trim();

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(htmlContent);
    final height = MediaQuery.of(context).size.height * 0.9;

    return SizedBox(
      height: height,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── Poignée ───────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ── Bouton fermer ─────────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // ── Contenu scrollable ────────────────────────────────────
            Expanded(
              child: blocks.isEmpty
                  ? const Center(
                      child: Text(
                        'Contenu non disponible',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: blocks,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
