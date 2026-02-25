import 'package:flutter/material.dart';
import 'package:betro/services/paiement_service.dart';
import 'package:betro/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DetailPaiementPage extends StatefulWidget {
  final int paiementId;

  const DetailPaiementPage({Key? key, required this.paiementId})
    : super(key: key);

  @override
  _DetailPaiementPageState createState() => _DetailPaiementPageState();
}

class _DetailPaiementPageState extends State<DetailPaiementPage> {
  final PaiementService _paiementService = PaiementService();
  final ApiService _apiService = ApiService();
  late Future<Map<String, dynamic>> _paiementDetails;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPaiementDetails();
  }

  Future<void> _loadPaiementDetails() async {
    try {
      final details = await _paiementService.getPaiementDetails(
        widget.paiementId,
      );
      setState(() {
        _paiementDetails = Future.value(details);
        _isLoading = false;
      });
    } catch (e) {
      String cleanError = _cleanErrorMessage(e.toString());
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur: $cleanError';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement: $cleanError'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Nettoie les messages d'erreur pour cacher les informations sensibles
  String _cleanErrorMessage(String errorMessage) {
    String cleaned = errorMessage.replaceAll(
      RegExp(r'https?://[^\s]+'),
      '[URL]',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\b[a-zA-Z0-9]{20,}\b'), '[TOKEN]');
    cleaned = cleaned.replaceAll(
      RegExp(r'ClientException.*'),
      'Erreur de connexion réseau',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'Failed host lookup.*'),
      'Serveur inaccessible',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'No address associated.*'),
      'Serveur inaccessible',
    );
    return cleaned;
  }

  // Formatte la date pour l'affichage
  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement'),
        backgroundColor: Colors.amber,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow),
                strokeWidth: 3,
              ),
            )
          : _errorMessage.isNotEmpty
          ? Center(
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : FutureBuilder<Map<String, dynamic>>(
              future: _paiementDetails,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow),
                      strokeWidth: 3,
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Erreur: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  );
                } else if (!snapshot.hasData) {
                  return const Center(child: Text('Aucune donnée disponible'));
                }

                final data = snapshot.data!;
                final paiement = data['paiement'] ?? {};
                final tarification = data['tarification'] ?? {};
                final villeDepart = tarification['ville_depart'] ?? {};
                final villeArrivee = tarification['ville_arrivee'] ?? {};
                final compagnie = data['compagnie'] ?? {};
                final gare = data['gare'] ?? {};

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard('Résumé du Paiement', [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Référence',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  paiement['referencePaiement'] ?? 'N/A',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    if (paiement['referencePaiement'] != null) {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: paiement['referencePaiement'],
                                        ),
                                      );
                                      Fluttertoast.showToast(
                                        msg: 'Référence copiée',
                                        toastLength: Toast.LENGTH_SHORT,
                                        gravity: ToastGravity.BOTTOM,
                                        backgroundColor: Colors.green,
                                        textColor: Colors.white,
                                      );
                                    }
                                  },
                                  child: const Icon(
                                    Icons.content_copy,
                                    size: 18,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Section "Attribuer à"
                        if ((paiement['nom_complet'] != null &&
                                paiement['nom_complet']
                                    .toString()
                                    .isNotEmpty) ||
                            (paiement['telephone_proprietaire'] != null &&
                                paiement['telephone_proprietaire']
                                    .toString()
                                    .isNotEmpty))
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              const Text(
                                'Attribuer à',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (paiement['nom_complet'] != null &&
                                  paiement['nom_complet'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Text(
                                    paiement['nom_complet'],
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                              if (paiement['telephone_proprietaire'] != null &&
                                  paiement['telephone_proprietaire']
                                      .toString()
                                      .isNotEmpty)
                                Text(
                                  paiement['telephone_proprietaire'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              const Divider(height: 24, thickness: 1),
                            ],
                          ),

                        _buildInfoRow(
                          'Code paiement',
                          paiement['code_paiement'] ?? 'N/A',
                        ),
                        _buildInfoRow(
                          'Numéro de place',
                          paiement['numero_place']?.toString() ?? 'N/A',
                        ),
                        _buildInfoRow(
                          'Montant payé',
                          '${paiement['montant']} FCFA',
                        ),
                        _buildInfoRow(
                          'Méthode',
                          paiement['moyenPaiement'] ?? 'N/A',
                        ),
                        _buildInfoRow(
                          'Date',
                          _formatDate(paiement['datePaiement'] ?? ''),
                        ),
                        _buildInfoRow(
                          'Heure',
                          paiement['HeurePaiement'] ?? 'N/A',
                        ),
                        _buildInfoRow(
                          'Statut',
                          _getStatusText(paiement['status']),
                          isStatus: true,
                        ),

                        // Lien pour voir le reçu en ligne
                        if (paiement['code_paiement'] != null &&
                            paiement['code_paiement'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Container(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final codePaiement = paiement['code_paiement']
                                      .toString();
                                  // Utiliser le baseUrl sans /api pour la page web
                                  final baseUrl = _apiService.baseUrl
                                      .replaceAll('/api', '');
                                  final url =
                                      '$baseUrl/status-paiement/$codePaiement';

                                  // Ouvrir la page dans une WebView
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          WebViewPage(url: url),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.receipt_long, size: 18),
                                label: const Text('Voir reçu en ligne'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ]),

                      const SizedBox(height: 16),

                      _buildInfoCard('Itinéraire', [
                        _buildInfoRow(
                          'Ville de départ',
                          villeDepart['nom_ville'] ?? 'N/A',
                        ),
                        _buildInfoRow(
                          'Ville d\'arrivée',
                          villeArrivee['nom_ville'] ?? 'N/A',
                        ),
                        if (tarification['montant'] != null)
                          _buildInfoRow(
                            'Prix du trajet',
                            '${tarification['montant']} FCFA',
                          ),
                      ]),

                      const SizedBox(height: 16),

                      _buildInfoCard('Informations de la Compagnie', [
                        if (compagnie['logo_compagnies'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.network(
                                  compagnie['logo_compagnies'],
                                  height: 60,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.business,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        _buildInfoRow(
                          'Nom',
                          compagnie['nom_complet_compagnies'] ?? 'N/A',
                        ),
                        if (compagnie['telephone_compagnies'] != null &&
                            compagnie['telephone_compagnies']
                                .toString()
                                .isNotEmpty)
                          _buildInfoRow(
                            'Téléphone',
                            compagnie['telephone_compagnies'],
                          ),
                        if (compagnie['email_compagnies'] != null &&
                            compagnie['email_compagnies'].toString().isNotEmpty)
                          _buildInfoRow('Email', compagnie['email_compagnies']),
                        if (compagnie['adresse_compagnies'] != null &&
                            compagnie['adresse_compagnies']
                                .toString()
                                .isNotEmpty)
                          _buildInfoRow(
                            'Adresse',
                            compagnie['adresse_compagnies'],
                          ),
                        if (compagnie['description_compagnies'] != null &&
                            compagnie['description_compagnies']
                                .toString()
                                .isNotEmpty)
                          _buildInfoRow(
                            'Description',
                            compagnie['description_compagnies'],
                          ),
                      ]),

                      const SizedBox(height: 16),
                      // _buildInfoCard('Informations de la Gare', [
                      //   _buildInfoRow('Nom', gare['nom_gare'] ?? 'N/A'),
                      //   if (gare['telephone_gare'] != null &&
                      //       gare['telephone_gare'].toString().isNotEmpty)
                      //     _buildInfoRow('Téléphone', gare['telephone_gare']),
                      //   if (gare['adresse_gare'] != null &&
                      //       gare['adresse_gare'].toString().isNotEmpty)
                      //     _buildInfoRow('Adresse', gare['adresse_gare']),
                      //   if (gare['email'] != null &&
                      //       gare['email'].toString().isNotEmpty)
                      //     _buildInfoRow('Email', gare['email']),
                      //   if (gare['heure_ouverture'] != null &&
                      //       gare['heure_ouverture'].toString().isNotEmpty)
                      //     _buildInfoRow(
                      //       'Heure d\'ouverture',
                      //       gare['heure_ouverture'],
                      //     ),
                      //   if (gare['heure_fermeture'] != null &&
                      //       gare['heure_fermeture'].toString().isNotEmpty)
                      //     _buildInfoRow(
                      //       'Heure de fermeture',
                      //       gare['heure_fermeture'],
                      //     ),
                      //   if (gare['parking_disponible'] == 1)
                      //     _buildInfoRow('Parking', 'Disponible'),
                      //   if (gare['wifi_disponible'] == 1)
                      //     _buildInfoRow('WiFi', 'Disponible'),
                      // ]),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isStatus)
            _getStatusBadge(value)
          else
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
            ),
        ],
      ),
    );
  }

  String _getStatusText(dynamic status) {
    if (status == null) return 'Inconnu';

    final statusStr = status.toString().toLowerCase();
    switch (statusStr) {
      case '1':
      case 'success':
      case 'réussi':
        return 'Payé';
      case '0':
      case 'failed':
      case 'échoué':
        return 'Échoué';
      case 'pending':
      case 'en attente':
        return 'En attente';
      default:
        return status.toString();
    }
  }

  Widget _getStatusBadge(dynamic status) {
    final statusStr = status?.toString().toLowerCase() ?? '';
    Color color;
    String statusText;

    switch (statusStr) {
      case '1':
      case 'success':
      case 'réussi':
      case 'payé':
        color = Colors.green;
        statusText = 'Payé';
        break;
      case '0':
      case 'failed':
      case 'échoué':
        color = Colors.red;
        statusText = 'Échoué';
        break;
      case 'pending':
      case 'en attente':
        color = Colors.orange;
        statusText = 'En attente';
        break;
      default:
        color = Colors.grey;
        statusText = status?.toString() ?? 'Inconnu';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusText.toLowerCase() == 'payé' ? Colors.green : color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

// Classe pour afficher la page web dans une WebView
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
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            print('Erreur WebView: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reçu de paiement'),
        backgroundColor: Colors.amber,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              _controller.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow),
                strokeWidth: 3,
              ),
            ),
        ],
      ),
    );
  }
}
