import '../../core/utils/parsing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/gare1_model.dart';
import '../../models/reservation_model.dart';
import '../../models/voyage_extra_model.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../paiement/detail_paiement_page.dart';
import 'gare_map_page.dart';
import '../../core/utils/logger.dart';

class TicketPage extends StatefulWidget {
  final Map<String, dynamic> reservation;

  const TicketPage({super.key, required this.reservation});

  @override
  State<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends State<TicketPage> with SingleTickerProviderStateMixin {
  bool _isAgentInfoExpanded = false;
  bool _isBusInfoExpanded = false;
  bool _isChauffeurInfoExpanded = false;
  bool _isCompanyInfoExpanded = false;
  bool _isItineraireExpanded = true;
  VoyageExtra? _voyageExtraInfo;
  bool _isLoadingExtra = false;
  String? _numeroReservationFromApi;

  late AnimationController _enterCtrl;
  late Animation<double> _fadeHeader;
  late Animation<Offset> _slideHeader;
  late Animation<double> _fadeHero;
  late Animation<Offset> _slideHero;
  late Animation<double> _fadeBody;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeHeader = CurvedAnimation(parent: _enterCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut));
    _slideHeader = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));
    _fadeHero = CurvedAnimation(parent: _enterCtrl, curve: const Interval(0.2, 0.65, curve: Curves.easeOut));
    _slideHero = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: const Interval(0.2, 0.65, curve: Curves.easeOut)));
    _fadeBody = CurvedAnimation(parent: _enterCtrl, curve: const Interval(0.45, 1.0, curve: Curves.easeOut));
    _enterCtrl.forward();
    _fetchVoyageExtra();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }


  Future<void> _fetchVoyageExtra() async {
    final vid = widget.reservation['voyage'] != null ? widget.reservation['voyage']['id'] : null;
    if (vid != null) {
      setState(() {
        _isLoadingExtra = true;
      });
      try {
        final token = await StorageService().getToken();
        final response = await ApiService().get('information_des_chaffeur_apprentir_bus/$vid', token: token);
        // log entire payload for debugging
        logDebug('Voyage extra API réponse : $response');
        logDebug('Response type: ${response.runtimeType}');
        if (response['data'] != null) {
          // also log sub-objects so we can see details in console
          logDebug('Bus details: ${response['data']['bus']}');
          logDebug('Chauffeur details: ${response['data']['chauffeur']}');
          logDebug('Company details: ${response['data']['compagnie']}');
          
          if (response['success'] == true) {
            // Extraire numero_reservation depuis response['reservations']
            final reservationsList = response['reservations'];
            if (reservationsList is List && reservationsList.isNotEmpty) {
              final currentResId = widget.reservation['id'];
              for (final r in reservationsList) {
                if (r is Map) {
                  final numRes = r['numero_reservation']?.toString();
                  if (numRes != null && numRes.isNotEmpty) {
                    final rid = r['id'];
                    if (currentResId == null || rid == null || rid.toString() == currentResId.toString()) {
                      setState(() => _numeroReservationFromApi = numRes);
                      break;
                    }
                  }
                }
              }
            }
            try {
              logDebug('Parsing VoyageExtra from: ${response['data'].runtimeType}');
              final voyageExtraData = VoyageExtra.fromJson(response['data'] as Map<String, dynamic>);
              setState(() {
                _voyageExtraInfo = voyageExtraData;
              });
              logDebug('VoyageExtraInfo stocké dans l\'état avec succès');
            } catch (parseError) {
              logDebug('Erreur parsing VoyageExtra: $parseError');
              // Create empty VoyageExtra as fallback
              setState(() {
                _voyageExtraInfo = VoyageExtra(
                  id: 0,
                  compagnieId: 0,
                  infoUserId: 0,
                  busId: 0,
                  chauffeurId: 0,
                  disponibleToujours: 0,
                  heureDepart: '',
                  status: '',
                  createdAt: '',
                  updatedAt: '',
                  agentsId: 0,
                  bus: Bus.empty(),
                  chauffeur: Chauffeur.empty(),
                  compagnie: Compagnie.empty(),
                  agent: Agent.empty(),
                );
              });
            }
          }
        }
      } catch (e) {
        logDebug('Erreur récupération info voyage : $e');
      } finally {
        setState(() {
          _isLoadingExtra = false;
        });
      }
    }
  }



