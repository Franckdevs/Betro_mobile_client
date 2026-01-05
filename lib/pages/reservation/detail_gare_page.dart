import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/gare_model.dart';
import '../../models/itineraire_model.dart';
import '../../services/api_service.dart';

class DetailGarePage extends StatefulWidget {
  final int gareId;

  const DetailGarePage({Key? key, required this.gareId}) : super(key: key);

  @override
  _DetailGarePageState createState() => _DetailGarePageState();
}

class _DetailGarePageState extends State<DetailGarePage> {
  final ApiService _apiService = ApiService();
  late Future<ItineraireResponse> _gareData;

  @override
  void initState() {
    super.initState();
    _gareData = _apiService.getItinerairesParGare(widget.gareId);
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de la gare'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<ItineraireResponse>(
        future: _gareData,
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

          final gare = snapshot.data!.gare;
          final itineraires = snapshot.data!.itineraires;

          // Debug: Afficher les informations de la gare
          print('Ville de la gare: ${gare.ville}');
          print('Données complètes de la gare: $gare');

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                gare.nomGare,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (gare.ville.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.yellow[700],
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  gare.ville.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.location_on, gare.adresseGare),
                        if (gare.telephoneGare.isNotEmpty)
                          _buildInfoRow(Icons.phone, gare.telephoneGare),
                        if (gare.email.isNotEmpty)
                          _buildInfoRow(Icons.email, gare.email),
                        if (gare.siteWeb.isNotEmpty)
                          GestureDetector(
                            onTap: () => _launchURL(
                              gare.siteWeb.startsWith('http')
                                  ? gare.siteWeb
                                  : 'https://${gare.siteWeb}',
                            ),
                            child: _buildInfoRow(
                              Icons.language,
                              gare.siteWeb,
                              textColor: Colors.blue,
                            ),
                          ),
                        _buildInfoRow(
                          Icons.access_time,
                          '${gare.heureOuverture} - ${gare.heureFermeture} (${gare.nomJourOuverture} au ${gare.nomJourFermeture})',
                        ),
                        if (gare.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Description:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(gare.description),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Itinéraires disponibles',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (itineraires.isEmpty)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Aucun itinéraire disponible pour cette gare',
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final itineraire = itineraires[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ExpansionTile(
                        title: Text(
                          'Vers ${itineraire.ville.nomVille}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Temps estimé: ${itineraire.estimation}',
                        ),
                        children: _buildVoyages(itineraire.voyages),
                      ),
                    );
                  }, childCount: itineraires.length),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildVoyages(List<Voyage> voyages) {
    return voyages.map((voyage) {
      return Column(
        children: [
          ListTile(
            title: Text('Départ: ${voyage.heureDepart} - ${voyage.dateDepart}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Itinéraire:'),
                ...voyage.arretVoyages.map((arretVoyage) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 4),
                    child: Text(
                      '• ${arretVoyage.arret.gare.nomGare} (${arretVoyage.montant} FCFA)',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      );
    }).toList();
  }

  Widget _buildInfoRow(IconData icon, String text, {Color? textColor}) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: textColor ?? Colors.black87,
                decoration: textColor != null ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
