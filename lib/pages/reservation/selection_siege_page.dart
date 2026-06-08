import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_service.dart';
import '../../core/widgets/shimmer_skeleton.dart';

class SelectionSiegePage extends StatefulWidget {
  final int busId;
  final int voyageId;
  final int nombrePlaces;

  const SelectionSiegePage({
    super.key,
    required this.busId,
    required this.voyageId,
    required this.nombrePlaces,
  });

  @override
  State<SelectionSiegePage> createState() => _SelectionSiegePageState();
}

class _SelectionSiegePageState extends State<SelectionSiegePage>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  static const _amber  = Color(0xFFFFC107);
  static const _green  = Color(0xFF2E7D32);
  static const _bgGreen = Color(0xFFE8F5E9);
  static const _borderGreen = Color(0xFF81C784);

  // Siège : largeur × hauteur
  static const double _sW = 50;
  static const double _sH = 56;
  // Espace entre sièges dans la même rangée (même côté)
  static const double _gap = 8;
  // Largeur numéro de rangée
  static const double _numW = 24;
  static const double _numGap = 6;
  // Largeur couloir fixe (garanti alignement)
  static const double _aisleW = 36;

  bool _isLoading = true;
  String? _errorMsg;
  List<dynamic> _placesOccupees = [];
  List<dynamic> _placesDisponibles = [];
  int? _selectedSeat;
  String? _selectedSeatName;

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
    _loadBusSeats();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBusSeats() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/bus_detail_place/${widget.busId}'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _placesOccupees    = data['liste_place_deja_occupe'] ?? [];
            _placesDisponibles = data['data']?['places'] ?? [];
          });
        } else {
          setState(() => _errorMsg = data['message'] ?? 'Erreur lors du chargement des places');
        }
      } else {
        setState(() => _errorMsg = 'Erreur serveur (${response.statusCode})');
      }
    } catch (_) {
      setState(() => _errorMsg = 'Erreur de connexion au serveur');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isSeatOccupied(int n) =>
      _placesOccupees.any((p) => p['numero_place'] == n);

  void _selectSeat(int num, String nom) {
    if (_isSeatOccupied(num)) return;
    setState(() {
      if (_selectedSeat == num) {
        _selectedSeat = null;
        _selectedSeatName = null;
      } else {
        _selectedSeat = num;
        _selectedSeatName = nom;
      }
    });
  }

  void _confirmReservation() {
    if (_selectedSeat == null) return;
    Navigator.of(context).pop({
      'seatNumber': _selectedSeat,
      'seatName': _selectedSeatName,
    });
  }

  // ── Siège individuel ───────────────────────────────────────────────────────
  Widget _buildSeat(Map<String, dynamic> place) {
    final int num    = place['numero'] ?? 0;
    final String nom = place['nom'] ?? '?';
    final bool isOccupied = _isSeatOccupied(num);
    final bool isSelected = _selectedSeat == num;

    final Color bg, border, fg;
    if (isOccupied) {
      bg = const Color(0xFFEEEEEE);
      border = const Color(0xFFBDBDBD);
      fg = Colors.grey;
    } else if (isSelected) {
      bg = _amber;
      border = const Color(0xFFF57F17);
      fg = Colors.black87;
    } else {
      bg = _bgGreen;
      border = _borderGreen;
      fg = _green;
    }

    return GestureDetector(
      onTap: () => _selectSeat(num, nom),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: _sW,
        height: _sH,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.only(
            topLeft:     Radius.circular(12),
            topRight:    Radius.circular(12),
            bottomLeft:  Radius.circular(5),
            bottomRight: Radius.circular(5),
          ),
          border: Border.all(color: border, width: isSelected ? 2 : 1.5),
          boxShadow: isSelected
              ? [BoxShadow(color: _amber.withOpacity(0.45), blurRadius: 10, offset: const Offset(0, 3))]
              : [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            isOccupied ? Icons.person_rounded : Icons.event_seat_rounded,
            size: 20,
            color: fg,
          ),
          const SizedBox(height: 3),
          Text(nom,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ]),
      ),
    );
  }

  // ── Layout bus : la largeur de chaque rangée est identique aux labels ──────
  // Structure : [numW+numGap] [A:sW] [gap] [B:sW] [aisleW] [C:sW] [gap] [D:sW]
  double get _rowWidth => _numW + _numGap + _sW + _gap + _sW + _aisleW + _sW + _gap + _sW;

  Widget _buildColumnLabels() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: _numW + _numGap), // aligne avec les numéros de rangée
        _label('A', _sW),
        SizedBox(width: _gap),
        _label('B', _sW),
        SizedBox(width: _aisleW),
        _label('C', _sW),
        SizedBox(width: _gap),
        _label('D', _sW),
      ],
    );
  }

  Widget _label(String t, double w) => SizedBox(
        width: w,
        child: Center(
          child: Text(t,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey[400],
                letterSpacing: 1,
              )),
        ),
      );

  Widget _buildSeatRow(int rowNum, List<dynamic> seats) {
    final left  = seats.take(2).toList();
    final right = seats.skip(2).take(2).toList();

    Widget seatOrEmpty(List<dynamic> list, int idx) {
      if (idx < list.length) return _buildSeat(list[idx] as Map<String, dynamic>);
      return SizedBox(width: _sW, height: _sH);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Numéro rangée
          SizedBox(
            width: _numW,
            child: Text('$rowNum',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w600)),
          ),
          SizedBox(width: _numGap),
          // Gauche A B
          seatOrEmpty(left, 0),
          SizedBox(width: _gap),
          seatOrEmpty(left, 1),
          // Couloir
          SizedBox(
            width: _aisleW,
            child: Center(
              child: Container(
                width: 2,
                height: _sH * 0.5,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
          // Droite C D
          seatOrEmpty(right, 0),
          SizedBox(width: _gap),
          seatOrEmpty(right, 1),
        ],
      ),
    );
  }

  Widget _buildBusContent() {
    final total    = _placesDisponibles.length;
    final occupied = _placesOccupees.length;
    final available = total - occupied;
    final rowCount  = (total / 4).ceil();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.blueGrey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Avant du bus ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(color: Colors.blueGrey.shade100, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_outline_rounded,
                      size: 22, color: Colors.blueGrey.shade600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chauffeur',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.blueGrey.shade700)),
                      Text('Avant du bus',
                          style: TextStyle(
                              fontSize: 10, color: Colors.blueGrey.shade400)),
                    ],
                  ),
                ),
                Icon(Icons.settings_rounded,
                    size: 22, color: Colors.blueGrey.shade300),
              ],
            ),
          ),

          // ── Légende + stats compacts ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _legendDot(_bgGreen, _borderGreen, 'Libre ($available)'),
                _legendDot(_amber, const Color(0xFFF57F17), 'Sélectionné'),
                _legendDot(const Color(0xFFEEEEEE), const Color(0xFFBDBDBD),
                    'Occupé ($occupied)'),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Grille sièges ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Labels colonnes
                _buildColumnLabels(),
                const SizedBox(height: 10),
                // Rangées
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rowCount,
                  itemBuilder: (_, row) {
                    final seats = _placesDisponibles
                        .skip(row * 4)
                        .take(4)
                        .toList();
                    return _buildSeatRow(row + 1, seats);
                  },
                ),
              ],
            ),
          ),

          // ── Arrière du bus ──────────────────────────────────────────────
          Container(
            height: 14,
            margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
              border: Border(
                  top: BorderSide(color: Colors.blueGrey.shade100, width: 1)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _legendDot(Color bg, Color border, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Icon(Icons.event_seat_rounded, size: 12, color: border),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    final total    = _placesDisponibles.length;
    final occupied = _placesOccupees.length;
    final available = total - occupied;

    return Container(
      decoration: const BoxDecoration(
        color: _amber,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.black87, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Sélection du siège',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  Text('Choisissez votre place',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                ]),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  '/dashboard',
                  (route) => false,
                ),
                icon: const Icon(Icons.home_outlined,
                    color: Colors.black87, size: 24),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.all(8),
                ),
                tooltip: 'Accueil',
              ),
            ]),
            if (!_isLoading && _errorMsg == null && _placesDisponibles.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(children: [
                _statChip(Icons.directions_bus_rounded, '${_placesDisponibles.length}', 'places total'),
                const SizedBox(width: 8),
                _statChip(Icons.event_seat_rounded, '$available', 'disponibles',
                    color: Colors.green.shade800),
                const SizedBox(width: 8),
                _statChip(Icons.person_rounded, '$occupied', 'occupées',
                    color: Colors.black54),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label,
      {Color color = Colors.black87}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text('$value ',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.75))),
      ]),
    );
  }

  // ── États ──────────────────────────────────────────────────────────────────
  Widget _buildLoadingState() {
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.red),
          ),
          const SizedBox(height: 16),
          const Text('Erreur de chargement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(_errorMsg ?? '',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadBusSeats,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _amber,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: _amber.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.event_seat_rounded, size: 48, color: _amber),
          ),
          const SizedBox(height: 16),
          const Text('Aucune place disponible',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Toutes les places de ce bus sont occupées',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  // ── Panel bas ──────────────────────────────────────────────────────────────
  Widget _buildBottomPanel() {
    if (_selectedSeat == null) return const SizedBox.shrink();

    return AnimatedSlide(
      offset: Offset.zero,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.event_seat_rounded,
                  color: _amber, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Siège sélectionné',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('Place $_selectedSeatName',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ]),
            ),
            GestureDetector(
              onTap: () => setState(() {
                _selectedSeat = null;
                _selectedSeatName = null;
              }),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.close_rounded,
                    size: 18, color: Colors.grey[600]),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _confirmReservation,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: const Text('Confirmer la réservation',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _amber,
                foregroundColor: Colors.black87,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          SlideTransition(
            position: _slideHeader,
            child: FadeTransition(
                opacity: _fadeHeader, child: _buildHeader(context)),
          ),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMsg != null
                    ? _buildErrorState()
                    : _placesDisponibles.isEmpty
                        ? _buildEmptyState()
                        : SingleChildScrollView(
                            padding: const EdgeInsets.only(top: 16),
                            child: _buildBusContent(),
                          ),
          ),
          _buildBottomPanel(),
        ],
      ),
    );
  }
}
