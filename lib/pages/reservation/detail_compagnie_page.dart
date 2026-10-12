import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/widgets/app_date_picker.dart';
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
import '../../core/utils/error_helper.dart';
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
  String? _gareArriveeId;
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
  // Palette du formulaire de recherche (tons chauds, cf. maquette web).
  static const _ink = Color(0xFF1C1A17);
  static const _sand = Color(0xFFF4F2EE);
  static const _muted = Color(0xFF8F897F);
  static const _placeholder = Color(0xFFB3ADA3);
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

  Future<void> _loadGares(String villeId, {bool preserverGareDepart = false}) async {
    if (villeId.isEmpty) return;
    setState(() {
      _isLoadingGares = true;
      if (!preserverGareDepart) _gareDepartId = null;
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
              content: Text('Erreur: ${ErrorHelper.cleanErrorMessage(e.toString())}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _swapVilles() {
    final tempVilleId = _villeDepartId;
    final tempGareId = _gareDepartId;
    setState(() {
      _villeDepartId = _villeArriveeId;
      _villeArriveeId = tempVilleId;
      // La gare sélectionnée suit sa ville pour rester cohérente avec la
      // modale filtrée par ville.
      _gareDepartId = _gareArriveeId;
      _gareArriveeId = tempGareId;
      _autocompleteKey++;
    });
    if (_villeDepartId != null) {
      _loadGares(_villeDepartId!, preserverGareDepart: true);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final aujourdhui = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _dateDepart,
      // Pas de départ dans le passé.
      firstDate: aujourdhui,
      lastDate: aujourdhui.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dateDepart = picked);
  }

  // Même serveur que l'API (sans le suffixe /api).
  static final String _imageBaseUrl = ApiService.baseUrl.replaceAll(RegExp(r'/api$'), '');

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
                    child: LayoutBuilder(builder: (context, zone) => Stack(
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
                          child: _buildSearchCard(context, zone.maxHeight),
                        ),
                      ],
                    )),
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
                        child: NetImage(widget.compagnie.logoUrl!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            error: (_) =>
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
  /// [hauteurDispo] : hauteur de la zone sous l'en-tête. Le formulaire
  /// déplié peut l'occuper entièrement avant de défiler.
  Widget _buildSearchCard(BuildContext context, double hauteurDispo) {
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
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
              child: Row(children: [
                const Expanded(
                  child: Text('Où allez-vous ?',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: _ink)),
                ),
                AnimatedRotation(
                  turns: _isSearchExpanded ? 0 : -0.5,
                  duration: const Duration(milliseconds: 250),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: _muted, size: 24),
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
                // Marges (8 en haut, 16 en bas) + en-tête de la carte (~56).
                maxHeight: (hauteurDispo - 80).clamp(120.0, double.infinity),
              ),
              child: SingleChildScrollView(
                controller: _searchPanelScrollController,
                physics: const BouncingScrollPhysics(),
                child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Itinéraire Départ / Arrivée ──────────────
                  _buildItineraire(),
                  const SizedBox(height: 20),

                  // Sélection gare (modale par ville, déclenchée après le
                  // choix de la ville et rappelable via ces résumés).
                  if (_villeDepartId != null) ...[
                    _buildGareSummaryRow(
                      label: 'Gare de départ',
                      icon: Icons.place_rounded,
                      gare: _findGare(_gareDepartId),
                      onTap: () => _openGareModal(isDepart: true),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_villeArriveeId != null) ...[
                    _buildGareSummaryRow(
                      label: "Gare d'arrivée",
                      icon: Icons.flag_rounded,
                      gare: _findGare(_gareArriveeId),
                      onTap: () => _openGareModal(isDepart: false),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Date de départ
                  _sectionLabel('Date de départ'),
                  _buildDateStrip(),
                  const SizedBox(height: 20),

                  // Classe
                  _buildClasseSelector(),
                  const SizedBox(height: 20),

                  // Bouton rechercher
                  SizedBox(
                    width: double.infinity,
                    height: 54,
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
                        foregroundColor: _ink,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
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

  // ── Résumé gare (départ / arrivée) — ouvre la modale filtrée par ville ────
  Gare? _findGare(String? id) {
    if (id == null) return null;
    return _gares.cast<Gare?>().firstWhere(
        (g) => g!.id.toString() == id, orElse: () => null);
  }

  String? _villeNom(String? id) {
    if (id == null) return null;
    return [..._villesCompagnie, ..._villes]
        .cast<Ville?>()
        .firstWhere((v) => v!.id.toString() == id, orElse: () => null)
        ?.nomVille;
  }

  Widget _buildGareSummaryRow({
    required String label,
    required IconData icon,
    required Gare? gare,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: _amber),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500])),
                  Text(' · facultatif',
                      style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                ]),
                const SizedBox(height: 2),
                Text(
                  gare?.nomGare ?? 'Toutes les gares',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: gare != null ? _ink : _placeholder),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
        ]),
      ),
    );
  }

  /// Ouvre la modale de sélection de gare, filtrée sur la seule ville
  /// concernée (départ ou arrivée) — jamais un mélange des deux.
  Future<void> _openGareModal({required bool isDepart}) async {
    final villeId = isDepart ? _villeDepartId : _villeArriveeId;
    if (villeId == null) return;

    if (_gares.isEmpty && !_isLoadingGares) {
      await _loadGares(villeId, preserverGareDepart: true);
      if (!mounted) return;
    }

    final gares = _gares.where((g) => g.villeId == villeId).toList();
    final currentId = isDepart ? _gareDepartId : _gareArriveeId;

    final result = await _showGareModal(
      title: isDepart ? 'Gare de départ' : "Gare d'arrivée",
      subtitle: _villeNom(villeId),
      gares: gares,
      selectedId: currentId,
    );
    if (!mounted || result == null) return;

    setState(() {
      final id = result == _GareModalSheet.clearValue ? null : result;
      if (isDepart) {
        _gareDepartId = id;
      } else {
        _gareArriveeId = id;
      }
    });
  }

  Future<String?> _showGareModal({
    required String title,
    String? subtitle,
    required List<Gare> gares,
    required String? selectedId,
  }) {
    FocusScope.of(context).unfocus();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      builder: (_) => _GareModalSheet(
        title: title,
        subtitle: subtitle,
        gares: gares,
        selectedId: selectedId,
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
    );
  }

  Widget _buildClasseSelector() {
    if (_isLoadingClasses) {
      return const AppShimmer(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SkBox(width: 60, height: 14),
          SizedBox(height: 10),
          SkBox(width: double.infinity, height: 48, radius: 14),
        ]),
      );
    }

    if (_classes.isEmpty) return const SizedBox.shrink();

    final options = <({String? id, String nom})>[
      (id: null, nom: 'Toutes'),
      ..._classes.map((c) => (
            id: c['id']?.toString(),
            nom: c['nom']?.toString() ?? c['libelle']?.toString() ?? '?',
          )),
    ];

    Widget segment(({String? id, String nom}) o) {
      final isSelected = _selectedClasseId == o.id;
      return GestureDetector(
        onTap: () => setState(() => _selectedClasseId = o.id),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ]
                : const [],
          ),
          child: Text(
            o.nom,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? _ink : _muted,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Classe'),
        Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _sand,
            borderRadius: BorderRadius.circular(14),
          ),
          // Jusqu'à 3 options : segments de largeur égale ; au-delà,
          // défilement horizontal pour ne pas écraser les libellés.
          child: options.length <= 3
              ? Row(
                  children: options
                      .map((o) => Expanded(child: segment(o)))
                      .toList(),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 4),
                  itemBuilder: (_, i) => segment(options[i]),
                ),
        ),
      ],
    );
  }

  // ── Bande de dates ────────────────────────────────────────────────────────
  static const _joursAbbr = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  Widget _buildDateStrip() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected =
        DateTime(_dateDepart.year, _dateDepart.month, _dateDepart.day);
    final days = List.generate(14, (i) => today.add(Duration(days: i)));
    final horsBande = !days.contains(selected);

    Widget chip({
      required String top,
      required String bottom,
      required bool isSelected,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 74,
          decoration: BoxDecoration(
            color: isSelected ? _ink : _sand,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(top,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? _amber : _ink)),
            const SizedBox(height: 2),
            Text(bottom,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: isSelected ? _amber : _ink)),
          ]),
        ),
      );
    }

    return SizedBox(
      height: 70,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < days.length; i++) ...[
            chip(
              top: i == 0
                  ? 'Auj.'
                  : i == 1
                      ? 'Demain'
                      : _joursAbbr[days[i].weekday - 1],
              bottom: '${days[i].day}',
              isSelected: days[i] == selected,
              onTap: () => setState(() => _dateDepart = days[i]),
            ),
            const SizedBox(width: 8),
          ],
          // Date plus lointaine : calendrier complet.
          horsBande
              ? chip(
                  top: _moisAbbr[selected.month - 1],
                  bottom: '${selected.day}',
                  isSelected: true,
                  onTap: () => _selectDate(context),
                )
              : GestureDetector(
                  onTap: () => _selectDate(context),
                  child: Container(
                    width: 74,
                    decoration: BoxDecoration(
                      color: _sand,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month_rounded,
                              size: 20, color: _ink),
                          SizedBox(height: 4),
                          Text('Autre',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _ink)),
                        ]),
                  ),
                ),
        ],
      ),
    );
  }

  // ── Itinéraire Départ / Arrivée ───────────────────────────────────────────
  Widget _buildItineraire() {
    return Container(
      decoration: BoxDecoration(
        color: _sand,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(children: [
        // Ligne de temps : départ (cercle) → arrivée (carré ambre)
        Column(children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _ink, width: 2),
            ),
          ),
          Container(width: 2, height: 46, color: const Color(0xFFD9D4CB)),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _amber,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Column(children: [
            _buildVilleField(
              key: ValueKey('depart_$_autocompleteKey'),
              label: 'Départ',
              sheetTitle: 'Ville de départ',
              selectedId: _villeDepartId,
              // La ville d'arrivée n'est pas proposée au départ
              excludeId: _villeArriveeId,
              onSelected: (id) async {
                setState(() {
                  _villeDepartId = id;
                  _gareDepartId = null;
                  _gareArriveeId = null;
                });
                await _loadGares(id);
                if (!mounted) return;
                await _openGareModal(isDepart: true);
              },
              validator: (id) =>
                  id == null ? 'Sélectionnez une ville de départ' : null,
            ),
            const Divider(height: 1, color: Color(0xFFE6E1D8)),
            _buildVilleField(
              key: ValueKey('arrivee_$_autocompleteKey'),
              label: 'Arrivée',
              sheetTitle: "Ville d'arrivée",
              selectedId: _villeArriveeId,
              // La ville de départ n'est pas proposée à l'arrivée
              excludeId: _villeDepartId,
              onSelected: (id) async {
                setState(() {
                  _villeArriveeId = id;
                  _gareArriveeId = null;
                });
                await _openGareModal(isDepart: false);
              },
              validator: (id) {
                if (id == null) return "Sélectionnez une ville d'arrivée";
                if (id == _villeDepartId) {
                  return 'Différente de la ville de départ';
                }
                return null;
              },
            ),
          ]),
        ),
        // Inversion départ / arrivée
        IconButton(
          onPressed: _swapVilles,
          tooltip: 'Inverser',
          icon: const Icon(Icons.swap_vert_rounded, size: 20, color: _ink),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(10),
          ),
        ),
      ]),
    );
  }

  Widget _buildVilleField({
    Key? key,
    required String label,
    required String sheetTitle,
    required String? selectedId,
    String? excludeId,
    required void Function(String id) onSelected,
    required String? Function(String?) validator,
  }) {
    // Villes de la compagnie d'abord : la liste générale peut ne pas
    // être encore chargée (ou avoir échoué).
    final ville = selectedId == null
        ? null
        : [..._villesCompagnie, ..._villes].cast<Ville?>().firstWhere(
            (v) => v!.id.toString() == selectedId,
            orElse: () => null);

    return FormField<String>(
      key: key,
      initialValue: selectedId,
      validator: (_) => validator(selectedId),
      builder: (state) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final id = await _showVillePicker(sheetTitle, selectedId, excludeId);
          if (id == null) return;
          onSelected(id);
          state.didChange(id);
          // Efface le message d'erreur dès qu'une ville est choisie.
          if (state.hasError) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => state.validate());
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: _muted)),
                const SizedBox(height: 2),
                Text(
                  ville?.nomVille ?? 'Choisir une ville',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: ville != null ? _ink : _placeholder,
                  ),
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(state.errorText!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _sansAccents(String s) {
    const de = 'àâäáãéèêëíìîïóòôöõúùûüçñ';
    const vers = 'aaaaaeeeeiiiiooooouuuucn';
    final b = StringBuffer();
    for (final c in s.toLowerCase().split('')) {
      final i = de.indexOf(c);
      b.write(i >= 0 ? vers[i] : c);
    }
    return b.toString();
  }

  /// Feuille de sélection d'une ville parmi celles desservies par la compagnie.
  /// [excludeId] : ville déjà choisie de l'autre côté (départ ≠ arrivée).
  Future<String?> _showVillePicker(
      String title, String? selectedId, String? excludeId) {
    FocusScope.of(context).unfocus();
    final villes = _villesCompagnie;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      builder: (ctx) {
        var query = '';
        return StatefulBuilder(builder: (ctx, setSheet) {
          final q = _sansAccents(query.trim());
          final filtered = villes
              .where((v) => v.id.toString() != excludeId)
              .where((v) => _sansAccents(v.nomVille).contains(q))
              .toList();
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 10, bottom: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0DCD4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: _ink)),
                ),
                Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                    child: TextField(
                      onChanged: (v) => setSheet(() => query = v),
                      decoration: InputDecoration(
                        hintText: 'Rechercher une ville',
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: _muted, size: 20),
                        filled: true,
                        fillColor: _sand,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 12, 24, 32),
                    child: Text('Aucune ville disponible',
                        style: TextStyle(color: _muted)),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(ctx).padding.bottom + 12),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final v = filtered[i];
                        final isSelected = v.id.toString() == selectedId;
                        return InkWell(
                          onTap: () => Navigator.pop(ctx, v.id.toString()),
                          child: Container(
                            color: isSelected
                                ? const Color(0xFFFAF6EC)
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            child: Row(children: [
                              Expanded(
                                child: Text(v.nomVille,
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: _ink)),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_rounded,
                                    size: 20, color: _amber),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        });
      },
    );
  }

  // ── État de chargement : spinner + skeleton ───────────────────────────────
  Widget _buildLoadingState(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Libellé de chargement
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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

  /// Formate une date ISO (yyyy-MM-dd) pour l'affichage sur une carte
  /// voyage : « Aujourd'hui » si c'est la date du jour, sinon dd/MM.
  String _formatVoyageDate(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate.split('-').reversed.join('/');
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return "Aujourd'hui";
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
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
                // Date du voyage (celle recherchée pour les rares voyages
                // legacy « toujours disponible », sans date propre).
                Text(
                  _formatVoyageDate(dateDepart.isNotEmpty
                      ? dateDepart
                      : _dateDepart.toString().split(' ')[0]),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
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
                            ? NetImage(photos.first,
                                width: 46,
                                height: 36,
                                fit: BoxFit.cover,
                                error: (_) => _busIconBox())
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
            child: NetImage(
              widget.urls[i],
              fit: BoxFit.contain,
              dark: true,
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.8,
              error: (_) =>
                  const Icon(Icons.error, color: Colors.red, size: 50),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Modale de sélection de gare (départ ou arrivée) ─────────────────────────
/// Toujours filtrée sur une seule ville : jamais de mélange départ/arrivée.
/// Entrée animée en cascade des cartes + recherche locale.
class _GareModalSheet extends StatefulWidget {
  /// Valeur renvoyée par [Navigator.pop] quand l'utilisateur choisit
  /// explicitement « Toutes les gares » (à distinguer d'une fermeture sans
  /// choix, qui renvoie `null`).
  static const clearValue = '__all__';

  final String title;
  final String? subtitle;
  final List<Gare> gares;
  final String? selectedId;

  const _GareModalSheet({
    required this.title,
    this.subtitle,
    required this.gares,
    required this.selectedId,
  });

  @override
  State<_GareModalSheet> createState() => _GareModalSheetState();
}

class _GareModalSheetState extends State<_GareModalSheet>
    with SingleTickerProviderStateMixin {
  static const _amber = Color(0xFFFFC107);
  static const _ink = Color(0xFF1C1A17);
  static const _sand = Color(0xFFF4F2EE);
  static const _muted = Color(0xFF8F897F);

  late final AnimationController _ctrl;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static String _sansAccents(String s) {
    const de = 'àâäáãéèêëíìîïóòôöõúùûüçñ';
    const vers = 'aaaaaeeeeiiiiooooouuuucn';
    final b = StringBuffer();
    for (final c in s.toLowerCase().split('')) {
      final i = de.indexOf(c);
      b.write(i >= 0 ? vers[i] : c);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final q = _sansAccents(_query.trim());
    final filtered = q.isEmpty
        ? widget.gares
        : widget.gares
            .where((g) =>
                _sansAccents(g.nomGare).contains(q) ||
                _sansAccents(g.adresseGare).contains(q))
            .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE0DCD4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: _ink)),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(widget.subtitle!,
                            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                      ],
                    ],
                  ),
                ),
                Text(
                    '${widget.gares.length} disponible${widget.gares.length > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Rechercher une gare',
                prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 20),
                filled: true,
                fillColor: _sand,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                    child: Text(
                        widget.gares.isEmpty
                            ? 'Aucune gare disponible pour cette ville'
                            : 'Aucun résultat pour « $_query »',
                        style: const TextStyle(color: _muted)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(
                        16, 4, 16, MediaQuery.of(context).padding.bottom + 16),
                    // +1 pour l'option "Toutes les gares" en tête de liste.
                    itemCount: filtered.length + 1,
                    itemBuilder: (_, i) {
                      final child = i == 0
                          ? _buildAllOption()
                          : _buildGareCard(filtered[i - 1]);
                      return _staggered(i, child);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _staggered(int index, Widget child) {
    final start = (index * 0.06).clamp(0.0, 0.7);
    final anim = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(start, (start + 0.35).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, c) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * 14),
          child: c,
        ),
      ),
      child: child,
    );
  }

  Widget _buildAllOption() {
    final isSelected = widget.selectedId == null;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.pop(context, _GareModalSheet.clearValue),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF8E1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _amber : const Color(0xFFEEEEEE),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected ? _amber : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isSelected ? Icons.check_rounded : Icons.apps_rounded,
              size: 18,
              color: isSelected ? Colors.black87 : Colors.grey[400],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Toutes les gares',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: Colors.black87)),
          ),
        ]),
      ),
    );
  }

  Widget _buildGareCard(Gare gare) {
    final isSelected = widget.selectedId == gare.id.toString();
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.pop(context, gare.id.toString()),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
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
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected ? _amber : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isSelected ? Icons.check_rounded : Icons.directions_bus_filled,
              size: 18,
              color: isSelected ? Colors.black87 : Colors.grey[400],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gare.nomGare,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: Colors.black87),
                    overflow: TextOverflow.ellipsis),
                if (gare.adresseGare.isNotEmpty || gare.ville.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 11, color: Colors.grey[400]),
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
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ],
                if (gare.heureOuverture.isNotEmpty && gare.heureFermeture.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.schedule_rounded, size: 11, color: Colors.grey[400]),
                    const SizedBox(width: 3),
                    Text('${gare.heureOuverture} – ${gare.heureFermeture}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ]),
                ],
              ],
            ),
          ),
          if (gare.wifiDisponible || gare.parkingDisponible) ...[
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (gare.wifiDisponible)
                  _badge(Icons.wifi_rounded, Colors.blue, 'WiFi'),
                if (gare.wifiDisponible && gare.parkingDisponible)
                  const SizedBox(height: 4),
                if (gare.parkingDisponible)
                  _badge(Icons.local_parking_rounded, Colors.indigo, 'P'),
              ],
            ),
          ],
        ]),
      ),
    );
  }

  Widget _badge(IconData icon, Color color, String label) {
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
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