Future<void> _startNavigation({
  required String endLat,
  required String endLng,
}) async {
  final uri = Uri.parse('google.navigation:q=$endLat,$endLng&mode=d');

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    // fallback si Google Maps ne s’ouvre pas
    final webUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$endLat,$endLng&travelmode=driving',
    );
    await launchUrl(webUrl, mode: LaunchMode.externalApplication);
  }
}

  @override
  Widget build(BuildContext context) {
    // Create Reservation object from Map
    Reservation? reservationObj;
    try {
      reservationObj = Reservation.fromJson(widget.reservation);
    } catch (e) {
      logDebug('Erreur lors de la création de l\'objet Reservation: $e');
      reservationObj = null;
    }

    final departureCity =
        widget.reservation['arret']['tarification']['ville_depart']['nom_ville'] ?? '';
    final arrivalCity =
        widget.reservation['arret']['tarification']['ville_arrivee']['nom_ville'] ??
        '';

    // convenience maps from extra API data if available
    final extraBus = _voyageExtraInfo?.bus;
    final extraChauffeur = _voyageExtraInfo?.chauffeur;
    final extraCompany = _voyageExtraInfo?.compagnie;

    // choose API-provided values first, fall back to reservation map

    final priceRaw = asInt(widget.reservation['arret']['montant']);
    final price = NumberFormat('#,##0', 'fr').format(priceRaw).replaceAll(',', ' ');
    final date = _formatDate(widget.reservation['voyage']['date_depart'] ?? '');
    final time = _formatTime(widget.reservation['voyage']['heure_depart'] ?? '');
    final duree = widget.reservation['voyage']['duree_voyage']?.toString() ?? '';
    final seatNumber = widget.reservation['numero_place']?.toString() ?? '';
    // prefer the strongly-typed object, fallback to raw map
    final totalSeats =
        widget.reservation['voyage']['bus']['places']?.length.toString() ?? '0';
    final reservationId = widget.reservation['id']?.toString() ?? '';
    final ticketNumber = widget.reservation['numero_reservation']?.toString().isNotEmpty == true
        ? widget.reservation['numero_reservation'].toString()
        : reservationId.isNotEmpty ? reservationId : 'N/A';
    final qrData = _numeroReservationFromApi?.isNotEmpty == true
        ? _numeroReservationFromApi!
        : widget.reservation['numero_reservation']?.toString().isNotEmpty == true
            ? widget.reservation['numero_reservation'].toString()
            : reservationId;

    // extract infractions - prefer API data first, fallback to reservation object
    final busInfractions = _voyageExtraInfo?.bus.infractions ?? reservationObj?.busInfractions ?? '';
    final chauffeurInfractions = _voyageExtraInfo?.chauffeur.infractions ?? reservationObj?.chauffeurInfractions ?? '';
    final companyInfractions = _voyageExtraInfo?.compagnie.infractions ?? reservationObj?.companyInfractions ?? '';
    final agentInfractions = _voyageExtraInfo?.agent.infractions ?? '';
    
    // Debug logging for infractions
    logDebug('=== INFRACTIONS DEBUG ===');
    logDebug('Bus Infractions (API): ${_voyageExtraInfo?.bus.infractions}');
    logDebug('Bus Infractions (Reservation): ${reservationObj?.busInfractions}');
    logDebug('Bus Infractions (Final): $busInfractions');
    logDebug('---');
    logDebug('Chauffeur Infractions (API): ${_voyageExtraInfo?.chauffeur.infractions}');
    logDebug('Chauffeur Infractions (Reservation): ${reservationObj?.chauffeurInfractions}');
    logDebug('Chauffeur Infractions (Final): $chauffeurInfractions');
    logDebug('---');
    logDebug('Company Infractions (API): ${_voyageExtraInfo?.compagnie.infractions}');
    logDebug('Company Infractions (Reservation): ${reservationObj?.companyInfractions}');
    logDebug('Company Infractions (Final): $companyInfractions');
    logDebug('---');
    logDebug('Agent Infractions (API): ${_voyageExtraInfo?.agent.infractions}');
    logDebug('Agent Infractions (Final): $agentInfractions');
    logDebug('======================');



    final isScanned = (widget.reservation['status'] ?? '').toString().toLowerCase().contains('scan') ||
        widget.reservation['status'] == '1';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          // ── Header jaune ──────────────────────────────────────────────
          SlideTransition(
            position: _slideHeader,
            child: FadeTransition(
              opacity: _fadeHeader,
              child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFFC107),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text('Mon Billet',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                  if (_isLoadingExtra)
                    const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black54))),
                ]),
              ),
            ),
          ),
            ),
          ),

          // ── Corps scrollable ──────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Carte hero : trajet ───────────────────────────────
                SlideTransition(
                  position: _slideHero,
                  child: FadeTransition(
                    opacity: _fadeHero,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 14, offset: const Offset(0, 5))],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        // Notice — affiché uniquement si non scanné
                        if (!isScanned) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(children: [
                              const Icon(Icons.info_outline_rounded, color: Color(0xFFF9A825), size: 16),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text('Présentez ce billet au contrôleur',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF795548))),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Départ → Arrivée
                        Row(children: [
                          Expanded(child: Column(children: [
                            const Text('Départ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(departureCity,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                                textAlign: TextAlign.center),
                          ])),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(children: [
                              Container(width: 30, height: 1, color: Colors.grey.shade300),
                              const Icon(Icons.directions_bus_rounded, color: Color(0xFFFFC107), size: 20),
                              Container(width: 30, height: 1, color: Colors.grey.shade300),
                            ]),
                          ),
                          Expanded(child: Column(children: [
                            const Text('Arrivée', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(arrivalCity,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                                textAlign: TextAlign.center),
                          ])),
                        ]),
                        const SizedBox(height: 16),
                        // Date · Heure · Siège
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(children: [
                            _heroStat(date, 'Date'),
                            _heroDivider(),
                            _heroStat(time, 'Heure'),
                            _heroDivider(),
                            _heroStat(seatNumber, 'Siège'),
                            if (duree.isNotEmpty) ...[
                              _heroDivider(),
                              _heroStat(duree, 'Durée'),
                            ],
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Infos rapides ─────────────────────────────────────
                FadeTransition(
                  opacity: _fadeBody,
                  child: Row(children: [
                    if (ticketNumber != 'N/A') ...[
                      _infoChip(null, ticketNumber, 'Référence', const Color(0xFFFFC107), copiable: true),
                      const SizedBox(width: 10),
                    ],
                    _infoChip(null, '$price FCFA', 'Prix', const Color(0xFF2E7D32)),
                  ]),
                ),

                const SizedBox(height: 10),

                // ── Bouton voir le paiement ───────────────────────────
                if ((int.tryParse(widget.reservation['paiements_id']?.toString() ?? '0') ?? 0) > 0)
                  FadeTransition(
                    opacity: _fadeBody,
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailPaiementPage(
                            paiementId: int.tryParse(widget.reservation['paiements_id']?.toString() ?? '0') ?? 0,
                          ),
                        ),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.35),
                            blurRadius: 8, offset: const Offset(0, 3),
                          )],
                        ),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.receipt_rounded, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('Voir le paiement',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 12),
                          ),
                        ]),
                      ),
                    ),
                  ),

                const SizedBox(height: 14),

                // ── Sections (bus, chauffeur, agent, compagnie, gares, QR) ─
                FadeTransition(
                  opacity: _fadeBody,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Infos bus ─────────────────────────────────────────
                if (widget.reservation['voyage']?['bus'] != null)
                  _buildSection(
                    icon: Icons.directions_bus_rounded,
                    title: 'Bus',
                    color: const Color(0xFF1565C0),
                    expanded: _isBusInfoExpanded,
                    onToggle: () => setState(() => _isBusInfoExpanded = !_isBusInfoExpanded),
                    child: Column(children: [
                      Builder(builder: (ctx) {
                          final photos = _buildBusPhotoUrls(
                            extraBus?.photoBus,
                            reservationObj?.photoBus,
                          );
                          if (photos.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(children: [
                              GestureDetector(
                                onTap: () => _showBusImages(ctx, photos),
                                child: Hero(
                                  tag: 'bus-ticket-${photos.first}',
                                  child: Stack(children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: AspectRatio(
                                        // Ratio fixe : la carte garde une hauteur stable
                                        // quelle que soit la taille de la photo reçue.
                                        aspectRatio: 16 / 9,
                                        child: Container(
                                          width: double.infinity,
                                          color: const Color(0xFFF1F3F5),
                                          child: Image.network(
                                            photos.first,
                                            // `contain` garde la photo entière visible.
                                            // `cover` sur une hauteur de 100 px rognait
                                            // le toit et les roues du bus.
                                            fit: BoxFit.contain,
                                            loadingBuilder: (_, child, progress) =>
                                                progress == null
                                                    ? child
                                                    : const Center(
                                                        child: SizedBox(
                                                          width: 22,
                                                          height: 22,
                                                          child: CircularProgressIndicator(strokeWidth: 2),
                                                        ),
                                                      ),
                                            errorBuilder: (_, __, ___) => const Center(
                                              child: Icon(Icons.directions_bus_rounded,
                                                  color: Colors.black26, size: 32),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (photos.length > 1)
                                      Positioned(
                                        right: 8,
                                        bottom: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            const Icon(Icons.photo_library_rounded, color: Colors.white, size: 11),
                                            const SizedBox(width: 3),
                                            Text('${photos.length}',
                                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ]),
                                        ),
                                      ),
                                  ]),
                                ),
                              ),
                              if (photos.length > 1) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: List.generate(
                                    photos.length,
                                        (i) => GestureDetector(
                                      onTap: () => _showBusImages(ctx, photos, initialIndex: i),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 56,
                                          height: 40,
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F3F5),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.grey.shade300),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.08),
                                                blurRadius: 3,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: Image.network(
                                            photos[i],
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => const Icon(
                                                Icons.directions_bus_rounded,
                                                color: Colors.black26, size: 16),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ]),
                          );
                        }),
                      _infoRow(null, 'Marque',
                          extraBus?.marqueBus ?? widget.reservation['voyage']['bus']['marque_bus'] ?? 'N/A'),
                      _infoRow(null, 'Nom',
                          widget.reservation['voyage']['bus']['nom_bus'] ?? 'N/A'),
                      _infoRow(null, 'Immatriculation',
                          widget.reservation['voyage']['bus']['immatriculation_bus'] ?? 'N/A'),
                      _infoRow(null, 'Nb places', totalSeats),
                      if (busInfractions.isNotEmpty)
                        _infractionBadge(busInfractions),
                    ]),
                  ),

                const SizedBox(height: 10),

                // ── Chauffeur ──────────────────────────────────────────
                if (widget.reservation['voyage']?['chauffeur'] != null)
                  _buildSection(
                    icon: Icons.person_rounded,
                    title: 'Chauffeur',
                    color: const Color(0xFF6A1B9A),
                    expanded: _isChauffeurInfoExpanded,
                    onToggle: () => setState(() => _isChauffeurInfoExpanded = !_isChauffeurInfoExpanded),
                    child: Column(children: [
                      // Photo
                      Builder(builder: (ctx) {
                        String? photoUrl;
                        if (extraChauffeur?.photo.isNotEmpty == true) {
                          photoUrl = extraChauffeur!.photo;
                        } else {
                          final p = widget.reservation['voyage']['chauffeur']['photo'];
                          if (p != null) {
                            final ps = p as String;
                            photoUrl = ps.startsWith('http') ? ps : '${ApiService.baseUrl.replaceAll('/api', '')}/$ps';
                          }
                        }
                        if (photoUrl == null || photoUrl.contains('default-user')) return const SizedBox.shrink();
                        final url = photoUrl;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Center(child: GestureDetector(
                            onTap: () => _showFullImage(ctx, url),
                            child: Hero(
                              tag: url,
                              child: CircleAvatar(
                                radius: 36,
                                backgroundColor: Colors.grey[300],
                                child: ClipOval(
                                  child: Image.network(
                                    url,
                                    width: 72, height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.person, size: 36, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          )),
                        );
                      }),
                      _infoRow(Icons.person_outline_rounded, 'Nom',
                          '${extraChauffeur?.nom ?? widget.reservation['voyage']['chauffeur']['nom'] ?? ''} ${extraChauffeur?.prenom ?? widget.reservation['voyage']['chauffeur']['prenom'] ?? ''}'),
                      _phoneRow('Téléphone',
                          extraChauffeur?.telephone ?? widget.reservation['voyage']['chauffeur']['telephone'] ?? ''),
                      _infoRow(Icons.badge_rounded, 'Permis',
                          extraChauffeur?.numeroPermis ?? widget.reservation['voyage']['chauffeur']['numeros_permis'] ?? 'N/A'),
                      if ((extraChauffeur?.dateNaissance ?? '').isNotEmpty)
                        _infoRow(Icons.cake_rounded, 'Naissance', _formatDate(extraChauffeur!.dateNaissance)),
                      if ((extraChauffeur?.adresse ?? '').isNotEmpty)
                        _infoRow(Icons.location_on_rounded, 'Adresse', extraChauffeur!.adresse ?? ''),
                      if (chauffeurInfractions.isNotEmpty)
                        _infractionBadge(chauffeurInfractions),
                    ]),
                  ),

                const SizedBox(height: 10),

                // ── Apprenti / Agent ───────────────────────────────────
                if (widget.reservation['voyage']?['agent'] != null)
                  _buildSection(
                    icon: Icons.support_agent_rounded,
                    title: 'Apprenti',
                    color: const Color(0xFF00695C),
                    expanded: _isAgentInfoExpanded,
                    onToggle: () => setState(() => _isAgentInfoExpanded = !_isAgentInfoExpanded),
                    child: Column(children: [
                      Builder(builder: (ctx) {
                        final p = widget.reservation['voyage']['agent']['photo'];
                        if (p == null) return const SizedBox.shrink();
                        final ps = p as String;
                        if (ps.isEmpty || ps.contains('default-user')) return const SizedBox.shrink();
                        final url = ps.startsWith('http') ? ps : '${ApiService.baseUrl.replaceAll('/api', '')}/$ps';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Center(child: GestureDetector(
                            onTap: () => _showFullImage(ctx, url),
                            child: Hero(
                              tag: url,
                              child: CircleAvatar(
                                radius: 36,
                                backgroundColor: Colors.grey[300],
                                child: ClipOval(
                                  child: Image.network(
                                    url,
                                    width: 72, height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.person, size: 36, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          )),
                        );
                      }),
                      _infoRow(Icons.person_outline_rounded, 'Nom complet',
                          '${widget.reservation['voyage']['agent']['nom'] ?? ''} ${widget.reservation['voyage']['agent']['prenom'] ?? ''}'),
                      if (agentInfractions.isNotEmpty)
                        _infractionBadge(agentInfractions),
                    ]),
                  ),

                const SizedBox(height: 10),

                // ── Compagnie ──────────────────────────────────────────
                if (extraCompany != null)
                  _buildSection(
                    icon: Icons.business_rounded,
                    title: 'Compagnie',
                    color: const Color(0xFFE65100),
                    expanded: _isCompanyInfoExpanded,
                    onToggle: () => setState(() => _isCompanyInfoExpanded = !_isCompanyInfoExpanded),
                    child: Builder(builder: (ctx) {
                      final tel = extraCompany.telephoneCompagnies.trim();
                      final email = extraCompany.emailCompagnies.trim();
                      final adresse = extraCompany.adresse.trim();

                      return Column(children: [
                        _identiteCompagnie(
                          ctx,
                          extraCompany.logoCompagnies,
                          extraCompany.nomCompletCompagnies,
                        ),
                        _ligneContact(
                          icone: Icons.phone_rounded,
                          label: 'Téléphone',
                          valeur: tel,
                          action: _estRenseigne(tel) ? Uri.parse('tel:$tel') : null,
                          // Appeler est la seule action urgente depuis un billet :
                          // c'est la seule qui reçoit un bouton plein.
                          boutonPrincipal: _estRenseigne(tel)
                              ? Material(
                                  color: const Color(0xFF2E7D32),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => _ouvrirUri(Uri.parse('tel:$tel')),
                                    child: const Padding(
                                      padding: EdgeInsets.all(9),
                                      child: Icon(Icons.call_rounded,
                                          size: 18, color: Colors.white),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        _ligneContact(
                          icone: Icons.mail_outline_rounded,
                          label: 'Email',
                          valeur: email,
                          action: _estRenseigne(email) ? Uri.parse('mailto:$email') : null,
                        ),
                        _ligneContact(
                          icone: Icons.place_outlined,
                          label: 'Adresse',
                          valeur: adresse,
                          action: _estRenseigne(adresse)
                              ? Uri.parse(
                                  'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(adresse)}')
                              : null,
                        ),
                        if (companyInfractions.isNotEmpty)
                          _infractionBadge(companyInfractions),
                      ]);
                    }),
                  ),

                const SizedBox(height: 10),

                // ── Gares ──────────────────────────────────────────────
                _buildGaresItineraireSection(context),

                // ── Attribué à ─────────────────────────────────────────
                if ((widget.reservation['nom_complet']?.toString().isNotEmpty == true) ||
                    (widget.reservation['telephone_proprietaire']?.toString().isNotEmpty == true)) ...[
                  const SizedBox(height: 10),
                  _buildSection(
                    icon: Icons.person_pin_rounded,
                    title: 'Attribué à',
                    color: const Color(0xFF4527A0),
                    expanded: true,
                    onToggle: () {},
                    showToggle: false,
                    child: Column(children: [
                      if (widget.reservation['nom_complet']?.toString().isNotEmpty == true)
                        _infoRow(Icons.person_rounded, 'Nom', widget.reservation['nom_complet']),
                      if (widget.reservation['telephone_proprietaire']?.toString().isNotEmpty == true)
                        _phoneRow('Téléphone', widget.reservation['telephone_proprietaire'].toString()),
                    ]),
                  ),
                ],

                const SizedBox(height: 20),

                // ── QR Code ───────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    // Tirets séparateurs
                    Row(children: [
                      Container(width: 20, height: 20, decoration: BoxDecoration(
                          color: const Color(0xFFF5F6FA), shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade200))),
                      Expanded(child: CustomPaint(
                          painter: DashedLinePainter(), size: const Size(double.infinity, 1))),
                      Container(width: 20, height: 20, decoration: BoxDecoration(
                          color: const Color(0xFFF5F6FA), shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade200))),
                    ]),
                    const SizedBox(height: 20),
                    if (qrData.isNotEmpty)
                      QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 160.0,
                        backgroundColor: Colors.white,
                      ),
                    const SizedBox(height: 8),
                    if (qrData.isNotEmpty)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          // Appui simple ET appui long : le copier était
                          // auparavant réservé à l'appui long, donc invisible.
                          onTap: () => _copierDansPressePapiers(qrData),
                          onLongPress: () => _copierDansPressePapiers(qrData),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.4)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Column(mainAxisSize: MainAxisSize.min, children: [
                                const Text('N° Réservation',
                                    style: TextStyle(fontSize: 10, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.qr_code_rounded, size: 14, color: Color(0xFFFFC107)),
                                  const SizedBox(width: 6),
                                  Text(
                                    qrData,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 2),
                                const Text('Appuyez pour copier',
                                    style: TextStyle(fontSize: 9, color: Colors.grey)),
                              ]),
                              const SizedBox(width: 6),
                              // Cible tactile explicite, visible sans découverte.
                              IconButton(
                                onPressed: () => _copierDansPressePapiers(qrData),
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                color: const Color(0xFF8D6E00),
                                tooltip: 'Copier le n° de réservation',
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Heure · Siège row
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(children: [
                            const Text('Heure de départ',
                                style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(time,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ]),
                        ),
                        Container(width: 1, height: 32, color: Colors.grey.shade300),
                        Expanded(
                          child: Column(children: [
                            const Text('Siège',
                                style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(seatNumber,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ]),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: isScanned ? const Color(0xFF2E7D32).withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isScanned ? const Color(0xFF2E7D32) : Colors.orange),
                      ),
                      child: Text(
                        isScanned ? '✓ Scanné par le contrôleur' : '⏳ En attente de scan',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold,
                          color: isScanned ? const Color(0xFF2E7D32) : Colors.orange[800],
                        ),
                      ),
                    ),
                  ]),
                ),

                  ]), // end FadeTransition Column
                ), // end FadeTransition

              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers UI ────────────────────────────────────────────────────────────

  static const String _imageBase = "http://192.168.95.123:8000";

  List<String> _buildBusPhotoUrls(List<String>? fromExtra, List<String>? fromReservation) {
    final raw = (fromExtra?.isNotEmpty == true) ? fromExtra! : (fromReservation ?? []);
    return raw.map((s) {
      if (s.startsWith('http')) return s;
      return '$_imageBase/buses/$s';
    }).toList();
  }

  void _showBusImages(BuildContext context, List<String> urls, {int initialIndex = 0}) {
    if (urls.isEmpty) return;
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) {
        int current = initialIndex;
        return StatefulBuilder(builder: (ctx, setSt) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: urls.length > 1
                ? Text('${current + 1} / ${urls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 14))
                : null,
          ),
          body: PageView.builder(
            itemCount: urls.length,
            controller: PageController(initialPage: initialIndex),
            onPageChanged: (i) => setSt(() => current = i),
            itemBuilder: (_, i) => InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.network(urls[i], fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.error, color: Colors.red, size: 50)),
              ),
            ),
          ),
        ));
      },
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  void _showFullImage(BuildContext context, String url) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(children: [
            Center(child: Hero(
              tag: url,
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 50)),
              ),
            )),
            Positioned(
              top: 40, right: 16,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ]),
        ),
      ),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  static const _orangeCompagnie = Color(0xFFE65100);

  Future<void> _ouvrirUri(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool _estRenseigne(String? v) {
    final s = v?.trim() ?? '';
    return s.isNotEmpty && s != 'N/A';
  }

  /// Sceau d'identité du transporteur : logo circulaire + raison sociale.
  Widget _identiteCompagnie(BuildContext ctx, String logoUrl, String nom) {
    return Column(children: [
      if (_estRenseigne(logoUrl))
        GestureDetector(
          onTap: () => _showFullImage(ctx, logoUrl),
          child: Hero(
            tag: logoUrl,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: _orangeCompagnie.withValues(alpha: 0.25), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: Padding(
                  // Marge intérieure : sans elle, un logo carré viendrait
                  // toucher l'anneau et paraîtrait rogné.
                  padding: const EdgeInsets.all(11),
                  child: Image.network(
                    logoUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.business_rounded, color: Colors.black26, size: 28),
                  ),
                ),
              ),
            ),
          ),
        ),
      if (_estRenseigne(nom)) ...[
        const SizedBox(height: 12),
        Text(
          nom,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            height: 1.25,
          ),
        ),
      ],
      const SizedBox(height: 14),
      Divider(height: 1, color: Colors.grey.shade200),
      const SizedBox(height: 6),
    ]);
  }

  /// Ligne de contact actionnable : libellé au-dessus, valeur en dessous,
  /// alignés à gauche — les emails et adresses longs ne sont plus comprimés
  /// dans la colonne de droite.
  Widget _ligneContact({
    required IconData icone,
    required String label,
    required String valeur,
    Uri? action,
    Widget? boutonPrincipal,
  }) {
    final renseigne = _estRenseigne(valeur);
    final contenu = Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _orangeCompagnie.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icone, size: 17, color: _orangeCompagnie),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.2)),
            const SizedBox(height: 2),
            Text(
              renseigne ? valeur.trim() : 'Non renseigné',
              style: TextStyle(
                fontSize: 14,
                fontWeight: renseigne ? FontWeight.w600 : FontWeight.w400,
                color: renseigne ? Colors.black87 : Colors.grey,
                height: 1.3,
              ),
            ),
          ]),
        ),
        if (boutonPrincipal != null) ...[const SizedBox(width: 8), boutonPrincipal],
      ]),
    );

    if (!renseigne || action == null) return contenu;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _ouvrirUri(action),
        child: contenu,
      ),
    );
  }

  Widget _phoneRow(String label, String phone) {
    final clean = phone.trim();
    if (clean.isEmpty || clean == 'N/A') {
      return _infoRow(Icons.phone_rounded, label, phone);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        const Icon(Icons.phone_rounded, size: 15, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label : ', style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Expanded(child: Text(clean,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
            textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            final uri = Uri.parse('tel:$clean');
            if (await canLaunchUrl(uri)) await launchUrl(uri);
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.call_rounded, size: 16, color: Colors.green),
          ),
        ),
      ]),
    );
  }

  Widget _heroStat(String value, String label) {
    return Expanded(child: Column(children: [
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
          textAlign: TextAlign.center),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]));
  }

  Widget _heroDivider() =>
      Container(width: 1, height: 28, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 4));

  Widget _infoChip(IconData? icon, String value, String label, Color color,
      {bool copiable = false}) {
    final contenu = Container(
      padding: EdgeInsets.fromLTRB(14, 12, copiable ? 4 : 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
              overflow: TextOverflow.ellipsis),
        ])),
        if (copiable)
          IconButton(
            onPressed: () => _copierDansPressePapiers(value),
            icon: const Icon(Icons.copy_rounded, size: 16),
            color: Colors.grey.shade600,
            tooltip: 'Copier $label',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          ),
      ]),
    );

    if (!copiable) return Expanded(child: contenu);

    // Toute la carte est cliquable, en plus du bouton dédié.
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _copierDansPressePapiers(value),
          onLongPress: () => _copierDansPressePapiers(value),
          child: contenu,
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
    bool showToggle = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        InkWell(
          onTap: showToggle ? onToggle : null,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87))),
              if (showToggle)
                Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey, size: 22),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Divider(height: 1, color: Colors.grey.shade100),
                    const SizedBox(height: 12),
                    child,
                  ]),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  /// Copie [valeur] dans le presse-papiers avec retour haptique et visuel.
  Future<void> _copierDansPressePapiers(String valeur) async {
    await Clipboard.setData(ClipboardData(text: valeur));
    await HapticFeedback.lightImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('Copié : $valeur')),
          ]),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
  }

  Widget _infoRow(IconData? icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: Colors.grey),
          const SizedBox(width: 8),
        ],
        Text('$label : ', style: const TextStyle(fontSize: 13, color: Colors.grey)),
        // Les immatriculations et noms de bus sont longs : on les laisse
        // passer à la ligne plutôt que de les tronquer par « … ».
        Expanded(child: Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
            textAlign: TextAlign.right, softWrap: true)),
      ]),
    );
  }

  Widget _infractionBadge(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
            style: const TextStyle(fontSize: 12, color: Colors.red, height: 1.4))),
      ]),
    );
  }

  // ── Gares & Itinéraire section ──────────────────────────────────────────

  Widget _buildGaresItineraireSection(BuildContext context) {
    final gareDepart = _voyageExtraInfo?.gare;
    final gareArrive = _voyageExtraInfo?.gareArrive;

    if (gareDepart == null && gareArrive == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Header toggle
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => setState(() => _isItineraireExpanded = !_isItineraireExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.route_rounded, size: 17, color: Color(0xFF1565C0)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Gares du voyage',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                  Icon(
                    _isItineraireExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isItineraireExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        Divider(height: 1, color: Colors.grey.shade100),
                        const SizedBox(height: 12),

                        // Gare de départ
                        if (gareDepart != null)
                          _buildGareTile(
                            context,
                            gare: gareDepart,
                            label: 'Gare de départ',
                            isDepart: true,
                          ),

                        if (gareDepart != null && gareArrive != null) const SizedBox(height: 10),

                        // Gare d'arrivée
                        if (gareArrive != null)
                          _buildGareTile(
                            context,
                            gare: gareArrive,
                            label: 'Gare d\'arrivée',
                            isDepart: false,
                          ),

                        // Bouton itinéraire complet (les deux gares)
                        if (gareDepart != null && gareArrive != null) ...[
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GareMapPage.itinerary(
                                    gareDepart: gareDepart,
                                    gareArrive: gareArrive,
                                    title:
                                        '${gareDepart.nomGare} → ${gareArrive.nomGare}',
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.map_rounded, size: 18),
                              label: const Text(
                                'Voir l\'itinéraire sur la carte',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1565C0),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),




                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildGareTile(
    BuildContext context, {
    required Gare gare,
    required String label,
    required bool isDepart,
  }) {
    final ville = gare.ville?.nomVille ?? '';
    final lat = gare.latitude;
    final lng = gare.longitude;
    final hasCoords = lat.isNotEmpty && lng.isNotEmpty && lat != '0' && lng != '0';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icône couleur
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDepart
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFEBEE),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDepart ? Icons.trip_origin : Icons.place,
              size: 18,
              color: isDepart ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
            ),
          ),
          const SizedBox(width: 12),
          // Texte
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  gare.nomGare,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                if (ville.isNotEmpty)
                  Text(ville,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (gare.heureOuverture.isNotEmpty || gare.heureFermeture.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${gare.heureOuvertureFormatee} – ${gare.heureFermetureFormatee}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Boutons actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Voir sur la carte (gare seule)

              const SizedBox(height: 6),
              // Voir itinéraires de cette gare
              if (hasCoords)
                GestureDetector(
                  onTap: () => _startNavigation(endLat: lat, endLng: lng),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDepart
                          ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                          : const Color(0xFFC62828).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions_rounded,
                          size: 14,
                          color: isDepart
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC62828),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Aller à la gare',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDepart
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFC62828),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }


  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatTime(String timeString) {
    try {
      final timeParts = timeString.split(':');
      if (timeParts.length >= 2) {
        return '${timeParts[0]}:${timeParts[1]}';
      }
      return timeString;
    } catch (e) {
      return timeString;
    }
  }
}

class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
