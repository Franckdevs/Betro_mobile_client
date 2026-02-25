import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../models/reservation_model.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../core/utils/error_helper.dart';
import '../reservation/list_compagnie_page.dart';
import '../auth/login_page.dart';
import 'reservation_list.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  bool _isLoading = true;
  String _errorMessage = '';
  List<Reservation> _reservations = [];
  List<Reservation> _filteredReservations = [];
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  String? _accueilImageUrl;
  bool _isImageLoading = true;

  // Options de filtre prédéfinies
  final List<Map<String, dynamic>> _filterOptions = [
    {'label': 'Aujourd\'hui', 'days': 0},
    {'label': 'Cette semaine', 'days': 7},
    {'label': 'Ce mois-ci', 'days': 30},
    {'label': 'Personnalisé', 'days': -1},
  ];

  int _selectedFilterIndex = 2; // Par défaut sur "Ce mois-ci"

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserAndLoadData();
    });
  }

  Future<void> _checkUserAndLoadData() async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        _navigateToLogin();
        return;
      }

      // Vérifier si l'utilisateur existe toujours
      final userCheck = await _apiService.verifierUtilisateurExiste(token);

      if (!userCheck['success']) {
        // Ne supprimer le token qu'en cas d'expiration de session (401) ou d'authentification invalide
        final message = userCheck['message'] ?? 'Session expirée';
        final shouldClearToken =
            ErrorHelper.isAuthError(message) || userCheck['statusCode'] == 401;

        if (shouldClearToken) {
          await _storageService.clearToken();
        }

        if (mounted) {
          ErrorHelper.showErrorSnackBar(context, message);
          _navigateToLogin();
        }
        return;
      }

      // Charger l'image d'accueil en parallèle pour optimiser le temps
      Future.microtask(() => _loadAccueilImage());

      // Si l'utilisateur est valide, charger les réservations
      await _loadReservations();
    } catch (e) {
      debugPrint('Erreur lors de la vérification de l\'utilisateur: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur de connexion au serveur'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  // Charger l'image d'accueil depuis l'API
  Future<void> _loadAccueilImage() async {
    try {
      final imageUrl = await _apiService.getAccueilImage();
      if (mounted) {
        setState(() {
          _accueilImageUrl = imageUrl;
          _isImageLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement de l\'image d\'accueil: $e');
      if (mounted) {
        setState(() {
          _isImageLoading = false;
        });
      }
    }
  }

  // Widget Skeleton pour le chargement de l'image
  Widget _buildImageSkeleton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[200],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Chargement de l\'image...',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // Appliquer un filtre prédéfini
  void _applyFilter(int index) {
    setState(() {
      _selectedFilterIndex = index;
      final now = DateTime.now();
      final days = _filterOptions[index]['days'] as int;

      if (days >= 0) {
        _selectedDateRange = DateTimeRange(
          start: now.subtract(Duration(days: days)),
          end: now,
        );
        _filterReservations();
      } else {
        _selectDateRange(context);
      }
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.amber,
              onPrimary: Colors.black,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _selectedFilterIndex =
            _filterOptions.length - 1; // Dernier index pour "Personnalisé"
        _filterReservations();
      });
    }
  }

  void _filterReservations() {
    _filteredReservations = _reservations.where((reservation) {
      return !reservation.dateCreation.isBefore(_selectedDateRange.start) &&
          !reservation.dateCreation.isAfter(
            _selectedDateRange.end.add(const Duration(days: 1)),
          );
    }).toList();
  }

  Future<void> _loadReservations() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final token = await _storageService.getToken();
      if (token == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Veuillez vous connecter pour voir vos réservations';
          _reservations = [];
          _filteredReservations = [];
        });
        _navigateToLogin();
        return;
      }

      final reservations = await _apiService.getReservations(token);
      setState(() {
        _reservations = reservations;
        _filteredReservations = List.from(reservations);
        _filterReservations();
        _isLoading = false;
        _errorMessage = '';
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des réservations: $e');

      // Vérifier si l'erreur est une erreur d'authentification
      final isAuthError = ErrorHelper.isAuthError(e.toString());

      if (isAuthError) {
        // Seulement en cas d'erreur d'authentification, supprimer le token
        await _storageService.clearToken();
        setState(() {
          _isLoading = false;
          _errorMessage = 'Session expirée. Veuillez vous reconnecter.';
          _reservations = [];
          _filteredReservations = [];
        });
        if (mounted) {
          ErrorHelper.showErrorSnackBar(
            context,
            'Erreur de chargement des réservations',
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Impossible de charger les réservations. Veuillez réessayer plus tard.';
          _reservations = [];
          _filteredReservations = [];
        });
        if (mounted) {
          ErrorHelper.showErrorSnackBar(
            context,
            'Erreur de chargement des réservations',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // En-tête fixe
            Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête avec bonjour
                  const Text(
                    'Bienvenue',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 24),

                  // Image de fond avec effet de recherche
                  Container(
                    height: 200,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[200],
                    ),
                    child: _isImageLoading
                        ? _buildImageSkeleton()
                        : Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: _accueilImageUrl != null
                                        ? NetworkImage(_accueilImageUrl!)
                                        : const AssetImage(
                                                'assets/images/compagnie.jpg',
                                              )
                                              as ImageProvider,
                                    fit: BoxFit.cover,
                                    onError: (error, stackTrace) {
                                      debugPrint(
                                        'Erreur de chargement de l\'image: $error',
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.3),
                                      Colors.black.withOpacity(0.1),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),

                  // Bouton de réservation
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ListCompagniePage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Iconsax.car, size: 24),
                      label: const Text(
                        'Réserver maintenant',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Séparateur
            Container(height: 1, color: Colors.grey[300]),

            // Filtre de dates simplifié
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Boutons de filtre rapide
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_filterOptions.length, (index) {
                        final isSelected = _selectedFilterIndex == index;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(_filterOptions[index]['label']),
                            selected: isSelected,
                            selectedColor: Colors.amber.withOpacity(0.2),
                            backgroundColor: Colors.grey[200],
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.black87
                                  : Colors.grey[700],
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            onSelected: (_) => _applyFilter(index),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.amber
                                    : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Affichage de la période sélectionnée
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () => _selectDateRange(context),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${_selectedDateRange.start.day}/${_selectedDateRange.start.month}/${_selectedDateRange.start.year}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const Text(
                            ' - ',
                            style: TextStyle(color: Colors.grey),
                          ),
                          Text(
                            '${_selectedDateRange.end.day}/${_selectedDateRange.end.month}/${_selectedDateRange.end.year}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.amber,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Section des réservations avec défilement
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Text(
                    'Mes réservations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Text(
                      _filteredReservations.length.toString(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Liste des réservations avec défilement et rafraîchissement
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadReservations,
                color: Colors.amber,
                backgroundColor: Colors.white,
                strokeWidth: 3.0,
                child: _isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.amber,
                            ),
                            strokeWidth: 3,
                          ),
                        ),
                      )
                    : _errorMessage.isNotEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 100.0),
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      )
                    : _filteredReservations.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Iconsax.calendar_remove,
                                    size: 64,
                                    color: Colors.amber,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Aucune réservation',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Vous n\'avez pas encore de réservation pour cette période',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[600],
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: ReservationList(
                          reservations: _filteredReservations,
                          isLoading: _isLoading,
                          errorMessage: _errorMessage,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
