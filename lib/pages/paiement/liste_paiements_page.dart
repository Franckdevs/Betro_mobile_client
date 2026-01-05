import 'package:flutter/material.dart';
import 'package:betro/services/paiement_service.dart';
import 'detail_paiement_page.dart';

class ListePaiementsPage extends StatefulWidget {
  const ListePaiementsPage({Key? key}) : super(key: key);

  @override
  _ListePaiementsPageState createState() => _ListePaiementsPageState();
}

class _ListePaiementsPageState extends State<ListePaiementsPage> {
  final PaiementService _paiementService = PaiementService();
  late Future<List<Map<String, dynamic>>> _paiementsFuture;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPaiements();
  }

  Future<List<Map<String, dynamic>>> _loadPaiements() async {
    try {
      final paiements = await _paiementService.getPaiements();
      setState(() {
        _paiementsFuture = Future.value(paiements);
        _isLoading = false;
        _errorMessage =
            ''; // Réinitialiser le message d'erreur en cas de succès
      });
      return paiements;
    } catch (e) {
      // Vérifier si c'est une erreur "Aucun paiement trouvé"
      final errorMessage = e.toString();
      if (errorMessage.contains('Aucun paiement trouvé')) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              ''; // Pas d'erreur à afficher, on laisse la liste vide
          _paiementsFuture = Future.value(
            [],
          ); // Liste vide pour déclencher l'affichage "Aucun paiement"
        });
        return [];
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = errorMessage.replaceAll(
            'Exception: ',
            '',
          ); // Enlever le préfixe 'Exception: '
        });
        return [];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Paiements'),
        backgroundColor: Colors.amber,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow),
                strokeWidth: 3,
              ),
            )
          : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage))
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _paiementsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.amber,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Aucun paiement trouvé',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vous n\'avez effectué aucun paiement pour le moment',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final paiements = snapshot.data!;

                return Column(
                  children: [
                    // En-tête avec le nombre de paiements
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total des paiements :',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${paiements.length} paiement${paiements.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Liste des paiements
                    Expanded(
                      child: ListView.builder(
                        itemCount: paiements.length,
                        itemBuilder: (context, index) {
                          final paiement = paiements[index]['paiement'];
                          final tarification =
                              paiements[index]['tarification'] ?? {};
                          final villeDepart =
                              tarification['ville_depart']?['nom_ville'] ??
                              'N/A';
                          final villeArrivee =
                              tarification['ville_arrivee']?['nom_ville'] ??
                              'N/A';

                          return Card(
                            color: Colors.white,
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey[200]!),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                tileColor: Colors.white,
                                title: Text(
                                  'Trajet: $villeDepart - $villeArrivee',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Montant: ${paiement['montant']} FCFA',
                                    ),
                                    Text(
                                      'Méthode: ${paiement['moyenPaiement'] ?? 'N/A'}',
                                    ),
                                    Text(
                                      'Date: ${_formatDate(paiement['datePaiement'])}',
                                    ),
                                  ],
                                ),
                                trailing: _getStatusBadge(
                                  paiement['status'] == '1'
                                      ? 'Réussi'
                                      : 'En attente',
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DetailPaiementPage(
                                        paiementId: paiement['id'],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _getStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'réussi':
      case 'success':
      case '1':
        color = Colors.green;
        break;
      case 'en attente':
      case 'pending':
        color = Colors.orange;
        break;
      case 'échoué':
      case 'failed':
      case '0':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      if (dateString == null || dateString.isEmpty) return 'N/A';

      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString; // Retourne la chaîne originale en cas d'erreur de parsing
    }
  }
}
