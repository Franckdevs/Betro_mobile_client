import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:betro/services/paiement_service.dart';
import 'detail_paiement_page.dart';

class ListePaiementsPage extends StatefulWidget {
  const ListePaiementsPage({super.key});

  @override
  State<ListePaiementsPage> createState() => _ListePaiementsPageState();
}

class _ListePaiementsPageState extends State<ListePaiementsPage>
    with SingleTickerProviderStateMixin {
  final PaiementService _paiementService = PaiementService();
  bool _isLoading = true;
  String _errorMessage = '';

  // ── Filtre date ──
  DateTime? _dateDebut;
  DateTime? _dateFin;
  List<Map<String, dynamic>> _allPaiements = [];

  final NumberFormat _montantFormat = NumberFormat.decimalPattern('fr');
  static const _amber = Color(0xFFFFC107);

  late final AnimationController _enterCtrl;
  late final Animation<Offset>   _slideHeader;
  late final Animation<double>   _fadeHeader;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _slideHeader = Tween<Offset>(begin: const Offset(0, -0.35), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)));
    _fadeHeader = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _enterCtrl,
            curve: const Interval(0.0, 0.55, curve: Curves.easeOut)));
    _enterCtrl.forward();
    _loadPaiements();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadPaiements() async {
    try {
      final paiements = await _paiementService.getPaiements();
      setState(() {
        _allPaiements = paiements;
        _isLoading = false;
        _errorMessage = '';
      });
      return paiements;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Aucun paiement trouvé')) {
        setState(() {
          _isLoading = false;
          _errorMessage = '';
          _allPaiements = [];
        });
        return [];
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = msg.replaceAll('Exception: ', '');
        });
        return [];
      }
    }
  }

  // ── Filtrage ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> all) {
    if (_dateDebut == null && _dateFin == null) return all;
    return all.where((item) {
      final dateStr = item['paiement']['datePaiement'] ?? item['paiement']['created_at'] ?? '';
      if (dateStr.isEmpty) return false;
      try {
        final date = DateTime.parse(dateStr);
        final d = DateTime(date.year, date.month, date.day);
        if (_dateDebut != null && d.isBefore(_dateDebut!)) return false;
        if (_dateFin != null && d.isAfter(_dateFin!)) return false;
        return true;
      } catch (_) { return false; }
    }).toList();
  }

  bool get _hasFilter => _dateDebut != null || _dateFin != null;

  void _clearFilter() => setState(() { _dateDebut = null; _dateFin = null; });




  String _formatShortDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _errorMessage.isNotEmpty
          ? _buildError()
          : Column(children: [
              SlideTransition(
                position: _slideHeader,
                child: FadeTransition(opacity: _fadeHeader, child: _buildHeader()),
              ),
              Expanded(
                child: _isLoading
                    ? _buildSkeleton()
                    : _allPaiements.isEmpty
                        ? _buildEmpty()
                        : _buildList(_allPaiements, _filtered(_allPaiements)),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Titre
            Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Colors.black87, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Mes Paiements',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
              // Bouton filtre
              GestureDetector(
                onTap: () => _showFilterSheet(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _hasFilter ? Colors.black87 : Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.tune_rounded,
                        size: 16,
                        color: _hasFilter ? _amber : Colors.black87),
                    const SizedBox(width: 5),
                    Text('Filtrer',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _hasFilter ? _amber : Colors.black87)),
                  ]),
                ),
              ),
            ]),
            // Chips filtre actif
            if (_hasFilter) ...[
              const SizedBox(height: 10),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.date_range_rounded, size: 13, color: Colors.black87),
                    const SizedBox(width: 5),
                    Text(
                      _dateDebut != null && _dateFin != null
                          ? '${_formatShortDate(_dateDebut!)} → ${_formatShortDate(_dateFin!)}'
                          : _dateDebut != null
                              ? 'Depuis ${_formatShortDate(_dateDebut!)}'
                              : 'Jusqu\'au ${_formatShortDate(_dateFin!)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _clearFilter,
                      child: const Icon(Icons.close_rounded, size: 14, color: Colors.black54),
                    ),
                  ]),
                ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  // ── Bottom sheet filtre ───────────────────────────────────────────────────
  void _showFilterSheet() {
    DateTime? tmpDebut = _dateDebut;
    DateTime? tmpFin = _dateFin;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Raccourcis prédéfinis
    final shortcuts = [
      {'label': "Aujourd'hui", 'debut': today, 'fin': today},
      {'label': '7 derniers jours', 'debut': today.subtract(const Duration(days: 6)), 'fin': today},
      {'label': '30 derniers jours', 'debut': today.subtract(const Duration(days: 29)), 'fin': today},
      {'label': 'Ce mois', 'debut': DateTime(now.year, now.month, 1), 'fin': DateTime(now.year, now.month + 1, 0)},
      {'label': 'Mois dernier', 'debut': DateTime(now.year, now.month - 1, 1), 'fin': DateTime(now.year, now.month, 0)},
    ];

    bool isShortcutActive(Map<String, dynamic> s, DateTime? d, DateTime? f) {
      if (d == null || f == null) return false;
      return d == s['debut'] && f == s['fin'];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> pickDate(bool isDebut) async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: (isDebut ? tmpDebut : tmpFin) ?? today,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              locale: const Locale('fr', 'FR'),
            );
            if (picked != null) {
              setSheetState(() {
                if (isDebut) {
                  tmpDebut = DateTime(picked.year, picked.month, picked.day);
                } else {
                  tmpFin = DateTime(picked.year, picked.month, picked.day);
                }
              });
            }
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 18),

              // Titre + reset
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.tune_rounded, color: _amber, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('Filtrer par date',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                const Spacer(),
                if (tmpDebut != null || tmpFin != null)
                  GestureDetector(
                    onTap: () => setSheetState(() { tmpDebut = null; tmpFin = null; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Effacer',
                          style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ]),
              const SizedBox(height: 18),

              // ── Raccourcis rapides ──
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Période rapide',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: shortcuts.map((s) {
                final active = isShortcutActive(s, tmpDebut, tmpFin);
                return GestureDetector(
                  onTap: () => setSheetState(() {
                    tmpDebut = s['debut'] as DateTime;
                    tmpFin = s['fin'] as DateTime;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? _amber : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? _amber : const Color(0xFFE0E0E0)),
                    ),
                    child: Text(s['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: active ? FontWeight.bold : FontWeight.normal,
                          color: active ? Colors.black87 : Colors.black54,
                        )),
                  ),
                );
              }).toList()),
              const SizedBox(height: 18),

              // ── Sélection manuelle ──
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Ou choisir une plage personnalisée',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 10),
              Row(children: [
                // Début
                Expanded(child: GestureDetector(
                  onTap: () => pickDate(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                    decoration: BoxDecoration(
                      color: tmpDebut != null ? _amber.withValues(alpha: 0.08) : const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tmpDebut != null ? _amber : const Color(0xFFE0E0E0)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Début', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      const SizedBox(height: 5),
                      Row(children: [
                        Icon(Icons.calendar_month_rounded, size: 15,
                            color: tmpDebut != null ? _amber : Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          tmpDebut != null ? _formatShortDate(tmpDebut!) : 'jj/mm/aaaa',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: tmpDebut != null ? FontWeight.w700 : FontWeight.normal,
                            color: tmpDebut != null ? Colors.black87 : Colors.grey[400],
                          ),
                        ),
                      ]),
                    ]),
                  ),
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(children: [
                    Container(width: 12, height: 1.5, color: Colors.grey[300]),
                    const SizedBox(height: 2),
                    Container(width: 12, height: 1.5, color: Colors.grey[300]),
                  ]),
                ),
                // Fin
                Expanded(child: GestureDetector(
                  onTap: () => pickDate(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                    decoration: BoxDecoration(
                      color: tmpFin != null ? _amber.withValues(alpha: 0.08) : const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tmpFin != null ? _amber : const Color(0xFFE0E0E0)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Fin', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      const SizedBox(height: 5),
                      Row(children: [
                        Icon(Icons.calendar_month_rounded, size: 15,
                            color: tmpFin != null ? _amber : Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          tmpFin != null ? _formatShortDate(tmpFin!) : 'jj/mm/aaaa',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: tmpFin != null ? FontWeight.w700 : FontWeight.normal,
                            color: tmpFin != null ? Colors.black87 : Colors.grey[400],
                          ),
                        ),
                      ]),
                    ]),
                  ),
                )),
              ]),
              const SizedBox(height: 22),

              // Bouton appliquer
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() { _dateDebut = tmpDebut; _dateFin = tmpFin; });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _amber,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Appliquer',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  // ── Groupement par mois ───────────────────────────────────────────────────
  List<dynamic> _buildGroupedItems(List<Map<String, dynamic>> items) {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    final List<String> order = [];
    for (final item in items) {
      final paiement = item['paiement'];
      final dateStr = paiement['datePaiement'] ?? paiement['created_at'] ?? '';
      String key = 'INCONNU';
      try {
        final date = DateTime.parse(dateStr);
        key = DateFormat('MMMM yyyy', 'fr').format(date).toUpperCase();
      } catch (_) {}
      if (!groups.containsKey(key)) {
        groups[key] = [];
        order.add(key);
      }
      groups[key]!.add(item);
    }
    final List<dynamic> result = [];
    for (final key in order) {
      result.add(key);
      result.addAll(groups[key]!);
    }
    return result;
  }

  // ── Liste ─────────────────────────────────────────────────────────────────
  Widget _buildList(List<Map<String, dynamic>> all, List<Map<String, dynamic>> filtered) {
    if (_hasFilter && filtered.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.search_off_rounded, size: 52, color: Colors.grey[400]),
        const SizedBox(height: 14),
        const Text('Aucun paiement sur cette période',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _clearFilter,
          child: const Text('Effacer le filtre',
              style: TextStyle(fontSize: 13, color: _amber, fontWeight: FontWeight.w600)),
        ),
      ]));
    }

    final grouped = _buildGroupedItems(filtered);
    int itemIndex = 0;

    return RefreshIndicator(
        onRefresh: _loadPaiements,
        color: _amber,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: grouped.length,
          itemBuilder: (context, i) {
            final entry = grouped[i];
            if (entry is String) {
              return Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Text(entry,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: Colors.black45, letterSpacing: 0.5)),
              );
            }
            final card = _buildPaiementCard(entry as Map<String, dynamic>);
            final idx = itemIndex++;
            return _StaggerItem(index: idx, child: card);
          },
        ),
    );
  }

  // ── Carte paiement ────────────────────────────────────────────────────────
  Widget _buildPaiementCard(Map<String, dynamic> item) {
    final paiement = item['paiement'];
    final tarification = item['tarification'] ?? {};
    final villeDepart = tarification['ville_depart']?['nom_ville'] ?? 'N/A';
    final villeArrivee = tarification['ville_arrivee']?['nom_ville'] ?? 'N/A';
    final montant = paiement['montant'];
    final moyenPaiement = paiement['moyenPaiement'] ?? 'N/A';
    final dateStr = (paiement['datePaiement'] ?? paiement['created_at'] ?? '').toString();
    final statut = (paiement['statut'] ?? paiement['status'] ?? '').toString().toLowerCase();

    final isFailed = statut == 'failed' || statut == 'echec' || statut == '0' ||
        statut == 'error' || statut == 'annulé' || statut == 'annule';
    final isPending = statut == 'pending' || statut == 'en attente';

    // Icône de statut
    final Color iconBg;
    final Color iconColor;
    final IconData iconData;
    if (isFailed) {
      iconBg = const Color(0xFFFFEBEE);
      iconColor = Colors.red;
      iconData = Icons.close_rounded;
    } else if (isPending) {
      iconBg = const Color(0xFFFFF8E1);
      iconColor = Colors.orange;
      iconData = Icons.access_time_rounded;
    } else {
      iconBg = const Color(0xFFE8F5E9);
      iconColor = Colors.green;
      iconData = Icons.check_rounded;
    }

    // Date courte : "13 mai"
    String shortDate = '';
    try {
      final date = DateTime.parse(dateStr);
      shortDate = DateFormat('d MMM', 'fr').format(date);
    } catch (_) {
      shortDate = dateStr;
    }

    // Montant : "15 000 F"
    String formattedAmount = '0 F';
    try {
      double val = 0;
      if (montant is String) {
        val = double.tryParse(montant) ?? 0;
      } else if (montant is int) {
        val = montant.toDouble();
      } else if (montant is double) {
        val = montant;
      }
      formattedAmount = '${_montantFormat.format(val)} F';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => DetailPaiementPage(paiementId: paiement['id']),
        )),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            // Icône statut
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            // Trajet + date · moyen
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$villeDepart → $villeArrivee',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('$shortDate • $moyenPaiement',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
            const SizedBox(width: 10),
            // Montant + badge échec
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(formattedAmount,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
              if (isFailed) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Échoué',
                      style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
                ),
              ] else if (isPending) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('En attente',
                      style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  // ── Skeleton shimmer ──────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE0E0E0),
      highlightColor: const Color(0xFFF5F5F5),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: 6,
        itemBuilder: (_, i) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(width: 44, height: 44,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 14, width: double.infinity, color: Colors.white),
              const SizedBox(height: 8),
              Container(height: 11, width: 120, color: Colors.white),
            ])),
            const SizedBox(width: 12),
            Container(height: 16, width: 70, color: Colors.white),
          ]),
        ),
      ),
    );
  }

  // ── État vide ─────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: _amber.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.receipt_long_rounded, size: 60, color: _amber),
        ),
        const SizedBox(height: 20),
        const Text('Aucun paiement trouvé',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        Text('Vous n\'avez effectué aucun paiement\npour le moment',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.5)),
      ]),
    );
  }

  // ── État vide filtré ──────────────────────────────────────────────────────

  // ── Erreur ────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(Icons.error_outline_rounded, size: 52, color: Colors.red[400]),
          ),
          const SizedBox(height: 16),
          Text(_errorMessage, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.red)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadPaiements,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Réessayer', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _amber, foregroundColor: Colors.black87, elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Widget stagger pour chaque item de liste ──────────────────────────────────
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
  late final Animation<Offset> _slide;
  late final Animation<double>  _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _slide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // Délai croissant par index (max 8 items décalés)
    final delay = Duration(milliseconds: 80 + widget.index.clamp(0, 8) * 55);
    Future.delayed(delay, () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => SlideTransition(
        position: _slide,
        child: FadeTransition(opacity: _fade, child: widget.child),
      );
}
