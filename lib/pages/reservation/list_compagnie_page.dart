import 'package:flutter/material.dart';
import '../../models/compagnie_model.dart';
import '../../services/api_service.dart';
import '../../core/widgets/shimmer_skeleton.dart';
import 'detail_compagnie_page.dart';

class ListCompagniePage extends StatefulWidget {
  const ListCompagniePage({super.key});

  @override
  State<ListCompagniePage> createState() => _ListCompagniePageState();
}

class _ListCompagniePageState extends State<ListCompagniePage>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const _amber = Color(0xFFFFC107);
  static const _itemsPerPage = 15;

  List<Compagnie> _allCompagnies = [];
  List<Compagnie> _displayedCompagnies = [];
  List<Compagnie> _filteredCompagnies = [];

  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  late Future<void> _initialLoad;

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
    _initialLoad = _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final companies = await _apiService.getCompagnies();
      if (mounted) {
        setState(() {
          _allCompagnies = companies;
          _displayedCompagnies = _allCompagnies.take(_itemsPerPage).toList();
          _hasMore = _allCompagnies.length > _displayedCompagnies.length;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore &&
        _searchController.text.isEmpty) {
      _loadMore();
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
      _allCompagnies = [];
      _displayedCompagnies = [];
      _filteredCompagnies = [];
    });
    await _loadInitialData();
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        final next = _allCompagnies
            .skip(_currentPage * _itemsPerPage)
            .take(_itemsPerPage)
            .toList();
        setState(() {
          _displayedCompagnies.addAll(next);
          _currentPage++;
          _hasMore = _displayedCompagnies.length < _allCompagnies.length;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _filterCompagnies(String query) {
    setState(() {
      _filteredCompagnies = _allCompagnies
          .where((c) => c.nomComplet.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  List<Compagnie> get _visibleList =>
      _searchController.text.isEmpty ? _displayedCompagnies : _filteredCompagnies;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Header jaune ─────────────────────────────────────
          SlideTransition(
            position: _slideHeader,
            child: FadeTransition(
              opacity: _fadeHeader,
              child: _buildHeader(context),
            ),
          ),
          // ── Body ─────────────────────────────────────────────
          Expanded(
            child: FutureBuilder<void>(
              future: _initialLoad,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: 12,
                    itemBuilder: (_, __) => const SkeletonCompagnieTile(),
                  );
                }
                if (snapshot.hasError) {
                  return _buildError(snapshot.error.toString());
                }

                final list = _visibleList;

                if (list.isEmpty) {
                  return _buildEmpty();
                }

                return Column(
                  children: [
                    // Compteur
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          Text(
                            '${list.length} compagnie${list.length > 1 ? 's' : ''}'
                            '${_searchController.text.isNotEmpty ? ' trouvée${list.length > 1 ? 's' : ''}' : ' disponible${list.length > 1 ? 's' : ''}'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Grille responsive
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const double tileMin = 120;
                          final int cols =
                              (constraints.maxWidth / tileMin).floor().clamp(2, 6);
                          return RefreshIndicator(
                            onRefresh: _onRefresh,
                            color: _amber,
                            strokeWidth: 2.5,
                            child: GridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: list.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= list.length) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(_amber),
                                    strokeWidth: 2.5,
                                  ),
                                );
                              }
                              return _StaggerItem(
                                index: index,
                                child: _buildCompagnieTile(list[index]),
                              );
                            },
                          ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _amber,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compagnies',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Choisissez votre transporteur',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Barre de recherche
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterCompagnies,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une compagnie…',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFFFFC107), size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.grey, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _filterCompagnies('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // ── Tuile grille ──────────────────────────────────────────────────────────
  Widget _buildCompagnieTile(Compagnie compagnie) {
    final hasLogo = compagnie.logoUrl != null && compagnie.logoUrl!.isNotEmpty;
    final initials = compagnie.nomComplet.isNotEmpty
        ? compagnie.nomComplet
            .substring(0, compagnie.nomComplet.length > 2 ? 2 : 1)
            .toUpperCase()
        : '?';
    final isActive = compagnie.status == '1';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailCompagniePage(compagnie: compagnie),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo / Avatar
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasLogo
                        ? Colors.transparent
                        : _amber.withValues(alpha: 0.15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: hasLogo
                      ? ClipOval(
                          child: Image.network(
                            compagnie.logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _amber,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _amber,
                            ),
                          ),
                        ),
                ),
                // Dot statut
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? Colors.green[600] : Colors.grey,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Nom
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                compagnie.nomComplet,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            if (compagnie.gares.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${compagnie.gares.length} gare${compagnie.gares.length > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }


  // ── États vides / erreur ──────────────────────────────────────────────────
  Widget _buildEmpty() {
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
            child: const Icon(Icons.business_outlined,
                size: 48, color: _amber),
          ),
          const SizedBox(height: 16),
          const Text('Aucune compagnie trouvée',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            _searchController.text.isNotEmpty
                ? 'Essayez un autre terme de recherche'
                : 'Aucune compagnie disponible pour le moment',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          const Text('Erreur de chargement',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(error,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => setState(() {
              _initialLoad = _loadInitialData();
            }),
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
}

// ── Animation stagger par tuile ───────────────────────────────────────────────
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
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    final delay = 80 + widget.index.clamp(0, 12) * 45;
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
