import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/connectivity_service.dart';
import '../../models/compagnie_model.dart';
import '../../models/ville_model.dart';
import '../../models/gare_model.dart';
import '../../models/gare1_model.dart' as gare1;
import '../../pages/dashboard/gare_map_page.dart';
import 'gares_compagnie_page.dart';
import 'selection_siege.dart' show SelectionSiegePage;
import '../../core/utils/logger.dart';
import '../../core/widgets/shimmer_skeleton.dart';

class DetailCompagniePage extends StatefulWidget {
  final Compagnie compagnie;

  const DetailCompagniePage({super.key, required this.compagnie});

  @override
  State<DetailCompagniePage> createState() => _DetailCompagniePageState();
}

class _DetailCompagniePageState extends State<DetailCompagniePage> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  List<Ville> _villes = [];
  // Sous-ensemble de _villes : uniquement les villes ou cette compagnie a
  // au moins une gare (au lieu de proposer toutes les villes du systeme).
  List<Ville> _villesCompagnie = [];
  List<Gare> _gares = [];
  List<Map<String, dynamic>> _classes = [];
  String? _villeDepartId;
  String? _villeArriveeId;
  String? _gareDepartId;
  String? _selectedClasseId;
  DateTime _dateDepart = DateTime.now();
  bool _isLoading = false;
  bool _isLoadingGares = false;
  bool _isLoadingClasses = false;
  List<dynamic> _voyages = [];
  bool _noVoyagesFound = false;
  bool _hasSearched = false;
  bool _isSearchExpanded = true;
  int _autocompleteKey = 0;

  // Indicateur "encore du contenu en dessous" pour le panneau de recherche
  // repliable (villes + liste des gares), qui peut deborder de sa hauteur max.
  final ScrollController _searchPanelScrollController = ScrollController();
  bool _searchPanelHasMoreBelow = false;

  static const _amber = Color(0xFFFFC107);
  static const _moisAbbr = ['jan', 'fév', 'mar', 'avr', 'mai', 'juin', 'juil', 'août', 'sep', 'oct', 'nov', 'déc'];

  @override
  void initState() {
    super.initState();
    _loadVilles();
    _loadVillesCompagnie();
    _loadClasses();
    _searchPanelScrollController.addListener(_updateSearchPanelScrollIndicator);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSearchPanelScrollIndicator());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchPanelScrollController.dispose();
    super.dispose();
  }

  /// Recalcule si le panneau de recherche a encore du contenu masque en
  /// dessous (liste de gares longue, notamment) pour afficher un indicateur.
  void _updateSearchPanelScrollIndicator() {
    if (!_searchPanelScrollController.hasClients) return;
    final position = _searchPanelScrollController.position;
    final encoreDuContenu = position.maxScrollExtent - position.pixels > 8;
    if (encoreDuContenu != _searchPanelHasMoreBelow) {
      setState(() => _searchPanelHasMoreBelow = encoreDuContenu);
    }
  }

  /// Degrade + chevron en bas du panneau de recherche, visible uniquement
  /// s'il reste du contenu masque (ex. liste de gares longue) sous la
  /// hauteur max visible.
  Widget _buildScrollMoreIndicator() {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _searchPanelHasMoreBelow ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 40,
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.95),
              ],
            ),
          ),
          padding: const EdgeInsets.only(bottom: 4),
          child: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 20, color: Colors.grey),
        ),
      ),
    );
  }


  Future<void> _loadVilles() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/liste_ville'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final list = (data['data'] as List).cast<Map<String, dynamic>>();
          setState(() {
            _villes = list.map((v) => Ville.fromJson(v)).toList();
          });
        }
      }
    } catch (_) {}
    finally {
      setState(() => _isLoading = false);
    }
  }

  /// Villes ou cette compagnie a reellement au moins une gare -- utilise
  /// pour restreindre les suggestions de "Ville de depart"/"Ville d'arrivee"
  /// au lieu de proposer toutes les villes du systeme.
  Future<void> _loadVillesCompagnie() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/liste_gare_compagnie/${widget.compagnie.id}'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final list = (data['data'] as List).cast<Map<String, dynamic>>();
          final gares = list.map((g) => Gare.fromJson(g)).toList();
          final villesParId = <String, Ville>{};
          for (final gare in gares) {
            if (gare.villeId.isEmpty || villesParId.containsKey(gare.villeId)) continue;
            final maintenant = DateTime.now();
            villesParId[gare.villeId] = Ville(
              id: int.tryParse(gare.villeId) ?? 0,
              nomVille: gare.ville,
              status: '',
              createdAt: maintenant,
              updatedAt: maintenant,
            );
          }
          final villes = villesParId.values.toList()
            ..sort((a, b) => a.nomVille.compareTo(b.nomVille));
          setState(() => _villesCompagnie = villes);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoadingClasses = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/liste_calsse_par_compagnie/${widget.compagnie.id}'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> list = [];
        if (data['data'] is List) {
          list = data['data'];
        } else if (data is List) {
          list = data;
        }
        setState(() {
          _classes = list.whereType<Map<String, dynamic>>().toList();
        });
      }
    } catch (_) {}
    finally {
      setState(() => _isLoadingClasses = false);
    }
  }

  Future<void> _loadGares(String villeId) async {
    if (villeId.isEmpty) return;
    setState(() {
      _isLoadingGares = true;
      _gareDepartId = null;
    });
    try {
      final url = '${ApiService.baseUrl}/liste_gare_compagnie/${widget.compagnie.id}';
      logDebug('[GARES] GET $url  (filtre ville_id=$villeId)');
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      logDebug('[GARES] status=${response.statusCode}  body=${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final list = (data['data'] as List).cast<Map<String, dynamic>>();
          // Gares de la ville de départ en premier, les autres ensuite
          final match    = list.where((g) => g['ville_id'].toString() == villeId).toList();
          final others   = list.where((g) => g['ville_id'].toString() != villeId).toList();
          final sorted   = [...match, ...others];
          logDebug('[GARES] total=${list.length}  ville_id=$villeId → ${match.length} prioritaire(s) + ${others.length} autre(s)');
          setState(() {
            _gares = sorted.map((g) => Gare.fromJson(g)).toList();
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _updateSearchPanelScrollIndicator());
        } else {
          logDebug('[GARES] success=false  message=${data['message']}');
        }
      }
    } catch (e) {
      logDebug('[GARES] ERREUR: $e');
    }
    finally {
      setState(() => _isLoadingGares = false);
    }
  }

  /// Une gare située hors de la ville de départ désigne la destination :
  /// on renseigne la ville d'arrivée automatiquement.
  /// À appeler dans un setState (modifie l'état sans le déclencher).
  bool _autoFillVilleArrivee(Gare gare) {
    final villeId = gare.villeId;
    if (villeId.isEmpty || villeId == _villeDepartId) return false;
    if (villeId == _villeArriveeId) return false;
    // La ville doit exister dans la liste, sinon le champ resterait vide
    if (!_villes.any((v) => v.id.toString() == villeId)) return false;

    _villeArriveeId = villeId;
    // Force les champs ville à réafficher la valeur sélectionnée
    _autocompleteKey++;
    return true;
  }

  Future<void> _rechercherVoyages() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _noVoyagesFound = false;
      _voyages = [];
      _hasSearched = true;
      _isSearchExpanded = false;
    });

    try {
      final requestData = {
        'compagnie_id': widget.compagnie.id,
        'ville_depart': int.tryParse(_villeDepartId ?? '0') ?? 0,
        'ville_arrivee': int.tryParse(_villeArriveeId ?? '0') ?? 0,
        'date_depart':
            '${_dateDepart.year}-${_dateDepart.month.toString().padLeft(2, '0')}-${_dateDepart.day.toString().padLeft(2, '0')}',
        'gare_depart': int.tryParse(_gareDepartId ?? '0') ?? 0,
        if (_selectedClasseId != null)
          'classe_id': int.tryParse(_selectedClasseId!) ?? 0,
      };

      final uri = Uri.parse('${ApiService.baseUrl}/choisir_destination');
      final body = json.encode(requestData);
      logDebug('┌─ [VOYAGE] POST $uri');
      logDebug('│  BODY : $body');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      final preview = response.body.length > 800
          ? '${response.body.substring(0, 800)}…'
          : response.body;
      logDebug('└─ [VOYAGE] ${response.statusCode}\n   $preview');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> voyages = [];
        if (data['voyage'] is List) {
          voyages = data['voyage'];
        } else if (data['data'] is List) {
          voyages = data['data'];
        } else if (data is List) {
          voyages = data;
        } else if (data is Map && data.isNotEmpty) {
          voyages = [data];
        }

        final List<Map<String, dynamic>> processed = [];
        for (var voyage in voyages) {
          if (voyage is! Map) continue;
          final Map<String, dynamic> p = {
            'id': voyage['id'],
            'heure_depart': voyage['heure_depart'],
            'heure_arrivee': voyage['heure_arrivee'],
            'date_depart': voyage['date_depart'],
            'disponible_toujours': voyage['disponible_toujours'],
            'duree_voyage': voyage['duree_voyage'],
            'bus': voyage['bus'],
            'itineraire': voyage['itineraire'],
          };
          if (voyage['itineraire'] is Map &&
              voyage['itineraire']['arrets'] is List &&
              (voyage['itineraire']['arrets'] as List).isNotEmpty) {
            final arret = (voyage['itineraire']['arrets'] as List).first;
            if (arret is Map && arret['tarification'] is Map) {
              final t = arret['tarification'];
              p['montant'] = t['montant'];
              if (t['ville_depart'] is Map) {
                p['ville_depart'] = {'nom_ville': t['ville_depart']['nom_ville']};
              }
              if (t['ville_arrivee'] is Map) {
                p['ville_arrivee'] = {'nom_ville': t['ville_arrivee']['nom_ville']};
              }
              if (t['classe'] is Map) p['classe'] = {'nom': t['classe']['nom']};
            }
            // Conserver les gares départ/arrivée pour la carte
            if (arret is Map) {
              if (arret['gare_depart'] is Map) p['gare_depart_data'] = arret['gare_depart'];
              if (arret['gare_arrivee'] is Map) p['gare_arrivee_data'] = arret['gare_arrivee'];
            }
          }
          processed.add(p);
        }

        setState(() {
          _voyages = processed;
          _noVoyagesFound = _voyages.isEmpty;
        });
      } else {
        throw Exception('Erreur serveur');
      }
    } catch (e) {
      setState(() {
        _voyages = [];
        _noVoyagesFound = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _swapVilles() {
    final tempId = _villeDepartId;
    setState(() {
      _villeDepartId = _villeArriveeId;
      _villeArriveeId = tempId;
      _gareDepartId = null;
      _gares = [];
      _autocompleteKey++;
    });
    if (_villeDepartId != null) _loadGares(_villeDepartId!);
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateDepart,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              const ColorScheme.light(primary: _amber, onPrimary: Colors.black87),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateDepart = picked);
  }

  static const String _imageBaseUrl = "http://192.168.95.123:8000";

  /// Retourne la liste des URLs complètes des photos d'un bus.
  /// photo_bus peut être un `List<dynamic>` ou une String JSON.
  List<String> _getBusPhotos(dynamic photoBus) {
    if (photoBus == null) return [];
    List<dynamic> items;
    if (photoBus is List) {
      items = photoBus;
    } else {
      try {
        final decoded = jsonDecode(photoBus.toString());
        items = decoded is List ? decoded : [photoBus.toString()];
      } catch (_) {
        items = [photoBus.toString()];
      }
    }
    return items
        .map((e) {
          final s = e.toString();
          if (s.startsWith('http')) return s;
          return '$_imageBaseUrl/buses/$s';
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }


  void _showBusImages(List<String> urls, {int initialIndex = 0}) {
    if (urls.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _BusImageViewer(urls: urls, initialIndex: initialIndex),
        fullscreenDialog: true,
      ),
    );
  }

  // ── Build principal ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _isLoading && _villes.isEmpty
          ? Column(children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: _buildLoadingState('Chargement de la compagnie…'),
                ),
              ),
            ])
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // Header fixe
                  _buildHeader(context),
                  // Stack : liste indépendante + card flottante au-dessus
                  Expanded(
                    child: Stack(
                      children: [
                        // ── Liste : occupe tout l'espace, ne sait pas que la card existe
                        Positioned.fill(
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            // Padding top fixe = hauteur card repliée (~70px) + gap
                            // Ne change JAMAIS → la liste ne saute jamais
                            padding: const EdgeInsets.fromLTRB(16, 78, 16, 32),
                            child: Column(
                              children: [
                                if (_isLoading && _villes.isNotEmpty)
                                  _buildLoadingState('Recherche des voyages…')
                                else if (!_hasSearched)
                                  _buildSearchHint()
                                else ...[
                                  _buildResultsHeader(),
                                  const SizedBox(height: 10),
                                  if (_noVoyagesFound || _voyages.isEmpty)
                                    _buildEmptyVoyages()
                                  else
                                    ..._voyages.asMap().entries.map((e) =>
                                      _AnimatedVoyageCard(
                                        index: e.key,
                                        child: _buildVoyageCard(e.value as Map<String, dynamic>),
                                      )),
                                ],
                              ],
                            ),
                          ),
                        ),
                        // ── Card flottante : positionnée absolument, invisible pour la liste
                        Positioned(
                          top: 8,
                          left: 16,
                          right: 16,
                          child: _buildSearchCard(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    final hasLogo =
        widget.compagnie.logoUrl != null && widget.compagnie.logoUrl!.isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        color: _amber,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.black87, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)
                  ],
                ),
                child: hasLogo
                    ? ClipOval(
                        child: Image.network(widget.compagnie.logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.business, color: _amber)))
                    : const Icon(Icons.business, color: _amber, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.compagnie.nomComplet,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                        overflow: TextOverflow.ellipsis),
                    if (widget.compagnie.adresse.isNotEmpty &&
                        widget.compagnie.adresse != 'Adresse non fournie')
                      Row(children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: Colors.black54),
                        const SizedBox(width: 3),
                        Expanded(
                            child: Text(widget.compagnie.adresse,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54),
                                overflow: TextOverflow.ellipsis)),
                      ]),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GaresCompagniePage(
                          compagnieId: widget.compagnie.id,
                          compagnieNom: widget.compagnie.nomComplet),
                    )),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Gares',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87)),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: Colors.black87),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Formulaire de recherche (sticky) ──────────────────────────────────────
  Widget _buildSearchCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 6)),
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête cliquable ──────────────────────────────
          GestureDetector(
            onTap: () {
              setState(() => _isSearchExpanded = !_isSearchExpanded);
              // Laisse l'AnimatedCrossFade se terminer avant de mesurer.
              Future.delayed(const Duration(milliseconds: 260),
                  _updateSearchPanelScrollIndicator);
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                      color: _amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.search_rounded,
                      size: 16, color: _amber),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Rechercher un voyage',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                ),
                AnimatedRotation(
                  turns: _isSearchExpanded ? 0 : -0.5,
                  duration: const Duration(milliseconds: 250),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey, size: 22),
                ),
              ]),
            ),
          ),
          // ── Contenu repliable ──────────────────────────────
          AnimatedCrossFade(
            firstChild: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: SingleChildScrollView(
                controller: _searchPanelScrollController,
                physics: const BouncingScrollPhysics(),
                child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                  const SizedBox(height: 16),

                  // ── Groupe Départ / Arrivée ──────────────────
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE8E8E8)),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 50, 12),
                              child: _buildVilleAutocomplete(
                                key: ValueKey('depart_$_autocompleteKey'),
                                label: 'Ville de départ',
                                icon: Icons.trip_origin_rounded,
                                iconColor: Colors.green,
                                selectedId: _villeDepartId,
                                onSelected: (id) {
                                  if (id != null) {
                                    setState(() {
                                      _villeDepartId = id;
                                      _gareDepartId = null;
                                    });
                                    _loadGares(id);
                                  } else {
                                    setState(() {
                                      _villeDepartId = null;
                                      _gareDepartId = null;
                                      _gares = [];
                                    });
                                  }
                                },
                                validator: (id) => id == null
                                    ? 'Sélectionnez une ville de départ'
                                    : null,
                                villesDisponibles: _villesCompagnie,
                              ),
                            ),
                            Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(horizontal: 14),
                              color: const Color(0xFFEEEEEE),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 50, 12),
                              child: _buildVilleAutocomplete(
                                key: ValueKey('arrivee_$_autocompleteKey'),
                                label: 'Ville d\'arrivée',
                                icon: Icons.location_on_rounded,
                                iconColor: Colors.red,
                                selectedId: _villeArriveeId,
                                onSelected: (id) => setState(() => _villeArriveeId = id),
                                validator: (id) {
                                  if (id == null) {
                                    return 'Sélectionnez une ville d\'arrivée';
                                  }
                                  if (id == _villeDepartId) {
                                    return 'Différente de la ville de départ';
                                  }
                                  return null;
                                },
                                villesDisponibles: _villesCompagnie,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ── Bouton swap fonctionnel ───────────────────
                      Positioned(
                        right: 10,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: _swapVilles,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _amber,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _amber.withValues(alpha: 0.45),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.swap_vert_rounded,
                                size: 20,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Sélection gare
                  if (_villeDepartId != null) ...[
                    _buildGareSelector(),
                    const SizedBox(height: 12),
                  ],

                  // Classe
                  _buildClasseSelector(),
                  const SizedBox(height: 12),

                  // Date de départ
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: Row(children: [
                        // Mini calendrier visuel
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _dateDepart.day.toString(),
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _amber,
                                    height: 1.0),
                              ),
                              Text(
                                _moisAbbr[_dateDepart.month - 1],
                                style: const TextStyle(
                                    fontSize: 9,
                                    color: _amber,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Date de départ',
                                  style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 3),
                              Text(
                                _formatDateFr(_dateDepart),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Modifier',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _amber)),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bouton rechercher
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _rechercherVoyages,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                          Colors.black87)))
                          : const Icon(Icons.search_rounded, size: 20),
                      label: Text(
                          _isLoading
                              ? 'Recherche…'
                              : 'Rechercher les voyages',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _amber,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
                ),
              ),
            ),
                _buildScrollMoreIndicator(),
              ],
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _isSearchExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 280),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  // ── Sélecteur de gare ────────────────────────────────────────────────────
  Widget _buildGareSelector() {
    if (_isLoadingGares) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_amber),
              strokeWidth: 2),
        ),
      );
    }

    if (_gares.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
        ),
        child: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
          SizedBox(width: 8),
          Expanded(
              child: Text('Aucune gare disponible pour cette ville',
                  style: TextStyle(fontSize: 13, color: Colors.orange))),
        ]),
      );
    }

    return FormField<String>(
      initialValue: _gareDepartId,
      validator: (v) => v == null ? 'Sélectionnez une gare de départ' : null,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Label ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.place_rounded, size: 14, color: _amber),
                ),
                const SizedBox(width: 8),
                Text('Gare de départ',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[800])),
                const Spacer(),
                Text('${_gares.length} disponible${_gares.length > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ]),
            ),

            // ── Liste des gares ────────────────────────────────────
            ..._gares.map<Widget>((gare) {
              final isSelected = _gareDepartId == gare.id.toString();
              final isVilleDepart = gare.villeId == _villeDepartId;
              final isVilleArrivee =
                  gare.villeId.isNotEmpty && gare.villeId == _villeArriveeId;

              return GestureDetector(
                onTap: () {
                  bool villeRemplie = false;
                  setState(() {
                    _gareDepartId = gare.id.toString();
                    villeRemplie = _autoFillVilleArrivee(gare);
                  });
                  state.didChange(gare.id.toString());
                  if (villeRemplie) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Text('Ville d\'arrivée : ${gare.ville}'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        backgroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                      ));
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFF8E1) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? _amber : const Color(0xFFEEEEEE),
                      width: isSelected ? 1.8 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? _amber.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.04),
                        blurRadius: isSelected ? 10 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // ── Indicateur sélection ───────────────────
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected ? _amber : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isSelected
                              ? Icons.check_rounded
                              : Icons.directions_bus_filled,
                          size: 18,
                          color: isSelected ? Colors.black87 : Colors.grey[400],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // ── Infos gare ─────────────────────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nom + badge ville départ
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    gare.nomGare,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? Colors.black87
                                          : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isVilleDepart) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: Colors.green.shade200),
                                    ),
                                    child: Text('Ville départ',
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ] else if (isVilleArrivee) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border:
                                          Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Text('Ville arrivée',
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ],
                            ),

                            // Adresse + ville (la ville doit toujours
                            // apparaitre : l'adresse brute -- souvent une
                            // saisie Google Places -- ne suffit pas a elle
                            // seule a identifier clairement la ville).
                            if (gare.adresseGare.isNotEmpty || gare.ville.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(children: [
                                Icon(Icons.location_on_outlined,
                                    size: 11, color: Colors.grey[400]),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                      [
                                        if (gare.adresseGare.isNotEmpty) gare.adresseGare,
                                        if (gare.ville.isNotEmpty &&
                                            !gare.adresseGare
                                                .toLowerCase()
                                                .contains(gare.ville.toLowerCase()))
                                          gare.ville,
                                      ].join(' · '),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500]),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ]),
                            ],

                            // Horaires
                            if (gare.heureOuverture.isNotEmpty &&
                                gare.heureFermeture.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(children: [
                                Icon(Icons.schedule_rounded,
                                    size: 11, color: Colors.grey[400]),
                                const SizedBox(width: 3),
                                Text(
                                  '${gare.heureOuverture} – ${gare.heureFermeture}',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[500]),
                                ),
                              ]),
                            ],
                          ],
                        ),
                      ),

                      // ── Badges WiFi / Parking ──────────────────
                      if (gare.wifiDisponible || gare.parkingDisponible) ...[
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (gare.wifiDisponible)
                              _buildBadge(Icons.wifi_rounded, Colors.blue, 'WiFi'),
                            if (gare.wifiDisponible && gare.parkingDisponible)
                              const SizedBox(height: 4),
                            if (gare.parkingDisponible)
                              _buildBadge(
                                  Icons.local_parking_rounded, Colors.indigo, 'P'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),

            // ── Erreur validation ──────────────────────────────────
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 13, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(state.errorText!,
                      style:
                          const TextStyle(color: Colors.red, fontSize: 12)),
                ]),
              ),
          ],
        );
      },
    );
  }

  Widget _buildClasseSelector() {
    if (_isLoadingClasses) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_amber),
                strokeWidth: 2)),
      );
    }

    if (_classes.isEmpty) return const SizedBox.shrink();

    final allClasses = <Map<String, dynamic>>[
      {'id': null, 'nom': 'Toutes', 'icon': Icons.select_all_rounded},
      ..._classes.map((c) => {
            'id': c['id']?.toString(),
            'nom': c['nom']?.toString() ?? c['libelle']?.toString() ?? '?',
            'icon': _classeIcon(c['nom']?.toString() ?? ''),
          }),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: _amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.airline_seat_recline_normal_rounded,
                  size: 14, color: _amber),
            ),
            const SizedBox(width: 8),
            Text('Classe de voyage',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800])),
            const Spacer(),
            Text('${allClasses.length - 1} classe${allClasses.length - 1 > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          ]),
        ),
        // Chips horizontaux scrollables
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: allClasses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final item = allClasses[i];
              final id = item['id'] as String?;
              final nom = item['nom'] as String;
              final icon = item['icon'] as IconData;
              final isSelected = _selectedClasseId == id;

              return GestureDetector(
                onTap: () => setState(() => _selectedClasseId = id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? _amber : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected ? _amber : const Color(0xFFE0E0E0),
                      width: isSelected ? 0 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: _amber.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon,
                          size: 15,
                          color: isSelected ? Colors.black87 : Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        nom,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected ? Colors.black87 : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDateFr(DateTime d) {
    const jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    const moisFull = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin',
                      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    return '${jours[d.weekday - 1]}. ${d.day} ${moisFull[d.month - 1]} ${d.year}';
  }

  IconData _classeIcon(String nom) {
    final n = nom.toLowerCase();
    if (n.contains('vip') || n.contains('luxe') || n.contains('premium')) {
      return Icons.star_rounded;
    }
    if (n.contains('business') || n.contains('affaire')) {
      return Icons.work_rounded;
    }
    if (n.contains('eco') || n.contains('standard') || n.contains('normal')) {
      return Icons.airline_seat_recline_normal_rounded;
    }
    if (n.contains('confort') || n.contains('comfort')) {
      return Icons.weekend_rounded;
    }
    return Icons.airline_seat_recline_extra_rounded;
  }

  Widget _buildBadge(IconData icon, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Autocomplete ville ────────────────────────────────────────────────────
  Widget _buildVilleAutocomplete({
    Key? key,
    required String label,
    required IconData icon,
    required Color iconColor,
    required String? selectedId,
    required void Function(String? id) onSelected,
    String? Function(String?)? validator,
    List<Ville>? villesDisponibles,
  }) {
    final sourceVilles = villesDisponibles ?? _villes;
    final initialVille = selectedId != null
        ? _villes.cast<Ville?>().firstWhere(
            (v) => v!.id.toString() == selectedId,
            orElse: () => null)
        : null;

    return Autocomplete<Ville>(
      key: key,
      initialValue: initialVille != null
          ? TextEditingValue(text: initialVille.nomVille)
          : null,
      displayStringForOption: (v) => v.nomVille,
      optionsBuilder: (textEditingValue) {
        final text = textEditingValue.text;
        if (text.isEmpty) return const Iterable<Ville>.empty();
        // Empêche le dropdown de réapparaître juste après la sélection
        if (selectedId != null) {
          final sel = _villes.cast<Ville?>().firstWhere(
            (v) => v!.id.toString() == selectedId,
            orElse: () => null);
          if (sel != null && sel.nomVille == text) {
            return const Iterable<Ville>.empty();
          }
        }
        return sourceVilles.where((v) => v.nomVille
            .toLowerCase()
            .contains(text.toLowerCase()));
      },
      onSelected: (ville) {
        onSelected(ville.id.toString());
        FocusScope.of(context).unfocus();
      },
      optionsViewBuilder: (context, onOptionSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(14),
            shadowColor: Colors.black.withValues(alpha: 0.12),
            color: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 52,
                    endIndent: 16,
                    color: Color(0xFFF0F0F0),
                  ),
                  itemBuilder: (context, index) {
                    final ville = options.elementAt(index);
                    return InkWell(
                      onTap: () => onOptionSelected(ville),
                      splashColor: _amber.withValues(alpha: 0.10),
                      highlightColor: _amber.withValues(alpha: 0.06),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        child: Row(children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 15, color: iconColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              ville.nomVille,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              size: 16, color: Colors.black26),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
      fieldViewBuilder:
          (context, textController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          style: const TextStyle(
              fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(10),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 52),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: textController,
              builder: (_, value, __) => value.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        textController.clear();
                        onSelected(null);
                      },
                      child: const Icon(Icons.close_rounded,
                          size: 17, color: Colors.grey),
                    )
                  : const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.black26, size: 20),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 15),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _amber, width: 1.8)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1.8)),
          ),
          validator:
              validator != null ? (_) => validator(selectedId) : null,
          onTapOutside: (_) {
            FocusScope.of(context).unfocus();
            // Un texte laisse dans le champ sans correspondre a une ville
            // proposee (ni a la selection en cours) est efface : on ne
            // peut pas valider autre chose qu'une ville reellement
            // disponible pour cette compagnie.
            final texte = textController.text.trim();
            if (texte.isEmpty) return;
            final correspond = sourceVilles.any(
                (v) => v.nomVille.toLowerCase() == texte.toLowerCase());
            if (!correspond) {
              textController.clear();
              onSelected(null);
            }
          },
        );
      },
    );
  }

  // ── État de chargement : spinner + skeleton ───────────────────────────────
  Widget _buildLoadingState(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Bandeau spinner + libellé
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(_amber)),
              ),
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54)),
            ],
          ),
        ),
        // Cartes fantômes
        ...List.generate(3, (_) => const SkeletonVoyageCard()),
      ],
    );
  }

  Widget _buildResultsHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Text('Voyages disponibles',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const Spacer(),
          if (_voyages.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                  '${_voyages.length} résultat${_voyages.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87)),
            ),
        ],
      ),
    );
  }

  // ── Carte voyage ──────────────────────────────────────────────────────────
  Widget _buildVoyageCard(Map<String, dynamic> voyage) {
    final heureDepart =
        (voyage['heure_depart']?.toString() ?? '').length >= 5
            ? voyage['heure_depart'].toString().substring(0, 5)
            : voyage['heure_depart']?.toString() ?? '--:--';
    final dateDepart = voyage['date_depart']?.toString() ?? '';
    final villeDepart = voyage['ville_depart']?['nom_ville'] ?? 'Inconnue';
    final villeArrivee = voyage['ville_arrivee']?['nom_ville'] ?? 'Inconnue';
    final montant = voyage['montant'];
    final montantFormatted = montant != null
        ? NumberFormat.decimalPattern('fr')
            .format(double.tryParse(montant.toString()) ?? 0)
        : null;
    final disponibleToujoursValue = voyage['disponible_toujours'];
    final disponibleToujours = disponibleToujoursValue?.toString() == '1' ||
        disponibleToujoursValue == true;
    final bus = voyage['bus'] is Map ? voyage['bus'] as Map : null;
    final classeNom = voyage['classe']?['nom'] as String?;
    final dureeVoyage = voyage['duree_voyage']?.toString();
    final bool canReserve = bus != null && voyage['id'] != null;

    void onReserver() {
      final isConnected =
          context.read<ConnectivityService>().isConnected;
      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pas de connexion Internet.\nVérifiez votre Wi-Fi ou vos données mobiles.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }
      if (!canReserve) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Informations manquantes'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      final vDepart = _villes
          .firstWhere((v) => v.id.toString() == _villeDepartId,
              orElse: () => Ville(
                  id: 0,
                  nomVille: 'Inconnue',
                  status: 'active',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now()))
          .nomVille;
      final vArrivee = _villes
          .firstWhere((v) => v.id.toString() == _villeArriveeId,
              orElse: () => Ville(
                  id: 0,
                  nomVille: 'Inconnue',
                  status: 'active',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now()))
          .nomVille;
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SelectionSiegePage(
              busId: int.tryParse(bus['id']?.toString() ?? '0') ?? 0,
              voyageId: int.tryParse(voyage['id']?.toString() ?? '0') ?? 0,
              nombrePlaces:
                  int.tryParse(bus['nombre_places']?.toString() ?? '0') ?? 0,
              montant:
                  double.tryParse(voyage['montant']?.toString() ?? '0') ?? 0.0,
              arretId: (voyage['itineraire']?['arrets'] as List?)
                      ?.first?['id'] ??
                  0,
              villeDepart: vDepart,
              villeArrivee: vArrivee,
              dateDepart: _dateDepart.toString().split(' ')[0],
              heureDepart: voyage['heure_depart'] ?? '00:00',
              marqueBus: bus['marque_bus'] ?? 'Inconnue',
              immatriculationBus: bus['immatriculation_bus'] ?? 'Inconnue',
              classe: voyage['classe']?['nom'],
              disponibleToujours: disponibleToujours,
              dureeVoyage: voyage['duree_voyage']?.toString(),
            ),
          ));
    }

    // Bus photos (kept for tap-to-view on photo chip)
    final photos = bus != null ? _getBusPhotos(bus['photo_bus']) : <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // ── Header : heure · disponibilité · prix ──────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFDE7),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 0),
                // Disponibilité
                if (disponibleToujours)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Tous les jours',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.w600)),
                  )
                else if (dateDepart.isNotEmpty)
                  Text(dateDepart.split('-').reversed.join('/'),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const Spacer(),
                // Prix + label
                if (montantFormatted != null)
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$montantFormatted FCFA',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    const Text('par personne',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ]),
              ],
            ),
          ),

          // ── Itinéraire : départ ─── durée ─── arrivée ──────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    // Ville départ
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.circle, size: 10, color: Colors.green),
                          const SizedBox(height: 4),
                          Text(villeDepart,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: Colors.black87),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    // Centre : lignes + bus icon
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 18, height: 1.5, color: Colors.grey[300]),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.directions_bus_rounded,
                              size: 14, color: _amber),
                        ),
                        Container(width: 18, height: 1.5, color: Colors.grey[300]),
                      ]),
                    ),
                    // Ville arrivée
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 10, color: Colors.red),
                          const SizedBox(height: 4),
                          Text(villeArrivee,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: Colors.black87),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // ── Ligne heure départ · durée · heure arrivée ──────────
                Row(
                  children: [
                    // Heure départ
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                        children: [
                          const TextSpan(text: 'Heure départ : '),
                          TextSpan(
                            text: heureDepart,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Durée trajet
                    if (dureeVoyage != null)
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                          children: [
                            const TextSpan(text: 'Trajet : '),
                            TextSpan(
                              text: dureeVoyage,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Pied : bus info + bouton Réserver ──────────────────────────
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                // Miniature photo si disponible, sinon icône bus
                GestureDetector(
                  onTap: photos.isNotEmpty ? () => _showBusImages(photos) : null,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: photos.isNotEmpty
                            ? Image.network(photos.first,
                                width: 46,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _busIconBox())
                            : _busIconBox(),
                      ),
                      if (photos.length > 1)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 3, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text('${photos.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Immatriculation · marque + places · classe
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    if (bus != null)
                      Text(
                        [
                          bus['immatriculation_bus']?.toString(),
                          bus['marque_bus']?.toString(),
                        ]
                            .where((s) => s != null && s.isNotEmpty)
                            .join(' · '),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 3),
                    Row(children: [
                      if (bus != null) ...[
                        const Icon(Icons.event_seat_rounded,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text('${bus['nombre_places'] ?? '0'} places',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                      if (classeNom != null) ...[
                        if (bus != null)
                          const Text(' · ',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(classeNom,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500)),
                      ],
                    ]),
                  ]),
                ),
                const SizedBox(width: 10),
                // Bouton Voir trajet
                _buildTrajetButton(voyage),
                const SizedBox(width: 6),
                // Bouton Réserver compact
                ElevatedButton.icon(
                  onPressed: onReserver,
                  icon: const Icon(Icons.confirmation_number_rounded, size: 15),
                  label: const Text('Réserver',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _amber,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrajetButton(Map<String, dynamic> voyage) {
    final gareDepData = voyage['gare_depart_data'];
    final gareArrData = voyage['gare_arrivee_data'];
    final hasMap = gareDepData is Map && gareArrData is Map &&
        (gareDepData['latitude']?.toString() ?? '').isNotEmpty &&
        (gareArrData['latitude']?.toString() ?? '').isNotEmpty;

    if (!hasMap) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        gare1.Gare buildGare(Map g) => gare1.Gare(
          id: int.tryParse(g['id']?.toString() ?? '0') ?? 0,
          infoUserId: 0, compagnieId: 0, villeId: 0,
          latitude: g['latitude']?.toString() ?? '0',
          longitude: g['longitude']?.toString() ?? '0',
          heureOuverture: '', heureFermeture: '',
          parkingDisponible: false, wifiDisponible: false,
          nomGare: g['nom_gare']?.toString() ?? 'Gare',
          status: '', createdAt: '', updatedAt: '', ville: null,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GareMapPage.itinerary(
              gareDepart: buildGare(gareDepData),
              gareArrive: buildGare(gareArrData),
              title: '${gareDepData['nom_gare'] ?? ''} → ${gareArrData['nom_gare'] ?? ''}',
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Icon(Icons.map_rounded, size: 18, color: Colors.blue[700]),
      ),
    );
  }

  Widget _busIconBox() => Container(
        width: 46,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.directions_bus_rounded,
            size: 18, color: Colors.blueGrey),
      );

  // ── Hint de recherche (état initial) ─────────────────────────────────────
  Widget _buildSearchHint() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_bus_rounded,
                size: 52, color: _amber),
          ),
          const SizedBox(height: 16),
          const Text(
            'Trouvez votre prochain voyage',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Renseignez vos villes de départ et d\'arrivée\npuis lancez la recherche.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          // Indicateurs d'étapes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStep('1', 'Ville départ', Colors.green),
              _buildStepDivider(),
              _buildStep('2', 'Ville arrivée', Colors.red),
              _buildStepDivider(),
              _buildStep('3', 'Date', _amber),
              _buildStepDivider(),
              _buildStep('4', 'Rechercher', Colors.black87),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String num, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(num,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildStepDivider() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
      child: Container(width: 18, height: 1, color: Colors.grey[300]),
    );
  }

  // ── État vide ─────────────────────────────────────────────────────────────
  Widget _buildEmptyVoyages() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)
        ],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(Icons.directions_bus_rounded,
              size: 48, color: Colors.grey[400]),
        ),
        const SizedBox(height: 16),
        const Text('Aucun voyage trouvé',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 8),
        Text(
            'Aucun voyage ne correspond à vos critères.\nEssayez une autre date ou destination ou modifiez vos critères.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
      ]),
    );
  }
}

