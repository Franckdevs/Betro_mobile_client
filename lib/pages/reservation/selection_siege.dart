import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../core/widgets/shimmer_skeleton.dart';
import 'paiement/paiement_webview_page.dart';

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
  final String? classe;
  final bool disponibleToujours;
  final String? dureeVoyage;

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
    this.classe,
    this.disponibleToujours = false,
    this.dureeVoyage,
  });

  @override
  State<SelectionSiegePage> createState() => _SelectionSiegePageState();
}

class _SelectionSiegePageState extends State<SelectionSiegePage> {
  static int _toInt(dynamic v, [int fallback = 0]) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? fallback;

  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _placesOccupees = [];
  List<dynamic> _placesDisponibles = [];
  int? _selectedSeat;
  String? _selectedSeatName; // used in future UI
  Map<String, dynamic>? _userInfo;
  bool _isLoadingUserInfo = false;
  bool _showAdditionalInfo = false;
  final _beneficiaryFormKey = GlobalKey<FormState>();

  // Beneficiary controllers (class-level for reliability across modal lifecycle)
  final _beneficiaryNomController = TextEditingController();
  final _beneficiaryTelController = TextEditingController();
  final _beneficiaryEmailController = TextEditingController();

  // Values captured when confirming, used after modal closes
  String? _assignNom;
  String? _assignTel;
  String? _assignEmail;
  bool _isAssigning = false;

  // Bus configuration
  int _colonnes = 4;
  int _rangees = 10;
  int _placesCoteChauffeur = 3;

  static const _amber = Color(0xFFFFC107);

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  @override
  void dispose() {
    _beneficiaryNomController.dispose();
    _beneficiaryTelController.dispose();
    _beneficiaryEmailController.dispose();
    super.dispose();
  }

  Future<void> _initPage() async {
    final isAuthenticated = await _checkAuthStatus();
    if (!isAuthenticated) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    await _loadBusSeats();
    await _fetchUserInfo();
  }

  Future<bool> _checkAuthStatus() async {
    try {
      final token = await StorageService().getToken();
      return token != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _fetchUserInfo() async {
    if (!mounted) return;
    setState(() => _isLoadingUserInfo = true);
    try {
      final storageService = StorageService();
      final cached = await storageService.getUserData();
      if (cached != null) {
        setState(() {
          _userInfo = cached;
          _isLoadingUserInfo = false;
        });
        _refreshUserData();
        return;
      }
      await _refreshUserData();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingUserInfo = false);
    }
  }

  Future<void> _refreshUserData() async {
    try {
      final storageService = StorageService();
      final token = await storageService.getToken();
      if (token == null) return;
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/recuperer_utilisateur/$token'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final userData = Map<String, dynamic>.from(data['data']);
          await storageService.saveUserData(userData);
          if (mounted) setState(() => _userInfo = userData);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingUserInfo = false);
    }
  }

