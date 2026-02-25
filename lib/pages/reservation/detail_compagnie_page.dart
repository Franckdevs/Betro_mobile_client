import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_service.dart';
import '../../models/compagnie_model.dart';
import '../../models/ville_model.dart';
import '../../models/gare_model.dart';
import 'gares_compagnie_page.dart';
import 'selection_siege.dart' show SelectionSiegePage;

class DetailCompagniePage extends StatefulWidget {
  final Compagnie compagnie;

  const DetailCompagniePage({super.key, required this.compagnie});

  @override
  State<DetailCompagniePage> createState() => _DetailCompagniePageState();
}

class _DetailCompagniePageState extends State<DetailCompagniePage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  List<Ville> _villes = [];
  List<Gare> _gares = [];
  String? _villeDepartId;
  String? _villeArriveeId;
  String? _gareDepartId;
  DateTime _dateDepart = DateTime.now();
  bool _isLoading = false;
  bool _isLoadingGares = false;
  List<dynamic> _voyages = [];
  bool _noVoyagesFound = false;
  bool _showScrollIndicator = true;

  @override
  void initState() {
    super.initState();
    _loadVilles();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Vérifier si on est proche du bas de la liste
    if (_scrollController.hasClients && _voyages.isNotEmpty) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      final viewportHeight = _scrollController.position.viewportDimension;

      // Calculer si on est proche du bas (dans les 90% de la hauteur de la vue)
      final threshold = maxScroll - (viewportHeight * 0.1);
      final shouldShowIndicator = currentScroll < threshold;

      // Mettre à jour l'état uniquement si nécessaire
      if (shouldShowIndicator != _showScrollIndicator) {
        if (mounted) {
          setState(() {
            _showScrollIndicator = shouldShowIndicator;
          });
        }
      }
    }
  }

  // Fonction pour faire défiler vers le bas de la liste
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _loadVilles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${_apiService.baseUrl}/liste_ville'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final villesList = (data['data'] as List)
              .cast<Map<String, dynamic>>();
          setState(() {
            _villes = villesList.map((ville) => Ville.fromJson(ville)).toList();
          });
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des villes: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadGares(String villeId) async {
    if (villeId.isEmpty) return;

    setState(() {
      _isLoadingGares = true;
      _gareDepartId = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
          '${_apiService.baseUrl}/liste_gare_compagnie/${widget.compagnie.id}',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final garesList = (data['data'] as List).cast<Map<String, dynamic>>();
          setState(() {
            _gares = garesList
                .where((gare) => gare['ville_id'].toString() == villeId)
                .map((gare) => Gare.fromJson(gare))
                .toList();
          });
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des gares: $e');
    } finally {
      setState(() {
        _isLoadingGares = false;
      });
    }
  }

  Future<void> _rechercherVoyages() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _noVoyagesFound = false;
        _voyages = [];
      });

      try {
        final requestData = {
          'compagnie_id': widget.compagnie.id,
          'ville_depart': int.tryParse(_villeDepartId ?? '0') ?? 0,
          'ville_arrivee': int.tryParse(_villeArriveeId ?? '0') ?? 0,
          'date_depart':
              '${_dateDepart.year}-${_dateDepart.month.toString().padLeft(2, '0')}-${_dateDepart.day.toString().padLeft(2, '0')}',
          'gare_depart': int.tryParse(_gareDepartId ?? '0') ?? 0,
        };

        final response = await http.post(
          Uri.parse('${_apiService.baseUrl}/choisir_destination'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestData),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          List<dynamic> voyages = [];

          // Vérifier si la réponse contient directement un tableau de voyages
          if (data['voyage'] is List) {
            voyages = data['voyage'];
          } else if (data['data'] is List) {
            voyages = data['data'];
          } else if (data is List) {
            voyages = data;
          } else if (data is Map && data.isNotEmpty) {
            voyages = [data];
          }

          // Traiter chaque voyage pour extraire les informations nécessaires
          final List<Map<String, dynamic>> processedVoyages = [];

          for (var voyage in voyages) {
            if (voyage is! Map) continue;

            // Afficher le JSON brut du voyage
            print('=== JSON COMPLET DU VOYAGE ===');
            print(const JsonEncoder.withIndent('  ').convert(voyage));
            print('=============================');

            // Extraire les informations de base du voyage
            final Map<String, dynamic> processedVoyage = {
              'id': voyage['id'],
              'heure_depart': voyage['heure_depart'],
              'date_depart': voyage['date_depart'],
              'disponible_toujours': voyage['disponible_toujours'],
              'bus': voyage['bus'],
              'itineraire': voyage['itineraire'],
            };

            // Afficher le voyage traité
            print('=== VOYAGE TRAITÉ ===');
            print(
              'disponible_toujours dans processedVoyage: ${processedVoyage['disponible_toujours']}',
            );
            print(
              'Clés dans processedVoyage: ${processedVoyage.keys.toList()}',
            );
            print('=====================');

            // Extraire les informations de tarification et de villes depuis les arrêts
            if (voyage['itineraire'] is Map &&
                voyage['itineraire']['arrets'] is List &&
                (voyage['itineraire']['arrets'] as List).isNotEmpty) {
              final premierArret =
                  (voyage['itineraire']['arrets'] as List).first;

              if (premierArret is Map && premierArret['tarification'] is Map) {
                final tarification = premierArret['tarification'];
                processedVoyage['montant'] = tarification['montant'];

                if (tarification['ville_depart'] is Map) {
                  processedVoyage['ville_depart'] = {
                    'nom_ville': tarification['ville_depart']['nom_ville'],
                  };
                }

                if (tarification['ville_arrivee'] is Map) {
                  processedVoyage['ville_arrivee'] = {
                    'nom_ville': tarification['ville_arrivee']['nom_ville'],
                  };
                }

                // Extraire les informations de la classe
                if (tarification['classe'] is Map) {
                  processedVoyage['classe'] = {
                    'nom': tarification['classe']['nom'],
                  };
                }
              }
            }

            processedVoyages.add(processedVoyage);
          }

          setState(() {
            _voyages = processedVoyages;
            _noVoyagesFound = _voyages.isEmpty;
            _isLoading = false;
          });
        } else {
          throw Exception('Erreur lors de la récupération des voyages');
        }
      } catch (e) {
        print('Erreur lors de la recherche de voyages: $e');

        setState(() {
          _voyages = [];
          _noVoyagesFound = true;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la recherche: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateDepart,
      firstDate: DateTime(2000), // Date minimale reculée
      lastDate: DateTime(2101), // Date maximale
    );
    if (picked != null) {
      setState(() {
        _dateDepart = picked;
      });
    }
  }

  // Fonction pour afficher l'image en plein écran
  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.yellow,
                      ),
                      strokeWidth: 3,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.error, color: Colors.red, size: 50),
                ),
              ),
            ),
          ),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Logo de l'entreprise
            if (widget.compagnie.logoUrl != null &&
                widget.compagnie.logoUrl!.isNotEmpty)
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  image: DecorationImage(
                    image: NetworkImage(widget.compagnie.logoUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Icon(Icons.business, color: Colors.amber),
              ),
            // Nom de l'entreprise
            Expanded(
              child: Text(
                widget.compagnie.nomComplet,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.yellow,
        toolbarHeight: 60, // Hauteur réduite de l'AppBar
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading && _villes.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow),
                strokeWidth: 3,
              ),
            )
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // En-tête fixe avec le formulaire
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      children: [
                        // Formulaire de recherche
                        Card(
                          elevation: 2,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 12.0,
                            ),
                            child: Column(
                              children: [
                                // Ville de départ
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder:
                                      (
                                        Widget child,
                                        Animation<double> animation,
                                      ) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: SizeTransition(
                                            sizeFactor: animation,
                                            axis: Axis.vertical,
                                            child: child,
                                          ),
                                        );
                                      },
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey<String>(
                                      'depart_${_villeDepartId ?? 'none'}',
                                    ),
                                    value: _villeDepartId,
                                    decoration: InputDecoration(
                                      labelText: 'Ville de départ',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.location_on,
                                        color: Colors.amber,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                    ),
                                    isExpanded: true,
                                    icon: const Icon(
                                      Icons.arrow_drop_down_circle,
                                      color: Colors.amber,
                                    ),
                                    dropdownColor: Colors.white,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 16,
                                    ),
                                    items: _villes.map((ville) {
                                      return DropdownMenuItem<String>(
                                        value: ville.id.toString(),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.location_city,
                                              size: 20,
                                              color: Colors.amber,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              ville.nomVille,
                                              style: const TextStyle(
                                                fontSize: 15,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (String? value) {
                                      setState(() {
                                        _villeDepartId = value;
                                        _gareDepartId = null;
                                        if (value != null) {
                                          _loadGares(value);
                                        } else {
                                          _gares = [];
                                        }
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null) {
                                        return 'Veuillez sélectionner une ville de départ';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Ville d'arrivée
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder:
                                      (
                                        Widget child,
                                        Animation<double> animation,
                                      ) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: SizeTransition(
                                            sizeFactor: animation,
                                            axis: Axis.vertical,
                                            child: child,
                                          ),
                                        );
                                      },
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey<String>(
                                      'arrivee_${_villeArriveeId ?? 'none'}',
                                    ),
                                    value: _villeArriveeId,
                                    decoration: InputDecoration(
                                      labelText: 'Ville d\'arrivée',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.location_pin,
                                        color: Colors.amber,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                    ),
                                    isExpanded: true,
                                    icon: const Icon(
                                      Icons.arrow_drop_down_circle,
                                      color: Colors.amber,
                                    ),
                                    dropdownColor: Colors.white,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 16,
                                    ),
                                    items: _villes.map((ville) {
                                      return DropdownMenuItem<String>(
                                        value: ville.id.toString(),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.location_city,
                                              size: 20,
                                              color: Colors.amber,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              ville.nomVille,
                                              style: const TextStyle(
                                                fontSize: 15,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (String? value) {
                                      setState(() {
                                        _villeArriveeId = value;
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null) {
                                        return 'Veuillez sélectionner une ville d\'arrivée';
                                      }
                                      if (value == _villeDepartId) {
                                        return 'La ville d\'arrivée doit être différente de la ville de départ';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Sélection de la gare de départ
                                if (_villeDepartId != null &&
                                    _villeDepartId!.isNotEmpty) ...[
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder:
                                        (
                                          Widget child,
                                          Animation<double> animation,
                                        ) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: SizeTransition(
                                              sizeFactor: animation,
                                              axis: Axis.vertical,
                                              child: child,
                                            ),
                                          );
                                        },
                                    child: _isLoadingGares
                                        ? const Center(
                                            child: CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.yellow,
                                                  ),
                                              strokeWidth: 3,
                                            ),
                                          )
                                        : _gares.isEmpty
                                        ? Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.grey[300]!,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(
                                                  Icons.warning_amber,
                                                  color: Colors.orange,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Aucune gare disponible pour cette ville',
                                                ),
                                              ],
                                            ),
                                          )
                                        : DropdownButtonFormField<String>(
                                            key: ValueKey<String>(
                                              'gare_${_gareDepartId ?? 'none'}',
                                            ),
                                            value: _gareDepartId,
                                            decoration: InputDecoration(
                                              labelText: 'Gare de départ',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              prefixIcon: const Icon(
                                                Icons.directions_bus,
                                                color: Colors.amber,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12,
                                                  ),
                                            ),
                                            isExpanded: true,
                                            icon: const Icon(
                                              Icons.arrow_drop_down_circle,
                                              color: Colors.amber,
                                            ),
                                            dropdownColor: Colors.white,
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 16,
                                            ),
                                            items: _gares.map((gare) {
                                              return DropdownMenuItem<String>(
                                                value: gare.id.toString(),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.departure_board,
                                                      size: 20,
                                                      color: Colors.amber,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        gare.nomGare,
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (String? value) {
                                              setState(() {
                                                _gareDepartId = value;
                                              });
                                            },
                                            validator: (value) {
                                              if (_villeDepartId != null &&
                                                  _villeDepartId!.isNotEmpty &&
                                                  (value == null ||
                                                      value.isEmpty)) {
                                                return 'Veuillez sélectionner une gare de départ';
                                              }
                                              return null;
                                            },
                                          ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                // Date de départ
                                TextFormField(
                                  readOnly: true,
                                  controller: TextEditingController(
                                    text:
                                        '${_dateDepart.day.toString().padLeft(2, '0')}/${_dateDepart.month.toString().padLeft(2, '0')}/${_dateDepart.year}',
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Date de départ',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.calendar_today,
                                      color: Colors.amber,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    suffixIcon: const Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.amber,
                                    ),
                                  ),
                                  onTap: () => _selectDate(context),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Veuillez sélectionner une date';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                // Bouton Voir les gares
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              GaresCompagniePage(
                                                compagnieId:
                                                    widget.compagnie.id,
                                                compagnieNom:
                                                    widget.compagnie.nomComplet,
                                              ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.directions_bus,
                                      color: Colors.yellow,
                                    ),
                                    label: const Text(
                                      'Voir toutes les gares',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Colors.yellow,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Bouton de recherche
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : _rechercherVoyages,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.yellow,
                                      foregroundColor: Colors.black87,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              valueColor:
                                                  const AlwaysStoppedAnimation<
                                                    Color
                                                  >(Colors.amber),
                                              strokeWidth: 3,
                                            ),
                                          )
                                        : const Text('Rechercher'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Section défilante des voyages
                  Expanded(
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Voyages disponibles',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_voyages.isNotEmpty)
                                    Text(
                                      '${_voyages.length} voyage${_voyages.length > 1 ? 's' : ''}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Section des résultats de recherche
                              if (_isLoading)
                                const Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.yellow,
                                      ),
                                      strokeWidth: 3,
                                    ),
                                  ),
                                )
                              else if (_noVoyagesFound || _voyages.isEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 40,
                                    horizontal: 20,
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.directions_bus,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Aucun voyage trouvé',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 20.0,
                                          ),
                                          child: Text(
                                            'Aucun voyage ne correspond à vos critères de recherche. Veuillez essayer avec d\'autres critères.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ..._voyages.map((voyage) {
                                  final heureDepart =
                                      voyage['heure_depart']
                                          ?.toString()
                                          .substring(0, 5) ??
                                      '--:--';
                                  final dateDepart =
                                      voyage['date_depart']?.toString() ?? '';

                                  // Récupérer les informations des villes
                                  final villeDepart =
                                      voyage['ville_depart']?['nom_ville'] ??
                                      'Inconnue';
                                  final villeArrivee =
                                      voyage['ville_arrivee']?['nom_ville'] ??
                                      'Inconnue';

                                  // Récupérer le montant du voyage
                                  final montant = voyage['montant'] != null
                                      ? '${voyage['montant']} FCFA'
                                      : 'Prix non disponible';

                                  // Vérifier si le voyage est toujours disponible
                                  final disponibleToujoursValue =
                                      voyage['disponible_toujours'];
                                  final disponibleToujours =
                                      disponibleToujoursValue?.toString() ==
                                          '1' ||
                                      disponibleToujoursValue == true;

                                  // Debug: afficher la valeur de disponible_toujours
                                  print(
                                    'disponible_toujours: $disponibleToujoursValue -> $disponibleToujours',
                                  );

                                  // Récupérer les informations du bus
                                  final bus = voyage['bus'] is Map
                                      ? voyage['bus']
                                      : null;

                                  return Card(
                                    color: Colors.white,
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 16,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // En-tête avec la date et l'heure de départ + prix
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                disponibleToujours == false
                                                    ? 'Date: ${dateDepart.split('-').reversed.join('/')} • Départ: $heureDepart'
                                                    : 'Départ: $heureDepart',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              Text(
                                                montant,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),

                                          // Itinéraire sur une seule ligne
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.location_on,
                                                size: 16,
                                                color: Colors.red,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                villeDepart,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.arrow_forward,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.location_on,
                                                size: 16,
                                                color: Colors.green,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                villeArrivee,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              // Ajouter la classe si elle existe
                                              if (voyage['classe'] != null) ...[
                                                const SizedBox(width: 12),
                                                const Icon(
                                                  Icons
                                                      .airline_seat_recline_normal,
                                                  size: 16,
                                                  color: Colors.purple,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '(${voyage['classe']['nom'] ?? 'Standard'})',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),

                                          const Divider(
                                            height: 24,
                                            thickness: 1,
                                          ),

                                          // Informations du bus
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Padding(
                                                padding: EdgeInsets.only(
                                                  top: 4.0,
                                                ),
                                                child: Icon(
                                                  Icons.directions_bus,
                                                  size: 18,
                                                  color: Colors.blueGrey,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const SizedBox(height: 2),
                                                    const SizedBox(height: 4),
                                                    // Affichage des détails du bus
                                                    if (bus != null)
                                                      Row(
                                                        children: [
                                                          if (bus['photo_bus'] !=
                                                                  null &&
                                                              bus['photo_bus']
                                                                  .toString()
                                                                  .isNotEmpty)
                                                            GestureDetector(
                                                              onTap: () =>
                                                                  _showFullScreenImage(
                                                                    bus['photo_bus'],
                                                                  ),
                                                              child: Hero(
                                                                tag:
                                                                    'bus-image-${bus['photo_bus']}',
                                                                child: Container(
                                                                  width: 80,
                                                                  height: 50,
                                                                  margin:
                                                                      const EdgeInsets.only(
                                                                        right:
                                                                            12,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          8,
                                                                        ),
                                                                    image: DecorationImage(
                                                                      image: NetworkImage(
                                                                        bus['photo_bus'],
                                                                      ),
                                                                      fit: BoxFit
                                                                          .cover,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  '${bus['nom_bus'] ?? 'N/A'} • ${bus['marque_bus'] ?? 'N/A'} • ${bus['immatriculation_bus'] ?? 'N/A'}',
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    color: Colors
                                                                        .black87,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 2,
                                                                ),
                                                                Text(
                                                                  '${bus['nombre_places']?.toString() ?? '0'} places',
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    color: Colors
                                                                        .grey,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
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
                                            ],
                                          ),

                                          const SizedBox(height: 12),

                                          // Bouton de réservation
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () {
                                                if (bus != null &&
                                                    voyage['id'] != null) {
                                                  final villeDepart = _villes
                                                      .firstWhere(
                                                        (v) =>
                                                            v.id.toString() ==
                                                            _villeDepartId,
                                                        orElse: () => Ville(
                                                          id: 0,
                                                          nomVille: 'Inconnue',
                                                          status: 'active',
                                                          createdAt:
                                                              DateTime.now(),
                                                          updatedAt:
                                                              DateTime.now(),
                                                        ),
                                                      )
                                                      .nomVille;

                                                  final villeArrivee = _villes
                                                      .firstWhere(
                                                        (v) =>
                                                            v.id.toString() ==
                                                            _villeArriveeId,
                                                        orElse: () => Ville(
                                                          id: 0,
                                                          nomVille: 'Inconnue',
                                                          status: 'active',
                                                          createdAt:
                                                              DateTime.now(),
                                                          updatedAt:
                                                              DateTime.now(),
                                                        ),
                                                      )
                                                      .nomVille;

                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => SelectionSiegePage(
                                                        busId:
                                                            int.tryParse(
                                                              bus['id']
                                                                      ?.toString() ??
                                                                  '0',
                                                            ) ??
                                                            0,
                                                        voyageId:
                                                            int.tryParse(
                                                              voyage['id']
                                                                      ?.toString() ??
                                                                  '0',
                                                            ) ??
                                                            0,
                                                        nombrePlaces:
                                                            int.tryParse(
                                                              bus['nombre_places']
                                                                      ?.toString() ??
                                                                  '0',
                                                            ) ??
                                                            0,
                                                        montant:
                                                            double.tryParse(
                                                              voyage['montant']
                                                                      ?.toString() ??
                                                                  '0',
                                                            ) ??
                                                            0.0,
                                                        arretId:
                                                            (voyage['itineraire']?['arrets']
                                                                    as List?)
                                                                ?.first?['id'] ??
                                                            0,
                                                        villeDepart:
                                                            villeDepart,
                                                        villeArrivee:
                                                            villeArrivee,
                                                        dateDepart: _dateDepart
                                                            .toString()
                                                            .split(' ')[0],
                                                        heureDepart:
                                                            voyage['heure_depart'] ??
                                                            '00:00',
                                                        marqueBus:
                                                            bus['marque_bus'] ??
                                                            'Inconnue',
                                                        immatriculationBus:
                                                            bus['immatriculation_bus'] ??
                                                            'Inconnue',
                                                        classe:
                                                            voyage['classe']?['nom'],
                                                        disponibleToujours:
                                                            disponibleToujours,
                                                      ),
                                                    ),
                                                  );
                                                } else {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Impossible de réserver: informations manquantes',
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.yellow,
                                                foregroundColor: Colors.black87,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                              ),
                                              child: const Text(
                                                'Réserver maintenant',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                        // Indicateur de défilement - n'afficher que s'il y a plus d'un élément
                        if (_showScrollIndicator && _voyages.length > 1)
                          Positioned(
                            bottom: 20,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: _scrollToBottom,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
