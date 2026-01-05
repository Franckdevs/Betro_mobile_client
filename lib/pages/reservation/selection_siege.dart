import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import 'paiement/paiement_webview_page.dart';
import '../profile/edit_profile_page.dart';

class SelectionSiegePage extends StatefulWidget {
  final int busId;
  final int voyageId;
  final int nombrePlaces;
  final double montant;
  final int arretId;
  final String villeDepart;
  final String villeArrivee;
  final String dateDepart;
  final String heureDepart;
  final String marqueBus;
  final String immatriculationBus;

  const SelectionSiegePage({
    super.key,
    required this.busId,
    required this.voyageId,
    required this.nombrePlaces,
    required this.montant,
    required this.arretId,
    required this.villeDepart,
    required this.villeArrivee,
    required this.dateDepart,
    required this.heureDepart,
    required this.marqueBus,
    required this.immatriculationBus,
  });

  @override
  State<SelectionSiegePage> createState() => _SelectionSiegePageState();
}

class _SelectionSiegePageState extends State<SelectionSiegePage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _placesOccupees = [];
  List<dynamic> _placesDisponibles = [];
  int? _selectedSeat;
  String? _selectedSeatName;
  Map<String, dynamic>? _userInfo;
  bool _isLoadingUserInfo = false;

  // Configuration du bus
  int _colonnes = 4;
  int _rangees = 10;
  int _placesCoteChauffeur = 3;

  @override
  void initState() {
    super.initState();
    print('=== INIT SELECTION SIÈGE ===');
    _initPage();
  }

  Future<void> _initPage() async {
    // Vérifier d'abord l'authentification
    final isAuthenticated = await _checkAuthStatus();
    if (!isAuthenticated) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    // Charger les données
    await _loadBusSeats();
    await _fetchUserInfo();
  }

  Future<bool> _checkAuthStatus() async {
    try {
      final storageService = StorageService();
      final token = await storageService.getToken();

      if (token == null) {
        print('🔒 Aucun token trouvé, redirection vers la page de connexion');
        return false;
      }

      print('🔑 Token valide trouvé');
      return true;
    } catch (e) {
      print('❌ Erreur lors de la vérification de l\'authentification: $e');
      return false;
    }
  }

  Future<void> _fetchUserInfo() async {
    if (!mounted) return;

    print('=== DÉBUT RÉCUPÉRATION INFOS UTILISATEUR ===');
    setState(() {
      _isLoadingUserInfo = true;
    });

    try {
      final storageService = StorageService();

      // 1. Essayer de récupérer les données depuis le stockage local
      final userData = await storageService.getUserData();

      if (userData != null) {
        print('✅ Données utilisateur trouvées dans le stockage local');
        setState(() {
          _userInfo = userData;
          _isLoadingUserInfo = false;
        });

        // Mettre à jour les données depuis le serveur en arrière-plan
        _refreshUserData();
        return;
      }

      // 2. Si pas de données locales, récupérer depuis le serveur
      await _refreshUserData();
    } catch (e) {
      print(
        '❌ Erreur lors de la récupération des informations utilisateur: $e',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Erreur lors de la récupération des informations utilisateur',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingUserInfo = false);
      }
    }
  }

  Future<void> _refreshUserData() async {
    try {
      final storageService = StorageService();
      final token = await storageService.getToken();

      if (token == null) {
        print(
          '❌ Aucun token disponible pour rafraîchir les données utilisateur',
        );
        return;
      }

      print('🔄 Mise à jour des données utilisateur depuis le serveur...');

      final response = await http.get(
        Uri.parse('${_apiService.baseUrl}/recuperer_utilisateur/$token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final userData = Map<String, dynamic>.from(data['data']);
          print(
            '✅ Données utilisateur mises à jour: ${userData['prenom']} ${userData['nom']}',
          );

          // Sauvegarder les données localement
          await storageService.saveUserData(userData);

          if (mounted) {
            setState(() {
              _userInfo = userData;
            });
          }
        } else {
          print('❌ Réponse API invalide: ${data['message']}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur: ${data['message']}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        print('❌ Erreur HTTP ${response.statusCode}: ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur de connexion au serveur'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour des données utilisateur: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la mise à jour des données'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUserInfo = false;
        });
      }
    }
  }

  Future<void> _loadBusSeats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          '${_apiService.baseUrl}/bus_detail_place/${widget.busId}/${widget.voyageId}',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _placesOccupees = data['liste_place_deja_occupe'] ?? [];
            _placesDisponibles = data['data']?['places'] ?? [];

            // Mettre à jour la configuration du bus
            final config = data['data']?['configuration_place'];
            if (config != null) {
              _colonnes = config['colonne'] ?? 0;
              _rangees = config['ranger'] ?? 0;
              _placesCoteChauffeur = config['places_cote_chauffeur'] ?? 3;
            }
          });

          // Afficher les informations détaillées des places dans la console
          print('=== CONFIGURATION DU BUS ===');
          print('Colonnes: $_colonnes');
          print('Rangées: $_rangees');
          print('Places côté chauffeur: $_placesCoteChauffeur');
          print('Total des places: ${_colonnes * _rangees}');

          print('\n=== PLACES DISPONIBLES (${_placesDisponibles.length}) ===');
          for (var place in _placesDisponibles) {
            print(
              'Siège ${place['numero']} - ${place['nom']} - Type: ${place['type']} - Disponible: ${place['disponible'] == 1 ? 'Oui' : 'Non'}',
            );
          }

          print('\n=== PLACES OCCUPÉES (${_placesOccupees.length}) ===');
          for (var place in _placesOccupees) {
            print(
              'Siège ${place['numero_place']} - ID Réservation: ${place['id_reservation']}',
            );
          }

          print('\n=== RÉCAPITULATIF ===');
          print('Total places: ${_colonnes * _rangees}');
          print('Places disponibles: ${_placesDisponibles.length}');
          print('Places occupées: ${_placesOccupees.length}');
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  data['message'] ?? 'Erreur lors du chargement des places',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        throw Exception('Erreur lors du chargement des places');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur de connexion au serveur'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isSeatOccupied(int seatNumber) {
    // La place du chauffeur est toujours occupée
    if (seatNumber == 0) return true;

    // Vérifier si la place est dans la liste des places occupées
    if (_placesOccupees.any(
      (occupee) => occupee['numero_place'] == seatNumber,
    )) {
      return true;
    }

    // Vérifier si la place est dans la liste des places disponibles
    final place = _placesDisponibles.firstWhere(
      (p) => p['numero'] == seatNumber,
      orElse: () => <String, dynamic>{},
    );

    // Si la place n'est pas dans la liste des disponibles, elle est considérée comme occupée
    if (place.isEmpty) return true;

    // La place est disponible si 'disponible' est égal à 1
    return place['disponible'] != 1;
  }

  // Vérifie si une place est de type proche_chauffeur
  bool _isProcheChauffeur(dynamic place) {
    return place['type'] == 'proche_chauffeur';
  }

  // Variable d'état pour gérer la visibilité de la zone déroulante
  bool _showAdditionalInfo = false;

  void _selectSeat(int seatNumber, String seatName) {
    // Ne pas permettre la sélection de la place du chauffeur
    if (seatNumber == 0) return;

    Future<void> _onSeatSelected(int seatNumber, String seatName) async {
      setState(() {
        _selectedSeat = seatNumber;
        _selectedSeatName = seatName;
        _showAdditionalInfo =
            false; // Réinitialiser l'état de la zone déroulante
      });

      // Récupérer les informations de l'utilisateur connecté
      final storageService = StorageService();
      final userData = await storageService.getUserData();
      final String nomComplet =
          '${userData?['prenom'] ?? ''} ${userData?['nom'] ?? ''}';

      // Afficher un dialogue de confirmation personnalisé
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Confirmer la réservation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isLoadingUserInfo)
                      const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.yellow,
                          ),
                          strokeWidth: 3,
                        ),
                      )
                    else if (_userInfo != null) ...[
                      const Text(
                        'Informations du passager :',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Prénom: ${_userInfo!['prenom'] ?? 'Non renseigné'}\n'
                        'Nom: ${_userInfo!['nom'] ?? 'Non renseigné'}\n'
                        'Téléphone: ${_userInfo!['telephone'] ?? 'Non renseigné'}',
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 15),
                      // Bouton pour afficher/masquer les informations supplémentaires
                      InkWell(
                        onTap: () {
                          setState(() {
                            _showAdditionalInfo = !_showAdditionalInfo;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Attribuer à quelqu’un',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue,
                                ),
                              ),
                              Icon(
                                _showAdditionalInfo
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Colors.blue,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Zone déroulante avec les champs supplémentaires
                      if (_showAdditionalInfo)
                        Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 15),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                initialValue: userData?['nom_complet'] ?? '',
                                decoration: const InputDecoration(
                                  labelText: 'Nom complet',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (value) {
                                  // Mettre à jour la valeur dans userData
                                  if (userData != null) {
                                    userData['nom_complet'] = value;
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                initialValue:
                                    userData?['telephone_proprietaire'] ?? '',
                                decoration: InputDecoration(
                                  labelText: 'Téléphone propriétaire',
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                      vertical: 12.0,
                                    ),
                                    child: Text(
                                      '🇨🇮 +225',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                keyboardType: TextInputType.phone,
                                onChanged: (value) {
                                  // Mettre à jour la valeur dans userData
                                  if (userData != null) {
                                    userData['telephone_proprietaire'] = value;
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                    ] else if (nomComplet.trim().isNotEmpty) ...[
                      const Text(
                        'Informations du passager :',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Prénom: ${userData?['prenom'] ?? 'Non renseigné'}\n'
                        'Nom: ${userData?['nom'] ?? 'Non renseigné'}\n'
                        'Téléphone: ${userData?['telephone'] ?? 'Non renseigné'}',
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 15),
                    ],
                    Text(
                      'Souhaitez-vous réserver le siège $seatName pour ${widget.montant.toInt()} FCFA ?',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: const Text('ANNULER'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            // Sauvegarder les données avant de fermer la modale
                            if (userData != null) {
                              storageService.saveUserData(userData);
                            }
                            Navigator.of(context).pop(true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'CONFIRMER',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      if (shouldProceed != true) {
        return;
      }

      // Afficher un indicateur de chargement
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      try {
        // Récupérer le token d'authentification (à adapter selon votre logique d'authentification)
        final storageService = StorageService();
        final token = await storageService.getToken();

        if (token == null) {
          throw Exception(
            'Vous devez être connecté pour effectuer cette action',
          );
        }

        // Appeler l'API d'initiation de paiement
        print('=== DÉBUT APPEL API INITIATION PAIEMENT ===');
        print('Token: $token');
        print('Voyage ID: ${widget.voyageId}');
        print('Numéro de place: $seatNumber');
        print('Arret ID: ${widget.arretId}');

        // Récupérer les données du formulaire
        final userData = await storageService.getUserData();
        final telephoneProprietaire = userData?['telephone_proprietaire']
            ?.toString();
        final nomComplet = userData?['nom_complet']?.toString();

        print('Téléphone propriétaire: $telephoneProprietaire');
        print('Nom complet: $nomComplet');

        final response = await _apiService.initierPaiement(
          token: token,
          voyageId: widget.voyageId,
          idArretVoyage: widget.arretId,
          numeroPlace: seatNumber,
          telephoneProprietaire: telephoneProprietaire,
          nomComplet: nomComplet,
        );

        print('=== RÉPONSE API ===');
        print('Status: ${response['success']}');
        print('URL de paiement: ${response['url']}');
        print('Message: ${response['message']}');
        print('Données complètes: $response');

        if (response['success'] == true && response['url'] != null) {
          if (!mounted) return;

          // Naviguer vers la page de paiement WebView
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  PaiementWebViewPage(urlPaiement: response['url']),
            ),
          );
        } else {
          throw Exception(
            response['message'] ??
                'Erreur lors de l\'initialisation du paiement',
          );
        }
      } catch (e) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (!_isSeatOccupied(seatNumber)) {
      _onSeatSelected(seatNumber, seatName);
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final days = [
        'Lundi',
        'Mardi',
        'Mercredi',
        'Jeudi',
        'Vendredi',
        'Samedi',
        'Dimanche',
      ];
      final months = [
        'Janvier',
        'Février',
        'Mars',
        'Avril',
        'Mai',
        'Juin',
        'Juillet',
        'Août',
        'Septembre',
        'Octobre',
        'Novembre',
        'Décembre',
      ];

      // Le jour de la semaine (0 = lundi, 6 = dimanche)
      final dayOfWeek = days[date.weekday - 1];
      final day = date.day;
      final month = months[date.month - 1];
      final year = date.year;

      return '$dayOfWeek $day $month $year';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildSeat(
    dynamic place,
    String seatName, {
    bool isProcheChauffeur = false,
    bool isChauffeur = false,
  }) {
    final int seatNumber = place['numero'] ?? 0;
    final bool isOccupied = _isSeatOccupied(seatNumber);
    final bool isSelected = _selectedSeat == seatNumber;

    Color seatColor;
    Color borderColor;
    double borderWidth = 1.5;

    if (isChauffeur) {
      seatColor = Colors.blueGrey[50]!;
      borderColor = Colors.blueGrey[400]!;
    } else if (isOccupied) {
      if (place['disponible'] == 0) {
        seatColor = Colors.red[50]!;
        borderColor = Colors.red[400]!;
      } else {
        seatColor = Colors.grey[100]!;
        borderColor = Colors.grey[400]!;
      }
    } else if (isSelected) {
      seatColor = Colors.amber[100]!;
      borderColor = Colors.orange;
      borderWidth = 2.5;
    } else if (isProcheChauffeur) {
      seatColor = Colors.blue[50]!;
      borderColor = Colors.blue[200]!;
    } else {
      seatColor = Colors.green[50]!;
      borderColor = Colors.green[300]!;
    }

    return GestureDetector(
      onTap: () => _selectSeat(seatNumber, seatName),
      child: Container(
        width: 75,
        height: 75,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: seatColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: borderColor.withOpacity(0.5)),
              ),
              child: Text(
                '${place['numero'] ?? '?'} - $seatName',
                style: TextStyle(
                  color: isOccupied && place['disponible'] != 0
                      ? Colors.grey[700]
                      : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            isChauffeur
                ? const Icon(
                    Icons.directions_bus,
                    size: 20,
                    color: Colors.blueGrey,
                  )
                : isOccupied
                ? Icon(
                    Icons.person,
                    size: 22,
                    color: place['disponible'] == 0
                        ? Colors.red[400]
                        : Colors.grey[600],
                  )
                : const Icon(Icons.event_seat, size: 20, color: Colors.green),
          ],
        ),
      ),
    );
  }

  // Widget pour la place du chauffeur
  Widget _buildChauffeurSeat() {
    return Container(
      width: 80,
      height: 60,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.airline_seat_recline_normal,
            size: 24,
            color: Colors.blueGrey,
          ),
          const SizedBox(height: 4),
          Text(
            'Chauffeur',
            style: TextStyle(
              fontSize: 10,
              color: Colors.blueGrey[800],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Créer une grille de places basée sur la configuration colonnes x rangées
  List<Widget> _buildSeatGrid([List<dynamic>? placesToShow]) {
    List<Widget> rows = [];

    // Si aucune liste n'est fournie, utiliser toutes les places disponibles
    final places = placesToShow ?? _placesDisponibles;

    // Créer une map des places disponibles pour un accès rapide
    final Map<int, dynamic> placesDisponiblesMap = {};
    for (var place in places) {
      placesDisponiblesMap[place['numero']] = place;
    }

    // Créer une map des places occupées pour un accès rapide
    final Map<int, dynamic> placesOccupeesMap = {};
    for (var place in _placesOccupees) {
      // Ne considérer que les places occupées qui sont dans la liste des places à afficher
      if (placesDisponiblesMap.containsKey(place['numero_place'])) {
        placesOccupeesMap[place['numero_place']] = place;
      }
    }

    // Créer une liste de tous les numéros de siège uniques
    final allSeatNumbers = <int>{};
    allSeatNumbers.addAll(placesDisponiblesMap.keys);
    allSeatNumbers.addAll(placesOccupeesMap.keys);

    if (allSeatNumbers.isEmpty) {
      return [const Center(child: Text('Aucune place disponible'))];
    }

    final sortedSeatNumbers = allSeatNumbers.toList()..sort();

    // Calculer le nombre de rangées nécessaires
    final numRows = (sortedSeatNumbers.length / _colonnes).ceil();

    // Créer les rangées de sièges
    for (int row = 0; row < numRows; row++) {
      List<Widget> rowChildren = [];

      for (int col = 0; col < _colonnes; col++) {
        final index = (row * _colonnes) + col;
        if (index >= sortedSeatNumbers.length) break;

        final seatNumber = sortedSeatNumbers[index];

        // Créer une place avec les informations disponibles
        final placeData =
            placesDisponiblesMap[seatNumber] ??
            placesOccupeesMap[seatNumber] ??
            {'numero': seatNumber, 'disponible': 0};

        final placeName = placeData['nom'] ?? 'Siège $seatNumber';

        rowChildren.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: _buildSeat(placeData, placeName),
            ),
          ),
        );
      }

      // Ajouter la rangée complète si elle n'est pas vide
      if (rowChildren.isNotEmpty) {
        rows.add(
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: rowChildren,
          ),
        );
      }
    }

    return [Column(children: rows)];
  }

  Widget _buildBusLayout() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
          strokeWidth: 3,
        ),
      );
    }

    // Séparer les places proches du chauffeur des autres
    final placesProcheChauffeur = _placesDisponibles
        .where((p) => _isProcheChauffeur(p))
        .toList();

    // Filtrer les places pour exclure celles qui sont déjà affichées dans la section "proche chauffeur"
    final placesAConsiderer = _placesDisponibles
        .where((p) => !_isProcheChauffeur(p))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Légende
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  const Text(
                    'Légende des places',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildLegendItem(Colors.green.shade200, 'Disponible'),
                      _buildLegendItem(Colors.amber, 'Sélectionné'),
                      _buildLegendItem(Colors.grey.shade400, 'Occupé'),
                      _buildLegendItem(Colors.red.shade200, 'Non disponible'),
                      _buildLegendItem(
                        Colors.blue.shade100,
                        'Proche chauffeur',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Représentation du bus
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.grey[200]!, Colors.grey[100]!],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  // Toit du bus
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue[900],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.marqueBus} - ${widget.immatriculationBus}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  // Corps du bus
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Ligne du chauffeur
                        if (placesProcheChauffeur.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Place du chauffeur
                              _buildChauffeurSeat(),

                              // Espace pour le tableau de bord
                              Container(
                                width: 100,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[400]!),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.directions_bus,
                                    size: 30,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),

                              // Places proches du chauffeur
                              Expanded(
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 4,
                                        childAspectRatio: 1,
                                        mainAxisSpacing: 8,
                                        crossAxisSpacing: 8,
                                      ),
                                  itemCount: placesProcheChauffeur.length,
                                  itemBuilder: (context, index) {
                                    final place = placesProcheChauffeur[index];
                                    return _buildSeat(
                                      place,
                                      place['nom'] ?? '?',
                                      isProcheChauffeur: true,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Ligne de séparation
                          Container(
                            height: 1,
                            color: Colors.grey[300],
                            margin: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ],

                        // Espacement après la section du conducteur
                        const SizedBox(height: 8),

                        // Sièges principaux
                        _buildSeatGrid(placesAConsiderer).first,
                      ],
                    ),
                  ),

                  // Bas du bus avec les roues
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Roue avant
                      Container(
                        width: 40,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),

                      // Roue arrière
                      Container(
                        width: 40,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Configuration des places
          const Padding(
            padding: EdgeInsets.only(top: 10, bottom: 5),
            child: Text(
              'Configuration des places',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          // Grille des places avec défilement
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildSeatGrid(placesAConsiderer),
            ),
          ),

          // Bouton de confirmation (masqué)
          // if (_selectedSeat != null) ...[
          //   const SizedBox(height: 20),
          //   Text(
          //     'Siège sélectionné: $_selectedSeatName',
          //     style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          //   ),
          //   const SizedBox(height: 20),
          //   SizedBox(
          //     width: double.infinity,
          //     height: 50,
          //     child: ElevatedButton(
          //       onPressed: () {
          //         if (mounted) {
          //           ScaffoldMessenger.of(context).showSnackBar(
          //             const SnackBar(
          //               content: Text('Fonctionnalité de réservation en cours de développement'),
          //               backgroundColor: Colors.orange,
          //             ),
          //           );
          //         }
          //       },
          //       style: ElevatedButton.styleFrom(
          //         backgroundColor: Colors.amber,
          //         shape: RoundedRectangleBorder(
          //           borderRadius: BorderRadius.circular(8),
          //         ),
          //       ),
          //       child: const Text(
          //         'Confirmer la réservation',
          //         style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          //       ),
          //     ),
          //   ),
          // ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: Colors.grey.shade400),
          ),
        ),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildVoyageDetails() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.villeDepart} → ${widget.villeArrivee}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${widget.montant.toInt()} FCFA',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    Icons.calendar_today,
                    widget.dateDepart,
                    isDate: true,
                  ),
                  const SizedBox(height: 4),
                  _buildDetailRow(Icons.access_time, widget.heureDepart),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    Icons.directions_bus,
                    '${widget.marqueBus} (${widget.immatriculationBus})',
                  ),
                  const SizedBox(height: 4),
                  _buildDetailRow(
                    Icons.event_seat,
                    '${widget.nombrePlaces} places',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, {bool isDate = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          isDate ? _formatDate(text) : text,
          style: TextStyle(fontSize: 14, color: Colors.grey[800]),
        ),
      ],
    );
  }

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfilePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sélectionnez votre siège'),
        backgroundColor: Colors.yellow,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_buildVoyageDetails(), _buildBusLayout()],
        ),
      ),
    );
  }
}
