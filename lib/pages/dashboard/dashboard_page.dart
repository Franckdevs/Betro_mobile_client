import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'home_page.dart';
import 'parametre_page.dart';
import '../paiement/liste_paiements_page.dart';
import '../auth/login_page.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import '../../core/widgets/shimmer_skeleton.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final StorageService _storageService = StorageService();
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  late final AnimationController _tabCtrl;

  static const _amber = Color(0xFFFFC107);

  // Pages accessibles depuis le Dashboard
  final List<Widget> _pages = [
    const HomePage(),
    const ListePaiementsPage(),
    const ParametrePage(),
  ];

  void _onItemTapped(int index) {
    if (index < 0 || index >= _pages.length) return;
    if (index != _selectedIndex) {
      _tabCtrl.forward(from: 0);
      setState(() => _selectedIndex = index);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _checkAuth();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    try {
      final token = await _storageService.getToken();
      if (token == null) {
        if (mounted) _navigateToLogin();
        return;
      }

      Map<String, dynamic> result;
      try {
        result = await _apiService.verifierStatutCompte(token);
      } catch (_) {
        // Erreur réseau : on laisse l'utilisateur sur le dashboard
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (result['est_bloque'] == true) {
        await _storageService.clearAllUserData();
        if (mounted) _navigateToLogin(blockedMessage: result['message']?.toString());
        return;
      }

      // Sauvegarder les infos de l'utilisateur connecté
      try {
        final utilisateur = result['utilisateur'];
        if (utilisateur is Map) {
          final userData = Map<String, dynamic>.from(utilisateur);
          await _storageService.saveUserData(userData);
          final serverToken = userData['token'] as String?;
          if (serverToken != null && serverToken != token) {
            await _storageService.saveToken(serverToken);
          }
        }
      } catch (e) {
        debugPrint('[Dashboard] sauvegarde utilisateur erreur: $e');
        // Non bloquant : on continue quand même
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('[Dashboard] _checkAuth erreur: $e');
      // Erreur inattendue : ne pas déconnecter, juste afficher le dashboard
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildNavBar() {
    const items = [
      (icon: Iconsax.home_1, activeIcon: Iconsax.home, label: 'Accueil'),
      (icon: Iconsax.wallet_1, activeIcon: Iconsax.wallet, label: 'Paiements'),
      (icon: Iconsax.setting_2, activeIcon: Iconsax.setting, label: 'Paramètres'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isSelected = _selectedIndex == i;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onItemTapped(i),
                  child: AnimatedBuilder(
                    animation: _tabCtrl,
                    builder: (_, __) {
                      final scale = isSelected
                          ? 1.0 + 0.12 * (1 - _tabCtrl.value)
                          : 1.0;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Indicateur pill animé
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            height: 3,
                            width: isSelected ? 28 : 0,
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: _amber,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Transform.scale(
                            scale: scale,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeInOut,
                              width: isSelected ? 48 : 36,
                              height: isSelected ? 36 : 28,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _amber.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isSelected ? item.activeIcon : item.icon,
                                size: isSelected ? 22 : 20,
                                color: isSelected ? _amber : Colors.grey[400],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 280),
                            style: TextStyle(
                              fontSize: isSelected ? 11 : 10,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected ? _amber : Colors.grey[400],
                            ),
                            child: Text(item.label),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _navigateToLogin({String? blockedMessage}) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => LoginPage(blockedMessage: blockedMessage),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Skeleton de l'accueil pendant la vérification du compte.
      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: Column(
          children: [
            Container(
              color: _amber,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: AppShimmer(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: SkBox(width: 36, height: 36, radius: 18),
                      ),
                      const SizedBox(height: 12),
                      const SkBox(width: 120, height: 12),
                      const SizedBox(height: 8),
                      const SkBox(width: 180, height: 20),
                    ],
                  ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    AppShimmer(
                      child: SkBox(
                          width: double.infinity, height: 158, radius: 20),
                    ),
                    const SizedBox(height: 20),
                    ...List.generate(
                        3, (_) => const SkeletonReservationCard()),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      // Contenu de la page sélectionnée
      body: _pages[_selectedIndex],
      /*
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Action à effectuer lors du clic sur le bouton +
        },
        backgroundColor: Colors.black,
        elevation: 10,
        child: const Icon(Iconsax.add, size: 30, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      */
      bottomNavigationBar: _buildNavBar(),
    );
  }
}