  Future<void> _loadBusSeats() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/bus_detail_place/${widget.busId}/${widget.voyageId}'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final rawOccupees = data['liste_place_deja_occupe'] ?? [];
          final rawPlaces = data['data']?['places'] ?? [];
          setState(() {
            _placesOccupees = rawOccupees;
            _placesDisponibles = rawPlaces;
            final config = data['data']?['configuration_place'];
            if (config != null) {
              _colonnes = _toInt(config['colonne'], 4);
              _rangees = _toInt(config['ranger'], 10);
              _placesCoteChauffeur = _toInt(config['places_cote_chauffeur'], 3);
            }
          });
        } else {
          _showError(data['message'] ?? 'Erreur lors du chargement des places');
        }
      } else {
        throw Exception();
      }
    } catch (_) {
      _showError('Erreur de connexion au serveur');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  bool _isSeatOccupied(int seatNumber) {
    if (seatNumber == 0) return true;
    if (_placesOccupees.any((o) => _toInt(o['numero_place']) == seatNumber)) return true;
    final place = _placesDisponibles.firstWhere(
      (p) => _toInt(p['numero']) == seatNumber,
      orElse: () => <String, dynamic>{},
    );
    if (place.isEmpty) return true;
    return _toInt(place['disponible']) != 1;
  }

  bool _isProcheChauffeur(dynamic place) => place['type'] == 'proche_chauffeur';

  // ── Seat selection + confirmation bottom sheet ────────────────────────────
  void _selectSeat(int seatNumber, String seatName) {
    if (seatNumber == 0 || _isSeatOccupied(seatNumber)) return;
    setState(() {
      if (_selectedSeat == seatNumber) {
        _selectedSeat = null;
        _selectedSeatName = null;
      } else {
        _selectedSeat = seatNumber;
        _selectedSeatName = seatName;
      }
    });
  }

  Future<void> _showConfirmationModal() async {
    if (_selectedSeat == null) return;
    final seatNumber = _selectedSeat!;
    final seatName = _selectedSeatName!;
    setState(() { _showAdditionalInfo = false; });

    // Reset beneficiary fields
    _beneficiaryNomController.clear();
    _beneficiaryTelController.clear();
    _beneficiaryEmailController.clear();
    _isAssigning = false;

    final storageService = StorageService();

    final shouldProceed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.72,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollController) => Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    // ── Handle ──────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),

                    // ── Scrollable body ──────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Title ──────────────────────────────────────
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _amber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.confirmation_number_outlined, size: 20, color: _amber),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Confirmer la réservation',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ]),
                            const SizedBox(height: 18),

                            // ── Trip card ──────────────────────────────────
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[200]!),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                              ),
                              child: Column(
                                children: [
                                  // Route section
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                    child: Column(
                                      children: [
                                        // Labels DÉPART / ARRIVÉE
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('DÉPART', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange[600], letterSpacing: 0.8)),
                                            // Time chip center
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[100],
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                widget.heureDepart.length >= 5 ? widget.heureDepart.substring(0, 5) : widget.heureDepart,
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                                              ),
                                            ),
                                            Text('ARRIVÉE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange[600], letterSpacing: 0.8)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        // Cities + arrow
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                widget.villeDepart,
                                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              child: Column(
                                                children: [
                                                  const Icon(Icons.arrow_forward_rounded, color: _amber, size: 20),
                                                  if (widget.dureeVoyage != null)
                                    Text(widget.dureeVoyage!, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                widget.villeArrivee,
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  Divider(height: 1, color: Colors.grey[150]),

                                  // Chips row
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        _tripChip(Icons.calendar_today_rounded, _formatDate(widget.dateDepart), Colors.blueGrey),
                                        _tripChip(Icons.event_seat_rounded, 'Siège $seatName', Colors.amber[800]!),
                                        if (widget.classe != null)
                                          _tripChip(Icons.eco_rounded, widget.classe!, Colors.green[700]!),
                                      ],
                                    ),
                                  ),

                                  // Total bar
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.green[600],
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(15),
                                        bottomRight: Radius.circular(15),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.credit_card_rounded, color: Colors.white, size: 18),
                                        const SizedBox(width: 8),
                                        const Text('Total à payer', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                                        const Spacer(),
                                        Text(
                                          '${_formatMontant(widget.montant)} FCFA',
                                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ── Passenger section ──────────────────────────
                            if (_isLoadingUserInfo)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(_amber),
                                    strokeWidth: 3,
                                  ),
                                ),
                              )
                            else ...[
                              Text(
                                'PASSAGER PRINCIPAL',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 1.2),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.grey[200]!),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(
                                        color: _amber.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          _initials(_userInfo?['prenom'], _userInfo?['nom']),
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amber[800]),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${_userInfo?['prenom'] ?? ''} ${_userInfo?['nom'] ?? ''}'.trim().isEmpty
                                                ? 'Utilisateur'
                                                : '${_userInfo?['prenom'] ?? ''} ${_userInfo?['nom'] ?? ''}'.trim(),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                                          ),
                                          if ((_userInfo?['telephone'] ?? '').toString().isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Row(children: [
                                              Icon(Icons.phone_rounded, size: 13, color: Colors.grey[500]),
                                              const SizedBox(width: 4),
                                              Text(
                                                _userInfo?['telephone'] ?? '',
                                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                              ),
                                            ]),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.green[200]!),
                                      ),
                                      child: Text('Moi', style: TextStyle(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // ── Assign toggle ──────────────────────────
                              GestureDetector(
                                onTap: () => setModalState(() => _showAdditionalInfo = !_showAdditionalInfo),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: _showAdditionalInfo ? Colors.blue[50] : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _showAdditionalInfo ? Colors.blue[300]! : Colors.grey[300]!,
                                      width: _showAdditionalInfo ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person_add_alt_1_rounded,
                                        size: 18,
                                        color: _showAdditionalInfo ? Colors.blue[600] : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Attribuer à quelqu\'un d\'autre',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: _showAdditionalInfo ? Colors.blue[700] : Colors.grey[700],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      AnimatedRotation(
                                        turns: _showAdditionalInfo ? 0.5 : 0,
                                        duration: const Duration(milliseconds: 200),
                                        child: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: _showAdditionalInfo ? Colors.blue[600] : Colors.grey[500],
                                          size: 22,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // ── Beneficiary form ───────────────────────
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: _showAdditionalInfo
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: Colors.grey[200]!),
                                        ),
                                        child: Form(
                                          key: _beneficiaryFormKey,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [
                                                Icon(Icons.person_pin_circle_rounded, size: 15, color: Colors.blue[600]),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Informations du bénéficiaire',
                                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.blue[700]),
                                                ),
                                              ]),
                                              const SizedBox(height: 12),
                                              _buildBeneficiaryField(
                                                controller: _beneficiaryNomController,
                                                label: 'Nom complet',
                                                icon: Icons.badge_outlined,
                                                isRequired: true,
                                                keyboardType: TextInputType.name,
                                              ),
                                              const SizedBox(height: 10),
                                              _buildBeneficiaryField(
                                                controller: _beneficiaryTelController,
                                                label: 'Numéro de téléphone',
                                                icon: Icons.phone_rounded,
                                                isRequired: true,
                                                keyboardType: TextInputType.phone,
                                                prefixText: '🇨🇮 +225',
                                                maxLength: 10,
                                              ),
                                              const SizedBox(height: 10),
                                              _buildBeneficiaryField(
                                                controller: _beneficiaryEmailController,
                                                label: 'Adresse email',
                                                icon: Icons.email_outlined,
                                                isRequired: false,
                                                keyboardType: TextInputType.emailAddress,
                                                hintText: 'Facultatif',
                                              ),
                                              const SizedBox(height: 8),
                                              Row(children: [
                                                Icon(Icons.info_outline_rounded, size: 12, color: Colors.grey[400]),
                                                const SizedBox(width: 5),
                                                Text(
                                                  'Nom complet et téléphone sont obligatoires',
                                                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                                                ),
                                              ]),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                              ),
                            ],
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // ── Fixed action buttons ──────────────────────────────
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        20, 12, 20,
                        MediaQuery.of(ctx).viewInsets.bottom +
                            MediaQuery.of(ctx).padding.bottom +
                            16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Colors.grey[100]!)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                                side: BorderSide(color: Colors.grey[350]!),
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                if (_showAdditionalInfo) {
                                  if (!(_beneficiaryFormKey.currentState?.validate() ?? false)) return;
                                  _isAssigning = true;
                                  _assignNom = _beneficiaryNomController.text.trim();
                                  _assignTel = _beneficiaryTelController.text.trim();
                                  _assignEmail = _beneficiaryEmailController.text.trim().isEmpty
                                      ? null
                                      : _beneficiaryEmailController.text.trim();
                                } else {
                                  _isAssigning = false;
                                  _assignNom = null;
                                  _assignTel = null;
                                  _assignEmail = null;
                                }
                                Navigator.of(ctx).pop(true);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _amber,
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_rounded, size: 16),
                                  SizedBox(width: 6),
                                  Text('Confirmer et payer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                ],
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
          },
        ),
      );

    if (shouldProceed != true || !mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigatorCtx = context;

    showDialog(
      context: navigatorCtx,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_amber),
          strokeWidth: 3,
        ),
      ),
    );

    try {
      final storageService = StorageService();
      final token = await storageService.getToken();
      if (token == null) throw Exception('Vous devez être connecté pour effectuer cette action');

      final response = await _apiService.initierPaiement(
        token: token,
        voyageId: widget.voyageId,
        idArretVoyage: widget.arretId,
        numeroPlace: seatNumber,
        telephoneProprietaire: _isAssigning ? _assignTel : null,
        nomComplet: _isAssigning ? _assignNom : null,
        emailProprietaire: _isAssigning ? _assignEmail : null,
      );

      if (!mounted) return;
      Navigator.of(navigatorCtx).pop(); // close loader

      if (response['success'] == true && response['url'] != null) {
        Navigator.push(
          navigatorCtx,
          MaterialPageRoute(builder: (_) => PaiementWebViewPage(urlPaiement: response['url'])),
        );
      } else {
        throw Exception(response['message'] ?? 'Erreur lors de l\'initialisation du paiement');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(navigatorCtx).pop(); // close loader
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _initials(dynamic prenom, dynamic nom) {
    final p = (prenom ?? '').toString().trim();
    final n = (nom ?? '').toString().trim();
    if (p.isEmpty && n.isEmpty) return '?';
    return '${p.isNotEmpty ? p[0] : ''}${n.isNotEmpty ? n[0] : ''}'.toUpperCase();
  }

  Widget _tripChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildBeneficiaryField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isRequired,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
    String? hintText,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        label: isRequired
            ? RichText(
                text: TextSpan(
                  text: label,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  children: const [
                    TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            : null,
        labelText: isRequired ? null : label,
        hintText: hintText,
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey[600]),
        prefixIcon: prefixText != null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Text(prefixText, style: const TextStyle(fontSize: 13)),
            )
          : Icon(icon, size: 18, color: Colors.blue[400]),
        counterText: '',
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.blue[100]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.blue[400]!, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      ),
      validator: isRequired
        ? (v) => (v == null || v.trim().isEmpty) ? 'Ce champ est obligatoire' : null
        : null,
    );
  }

  String _formatMontant(double montant) {
    final s = montant.toInt().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
      return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  // ── Seat widget ───────────────────────────────────────────────────────────

  Widget _buildSeat(
    dynamic place,
    String seatName, {
    bool isProcheChauffeur = false,
    bool isChauffeur = false,
    double seatW = 52,
    double seatH = 62,
  }) {
    final int seatNumber = _toInt(place['numero']);
    final bool isOccupied = _isSeatOccupied(seatNumber);
    final bool isUnavailable = _toInt(place['disponible']) == 0;
    final bool isSelected = _selectedSeat == seatNumber;
    final double iconSz = (seatW * 0.33).clamp(14, 20);
    final double numSz = (seatW * 0.22).clamp(9, 13);
    final double nameSz = (seatW * 0.16).clamp(7, 10);

    Color bgColor;
    Color borderColor;
    double borderWidth = 1.5;
    Widget iconWidget;
    Color numColor;

    if (isChauffeur) {
      bgColor = Colors.blue[50]!;
      borderColor = Colors.blue[200]!;
      iconWidget = Icon(Icons.directions_bus, size: iconSz, color: Colors.blue[400]);
      numColor = Colors.blue[700]!;
    } else if (isSelected) {
      bgColor = Colors.amber[100]!;
      borderColor = _amber;
      borderWidth = 2.5;
      iconWidget = Icon(Icons.check_circle, size: iconSz, color: Colors.amber[700]);
      numColor = Colors.amber[900]!;
    } else if (isUnavailable) {
      bgColor = Colors.red[50]!;
      borderColor = Colors.red[300]!;
      iconWidget = Icon(Icons.block, size: iconSz, color: Colors.red[400]);
      numColor = Colors.red[400]!;
    } else if (isOccupied) {
      bgColor = Colors.grey[200]!;
      borderColor = Colors.grey[400]!;
      iconWidget = Icon(Icons.person, size: iconSz, color: Colors.grey[500]);
      numColor = Colors.grey[500]!;
    } else if (isProcheChauffeur) {
      bgColor = Colors.blue[50]!;
      borderColor = Colors.blue[200]!;
      iconWidget = Icon(Icons.event_seat, size: iconSz, color: Colors.blue[400]);
      numColor = Colors.blue[700]!;
    } else {
      bgColor = Colors.green[50]!;
      borderColor = Colors.green[400]!;
      iconWidget = Icon(Icons.event_seat, size: iconSz, color: Colors.green[600]);
      numColor = Colors.green[700]!;
    }

    return GestureDetector(
      onTap: () => _selectSeat(seatNumber, seatName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: seatW,
        height: seatH,
        margin: EdgeInsets.all(seatW * 0.055),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(5),
            bottomRight: Radius.circular(5),
          ),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: isSelected
            ? [BoxShadow(color: _amber.withOpacity(0.4), spreadRadius: 1, blurRadius: 6, offset: const Offset(0, 2))]
            : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 3, offset: const Offset(0, 1))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 2),
            Text(
              '${place['numero'] ?? '?'}',
              style: TextStyle(color: numColor, fontWeight: FontWeight.bold, fontSize: numSz),
            ),
            Text(
              seatName,
              style: TextStyle(color: numColor.withOpacity(0.75), fontSize: nameSz),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChauffeurSeat({double seatW = 52, double seatH = 62}) {
    return Container(
      width: seatW,
      height: seatH,
      margin: EdgeInsets.all(seatW * 0.055),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
          bottomLeft: Radius.circular(5),
          bottomRight: Radius.circular(5),
        ),
        border: Border.all(color: Colors.black54),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings_rounded, size: (seatW * 0.36).clamp(14, 22), color: Colors.white),
          const SizedBox(height: 2),
          Text(
            'Chauf.',
            style: TextStyle(fontSize: (seatW * 0.16).clamp(7, 10), color: Colors.white70, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnLabels({double seatW = 52, double aisleW = 16}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 24),
        _colLabel('A', seatW),
        _colLabel('B', seatW),
        SizedBox(width: aisleW),
        _colLabel('C', seatW),
        _colLabel('D', seatW),
      ],
    );
  }

  Widget _colLabel(String t, double w) => SizedBox(
    width: w,
    child: Center(
      child: Text(t,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 1)),
    ),
  );

  List<Widget> _buildSeatGrid([List<dynamic>? placesToShow, double seatW = 52, double seatH = 62]) {
    List<Widget> rows = [];
    final places = placesToShow ?? _placesDisponibles;
    final Map<int, dynamic> disponiblesMap = {};
    for (var p in places) disponiblesMap[_toInt(p['numero'])] = p;
    final Map<int, dynamic> occupeesMap = {};
    for (var p in _placesOccupees) {
      final num = _toInt(p['numero_place']);
      if (disponiblesMap.containsKey(num)) occupeesMap[num] = p;
    }
    final allNums = <int>{...disponiblesMap.keys, ...occupeesMap.keys};
    if (allNums.isEmpty) return [const Center(child: Text('Aucune place disponible'))];

    final sorted = allNums.toList()..sort();
    final numRows = (sorted.length / _colonnes).ceil();
    final lblW = seatW + (seatW * 0.115);
    final aisleW = (seatW * 0.3).clamp(10.0, 16.0);

    for (int row = 0; row < numRows; row++) {
      List<Widget> rowChildren = [];
      for (int col = 0; col < _colonnes; col++) {
        final idx = (row * _colonnes) + col;
        if (idx >= sorted.length) {
          rowChildren.add(SizedBox(width: lblW, height: seatH + 6));
          if (_colonnes == 4 && col == 1) rowChildren.add(SizedBox(width: aisleW));
          continue;
        }
        if (_colonnes == 4 && col == 2) rowChildren.add(SizedBox(width: aisleW));
        final seatNum = sorted[idx];
        final placeData = disponiblesMap[seatNum] ?? occupeesMap[seatNum] ?? {'numero': seatNum, 'disponible': 0};
        final placeName = placeData['nom'] ?? 'S$seatNum';
        rowChildren.add(_buildSeat(placeData, placeName, seatW: seatW, seatH: seatH));
      }
      if (rowChildren.isNotEmpty) {
        rows.add(Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              child: Text('${row + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 4),
            ...rowChildren,
          ],
        ));
      }
    }
    return [Column(mainAxisSize: MainAxisSize.min, children: rows)];
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 12, height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.6), width: 1),
        ),
      ),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _buildSeatStats(int availableCount, int occupiedCount) {
    final total = _placesDisponibles.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        _statCard(Icons.event_seat_rounded, '$total', 'Total', Colors.blueGrey),
        const SizedBox(width: 8),
        _statCard(Icons.check_circle_outline_rounded, '$availableCount', 'Disponible', Colors.green),
        const SizedBox(width: 8),
        _statCard(Icons.person_rounded, '$occupiedCount', 'Occupé', Colors.orange),
      ]),
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.75))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusLayout() {
    if (_isLoading) {
      return AppShimmer(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: 30,
          itemBuilder: (_, __) => const SkeletonSeat(),
        ),
      );
    }

    final placesProcheChauffeur = _placesDisponibles.where(_isProcheChauffeur).toList();
    final placesAConsiderer = _placesDisponibles.where((p) => !_isProcheChauffeur(p)).toList();
    final occupiedCount = _placesOccupees.length;
    final unavailableCount = _placesDisponibles.where((p) => _toInt(p['disponible']) == 0).length;
    final total = _placesDisponibles.length;
    final availableCount = _placesDisponibles.where((p) {
      if (_toInt(p['disponible']) != 1) return false;
      return !_placesOccupees.any((o) => _toInt(o['numero_place']) == _toInt(p['numero']));
    }).length;
    final libreCount = total - occupiedCount - unavailableCount;
    final progress = total > 0 ? (total - libreCount) / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Stats card ──────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$availableCount',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        TextSpan(
                          text: ' / $total places libres',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: _formatMontant(widget.montant),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _amber),
                        ),
                        TextSpan(
                          text: '\nFCFA / siège',
                          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (occupiedCount > 0) ...[
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('$occupiedCount occupé', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    const SizedBox(width: 12),
                  ],
                  if (unavailableCount > 0) ...[
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.red[300], shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('$unavailableCount indispo.', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ],
              ),
            ],
          ),
        ),

        // ── Legend row ──────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem(Colors.green[400]!, 'Libre'),
              _buildLegendItem(_amber, 'Choisi'),
              _buildLegendItem(Colors.grey[400]!, 'Occupé'),
              _buildLegendItem(Colors.red[300]!, 'Indispo.'),
              _buildLegendItem(const Color(0xFF2C2C2C), 'Chauffeur'),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Bus frame ───────────────────────────────────────────────────────
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!, width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                // PORTE / AVANT DU VÉHICULE header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
                    border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('PORTE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[600], letterSpacing: 0.8)),
                      ),
                      Text('AVANT DU VÉHICULE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[500], letterSpacing: 0.5)),
                    ],
                  ),
                ),

                // Bus body
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final aw = constraints.maxWidth - 28;
                        final seatW = ((aw - 24) / 4.74).clamp(34.0, 60.0);
                        final seatH = seatW * 1.18;
                        final aisleW = (seatW * 0.3).clamp(10.0, 16.0);

                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                          child: Column(
                            children: [
                              // Chauffeur row
                              if (placesProcheChauffeur.isNotEmpty) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildChauffeurSeat(seatW: seatW, seatH: seatH),
                                    const SizedBox(width: 12),
                                    Wrap(
                                      children: placesProcheChauffeur.map((p) => _buildSeat(
                                        p, p['nom'] ?? '?',
                                        isProcheChauffeur: true,
                                        seatW: seatW, seatH: seatH,
                                      )).toList(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Divider(color: Colors.grey[200], thickness: 1),
                                const SizedBox(height: 8),
                              ],

                              // Column labels
                              if (_colonnes == 4) ...[
                                _buildColumnLabels(seatW: seatW, aisleW: aisleW),
                                const SizedBox(height: 4),
                              ],

                              // Seat grid
                              Center(
                                child: _buildSeatGrid(placesAConsiderer, seatW, seatH).first,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoyageDetails() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _buildDetailChip(Icons.access_time, widget.heureDepart.length >= 5 ? widget.heureDepart.substring(0, 5) : widget.heureDepart),
        const SizedBox(width: 8),
        _buildDetailChip(Icons.directions_bus, widget.immatriculationBus),
        if (widget.classe != null) ...[
          const SizedBox(width: 8),
          _buildDetailChip(Icons.event_seat, widget.classe!),
        ],
        if (!widget.disponibleToujours) ...[
          const SizedBox(width: 8),
          _buildDetailChip(Icons.calendar_today_rounded, _formatDate(widget.dateDepart)),
        ] else ...[
          const SizedBox(width: 8),
          _buildDetailChip(Icons.repeat_rounded, 'Tous les jours'),
        ],
      ]),
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.black87),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildBottomBar() {
    if (_selectedSeat == null) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -3))],
      ),
      child: Row(
        children: [
          // Seat chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _amber,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _selectedSeatName ?? '',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  const TextSpan(
                    text: '1 siège · ',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  TextSpan(
                    text: '${_formatMontant(widget.montant)} FCFA',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _showConfirmationModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: _amber,
              foregroundColor: Colors.black87,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Continuer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: _amber,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, color: Colors.black87, size: 24),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.all(6),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text('Sélection du siège',
                            style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500)),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ]),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${widget.villeDepart}  →  ${widget.villeArrivee}',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _buildVoyageDetails(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bus layout ────────────────────────────────────────────────────
          Expanded(child: _buildBusLayout()),

          // ── Bottom bar ────────────────────────────────────────────────────
          _buildBottomBar(),
        ],
      ),
    );
  }
}
