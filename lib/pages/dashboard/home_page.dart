import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/shimmer_skeleton.dart';

import '../../models/reservation_model.dart';
import '../../services/api_service.dart';
import '../../services/location_sharing_service.dart';
import '../../services/storage_service.dart';
import '../../core/utils/error_helper.dart';
import '../reservation/list_compagnie_page.dart';
import '../paiement/liste_paiements_page.dart';
import 'reservation_list.dart';
import 'notifications_page.dart';
import 'track_location_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  bool _isLoading = true;
  String _errorMessage = '';
  List<Reservation> _reservations = [];
  List<String> _accueilImages = [];
  bool _isImageLoading = true;
  String _userName = '';

  // ── Slider ──
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _sliderTimer;

  // ── Filtre date ──
  DateTime? _dateDebut;
  DateTime? _dateFin;

  // ── Filtre statut : 'all' | 'pending' | 'scanned' ──
  String _statusFilter = 'all';

  // ── Historique de suivi ──
  List<Map<String, dynamic>> _trackHistory = [];

  // ── Animations ──
  late final AnimationController _enterCtrl;
  late final Animation<double> _fadeHeader;
  late final Animation<Offset> _slideHeader;
  late final Animation<double> _fadeBanner;
  late final Animation<Offset> _slideBanner;
  late final Animation<double> _fadeContent;

  static const _amber = Color(0xFFFFC107);
  static const _blue = Color(0xFF1565C0);
  static const _green = Color(0xFF2E7D32);
  static const _orange = Color(0xFFE65100);

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeHeader = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _slideHeader = Tween<Offset>(
      begin: const Offset(0, -0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _fadeBanner = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
    );
    _slideBanner = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
    ));

    _fadeContent = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );

    _pageController = PageController();
    _enterCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserAndLoadData();
      _loadTrackHistory();
    });
  }

  @override
  void dispose() {
    _sliderTimer?.cancel();
    _pageController.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  // ── Auth / chargement ─────────────────────────────────────────────────────
  Future<void> _checkUserAndLoadData() async {
    try {
      final token = await _storageService.getToken();
      if (token == null) { _navigateToLogin(); return; }

      try {
        final check = await _apiService.verifierUtilisateurExiste(token);
        if (!check['success']) {
          final msg = check['message']?.toString() ?? '';
          final isAuth = ErrorHelper.isAuthError(msg) || check['statusCode'] == 401;
          if (isAuth) {
            // Déconnexion uniquement sur erreur d'authentification réelle (401)
            await _storageService.clearToken();
            if (mounted) _navigateToLogin();
            return;
          }
          // Erreur serveur / réseau : on continue quand même, les réservations chargeront
        }
      } catch (_) {
        // Erreur réseau lors de la vérification : on continue sans bloquer l'accès
      }

      Future.microtask(_loadAccueilImage);
      Future.microtask(_loadUserName);
      await _loadReservations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur de connexion au serveur'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _navigateToLogin() {
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _loadAccueilImage() async {
    try {
      final images = await _apiService.getAccueilImages(
        onRefreshed: (newUrls) {
          if (!mounted) return;
          setState(() => _accueilImages = newUrls);
          _sliderTimer?.cancel();
          if (newUrls.length > 1) _startSlider();
        },
      );
      if (mounted) {
        setState(() { _accueilImages = images; _isImageLoading = false; });
        if (images.length > 1) _startSlider();
      }
    } catch (_) {
      if (mounted) setState(() => _isImageLoading = false);
    }
  }

  Future<void> _loadUserName() async {
    final userData = await _storageService.getUserData();
    if (userData == null || !mounted) return;
    final prenom = userData['prenom']?.toString() ?? '';
    final nom = userData['nom']?.toString() ?? '';
    final full = '$prenom $nom'.trim();
    setState(() => _userName = full.isNotEmpty ? full : userData['pseudo']?.toString() ?? '');
  }

  String get _initials {
    final parts = _userName.trim().split(RegExp(r'\s+'));
    if (_userName.isEmpty || parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  void _startSlider() {
    _sliderTimer?.cancel();
    _sliderTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _accueilImages.isEmpty) return;
      final next = (_currentPage + 1) % _accueilImages.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadReservations({bool silent = false}) async {
    setState(() { if (!silent) _isLoading = true; _errorMessage = ''; });
    try {
      final token = await _storageService.getToken();
      if (token == null) { _navigateToLogin(); return; }
      final list = await _apiService.getReservations(token);
      if (mounted) {
        setState(() { _reservations = list; _isLoading = false; });
        _enterCtrl.forward(from: _enterCtrl.value == 1.0 ? 0.45 : _enterCtrl.value);
      }
    } catch (e) {
      final isAuth = ErrorHelper.isAuthError(e.toString());
      if (isAuth) await _storageService.clearToken();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = isAuth
              ? 'Session expirée. Veuillez vous reconnecter.'
              : 'Impossible de charger les réservations. Vérifiez votre connexion.';
          _reservations = [];
        });
        ErrorHelper.showErrorSnackBar(context, 'Erreur de chargement');
      }
    }
  }

  // ── Filtrage ──────────────────────────────────────────────────────────────
  bool _isScanned(Reservation r) {
    final s = r.status.toLowerCase();
    return s.contains('scan') || s == 'valide' || s == 'utilisé';
  }

  List<Reservation> get _filtered {
    var list = _reservations;
    if (_dateDebut != null || _dateFin != null) {
      list = list.where((r) {
        final d = DateTime(r.dateCreation.year, r.dateCreation.month, r.dateCreation.day);
        if (_dateDebut != null && d.isBefore(_dateDebut!)) return false;
        if (_dateFin != null && d.isAfter(_dateFin!)) return false;
        return true;
      }).toList();
    }
    return list;
  }

  bool get _hasDateFilter => _dateDebut != null || _dateFin != null;

  int get _scannedCount => _reservations.where(_isScanned).length;
  int get _pendingCount => _reservations.length - _scannedCount;

  String _fmt(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  void _clearDateFilter() => setState(() { _dateDebut = null; _dateFin = null; });

  // ── Bottom sheet filtre date ───────────────────────────────────────────────
  void _showFilterSheet() {
    DateTime? tmpD = _dateDebut;
    DateTime? tmpF = _dateFin;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final shortcuts = [
      {'label': "Aujourd'hui", 'debut': today, 'fin': today},
      {'label': '7 derniers jours', 'debut': today.subtract(const Duration(days: 6)), 'fin': today},
      {'label': '30 derniers jours', 'debut': today.subtract(const Duration(days: 29)), 'fin': today},
      {'label': 'Ce mois', 'debut': DateTime(now.year, now.month, 1), 'fin': DateTime(now.year, now.month + 1, 0)},
      {'label': 'Mois dernier', 'debut': DateTime(now.year, now.month - 1, 1), 'fin': DateTime(now.year, now.month, 0)},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, ss) {
        Future<void> pick(bool isD) async {
          final p = await showDatePicker(
            context: ctx,
            initialDate: (isD ? tmpD : tmpF) ?? today,
            firstDate: DateTime(2020), lastDate: DateTime(2030),
            locale: const Locale('fr', 'FR'),
          );
          if (p != null) ss(() {
            if (isD) tmpD = DateTime(p.year, p.month, p.day);
            else tmpF = DateTime(p.year, p.month, p.day);
          });
        }

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(24, 12, 24, 32 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 18),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _amber.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.tune_rounded, color: _amber, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Filtrer par date',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (tmpD != null || tmpF != null)
                GestureDetector(
                  onTap: () => ss(() { tmpD = null; tmpF = null; }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Effacer',
                        style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                  ),
                ),
            ]),
            const SizedBox(height: 18),
            const Align(alignment: Alignment.centerLeft,
                child: Text('Période rapide', style: TextStyle(fontSize: 12, color: Colors.grey))),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: shortcuts.map((s) {
              final active = tmpD == s['debut'] && tmpF == s['fin'];
              return GestureDetector(
                onTap: () => ss(() { tmpD = s['debut'] as DateTime; tmpF = s['fin'] as DateTime; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? _amber : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: active ? _amber : const Color(0xFFE0E0E0)),
                  ),
                  child: Text(s['label'] as String,
                      style: TextStyle(fontSize: 12,
                          fontWeight: active ? FontWeight.bold : FontWeight.normal,
                          color: active ? Colors.black87 : Colors.black54)),
                ),
              );
            }).toList()),
            const SizedBox(height: 18),
            const Align(alignment: Alignment.centerLeft,
                child: Text('Ou choisir une plage personnalisée',
                    style: TextStyle(fontSize: 12, color: Colors.grey))),
            const SizedBox(height: 10),
            Row(children: [
              _dateBox(tmpD, 'Début', () => pick(true)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(children: [
                  Container(width: 12, height: 1.5, color: Colors.grey[300]),
                  const SizedBox(height: 2),
                  Container(width: 12, height: 1.5, color: Colors.grey[300]),
                ]),
              ),
              _dateBox(tmpF, 'Fin', () => pick(false)),
            ]),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () {
                  setState(() { _dateDebut = tmpD; _dateFin = tmpF; });
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _amber, foregroundColor: Colors.black87, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Appliquer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        );
      }),
    );
  }

  Widget _dateBox(DateTime? date, String label, VoidCallback onTap) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: date != null ? _amber.withOpacity(0.08) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: date != null ? _amber : const Color(0xFFE0E0E0)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          const SizedBox(height: 5),
          Row(children: [
            Icon(Icons.calendar_month_rounded, size: 14, color: date != null ? _amber : Colors.grey),
            const SizedBox(width: 5),
            Text(
              date != null ? _fmt(date) : 'jj/mm/aaaa',
              style: TextStyle(
                fontSize: 12,
                fontWeight: date != null ? FontWeight.w700 : FontWeight.normal,
                color: date != null ? Colors.black87 : Colors.grey[400],
              ),
            ),
          ]),
        ]),
      ),
    ));
  }

  // ── Historique & suivi ────────────────────────────────────────────────────

  Future<void> _loadTrackHistory() async {
    final history = await LocationSharingService.getTrackHistory();
    if (mounted) setState(() => _trackHistory = history);
  }

  void _openTracking(String code) async {
    await LocationSharingService.addToTrackHistory(code);
    if (!mounted) return;
    setState(() {});
    await _loadTrackHistory();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrackLocationPage(code: code)),
    );
  }

  // ── Rejoindre un suivi de position ────────────────────────────────────────
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
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx2).viewInsets.bottom),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 20,
                    bottom: MediaQuery.of(ctx2).padding.bottom + 28,
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A237E))),
                            Text(
                              'Saisis le code reçu pour suivre en direct',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.black45),
                            ),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    // Champ code
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: errorMsg != null
                              ? Colors.red
                              : const Color(0xFFE0E0E0),
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
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          hintStyle: TextStyle(
                              color: Colors.black26,
                              fontSize: 22,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w600),
                        ),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 5,
                          color: Color(0xFF1A237E),
                        ),
                        onChanged: (_) => setInner(() { errorMsg = null; }),
                      ),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.red, size: 16),
                        const SizedBox(width: 6),
                        Text(errorMsg!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13)),
                      ]),
                    ],
                    const SizedBox(height: 20),
                    // Bouton Suivre
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isReady
                            ? () async {
                                setInner(() { isLoading = true; errorMsg = null; });
                                final exists = await LocationSharingService.codeExists(code);
                                if (!exists) {
                                  setInner(() {
                                    isLoading = false;
                                    errorMsg = 'Code introuvable. Vérifie et réessaie.';
                                  });
                                  return;
                                }
                                if (ctx2.mounted) Navigator.pop(ctx2);
                                _openTracking(code);
                              }
                            : null,
                        icon: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white)),
                              )
                            : const Icon(Icons.location_on_rounded, size: 20),
                        label: const Text('Suivre la position',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isReady ? const Color(0xFF1565C0) : Colors.grey[300],
                          foregroundColor:
                              isReady ? Colors.white : Colors.black45,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: isLoading ? null : () => Navigator.pop(ctx2),
                      child: const Text('Annuler',
                          style: TextStyle(color: Colors.black45)),
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

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          SlideTransition(
            position: _slideHeader,
            child: FadeTransition(opacity: _fadeHeader, child: _buildHeader()),
          ),
          Expanded(
            child: FadeTransition(
              opacity: _fadeContent,
              child: RefreshIndicator(
                onRefresh: () => _loadReservations(silent: true),
                color: _amber,
                backgroundColor: Colors.white,
                child: _buildScrollContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SlideTransition(
            position: _slideBanner,
            child: FadeTransition(opacity: _fadeBanner, child: _buildBanner()),
          ),
          _buildListHeader(),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                children: List.generate(4, (_) => const SkeletonReservationCard()),
              ),
            )
          else if (_errorMessage.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height * 0.38,
              ),
              child: Center(child: _buildErrorSection()),
            )
          else if (_filtered.isEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height * 0.38,
              ),
              child: Center(child: _buildEmptySection()),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: ReservationList(
                reservations: _filtered,
                isLoading: false,
                errorMessage: '',
              ),
            ),
        ],
      ),
    );
  }

  // ── Header jaune ──────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _amber,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Spacer(),
              // Notification
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                ),
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Iconsax.notification, color: Colors.black87, size: 22),
                ),
              ),
              // Filtre date
              GestureDetector(
                onTap: _showFilterSheet,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _hasDateFilter ? Colors.black87 : Colors.black.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.tune_rounded, size: 15,
                        color: _hasDateFilter ? _amber : Colors.black87),
                    const SizedBox(width: 5),
                    Text('Filtrer',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: _hasDateFilter ? _amber : Colors.black87)),
                  ]),
                ),
              ),
            ]),
            // Chip filtre actif
            if (_hasDateFilter) ...[
              const SizedBox(height: 8),
              AnimatedOpacity(
                opacity: 1.0, duration: const Duration(milliseconds: 250),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.date_range_rounded, size: 12, color: Colors.black87),
                    const SizedBox(width: 5),
                    Text(
                      _dateDebut != null && _dateFin != null
                          ? '${_fmt(_dateDebut!)} → ${_fmt(_dateFin!)}'
                          : _dateDebut != null ? 'Depuis ${_fmt(_dateDebut!)}' : 'Jusqu\'au ${_fmt(_dateFin!)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _clearDateFilter,
                      child: const Icon(Icons.close_rounded, size: 13, color: Colors.black54),
                    ),
                  ]),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Search / CTA bar
            GestureDetector(
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ListCompagniePage())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        color: _amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.search_rounded, color: Colors.black54, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Où allez-vous ?',
                          style: TextStyle(fontSize: 11, color: Colors.black45)),
                      const Text('Rechercher un voyage',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                    ]),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.black38, size: 18),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Bannière promo ────────────────────────────────────────────────────────
  Widget _buildBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 158, width: double.infinity,
          child: _isImageLoading
              ? _buildBannerSlide(null)
              : _accueilImages.isEmpty
                  ? _buildBannerSlide(null)
                  : Stack(children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: _accueilImages.length,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemBuilder: (_, i) => _buildBannerSlide(_accueilImages[i]),
                      ),
                      // Indicateur vertical droite
                      if (_accueilImages.length > 1)
                        Positioned(
                          right: 14, top: 0, bottom: 0,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(_accueilImages.length, (i) {
                                final active = i == _currentPage;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(vertical: 2.5),
                                  width: 6,
                                  height: active ? 18 : 6,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.45),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                    ]),
        ),
      ),
    );
  }

  Widget _buildBannerSlide(String? imageUrl) {
    return Stack(fit: StackFit.expand, children: [
      // Background : image ou dégradé amber
      if (imageUrl != null)
        CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => _bannerGradientBg(),
          errorWidget: (_, __, ___) => _bannerGradientBg(),
        )
      else
        _bannerGradientBg(),
      // Overlay dégradé pour lisibilité du texte
      if (imageUrl != null)
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight, end: Alignment.centerLeft,
              colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
            ),
          ),
        ),
      // Cercles décoratifs
      Positioned(
        right: -24, bottom: -32,
        child: Container(
          width: 110, height: 110,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
        ),
      ),
      Positioned(
        right: 30, bottom: -52,
        child: Container(
          width: 150, height: 150,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07), shape: BoxShape.circle),
        ),
      ),
      // Contenu texte : uniquement sur le slide dégradé (sans image)
      if (imageUrl == null)
        Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 60, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Promo',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Voyagez en toute\nsérénité',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        color: Colors.black87, height: 1.2),
                  ),
                  const SizedBox(height: 3),
                  const Text('Réservez en 30 secondes',
                      style: TextStyle(fontSize: 11, color: Colors.black54)),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const ListCompagniePage())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text("C'est parti",
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.black87),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _bannerGradientBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFC107), Color(0xFFFFAA00)],
        ),
      ),
    );
  }

  // ── Quick actions ─────────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        _quickActionItem(
          Iconsax.bus, 'Voyages',
          const Color(0xFFFFF8E1), _amber,
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const ListCompagniePage())),
        ),
        _quickActionItem(
          Iconsax.map_1, 'Suivi live',
          const Color(0xFFE3F2FD), const Color(0xFF1565C0),
          onTap: _showJoinTrackingDialog,
        ),
        _quickActionItem(
          Iconsax.wallet_1, 'Paiements',
          const Color(0xFFE8F5E9), const Color(0xFF2E7D32),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ListePaiementsPage())),
        ),
      ]),
    );
  }

  Widget _quickActionItem(
    IconData icon,
    String label,
    Color bg,
    Color iconColor, {
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87)),
        ]),
      ),
    );
  }

  // ── Onglets statut ────────────────────────────────────────────────────────
  Widget _buildStatusTabs() {
    final tabs = [
      {'key': 'all',     'label': 'Tous',       'count': _reservations.length, 'icon': Iconsax.ticket,  'color': _blue},
      {'key': 'pending', 'label': 'En attente', 'count': _pendingCount,        'icon': Iconsax.clock,   'color': _orange},
      {'key': 'scanned', 'label': 'Scanné',     'count': _scannedCount,        'icon': Iconsax.scan,    'color': _green},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: tabs.asMap().entries.map((e) {
          final tab = e.value;
          final key = tab['key'] as String;
          final isActive = _statusFilter == key;
          final color = tab['color'] as Color;
          final isLast = e.key == tabs.length - 1;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : 8),
              child: GestureDetector(
                onTap: () => setState(() => _statusFilter = key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive ? color : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isActive ? color : Colors.grey.shade200, width: 1.5),
                    boxShadow: isActive
                        ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                        : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(tab['icon'] as IconData,
                        size: 18, color: isActive ? Colors.white : color),
                    const SizedBox(height: 5),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Text(
                        '${tab['count']}',
                        key: ValueKey('${key}_${tab['count']}'),
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold,
                          color: isActive ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(tab['label'] as String,
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w500,
                          color: isActive ? Colors.white.withOpacity(0.9) : Colors.grey[600],
                        )),
                  ]),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── En-tête liste ─────────────────────────────────────────────────────────
  Widget _buildListHeader() {
    final count = _filtered.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Mes réservations',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Container(
                key: ValueKey(count),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: _amber, borderRadius: BorderRadius.circular(10)),
                child: Text('$count',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
            ),
          ]),
          if (_reservations.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFE65100)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Présentez-vous à la gare 30 min avant le départ.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFE65100)),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorSection() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration:
              BoxDecoration(color: Colors.red.withOpacity(0.07), shape: BoxShape.circle),
          child: const Icon(Icons.wifi_off_rounded, size: 46, color: Colors.red),
        ),
        const SizedBox(height: 16),
        const Text('Connexion impossible',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(_errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.5)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _loadReservations,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Réessayer'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _blue,
            side: const BorderSide(color: _blue),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
    );
  }

  Widget _buildEmptySection() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration:
              BoxDecoration(color: _amber.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Iconsax.calendar_remove, size: 46, color: _amber),
        ),
        const SizedBox(height: 16),
        const Text('Aucune réservation',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          _hasDateFilter
              ? 'Aucune réservation sur cette période.'
              : 'Vous n\'avez pas encore de réservation.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.5),
        ),
        const SizedBox(height: 16),
        if (_hasDateFilter)
          OutlinedButton.icon(
            onPressed: () => setState(() => _clearDateFilter()),
            icon: const Icon(Icons.close_rounded, size: 14),
            label: const Text('Effacer les filtres'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _amber,
              side: const BorderSide(color: _amber),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
      ]),
    );
  }
}

