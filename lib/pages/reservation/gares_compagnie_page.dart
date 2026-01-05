import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../models/gare_model.dart';
import '../../services/api_service.dart';

class GaresCompagniePage extends StatefulWidget {
  final int compagnieId;
  final String compagnieNom;

  const GaresCompagniePage({
    Key? key,
    required this.compagnieId,
    required this.compagnieNom,
  }) : super(key: key);

  @override
  _GaresCompagniePageState createState() => _GaresCompagniePageState();
}

class _GaresCompagniePageState extends State<GaresCompagniePage> {
  List<Gare> _gares = [];
  List<Gare> _filteredGares = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String? _selectedVille;

  @override
  void initState() {
    super.initState();
    _loadGares();
  }

  final ApiService _apiService = ApiService();

  Future<void> _loadGares() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse(
          '${_apiService.baseUrl}/liste_gare_compagnie/${widget.compagnieId}',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final garesList = (data['data'] as List).cast<Map<String, dynamic>>();
          setState(() {
            _gares = garesList.map((gare) => Gare.fromJson(gare)).toList();
            _filteredGares = List.from(_gares);
          });
        } else {
          setState(() {
            _errorMessage =
                data['message'] ?? 'Erreur lors du chargement des gares';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Erreur de connexion au serveur';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterGares(String? ville) {
    setState(() {
      _selectedVille = ville;
      _filteredGares = ville == null
          ? List.from(_gares)
          : _gares.where((gare) => gare.ville == ville).toList();
    });
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir l\'URL')),
      );
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'effectuer l\'appel')),
      );
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri emailLaunchUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir l\'application email'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final villesUniques = _gares.map((gare) => gare.ville).toSet().toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gares - ${widget.compagnieNom}',
              style: const TextStyle(color: Colors.black),
            ),
            if (_gares.isNotEmpty)
              Text(
                '${_gares.length} gare${_gares.length > 1 ? 's' : ''} dans ${villesUniques.length} ville${villesUniques.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Colors.black,
                ),
              ),
          ],
        ),
        backgroundColor: Colors.yellow,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(
          color: Colors.black,
        ), // Icône de retour en noir
        toolbarHeight: _gares.isNotEmpty ? 90 : null,
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
          : _gares.isEmpty
          ? const Center(child: Text('Aucune gare disponible'))
          : Column(
              children: [
                // Filtre par ville
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedVille,
                        hint: const Text('Toutes les villes'),
                        isExpanded: true,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.grey,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Toutes les villes'),
                          ),
                          ...villesUniques.map(
                            (ville) => DropdownMenuItem(
                              value: ville,
                              child: Text(ville),
                            ),
                          ),
                        ],
                        onChanged: (value) => _filterGares(value),
                      ),
                    ),
                  ),
                ),
                // Liste des gares
                Expanded(
                  child: _filteredGares.isEmpty
                      ? const Center(
                          child: Text('Aucune gare trouvée pour cette ville'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: _filteredGares.length,
                          itemBuilder: (context, index) {
                            final gare = _filteredGares[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                vertical: 8.0,
                                horizontal: 12.0,
                              ),
                              color: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                side: BorderSide(color: Colors.grey[200]!),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Nom de la gare
                                    Text(
                                      gare.nomGare,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),

                                    // Badge de la ville
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        gare.ville,
                                        style: TextStyle(
                                          color: Colors.amber[900],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),

                                    // Détails de la gare
                                    const SizedBox(height: 8),
                                    if (gare.adresseGare.isNotEmpty)
                                      _buildInfoRow(
                                        Icons.location_on,
                                        gare.adresseGare,
                                      ),
                                    if (gare.telephoneGare.isNotEmpty)
                                      _buildInfoRow(
                                        Icons.phone,
                                        gare.telephoneGare,
                                      ),
                                    if (gare.email.isNotEmpty)
                                      _buildInfoRow(Icons.email, gare.email),
                                    if (gare.heureOuverture.isNotEmpty &&
                                        gare.heureFermeture.isNotEmpty)
                                      _buildInfoRow(
                                        Icons.access_time,
                                        '${gare.heureOuverture} - ${gare.heureFermeture}',
                                      ),
                                    if (gare.nomJourOuverture.isNotEmpty &&
                                        gare.nomJourFermeture.isNotEmpty)
                                      _buildInfoRow(
                                        Icons.calendar_today,
                                        'Du ${gare.nomJourOuverture} au ${gare.nomJourFermeture}',
                                      ),
                                    if (gare.description.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                          bottom: 8.0,
                                        ),
                                        child: Text(
                                          gare.description,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),

                                    // Boutons d'action
                                    Container(
                                      margin: const EdgeInsets.only(top: 10),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: Colors.grey[200]!,
                                            width: 1.0,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          if (gare.telephoneGare.isNotEmpty)
                                            _buildActionButton(
                                              icon: Icons.phone,
                                              label: 'Appeler',
                                              color: Colors.green,
                                              onTap: () => _makePhoneCall(
                                                gare.telephoneGare,
                                              ),
                                            ),
                                          if (gare.email.isNotEmpty)
                                            _buildActionButton(
                                              icon: Icons.email,
                                              label: 'Email',
                                              color: Colors.blue,
                                              onTap: () =>
                                                  _sendEmail(gare.email),
                                            ),
                                          if (gare.siteWeb?.isNotEmpty ?? false)
                                            _buildActionButton(
                                              icon: Icons.language,
                                              label: 'Site web',
                                              color: Colors.blue[700]!,
                                              onTap: () => _launchUrl(
                                                gare.siteWeb!.startsWith('http')
                                                    ? gare.siteWeb!
                                                    : 'https://${gare.siteWeb}',
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
                ),
                // Villes desservies
                if (villesUniques.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    color: Colors.grey[50],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Villes desservies:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: villesUniques.map((ville) {
                            return GestureDetector(
                              onTap: () => _filterGares(ville),
                              child: Chip(
                                label: Text(ville),
                                backgroundColor: _selectedVille == ville
                                    ? Colors.amber[300]
                                    : Colors.amber[100],
                                labelStyle: TextStyle(
                                  color: Colors.amber[900],
                                  fontWeight: _selectedVille == ville
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
