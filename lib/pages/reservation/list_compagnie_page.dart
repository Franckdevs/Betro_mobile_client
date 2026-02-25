import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../models/compagnie_model.dart';
import '../../services/api_service.dart';
import 'detail_compagnie_page.dart';

class ListCompagniePage extends StatefulWidget {
  const ListCompagniePage({super.key});

  @override
  State<ListCompagniePage> createState() => _ListCompagniePageState();
}

class _ListCompagniePageState extends State<ListCompagniePage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  // Variables pour la pagination
  final int _itemsPerPage = 15;
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  List<Compagnie> _allCompagnies = [];
  List<Compagnie> _displayedCompagnies = [];
  List<Compagnie> _filteredCompagnies = [];
  late Future<void> _initialLoad;

  @override
  void initState() {
    super.initState();
    _initialLoad = _loadInitialData();
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
          SnackBar(content: Text('Erreur lors du chargement: $e')),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Simuler un délai de chargement
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        final nextPageItems = _allCompagnies
            .skip(_currentPage * _itemsPerPage)
            .take(_itemsPerPage)
            .toList();

        setState(() {
          _displayedCompagnies.addAll(nextPageItems);
          _currentPage++;
          _hasMore = _displayedCompagnies.length < _allCompagnies.length;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement: $e')),
        );
      }
    }
  }

  void _filterCompagnies(String query) {
    setState(() {
      _filteredCompagnies = _allCompagnies
          .where(
            (compagnie) => compagnie.nomComplet.toLowerCase().contains(
              query.toLowerCase(),
            ),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        toolbarHeight: 100, // Augmentation de la hauteur de l'AppBar
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 8.0),
              child: Text(
                'Choisissez une compagnie',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: Colors.black, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Rechercher une compagnie...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  suffixIcon: const SizedBox(
                    width: 48,
                  ), // Espace pour garder la forme
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
                  ),
                  isDense: true,
                ),
                onChanged: (value) {
                  _filterCompagnies(value);
                },
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<void>(
              future: _initialLoad,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow),
                      strokeWidth: 3,
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                final compagnies = _searchController.text.isEmpty
                    ? _displayedCompagnies
                    : _filteredCompagnies;

                if (compagnies.isEmpty) {
                  return const Center(
                    child: Text('Aucune compagnie disponible'),
                  );
                }

                return Column(
                  children: [
                    // Compteur de compagnies
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${compagnies.length} compagnie${compagnies.length > 1 ? 's' : ''} disponible${compagnies.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    // Liste des compagnies avec défilement infini
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          if (scrollInfo is ScrollEndNotification &&
                              scrollInfo.metrics.pixels ==
                                  scrollInfo.metrics.maxScrollExtent &&
                              !_isLoadingMore &&
                              _hasMore &&
                              _searchController.text.isEmpty) {
                            _loadMore();
                          }
                          return true;
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: MasonryGridView.count(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 8,
                            itemCount:
                                _isLoadingMore && _searchController.text.isEmpty
                                ? compagnies.length + 1
                                : compagnies.length,
                            itemBuilder: (context, index) {
                              // Afficher l'indicateur de chargement à la fin de la liste
                              if (index >= compagnies.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.yellow,
                                      ),
                                      strokeWidth: 3,
                                    ),
                                  ),
                                );
                              }

                              final compagnie = compagnies[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DetailCompagniePage(
                                        compagnie: compagnie,
                                      ),
                                    ),
                                  );
                                },
                                child: Card(
                                  elevation: 2,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Logo de la compagnie
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.grey[200],
                                            image: DecorationImage(
                                              image:
                                                  compagnie.logoUrl != null &&
                                                      compagnie
                                                          .logoUrl!
                                                          .isNotEmpty
                                                  ? NetworkImage(
                                                      compagnie.logoUrl!,
                                                    )
                                                  : const AssetImage(
                                                          'assets/images/default_company.png',
                                                        )
                                                        as ImageProvider,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 24),

                                        // Nom de la compagnie
                                        Text(
                                          compagnie.nomComplet,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
