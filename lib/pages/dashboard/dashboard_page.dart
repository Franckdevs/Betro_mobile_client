import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'home_page.dart';
import 'parametre_page.dart';
import '../paiement/liste_paiements_page.dart';
import '../auth/login_page.dart';
import '../../services/storage_service.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<Dashboard> {
  int _selectedIndex = 0;
  final StorageService _storageService = StorageService();
  bool _isLoading = true;

  // Pages accessibles depuis le Dashboard
  final List<Widget> _pages = [
    const HomePage(),
    const ListePaiementsPage(),
    const ParametrePage(),
  ];

  void _onItemTapped(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        _navigateToLogin();
        return;
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        _navigateToLogin();
      }
    }
  }

  void _navigateToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 5,
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.amber.shade700,
          unselectedItemColor: Colors.grey,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Iconsax.home_1),
              label: 'Accueil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Iconsax.wallet_1),
              label: 'Paiements',
            ),
            BottomNavigationBarItem(
              icon: Icon(Iconsax.setting_2),
              label: 'Paramètres',
            ),
          ],
          // Gestion du clic sur les éléments de la barre de navigation
          onTap: (index) {
            _onItemTapped(index);
          },
        ),
      ),
    );
  }
}
