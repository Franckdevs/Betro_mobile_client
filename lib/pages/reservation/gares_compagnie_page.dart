import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../models/gare_model.dart';
import '../../services/api_service.dart';
import '../../core/widgets/shimmer_skeleton.dart';
import '../../core/utils/logger.dart';

class GaresCompagniePage extends StatefulWidget {
  final int compagnieId;
  final String compagnieNom;

  const GaresCompagniePage({
    super.key,
    required this.compagnieId,
    required this.compagnieNom,
  });

  @override
  State<GaresCompagniePage> createState() => _GaresCompagniePageState();
}

class _GaresCompagniePageState extends State<GaresCompagniePage>
    with SingleTickerProviderStateMixin {
  static const _amber = Color(0xFFFFC107);

  List<Gare> _gares = [];
  List<Gare> _filteredGares = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String? _selectedVille;

  late final AnimationController _enterCtrl;
  late final Animation<Offset> _slideHeader;
  late final Animation<double> _fadeHeader;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideHeader = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _fadeHeader = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _enterCtrl.forward();
    _loadGares();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGares() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final url = '${ApiService.baseUrl}/liste_gare_compagnie/${widget.compagnieId}';
    logDebug('[GARES_PAGE] ── GET $url');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      logDebug('[GARES_PAGE] ── STATUS: ${response.statusCode}');
      logDebug('[GARES_PAGE] ── BODY  : ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final garesList = (data['data'] as List).cast<Map<String, dynamic>>();
          logDebug('[GARES_PAGE] ── ${garesList.length} gare(s) reçue(s)');
          setState(() {
            _gares = garesList.map((g) => Gare.fromJson(g)).toList();
            _filteredGares = List.from(_gares);
          });
        } else {
          final msg = data['message'] ?? 'Erreur lors du chargement des gares';
          logDebug('[GARES_PAGE] ── success=false  message=$msg');
          setState(() => _errorMessage = msg);
        }
      } else {
        logDebug('[GARES_PAGE] ── Erreur HTTP ${response.statusCode}');
        setState(() => _errorMessage = 'Erreur serveur (${response.statusCode})');
      }
    } catch (e) {
      logDebug('[GARES_PAGE] ── EXCEPTION: $e');
      setState(() => _errorMessage = 'Erreur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterGares(String? ville) {
    setState(() {
      _selectedVille = ville;
      _filteredGares = ville == null
          ? List.from(_gares)
          : _gares.where((g) => g.ville == ville).toList();
    });
  }

  Future<void> _openItineraire(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Veuillez installer Google Maps pour afficher l'itinéraire.",
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }


  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir l'URL")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final villes = _gares.map((g) => g.ville).toSet().toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Header animé ──────────────────────────────────────
          SlideTransition(
            position: _slideHeader,
            child: FadeTransition(
              opacity: _fadeHeader,
              child: _buildHeader(context, villes),
            ),
          ),
          // ── Body ──────────────────────────────────────────────
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, List<String> villes) {
    return Container(
      decoration: const BoxDecoration(
        color: _amber,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre + retour
              Row(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.compagnieNom,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_gares.isNotEmpty)
                          Text(
                            '${_gares.length} gare${_gares.length > 1 ? 's' : ''} · ${villes.length} ville${villes.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              // Chips filtre villes
              if (villes.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // Chip "Toutes"
                      _filterChip(null, 'Toutes', villes),
                      ...villes.map((v) => _filterChip(v, v, villes)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String? value, String label, List<String> villes) {
    final isSelected = _selectedVille == value;
    return GestureDetector(
      onTap: () => _filterGares(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black87 : Colors.black.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: 8,
        itemBuilder: (_, __) => const SkeletonGareCard(),
      );
    }
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, size: 48, color: Colors.red),
            ),
            const SizedBox(height: 16),
            const Text('Erreur de chargement',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_errorMessage,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadGares,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _amber,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }
    if (_gares.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _amber.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.departure_board_outlined,
                  size: 48, color: _amber),
            ),
            const SizedBox(height: 16),
            const Text('Aucune gare disponible',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Cette compagnie n\'a pas encore de gares enregistrées',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }
    if (_filteredGares.isEmpty) {
      return Center(
        child: Text(
          'Aucune gare pour "$_selectedVille"',
          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGares,
      color: _amber,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _filteredGares.length,
        itemBuilder: (context, index) {
          return _StaggerItem(
            index: index,
            child: _buildGareCard(_filteredGares[index]),
          );
        },
      ),
    );
  }

  // ── Carte gare ─────────────────────────────────────────────────────────────
  Widget _buildGareCard(Gare gare) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête carte ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icône gare
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.departure_board_rounded,
                      color: _amber, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gare.nomGare,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Badge ville
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _amber.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          gare.ville,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF7A5800),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Infos ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                if (gare.adresseGare.isNotEmpty)
                  _infoRow(Icons.location_on_outlined, gare.adresseGare,
                      Colors.blue),
                if (gare.heureOuverture.isNotEmpty &&
                    gare.heureFermeture.isNotEmpty)
                  _infoRow(Icons.access_time_rounded,
                      '${gare.heureOuverture} – ${gare.heureFermeture}',
                      Colors.orange),
                if (gare.nomJourOuverture.isNotEmpty &&
                    gare.nomJourFermeture.isNotEmpty)
                  _infoRow(
                    Icons.calendar_today_outlined,
                    gare.nomJourOuverture
                            .toLowerCase()
                            .contains('tous')
                        ? gare.nomJourOuverture
                        : 'Du ${gare.nomJourOuverture} au ${gare.nomJourFermeture}',
                    Colors.purple,
                  ),
                if (gare.description.isNotEmpty)
                  _infoRow(Icons.info_outline, gare.description, Colors.grey),
              ],
            ),
          ),

          // ── Boutons d'action ───────────────────────────────────
          if ((gare.latitude != 0 && gare.longitude != 0) ||
              gare.siteWeb.isNotEmpty) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  if (gare.latitude != 0 && gare.longitude != 0)
                    _actionBtn(
                      icon: Icons.directions_rounded,
                      label: 'Itinéraire',
                      color: Colors.blue,
                      onTap: () =>
                          _openItineraire(gare.latitude, gare.longitude),
                    ),
                  if ((gare.latitude != 0 && gare.longitude != 0) &&
                      gare.siteWeb.isNotEmpty)
                    const SizedBox(width: 8),
                  if (gare.siteWeb.isNotEmpty)
                    _actionBtn(
                      icon: Icons.language_rounded,
                      label: 'Site web',
                      color: Colors.blue[700]!,
                      onTap: () => _launchUrl(
                        gare.siteWeb.startsWith('http')
                            ? gare.siteWeb
                            : 'https://${gare.siteWeb}',
                      ),
                    ),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text,
                  style:
                      const TextStyle(fontSize: 13, color: Colors.black87)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stagger animation ─────────────────────────────────────────────────────────
class _StaggerItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggerItem({required this.index, required this.child});

  @override
  State<_StaggerItem> createState() => _StaggerItemState();
}

class _StaggerItemState extends State<_StaggerItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    final delay = 80 + widget.index.clamp(0, 10) * 60;
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
