import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/shimmer_skeleton.dart';

import '../../models/reservation_model.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../core/utils/error_helper.dart';
import '../reservation/list_compagnie_page.dart';
import 'reservation_list.dart';
import 'notifications_page.dart';

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

  // ── Slider ──
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _sliderTimer;

  // ── Filtre date ──
  DateTime? _dateDebut;
  DateTime? _dateFin;

  // ── Filtre statut : 'all' | 'pending' | 'scanned' ──

  // ── Historique de suivi ──

  // ── Animations ──
  late final AnimationController _enterCtrl;
  late final Animation<double> _fadeHeader;
  late final Animation<Offset> _slideHeader;
  late final Animation<double> _fadeBanner;
  late final Animation<Offset> _slideBanner;
  late final Animation<double> _fadeContent;

  static const _amber = Color(0xFFFFC107);
  static const _blue = Color(0xFF1565C0);

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
          if (p != null) {
            ss(() {
            if (isD) {
              tmpD = DateTime(p.year, p.month, p.day);
            } else {
              tmpF = DateTime(p.year, p.month, p.day);
            }
          });
          }
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
                decoration: BoxDecoration(color: _amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
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
                        color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
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
          color: date != null ? _amber.withValues(alpha: 0.08) : const Color(0xFFF8F8F8),
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
                    color: _hasDateFilter ? Colors.black87 : Colors.black.withValues(alpha: 0.08),
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
                      color: Colors.black.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
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
            _AnimatedSearchBar(
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ListCompagniePage())),
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
                                        : Colors.white.withValues(alpha: 0.45),
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
      if (imageUrl != null) ...[
        // Fond visible dans les bandes vides quand l'image (BoxFit.contain,
        // jamais rognée) ne remplit pas tout le cadre.
        _bannerGradientBg(),
        CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          placeholder: (_, __) => _bannerGradientBg(),
          errorWidget: (_, __, ___) => _bannerGradientBg(),
        ),
      ] else
        _bannerGradientBg(),
      // Overlay dégradé pour lisibilité du texte
      if (imageUrl != null)
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight, end: Alignment.centerLeft,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
            ),
          ),
        ),
      // Cercles décoratifs
      Positioned(
        right: -24, bottom: -32,
        child: Container(
          width: 110, height: 110,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
        ),
      ),
      Positioned(
        right: 30, bottom: -52,
        child: Container(
          width: 150, height: 150,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07), shape: BoxShape.circle),
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
                  color: Colors.black.withValues(alpha: 0.14),
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
              BoxDecoration(color: Colors.red.withValues(alpha: 0.07), shape: BoxShape.circle),
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
              BoxDecoration(color: _amber.withValues(alpha: 0.1), shape: BoxShape.circle),
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


// ── Barre de recherche animée ───────────────────────────────────────────────
class _AnimatedSearchBar extends StatefulWidget {
  final VoidCallback onTap;

  const _AnimatedSearchBar({required this.onTap});

  @override
  State<_AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<_AnimatedSearchBar>
    with SingleTickerProviderStateMixin {
  static const _amber = Color(0xFFFFC107);
  static const _hints = [
    'Où allez-vous ?',
    'Comparez les compagnies',
    'Réservez en 2 minutes',
  ];

  late final AnimationController _loopCtrl;
  Timer? _hintTimer;
  int _hintIndex = 0;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    // Va-et-vient permanent de la flèche
    _loopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _hintIndex = (_hintIndex + 1) % _hints.length);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _loopCtrl.dispose();
    super.dispose();
  }

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      button: true,
      label: 'Rechercher un voyage',
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _pressed ? 0.04 : 0.10),
                blurRadius: _pressed ? 6 : 14,
                offset: Offset(0, _pressed ? 1 : 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: (_) => _setPressed(true),
              onTapUp: (_) => _setPressed(false),
              onTapCancel: () => _setPressed(false),
              splashColor: _amber.withValues(alpha: 0.22),
              highlightColor: _amber.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(children: [
                  // Pastille loupe
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_amber, _amber.withValues(alpha: 0.75)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.search_rounded, color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Accroche qui défile
                        SizedBox(
                          height: 15,
                          child: AnimatedSwitcher(
                            duration: Duration(milliseconds: reduceMotion ? 0 : 400),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.6),
                                  end: Offset.zero,
                                ).animate(anim),
                                child: child,
                              ),
                            ),
                            child: Text(
                              _hints[_hintIndex],
                              key: ValueKey(_hintIndex),
                              style: const TextStyle(fontSize: 11, color: Colors.black45),
                            ),
                          ),
                        ),
                        const SizedBox(height: 1),
                        const Text('Rechercher un voyage',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Flèche dans sa pastille, avec petit va-et-vient
                  AnimatedBuilder(
                    animation: _loopCtrl,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(reduceMotion ? 0 : 3 * _loopCtrl.value, 0),
                      child: child,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward_rounded,
                          color: Colors.black87, size: 16),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