// ── Widget animé pour les cartes de voyage ────────────────────────────────────
class _AnimatedVoyageCard extends StatefulWidget {
  final Widget child;
  final int index;

  const _AnimatedVoyageCard({required this.child, required this.index});

  @override
  State<_AnimatedVoyageCard> createState() => _AnimatedVoyageCardState();
}

class _AnimatedVoyageCardState extends State<_AnimatedVoyageCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Délai staggeré : 80ms par carte
    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

// ── Visionneuse photos bus ─────────────────────────────────────────────────
class _BusImageViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _BusImageViewer({required this.urls, this.initialIndex = 0});

  @override
  State<_BusImageViewer> createState() => _BusImageViewerState();
}

class _BusImageViewerState extends State<_BusImageViewer> {
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: widget.urls.length > 1
            ? Text('${_current + 1} / ${widget.urls.length}',
                style: const TextStyle(color: Colors.white, fontSize: 14))
            : null,
      ),
      body: PageView.builder(
        itemCount: widget.urls.length,
        controller: PageController(initialPage: widget.initialIndex),
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.network(
              widget.urls[i],
              fit: BoxFit.contain,
              loadingBuilder: (_, child, prog) {
                if (prog == null) return child;
                return const Center(
                    child: CircularProgressIndicator(color: Colors.amber));
              },
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.error, color: Colors.red, size: 50),
            ),
          ),
        ),
      ),
    );
  }
}
