import 'package:flutter/material.dart';
import 'package:betro/services/paiement_service.dart';
import 'package:betro/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shimmer/shimmer.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../dashboard/ticket_page.dart';

class DetailPaiementPage extends StatefulWidget {
  final int paiementId;

  const DetailPaiementPage({Key? key, required this.paiementId}) : super(key: key);

  @override
  _DetailPaiementPageState createState() => _DetailPaiementPageState();
}

class _DetailPaiementPageState extends State<DetailPaiementPage>
    with SingleTickerProviderStateMixin {
  final PaiementService _paiementService = PaiementService();
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _paiementData;
  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  String _errorMessage = '';

  static const _amber = Color(0xFFFFC107);

  final NumberFormat _montantFormat = NumberFormat.decimalPattern('fr');

  AnimationController? _enterCtrl;

  // Accesseurs avec valeurs de repli si non initialisé
  Animation<Offset> get _slideHeader => _enterCtrl == null
      ? AlwaysStoppedAnimation(Offset.zero)
      : Tween<Offset>(begin: const Offset(0, -0.35), end: Offset.zero).animate(
          CurvedAnimation(parent: _enterCtrl!,
              curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic)));

  Animation<double> get _fadeHeader => _enterCtrl == null
      ? const AlwaysStoppedAnimation(1.0)
      : Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: _enterCtrl!,
              curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));

  Animation<double> get _fadeHero => _enterCtrl == null
      ? const AlwaysStoppedAnimation(1.0)
      : Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: _enterCtrl!,
              curve: const Interval(0.3, 0.7, curve: Curves.easeOut)));

  Animation<double> get _fadeCards => _enterCtrl == null
      ? const AlwaysStoppedAnimation(1.0)
      : Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: _enterCtrl!,
              curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));

  Animation<Offset> get _slideCards => _enterCtrl == null
      ? AlwaysStoppedAnimation(Offset.zero)
      : Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
          CurvedAnimation(parent: _enterCtrl!,
              curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic)));

  Animation<Offset> get _slideHero => _enterCtrl == null
      ? AlwaysStoppedAnimation(Offset.zero)
      : Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(parent: _enterCtrl!,
              curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic)));

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _loadPaiementDetails();
  }

  @override
  void dispose() {
    _enterCtrl?.dispose();
    super.dispose();
  }

  Future<void> _loadPaiementDetails() async {
    try {
      final details = await _paiementService.getPaiementDetails(widget.paiementId);
      setState(() { _paiementData = details; _isLoading = false; });
      _enterCtrl?.forward();
    } catch (e) {
      final cleaned = _cleanErrorMessage(e.toString());
      setState(() { _isLoading = false; _errorMessage = 'Erreur: $cleaned'; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur de chargement: $cleaned'),
          backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  String _cleanErrorMessage(String msg) {
    return msg
        .replaceAll(RegExp(r'https?://[^\s]+'), '[URL]')
        .replaceAll(RegExp(r'\b[a-zA-Z0-9]{20,}\b'), '[TOKEN]')
        .replaceAll(RegExp(r'ClientException.*'), 'Erreur de connexion réseau')
        .replaceAll(RegExp(r'Failed host lookup.*'), 'Serveur inaccessible')
        .replaceAll(RegExp(r'No address associated.*'), 'Serveur inaccessible');
  }

  String _formatDate(String dateStr) {
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(dateStr));
    } catch (_) { return dateStr; }
  }

  String _formatMontant(dynamic m) {
    try {
      double v = m is String ? double.tryParse(m) ?? 0 : (m as num).toDouble();
      return _montantFormat.format(v);
    } catch (_) { return m.toString(); }
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
      else _toast('Impossible de lancer l\'appel', Colors.red);
    } catch (_) { _toast('Erreur lors de l\'appel', Colors.red); }
  }

  void _toast(String msg, Color bg) => Fluttertoast.showToast(
    msg: msg, toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM,
    backgroundColor: bg, textColor: Colors.white,
  );

  void _showFullImage(String url) {
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.all(20),
      child: Stack(alignment: Alignment.topRight, children: [
        Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: ClipRRect(borderRadius: BorderRadius.circular(20),
            child: Image.network(url, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.broken_image, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('Image non disponible', style: TextStyle(color: Colors.grey.shade600)),
              ])),
            ),
          ),
        ),
        Positioned(top: 10, right: 10,
          child: Container(
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
            child: IconButton(icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop()),
          ),
        ),
      ]),
    ));
  }

  String _getStatusText(dynamic status) {
    switch (status?.toString().toLowerCase()) {
      case '1': case 'success': case 'réussi': return 'Payé';
      case '0': case 'failed': case 'échoué': return 'Échoué';
      case 'pending': case 'en attente': return 'En attente';
      default: return status?.toString() ?? 'Inconnu';
    }
  }

  Map<String, dynamic> _statusStyle(dynamic status) {
    switch (status?.toString().toLowerCase()) {
      case '1': case 'success': case 'réussi': case 'payé':
        return {'color': Colors.green, 'bg': Colors.green.shade50, 'icon': Icons.check_circle_rounded, 'text': 'Payé'};
      case '0': case 'failed': case 'échoué':
        return {'color': Colors.red, 'bg': Colors.red.shade50, 'icon': Icons.cancel_rounded, 'text': 'Échoué'};
      case 'pending': case 'en attente':
        return {'color': Colors.orange, 'bg': Colors.orange.shade50, 'icon': Icons.schedule_rounded, 'text': 'En attente'};
      default:
        return {'color': Colors.grey, 'bg': Colors.grey.shade50, 'icon': Icons.help_rounded, 'text': status?.toString() ?? 'Inconnu'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: _isLoading
              ? _buildSkeleton()
              : _errorMessage.isNotEmpty
                  ? _buildError()
                  : _paiementData == null
                      ? _buildEmpty()
                      : _buildContentBody(),
        ),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: _amber,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Row(children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.all(8),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_rounded, color: Colors.black87, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Détail du paiement',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87))),
            if (_paiementData != null)
              _isGeneratingPdf
                  ? const SizedBox(
                      width: 36, height: 36,
                      child: Center(
                        child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black87))),
                      ),
                    )
                  : IconButton(
                      onPressed: _downloadPdf,
                      icon: const Icon(Icons.download_rounded, color: Colors.black87, size: 22),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.all(8),
                      ),
                      tooltip: 'Télécharger le reçu PDF',
                    ),
          ]),
        ),
      ),
    );
  }

  // ── Contenu principal ─────────────────────────────────────────────────────
  Widget _buildContentBody() {
    final p = _paiementData!['paiement'];
    final t = _paiementData!['tarification'] ?? {};
    final c = _paiementData!['compagnie'] ?? {};
    final statusInfo = _statusStyle(p['status']);
    final montant = p['montant'];
    final villeDepart = t['ville_depart']?['nom_ville'] ?? 'N/A';
    final villeArrivee = t['ville_arrivee']?['nom_ville'] ?? 'N/A';

    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(children: [
          // ── Hero : montant + statut ──
          FadeTransition(
            opacity: _fadeHero,
            child: SlideTransition(
              position: _slideHero,
              child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))],
            ),
            child: Column(children: [
              // Statut
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: (statusInfo['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: (statusInfo['color'] as Color).withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(statusInfo['icon'] as IconData, size: 15, color: statusInfo['color'] as Color),
                  const SizedBox(width: 6),
                  Text(statusInfo['text'] as String,
                      style: TextStyle(color: statusInfo['color'] as Color,
                          fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 14),
              // Montant
              Text('${_formatMontant(montant)} FCFA',
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 6),
              // Trajet
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.circle, size: 8, color: Colors.green),
                const SizedBox(width: 5),
                Text(villeDepart, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                ),
                Text(villeArrivee, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 5),
                const Icon(Icons.location_on_rounded, size: 8, color: Colors.red),
              ]),
            ]),
          ),
            ), // SlideTransition hero
          ), // FadeTransition hero
          const SizedBox(height: 14),

          // ── Section cards avec stagger ──
          FadeTransition(
            opacity: _fadeCards,
            child: SlideTransition(
              position: _slideCards,
              child: Column(children: [

          // ── Résumé paiement ──
          _buildCard('Résumé du paiement', Icons.receipt_long_rounded, [
            // Référence (copiable)
            _buildCopyRow('Référence', p['referencePaiement'] ?? 'N/A'),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 8),
            // Attribué à
            if ((p['nom_complet']?.toString().isNotEmpty ?? false) ||
                (p['telephone_proprietaire']?.toString().isNotEmpty ?? false)) ...[
              _buildLabel('Attribué à'),
              const SizedBox(height: 6),
              if (p['nom_complet']?.toString().isNotEmpty ?? false)
                _buildIconRow(Icons.person_outline_rounded, p['nom_complet'], Colors.amber.shade800),
              if (p['telephone_proprietaire']?.toString().isNotEmpty ?? false)
                GestureDetector(
                  onTap: () => _makePhoneCall(p['telephone_proprietaire']),
                  child: _buildIconRow(Icons.phone_rounded, p['telephone_proprietaire'], Colors.green.shade700),
                ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 8),
            ],
            _buildRow('Code paiement', p['code_paiement'] ?? 'N/A'),
            _buildRow('N° de place', p['numero_place']?.toString() ?? 'N/A'),
            _buildRow('Téléphone', p['telephone']?.toString() ?? 'N/A'),
            _buildRow('Méthode', p['moyenPaiement'] ?? 'N/A'),
            _buildRow('Date', _formatDate(p['datePaiement'] ?? '')),
            _buildRow('Heure', p['HeurePaiement'] ?? 'N/A'),
          ]),
          const SizedBox(height: 14),

          // ── Itinéraire ──
          _buildCard('Itinéraire', Icons.route_rounded, [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDE7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Expanded(child: Column(children: [
                  Container(width: 34, height: 34,
                    decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                    child: const Icon(Icons.circle, size: 12, color: Colors.green)),
                  const SizedBox(height: 8),
                  Text(villeDepart, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      textAlign: TextAlign.center),
                  Text('Départ', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ])),
                Column(children: [
                  Container(width: 40, height: 2, color: Colors.grey[300]),
                  const Icon(Icons.directions_bus_rounded, color: _amber, size: 22),
                  Container(width: 40, height: 2, color: Colors.grey[300]),
                ]),
                Expanded(child: Column(children: [
                  Container(width: 34, height: 34,
                    decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                    child: const Icon(Icons.location_on_rounded, size: 18, color: Colors.red)),
                  const SizedBox(height: 8),
                  Text(villeArrivee, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      textAlign: TextAlign.center),
                  Text('Arrivée', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ])),
              ]),
            ),
            if (t['montant'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _amber.withOpacity(0.3)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Prix du trajet', style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.w500)),
                  Text('${t['montant']} FCFA',
                      style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.bold, fontSize: 15)),
                ]),
              ),
            ],
          ]),
          const SizedBox(height: 14),

          // ── Compagnie ──
          if (c.isNotEmpty)
            _buildCard('Compagnie', Icons.business_rounded, [
              if (c['logo_compagnies'] != null) ...[
                Center(child: GestureDetector(
                  onTap: () => _showFullImage(c['logo_compagnies']),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ClipRRect(borderRadius: BorderRadius.circular(8),
                      child: Image.network(c['logo_compagnies'], height: 72, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(Icons.business, size: 48, color: Colors.grey.shade400)),
                    ),
                  ),
                )),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                const SizedBox(height: 10),
              ],
              _buildRow('Nom', c['nom_complet_compagnies'] ?? 'N/A'),
              if (c['telephone_compagnies']?.toString().isNotEmpty ?? false)
                GestureDetector(
                  onTap: () => _makePhoneCall(c['telephone_compagnies']),
                  child: _buildRow('Téléphone', c['telephone_compagnies'], valueColor: Colors.green.shade700),
                ),
              if (c['email_compagnies']?.toString().isNotEmpty ?? false)
                _buildRow('Email', c['email_compagnies']),
              if (c['adresse_compagnies']?.toString().isNotEmpty ?? false)
                _buildRow('Adresse', c['adresse_compagnies']),
            ]),
          const SizedBox(height: 14),

          // ── Carte réservation cliquable ──
          _buildReservationCard(p),
          ]), // Column cards
            ), // SlideTransition cards
          ), // FadeTransition cards
        ]),
      );
  }

  // ── Carte réservation ─────────────────────────────────────────────────────
  Widget _buildReservationCard(Map<String, dynamic> p) {
    final ref = p['referencePaiement'] ?? 'N/A';
    final place = p['numero_place']?.toString() ?? 'N/A';
    return GestureDetector(
      onTap: () => _showReservationSheet(p),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.3),
            blurRadius: 12, offset: const Offset(0, 4),
          )],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Réservation', style: TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 3),
            Text(ref, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('Place N° $place', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _amber,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Voir', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
        ]),
      ),
    );
  }

  // ── Bottom sheet réservation ──────────────────────────────────────────────
  void _showReservationSheet(Map<String, dynamic> p) {
    final t = _paiementData!['tarification'] ?? {};
    final ref = p['referencePaiement'] ?? 'N/A';
    final place = p['numero_place']?.toString() ?? 'N/A';
    final montant = p['montant'];
    final statusInfo = _statusStyle(p['status']);
    final villeDepart = t['ville_depart']?['nom_ville'] ?? 'N/A';
    final villeArrivee = t['ville_arrivee']?['nom_ville'] ?? 'N/A';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle bar
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),

          // Titre
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _amber.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.confirmation_number_rounded, color: _amber, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Votre réservation',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)),
            const Spacer(),
            // Badge statut
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (statusInfo['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(statusInfo['text'] as String,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: statusInfo['color'] as Color)),
            ),
          ]),
          const SizedBox(height: 20),

          // Infos en grille
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              _sheetRow(Icons.tag_rounded, 'Référence', ref),
              const SizedBox(height: 10),
              _sheetRow(Icons.event_seat_rounded, 'Place', 'N° $place'),
              const SizedBox(height: 10),
              _sheetRow(Icons.payments_rounded, 'Montant', '${_formatMontant(montant)} FCFA'),
              const SizedBox(height: 10),
              _sheetRow(Icons.route_rounded, 'Trajet', '$villeDepart → $villeArrivee'),
            ]),
          ),
          const SizedBox(height: 24),

          // Bouton voir le ticket
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _ouvrirTicket,
              icon: const Icon(Icons.article_rounded, size: 20),
              label: const Text('Voir le ticket de réservation',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sheetRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 16, color: Colors.grey[400]),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
    ]);
  }

  void _ouvrirTicket() {
    Navigator.pop(context); // ferme le bottom sheet

    final reservationData = _paiementData?['reservation'];
    if (reservationData == null) {
      _toast('Réservation introuvable', Colors.orange);
      return;
    }

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => TicketPage(reservation: Map<String, dynamic>.from(reservationData)),
    ));
  }

  // ── Génération PDF ────────────────────────────────────────────────────────
  Future<void> _downloadPdf() async {
    if (_paiementData == null) return;
    setState(() => _isGeneratingPdf = true);
    try {
      final p = _paiementData!['paiement'];
      final t = _paiementData!['tarification'] ?? {};
      final c = _paiementData!['compagnie'] ?? {};

      final villeDepart = t['ville_depart']?['nom_ville'] ?? 'N/A';
      final villeArrivee = t['ville_arrivee']?['nom_ville'] ?? 'N/A';
      final montant = _formatMontant(p['montant']);
      final ref = p['referencePaiement'] ?? 'N/A';
      final statut = _getStatusText(p['status']);
      final date = _formatDate(p['datePaiement'] ?? '');
      final heure = p['HeurePaiement'] ?? 'N/A';
      final moyen = p['moyenPaiement'] ?? 'N/A';
      final place = p['numero_place']?.toString() ?? 'N/A';
      final nomCompagnie = c['nom_complet_compagnies'] ?? 'N/A';
      final telephone = p['telephone']?.toString() ?? 'N/A';

      final amber = PdfColor.fromHex('#FFC107');
      final darkText = PdfColors.grey900;
      final lightGrey = PdfColor.fromHex('#F5F5F5');
      final labelGrey = PdfColors.grey600;

      pw.TextStyle labelStyle() => pw.TextStyle(fontSize: 10, color: labelGrey);
      pw.TextStyle valueStyle() => pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkText);

      pw.Widget infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: labelStyle()),
            pw.Text(value, style: valueStyle()),
          ],
        ),
      );

      pw.Widget divider() => pw.Divider(color: PdfColor.fromHex('#EEEEEE'), thickness: 0.5);

      final doc = pw.Document();
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── En-tête ──
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: pw.BoxDecoration(
                color: amber,
                borderRadius: pw.BorderRadius.circular(14),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('BETRO', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                pw.SizedBox(height: 4),
                pw.Text('Reçu de paiement', style: pw.TextStyle(fontSize: 13, color: PdfColor.fromHex('#333333'))),
              ]),
            ),
            pw.SizedBox(height: 24),

            // ── Montant + trajet ──
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: lightGrey,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(children: [
                pw.Text('$montant FCFA',
                    style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: darkText)),
                pw.SizedBox(height: 6),
                pw.Text('$villeDepart  >  $villeArrivee',
                    style: pw.TextStyle(fontSize: 13, color: labelGrey)),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: amber,
                    borderRadius: pw.BorderRadius.circular(20),
                  ),
                  child: pw.Text(statut,
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                ),
              ]),
            ),
            pw.SizedBox(height: 20),

            // ── Détails ──
            pw.Text('DÉTAILS DU PAIEMENT',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold,
                    color: labelGrey, letterSpacing: 1.2)),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromHex('#EEEEEE')),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(children: [
                infoRow('Référence', ref),
                divider(),
                infoRow('N° de place', place),
                divider(),
                infoRow('Méthode de paiement', moyen),
                divider(),
                infoRow('Date', date),
                divider(),
                infoRow('Heure', heure),
                divider(),
                infoRow('Téléphone', telephone),
              ]),
            ),
            pw.SizedBox(height: 20),

            // ── Compagnie ──
            if (nomCompagnie != 'N/A') ...[
              pw.Text('COMPAGNIE',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold,
                      color: labelGrey, letterSpacing: 1.2)),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#EEEEEE')),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: infoRow('Nom', nomCompagnie),
              ),
              pw.SizedBox(height: 20),
            ],

            // ── Pied de page ──
            pw.SizedBox(height: 30),
            pw.Divider(color: PdfColor.fromHex('#EEEEEE')),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Généré par Betro • ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 9, color: labelGrey),
              ),
            ),
          ],
        ),
      ));

      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'recu_betro_$ref.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur PDF: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // ── Card section ──────────────────────────────────────────────────────────
  Widget _buildCard(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: _amber.withOpacity(0.15), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 16, color: _amber),
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ]),
    );
  }

  // ── Ligne label / valeur ──────────────────────────────────────────────────
  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(width: 12),
        Expanded(child: Text(value,
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87))),
      ]),
    );
  }

  // ── Ligne copiable ────────────────────────────────────────────────────────
  Widget _buildCopyRow(String label, String value) {
    return Row(children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      const Spacer(),
      GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: value));
          _toast('Copié !', _amber);
        },
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.amber.shade800),
              overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 5),
          Icon(Icons.copy_rounded, size: 13, color: Colors.amber.shade700),
        ]),
      ),
    ]);
  }

  // ── Ligne icône ───────────────────────────────────────────────────────────
  Widget _buildIconRow(IconData icon, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 7),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
      ]),
    );
  }

  Widget _buildLabel(String text) =>
      Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey));

  // ── Skeleton shimmer ──────────────────────────────────────────────────────
  Widget _skBox({double? w, double h = 14, double r = 8}) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(r)),
  );

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE0E0E0),
      highlightColor: const Color(0xFFF5F5F5),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(children: [
          // Hero card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              _skBox(w: 80, h: 28, r: 20),
              const SizedBox(height: 14),
              _skBox(w: 160, h: 36, r: 8),
              const SizedBox(height: 10),
              _skBox(w: 120, h: 14, r: 8),
            ]),
          ),
          const SizedBox(height: 14),
          // Résumé card
          _skeletonCard(rows: 7),
          const SizedBox(height: 14),
          // Itinéraire card
          _skeletonCard(rows: 2, tallFirst: true),
          const SizedBox(height: 14),
          // Compagnie card
          _skeletonCard(rows: 3),
          const SizedBox(height: 14),
          // Reservation card
          Container(
            height: 72,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          ),
        ]),
      ),
    );
  }

  Widget _skeletonCard({int rows = 4, bool tallFirst = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // titre de section
        Row(children: [
          _skBox(w: 28, h: 28, r: 8),
          const SizedBox(width: 10),
          _skBox(w: 120, h: 14),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        const SizedBox(height: 12),
        if (tallFirst) ...[
          _skBox(w: double.infinity, h: 80, r: 14),
          const SizedBox(height: 10),
        ],
        for (int i = 0; i < rows; i++) ...[
          Row(children: [
            _skBox(w: 80, h: 12),
            const Spacer(),
            _skBox(w: 100 + (i % 3) * 20.0, h: 12),
          ]),
          if (i < rows - 1) const SizedBox(height: 12),
        ],
      ]),
    );
  }

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade400),
    const SizedBox(height: 16),
    Text('Aucune donnée disponible', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
  ]));

  Widget _buildError() => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
        child: Icon(Icons.error_outline_rounded, size: 52, color: Colors.red.shade400)),
      const SizedBox(height: 16),
      Text(_errorMessage, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: Colors.red)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: _loadPaiementDetails,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Réessayer', style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: _amber, foregroundColor: Colors.black87,
            elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    ]),
  ));
}

// ── WebView ───────────────────────────────────────────────────────────────────
class WebViewPage extends StatefulWidget {
  final String url;
  const WebViewPage({Key? key, required this.url}) : super(key: key);

  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (_) => setState(() => _isLoading = false),
        onWebResourceError: (_) {},
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reçu de paiement',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
        backgroundColor: const Color(0xFFFFC107),
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _controller.reload)],
      ),
      body: Stack(children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          Center(child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)]),
            child: const Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFC107)), strokeWidth: 3),
              SizedBox(height: 14),
              Text('Chargement du reçu…', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
            ]),
          )),
      ]),
    );
  }
}
