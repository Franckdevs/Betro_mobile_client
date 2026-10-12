import 'package:flutter/material.dart';
import '../../core/constant/colors.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../services/location_sharing_service.dart';
import 'edit_profile_page.dart';
import 'track_location_page.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/login_page.dart';

class ParametrePage extends StatefulWidget {
  const ParametrePage({super.key});

  @override
  State<ParametrePage> createState() => _ParametrePageState();
}

class _ParametrePageState extends State<ParametrePage> {
  final StorageService _storageService = StorageService();
  final LocationSharingService _locationSharing = LocationSharingService();
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _trackHistory = [];

  static const _amber = AppColors.primaire;
  static const _darkBlue = AppColors.secondaire;
  static const _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTrackHistory();
  }

  @override
  void dispose() {
    _locationSharing.dispose();
    super.dispose();
  }

  Future<void> _loadTrackHistory() async {
    final history = await LocationSharingService.getTrackHistory();
    if (mounted) setState(() => _trackHistory = history);
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _storageService.getUserData();
      if (mounted) {
        setState(() {
          if (userData != null) {
            if (userData.containsKey('data') && userData['data'] is Map) {
              try {
                _userData = Map<String, dynamic>.from(
                  (userData['data'] as Map).cast<String, dynamic>(),
                );
              } catch (_) {
                _userData = userData;
              }
            } else {
              try {
              _userData = Map<String, dynamic>.from(
                userData.cast<String, dynamic>(),
              );
            } catch (_) {
              _userData = userData;
            }
            }

          }
        });
      }
    } catch (_) {
      // Rien à afficher : l'écran reste sur les données déjà en cache.
    }
  }

  String _getInitials(String? nom, String? prenom) {
    final n = nom?.isNotEmpty == true ? nom![0].toUpperCase() : '';
    final p = prenom?.isNotEmpty == true ? prenom![0].toUpperCase() : '';
    return '$p$n'.isEmpty ? '?' : '$p$n';
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _showContactDialog() async {
    final apiService = ApiService();
    final token = await _storageService.getToken() ?? '';
    if (!mounted) return;

    // La requête est lancée une seule fois, hors de tout `build`.
    final futureContacts = apiService.recupereNumeroTelephone(token: token);

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      builder: (_) {
        return FutureBuilder<Map<String, dynamic>>(
          future: futureContacts,
          builder: (ctx, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            final data = snapshot.data;
            final String? error = snapshot.hasError || (data != null && data['success'] != true)
                ? 'Impossible de charger les numéros.'
                : null;
            final whatsapp = (data?['lien_whatsapp'] as String?) ?? '';
            final telephone = (data?['lien_telephone'] as String?) ?? '';

            return SizedBox(
              width: double.infinity,
              child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.whatsapp.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.headset_mic_rounded,
                        color: AppColors.whatsapp, size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Service Client',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                 
                  const SizedBox(height: 24),
                  if (loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.whatsapp),
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  else if (error != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(error,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                            textAlign: TextAlign.center),
                      ),
                    )
                  else if (whatsapp.isEmpty && telephone.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Contact non assigné pour le moment',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else ...[
                    // Bouton WhatsApp
                    if (whatsapp.isNotEmpty)
                      InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          final cleaned = whatsapp.replaceAll(RegExp(r'[^\d+]'), '');
                          launchUrl(Uri.parse('https://wa.me/$cleaned'));
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.whatsapp,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat_rounded,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                whatsapp,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (whatsapp.isNotEmpty && telephone.isNotEmpty)
                      const SizedBox(height: 12),
                    // Bouton Téléphone
                    if (telephone.isNotEmpty)
                      InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          final cleaned = telephone.replaceAll(RegExp(r'[^\d+]'), '');
                          _makePhoneCall(cleaned);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.appel,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.phone_rounded,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                telephone,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ));
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Déconnexion',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
          style: TextStyle(color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Se déconnecter',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_amber),
        ),
      ),
    );

    try {
      await _storageService.clearAllUserData();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true)
          .popUntil((route) => route.isFirst);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la déconnexion: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
              slivers: [
                // ── Header ────────────────────────────────────────
                SliverToBoxAdapter(child: _buildHeader()),
                // ── Content ───────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Section label
                      _sectionLabel('Paramètres'),
                      const SizedBox(height: 10),
                      // Menu card
                      _buildMenuCard(),
                      const SizedBox(height: 20),
                      // Section Support
                      _sectionLabel('Support'),
                      const SizedBox(height: 10),
                      _buildSupportCard(),
                      const SizedBox(height: 20),
                      // Logout button
                      _buildLogoutButton(),
                      const SizedBox(height: 32),
                      // App info
                      _buildAppInfo(),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final nom = _userData?['nom'] ?? '';
    final prenom = _userData?['prenom'] ?? '';
    final email = _userData?['email'] ?? '';
    final photoUrl = _userData?['photo_url']?.toString();
    final fullName = '$prenom $nom'.trim();

    return Container(
      decoration: const BoxDecoration(
        color: _amber,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            children: [
              // Title row
              const Row(
                children: [
                  Text(
                    'Mon Profil',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Avatar + name
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: (photoUrl != null && photoUrl.isNotEmpty && !photoUrl.contains('default-user'))
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              width: 72,
                              height: 72,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  _getInitials(nom, prenom),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: _amber,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                _getInitials(nom, prenom),
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: _amber,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Name + email
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName.isEmpty ? 'Utilisateur' : fullName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87.withValues(alpha: 0.6),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Betro',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }



  // ── Section label ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ── Menu card ─────────────────────────────────────────────────────────────
  Widget _buildMenuCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _menuTile(
            icon: Icons.edit_rounded,
            iconColor: _amber,
            title: 'Modifier mon profil',
            subtitle: 'Nom, email, téléphone, mot de passe',
            isFirst: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const EditProfilePage()),
              ).then((_) => _loadUserData());
            },
          ),
          const Divider(height: 1, indent: 60),
          _menuTile(
            icon: Icons.headset_mic_rounded,
            iconColor: Colors.green,
            title: 'Service client',
            subtitle: 'Nous contacter par téléphone',
            isLast: true,
            onTap: _showContactDialog,
          ),
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  // ── Support card ──────────────────────────────────────────────────────────
  Widget _buildSupportCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _menuTile(
            icon: Icons.bug_report_rounded,
            iconColor: _amber,
            title: 'Signaler un problème',
            subtitle: 'Décrivez un bug ou un dysfonctionnement',
            isFirst: true,
            onTap: _showReportProblemSheet,
          ),
          const Divider(height: 1, indent: 60),
          _menuTile(
            icon: Icons.help_outline_rounded,
            iconColor: Colors.blue,
            title: 'FAQ',
            subtitle: 'Questions fréquemment posées',
            isLast: true,
            onTap: _showFaqSheet,
          ),
        ],
      ),
    );
  }

  // ── Partager ma position ──────────────────────────────────────────────────
  Future<void> _showShareLocationSheet() async {
    String? code;
    bool isStarting = true;
    String? error;
    List<Map<String, dynamic>> shareHistory = [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            if (isStarting && code == null && error == null) {
              Future.microtask(() async {
                final history = await LocationSharingService.getShareHistory();
                if (_locationSharing.isSharing) {
                  setSheet(() { isStarting = false; code = _locationSharing.sessionCode; shareHistory = history; });
                  return;
                }
                final saved = await LocationSharingService.getSavedShareCode();
                if (saved != null) {
                  try {
                    final result = await _locationSharing.resumeSharing(saved);
                    setSheet(() { isStarting = false; code = result; shareHistory = history; });
                  } catch (e) {
                    await LocationSharingService.clearSavedShareCode();
                    try {
                      final result = await _locationSharing.startSharing();
                      final h2 = await LocationSharingService.getShareHistory();
                      setSheet(() { isStarting = false; code = result; shareHistory = h2; });
                    } catch (e2) {
                      setSheet(() { isStarting = false; error = e2.toString().replaceFirst('Exception: ', ''); shareHistory = history; });
                    }
                  }
                  return;
                }
                try {
                  final result = await _locationSharing.startSharing();
                  final h2 = await LocationSharingService.getShareHistory();
                  setSheet(() { isStarting = false; code = result; shareHistory = h2; });
                } catch (e) {
                  setSheet(() { isStarting = false; error = e.toString().replaceFirst('Exception: ', ''); shareHistory = history; });
                }
              });
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(ctx).padding.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Handle
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                  if (isStarting) ...[
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(color: _amber),
                    const SizedBox(height: 16),
                    const Text('Démarrage du partage…',
                        style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 20),
                  ] else if (error != null) ...[
                    const Icon(Icons.location_off_rounded, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(error!,
                        style: const TextStyle(color: Colors.black54),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fermer'),
                    ),
                  ] else ...[
                    // Titre
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EAF6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.share_location_rounded,
                            color: _darkBlue, size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Position partagée',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _darkBlue)),
                          Text('Mise à jour toutes les ~10 m',
                              style: TextStyle(fontSize: 12, color: Colors.black45)),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const SizedBox(
                            width: 7, height: 7,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text('EN DIRECT',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // Code de suivi
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A237E), Color(0xFF283593)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1A237E).withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(children: [
                        const Text('CODE DE SUIVI',
                            style: TextStyle(
                                fontSize: 11, color: Colors.white60, letterSpacing: 2)),
                        const SizedBox(height: 10),
                        Text(
                          code!,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 7,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: code!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Code copié !'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy_rounded, size: 14, color: Colors.white70),
                                SizedBox(width: 6),
                                Text('Copier le code',
                                    style: TextStyle(fontSize: 12, color: Colors.white70)),
                              ],
                            ),
                          ),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 16),

                    // Bouton Partager via…
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Share.share(
                            '📍 Je partage ma position en direct !\n\n'
                            'Code de suivi : $code\n\n'
                            'Ouvre l\'application Betro > "Rejoindre un suivi" '
                            'et saisis ce code pour me suivre en temps réel.',
                          );
                        },
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: const Text('Partager via…',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _amber,
                          foregroundColor: Colors.black87,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Bouton Désactiver le partage
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: ctx,
                            builder: (_) => AlertDialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: const Row(children: [
                                Icon(Icons.location_off_rounded, color: Colors.red, size: 22),
                                SizedBox(width: 8),
                                Text('Désactiver le partage',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ]),
                              content: const Text(
                                'Votre position ne sera plus visible par les autres utilisateurs.',
                                style: TextStyle(color: Colors.black54),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Annuler',
                                      style: TextStyle(color: Colors.black45)),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text('Désactiver'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _locationSharing.stopSharing();
                            if (ctx.mounted) Navigator.pop(ctx);
                          }
                        },
                        icon: const Icon(Icons.location_off_rounded, size: 18),
                        label: const Text('Désactiver le partage',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                    // Historique des partages
                    if (shareHistory.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Row(children: [
                        const Icon(Icons.history_rounded, size: 16, color: Colors.black45),
                        const SizedBox(width: 6),
                        const Text('Historique de partage',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () async {
                            for (final e in shareHistory) {
                              await LocationSharingService
                                  .removeFromShareHistory(e['code'] as String);
                            }
                            setSheet(() => shareHistory = []);
                          },
                          child: const Text('Tout effacer',
                              style: TextStyle(fontSize: 12, color: Colors.black38)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      ...shareHistory.map((entry) {
                        final entryCode = entry['code'] as String;
                        final ts = DateTime.fromMillisecondsSinceEpoch(entry['ts'] as int);
                        final isActive = entryCode == code;
                        final label = isActive
                            ? 'En cours'
                            : DateFormat('dd/MM/yyyy à HH:mm').format(ts);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFF5F6FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive
                                  ? Colors.green.shade200
                                  : const Color(0xFFE8E8E8),
                            ),
                          ),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.green.withValues(alpha: 0.12)
                                    : Colors.deepOrange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isActive
                                    ? Icons.location_on_rounded
                                    : Icons.share_location_rounded,
                                size: 16,
                                color: isActive ? Colors.green : Colors.deepOrange,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entryCode,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      letterSpacing: 2.5,
                                      color: isActive ? Colors.green.shade700 : _darkBlue,
                                    ),
                                  ),
                                  Text(label,
                                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                ],
                              ),
                            ),
                            _historyActionBtn(
                              icon: Icons.copy_rounded,
                              color: Colors.blue.shade50,
                              iconColor: Colors.blue,
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: entryCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Code copié !'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                            _historyActionBtn(
                              icon: Icons.delete_outline_rounded,
                              color: Colors.red.shade50,
                              iconColor: Colors.red,
                              onTap: () async {
                                await LocationSharingService
                                    .removeFromShareHistory(entryCode);
                                final updated =
                                    await LocationSharingService.getShareHistory();
                                setSheet(() => shareHistory = updated);
                              },
                            ),
                          ]),
                        );
                      }),
                    ],
                  ],
                ]),
              ),
            );
          },
        );
      },
    );
  }

  // ── Rejoindre un suivi ───────────────────────────────────────────────────
  void _openTracking(String code) async {
    await LocationSharingService.addToTrackHistory(code);
    if (!mounted) return;
    setState(() {});
    await _loadTrackHistory();
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => TrackLocationPage(code: code)));
  }

  void _showJoinTrackingDialog() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          bool isLoading = false;
          String? errorMsg;

          return StatefulBuilder(
            builder: (ctx2, setInner) {
              final code = ctrl.text.trim().toUpperCase();
              final isReady = code.length == 8 && !isLoading;

              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: EdgeInsets.only(
                    left: 24, right: 24, top: 20,
                    bottom: MediaQuery.of(ctx2).padding.bottom + 28,
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.location_searching_rounded,
                            color: Color(0xFFFFC107), size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Rejoindre un suivi',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                            Text('Saisis le code reçu pour suivre en direct',
                                style: TextStyle(fontSize: 12, color: Colors.black45)),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: errorMsg != null ? Colors.red : const Color(0xFFE0E0E0),
                        ),
                      ),
                      child: TextField(
                        controller: ctrl,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 8,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          hintText: 'EX : ABCD1234',
                          counterText: '',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          hintStyle: TextStyle(color: Colors.black26, fontSize: 22, letterSpacing: 4, fontWeight: FontWeight.w600),
                        ),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 5, color: Color(0xFF1A237E)),
                        onChanged: (_) => setInner(() { errorMsg = null; }),
                      ),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                        const SizedBox(width: 6),
                        Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ]),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isReady
                            ? () async {
                                setInner(() { isLoading = true; errorMsg = null; });
                                final exists = await LocationSharingService.codeExists(code);
                                if (!exists) {
                                  setInner(() { isLoading = false; errorMsg = 'Code introuvable. Vérifie et réessaie.'; });
                                  return;
                                }
                                if (ctx2.mounted) Navigator.pop(ctx2);
                                _openTracking(code);
                              }
                            : null,
                        icon: isLoading
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                            : const Icon(Icons.location_on_rounded, size: 20),
                        label: const Text('Suivre la position',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isReady ? const Color(0xFF1565C0) : Colors.grey[300],
                          foregroundColor: isReady ? Colors.white : Colors.black45,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: isLoading ? null : () => Navigator.pop(ctx2),
                      child: const Text('Annuler', style: TextStyle(color: Colors.black45)),
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Historique de suivi ───────────────────────────────────────────────────
  void _showTrackHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: MediaQuery.of(ctx).padding.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Header
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _darkBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.history_rounded,
                        color: _darkBlue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Historique de suivi',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A237E))),
                        Text('Codes utilisés récemment',
                            style: TextStyle(
                                fontSize: 12, color: Colors.black45)),
                      ],
                    ),
                  ),
                  if (_trackHistory.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (_) => AlertDialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            title: const Text('Tout effacer ?',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            content: const Text(
                                'Tout l\'historique sera supprimé.',
                                style: TextStyle(color: Colors.black54)),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, false),
                                child: const Text('Annuler'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white),
                                child: const Text('Effacer'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          for (final h in List.from(_trackHistory)) {
                            await LocationSharingService
                                .removeFromTrackHistory(h['code']);
                          }
                          await _loadTrackHistory();
                          ss(() {});
                        }
                      },
                      child: const Text('Tout effacer',
                          style: TextStyle(
                              color: Colors.redAccent, fontSize: 12)),
                    ),
                ]),
                const SizedBox(height: 16),
                // Liste ou vide
                _trackHistory.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(children: [
                          Icon(Icons.history_toggle_off_rounded,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          const Text('Aucun suivi effectué',
                              style: TextStyle(
                                  color: Colors.black38, fontSize: 14)),
                        ]),
                      )
                    : Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _trackHistory.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final item = _trackHistory[i];
                            final code = item['code'] as String;
                            final dt =
                                DateTime.fromMillisecondsSinceEpoch(
                                    item['ts'] as int);
                            final label =
                                DateFormat('dd/MM/yyyy à HH:mm')
                                    .format(dt);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F6FA),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: const Color(0xFFE8E8E8)),
                              ),
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                      Icons.location_on_rounded,
                                      size: 18,
                                      color: _amber),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(code,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              letterSpacing: 2.5,
                                              color: _darkBlue)),
                                      const SizedBox(height: 2),
                                      Text(label,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500])),
                                    ],
                                  ),
                                ),
                                // Copier
                                _historyActionBtn(
                                  icon: Icons.copy_rounded,
                                  color: Colors.blue.shade50,
                                  iconColor: Colors.blue,
                                  onTap: () {
                                    Clipboard.setData(
                                        ClipboardData(text: code));
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                      content: Text('Code copié !'),
                                      duration: Duration(seconds: 2),
                                    ));
                                  },
                                ),
                                const SizedBox(width: 6),
                                // Modifier
                                _historyActionBtn(
                                  icon: Icons.edit_rounded,
                                  color: _amber.withValues(alpha: 0.12),
                                  iconColor: _amber,
                                  onTap: () async {
                                    final newCode = await _showEditCodeDialog(ctx, code);
                                    if (newCode != null &&
                                        newCode.isNotEmpty &&
                                        newCode != code) {
                                      await LocationSharingService
                                          .removeFromTrackHistory(code);
                                      await LocationSharingService
                                          .addToTrackHistory(newCode);
                                      await _loadTrackHistory();
                                      ss(() {});
                                    }
                                  },
                                ),
                                const SizedBox(width: 6),
                                // Supprimer
                                _historyActionBtn(
                                  icon: Icons.delete_outline_rounded,
                                  color: Colors.red.shade50,
                                  iconColor: Colors.red,
                                  onTap: () async {
                                    await LocationSharingService
                                        .removeFromTrackHistory(code);
                                    await _loadTrackHistory();
                                    ss(() {});
                                  },
                                ),
                                const SizedBox(width: 6),
                                // Utiliser / Rejoindre
                                _historyActionBtn(
                                  icon: Icons.play_arrow_rounded,
                                  color: _darkBlue.withValues(alpha: 0.1),
                                  iconColor: _darkBlue,
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _openTracking(code);
                                  },
                                ),
                              ]),
                            );
                          },
                        ),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<String?> _showEditCodeDialog(BuildContext ctx, String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Modifier le code',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          maxLength: 8,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            counterText: '',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              color: _darkBlue),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.black45)),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, ctrl.text.trim().toUpperCase()),
            style: ElevatedButton.styleFrom(
                backgroundColor: _darkBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Widget _historyActionBtn({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: iconColor),
      ),
    );
  }

  void _showReportProblemSheet() {
    final controller = TextEditingController();
    final apiService = ApiService();
    bool sending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _amber.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bug_report_rounded,
                          color: _amber, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Signaler un problème',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text('Votre retour nous aide à améliorer l\'app',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      hintText: 'Décrivez le problème rencontré…',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8F8F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _amber, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: sending
                          ? null
                          : () async {
                              if (controller.text.trim().isEmpty) return;
                              // Capturé avant l'await : le contexte peut être
                              // démonté pendant l'appel réseau.
                              final messenger = ScaffoldMessenger.of(context);
                              ss(() => sending = true);
                              final token = await _storageService.getToken();
                              if (token == null) {
                                ss(() => sending = false);
                                return;
                              }
                              final result = await apiService.envoyerSignalement(
                                token: token,
                                contenu: controller.text.trim(),
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(result['success'] == true
                                      ? 'Merci ! Votre signalement a été envoyé.'
                                      : 'Erreur : ${result['message'] ?? 'Réessayez plus tard.'}'),
                                  backgroundColor: result['success'] == true
                                      ? _amber
                                      : Colors.red,
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _amber,
                        foregroundColor: _darkBlue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: sending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(_darkBlue),
                              ),
                            )
                          : const Text('Envoyer le signalement',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Supprime les balises HTML d'une chaîne
  String _stripHtml(String html) => html
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .trim();

  void _showFaqSheet() {
    final apiService = ApiService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        int? openIndex;
        List<Map<String, dynamic>> faqs = [];
        bool loading = true;
        String? error;

        return StatefulBuilder(
          builder: (ctx, ss) {
            // Charger au premier build
            if (loading && faqs.isEmpty && error == null) {
              apiService.getFaqs().then((data) {
                ss(() { faqs = data; loading = false; });
              }).catchError((_) {
                ss(() { loading = false; error = 'Impossible de charger la FAQ.'; });
              });
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.92,
              minChildSize: 0.4,
              builder: (_, scrollCtrl) => Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    // ── Header ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Column(children: [
                        Center(
                          child: Container(
                            width: 40, height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _amber.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.help_outline_rounded,
                                color: _amber, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('FAQ',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87)),
                              SizedBox(height: 2),
                              Text('Questions fréquemment posées',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 16),
                      ]),
                    ),
                    // ── Contenu ──
                    Expanded(
                      child: loading
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(_amber),
                              ),
                            )
                          : error != null
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.wifi_off_rounded,
                                            size: 40,
                                            color: Colors.grey[400]),
                                        const SizedBox(height: 12),
                                        Text(error!,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: Colors.grey[600])),
                                        const SizedBox(height: 16),
                                        OutlinedButton.icon(
                                          onPressed: () => ss(() {
                                            loading = true;
                                            error = null;
                                          }),
                                          icon: const Icon(Icons.refresh_rounded,
                                              size: 16),
                                          label: const Text('Réessayer'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: _amber,
                                            side: const BorderSide(color: _amber),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : faqs.isEmpty
                                  ? Center(
                                      child: Text('Aucune question disponible.',
                                          style: TextStyle(
                                              color: Colors.grey[500])),
                                    )
                                  : ListView.separated(
                                      controller: scrollCtrl,
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 0, 16, 32),
                                      itemCount: faqs.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 8),
                                      itemBuilder: (_, i) {
                                        final isOpen = openIndex == i;
                                        final titre =
                                            faqs[i]['titre'] as String? ?? '';
                                        final desc = _stripHtml(
                                            faqs[i]['description'] as String? ??
                                                '');
                                        return AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 200),
                                          decoration: BoxDecoration(
                                            color: isOpen
                                                ? _amber.withValues(alpha: 0.05)
                                                : const Color(0xFFF8F8F8),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color: isOpen
                                                  ? _amber.withValues(alpha: 0.4)
                                                  : Colors.transparent,
                                            ),
                                          ),
                                          child: InkWell(
                                            onTap: () => ss(() =>
                                                openIndex =
                                                    isOpen ? null : i),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            child: Padding(
                                              padding: const EdgeInsets.all(14),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(children: [
                                                    Container(
                                                      width: 24,
                                                      height: 24,
                                                      decoration: BoxDecoration(
                                                        color: _amber
                                                            .withValues(alpha: 0.18),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          '${i + 1}',
                                                          style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: _amber),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        titre,
                                                        style: const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                Colors.black87),
                                                      ),
                                                    ),
                                                    Icon(
                                                      isOpen
                                                          ? Icons
                                                              .keyboard_arrow_up_rounded
                                                          : Icons
                                                              .keyboard_arrow_down_rounded,
                                                      color: _amber,
                                                      size: 20,
                                                    ),
                                                  ]),
                                                  if (isOpen && desc.isNotEmpty)
                                                    ...[
                                                    const SizedBox(height: 10),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 34),
                                                      child: Text(
                                                        desc,
                                                        style: TextStyle(
                                                            fontSize: 13,
                                                            color: Colors
                                                                .grey[700],
                                                            height: 1.5),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── App info (logo + version) ──────────────────────────────────────────────
  Widget _buildAppInfo() {
    return Column(
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/logo.png',
            width: 56,
            height: 56,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Version $_appVersion',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Logout button ─────────────────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return InkWell(
      onTap: _logout,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded,
                  color: Colors.red, size: 18),
            ),
            const SizedBox(width: 12),
            const Text(
              'Se déconnecter',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
