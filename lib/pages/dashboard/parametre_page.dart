import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import 'edit_profile_page.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/login_page.dart';

class ParametrePage extends StatefulWidget {
  const ParametrePage({super.key});

  @override
  _ParametrePageState createState() => _ParametrePageState();
}

class _ParametrePageState extends State<ParametrePage> {
  final StorageService _storageService = StorageService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  Future<void> _loadUserData() async {
    try {
      print(
        '🔍 [ParametrePage] Début du chargement des données utilisateur...',
      );

      // Vérifier d'abord si le token existe
      final token = await _storageService.getToken();
      print(
        '🔑 [ParametrePage] Token récupéré: ${token != null ? 'Oui' : 'Non'}',
      );

      // Récupérer les données utilisateur
      print('🔄 [ParametrePage] Appel à _storageService.getUserData()...');
      final userData = await _storageService.getUserData();
      print('📋 [ParametrePage] Données brutes récupérées: $userData');

      if (mounted) {
        setState(() {
          if (userData != null) {
            // Vérifier le format des données
            print(
              '🔍 [ParametrePage] Type de données: ${userData.runtimeType}',
            );
            print(
              '🔍 [ParametrePage] Clés disponibles: ${userData.keys.toList()}',
            );

            // Vérifier si les données sont dans une propriété 'data'
            if (userData.containsKey('data')) {
              print(
                '📥 [ParametrePage] Données trouvées dans la propriété "data"',
              );
              final data = userData['data'];
              print('🔍 [ParametrePage] Type de data: ${data.runtimeType}');

              if (data is Map) {
                try {
                  _userData = Map<String, dynamic>.from(
                    data.cast<String, dynamic>(),
                  );
                  print(
                    '✅ [ParametrePage] Données utilisateur extraites avec succès',
                  );
                } catch (e) {
                  print(
                    '❌ [ParametrePage] Erreur lors du cast des données: $e',
                  );
                  _userData = userData;
                }
              } else {
                print(
                  '⚠️ [ParametrePage] La propriété "data" n\'est pas un Map: ${data.runtimeType}',
                );
                _userData = userData;
              }
            }
            // Si pas de propriété 'data', utiliser directement les données
            else if (userData is Map) {
              print(
                '📥 [ParametrePage] Utilisation directe des données utilisateur',
              );
              try {
                _userData = Map<String, dynamic>.from(
                  userData.cast<String, dynamic>(),
                );
                print(
                  '✅ [ParametrePage] Données utilisateur converties avec succès',
                );
              } catch (e) {
                print(
                  '❌ [ParametrePage] Erreur lors de la conversion des données: $e',
                );
                _userData = userData;
              }
            } else {
              print('⚠️ [ParametrePage] Format de données non reconnu');
              _userData = null;
            }

            print(
              '✅ [ParametrePage] Données utilisateur mises à jour: $_userData',
            );

            // Vérifier les clés disponibles dans _userData
            if (_userData != null) {
              print(
                '🔍 [ParametrePage] Clés dans _userData: ${_userData!.keys.toList()}',
              );
              print('🔍 [ParametrePage] Prénom: ${_userData!['prenom']}');
              print('🔍 [ParametrePage] Nom: ${_userData!['nom']}');
              print('🔍 [ParametrePage] Email: ${_userData!['email']}');
              print('🔍 [ParametrePage] Téléphone: ${_userData!['telephone']}');
            } else {
              print('⚠️ [ParametrePage] _userData est null après traitement');
            }
          } else {
            print(
              '⚠️ [ParametrePage] Aucune donnée utilisateur trouvée dans le stockage (userData est null)',
            );
          }
          _isLoading = false;
          print('🔄 [ParametrePage] État mis à jour avec _isLoading = false');
        });
      }
    } catch (e) {
      print(
        '❌ [ParametrePage] Erreur lors du chargement des données utilisateur: $e',
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          print(
            '🔄 [ParametrePage] État mis à jour après erreur avec _isLoading = false',
          );
        });
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'Impossible de lancer l\'appel vers $phoneNumber';
    }
  }

  Future<void> _showContactDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide.none,
              ),
              elevation: 0,
            ),
          ),
          child: AlertDialog(
            title: const Text('Service Client'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Contactez notre service client au :'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '01 40 69 05 89',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(
                        Icons.phone,
                        color: Colors.green,
                        size: 32,
                      ),
                      onPressed: () {
                        _makePhoneCall('0140690589');
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Fermer'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _getInitials(String? nom, String? prenom) {
    final nomInitial = nom?.isNotEmpty == true ? nom![0] : '';
    final prenomInitial = prenom?.isNotEmpty == true ? prenom![0] : '';
    return '$prenomInitial$nomInitial'.toUpperCase();
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.amber[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _logout() async {
    try {
      // Afficher une boîte de dialogue de confirmation
      final shouldLogout = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.amber, width: 2.0),
                borderRadius: BorderRadius.zero,
              ),
              elevation: 0,
            ),
          ),
          child: AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text(
              'Déconnexion',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'Êtes-vous sûr de vouloir vous déconnecter ?',
              style: TextStyle(color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Annuler',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Se déconnecter',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      if (shouldLogout == true) {
        if (!mounted) return;

        // Afficher un indicateur de chargement
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );

        try {
          // Supprimer toutes les données utilisateur
          await _storageService.clearAllUserData();

          if (!mounted) return;

          // Fermer tous les dialogues ouverts (y compris l'indicateur de chargement)
          Navigator.of(
            context,
            rootNavigator: true,
          ).popUntil((route) => route.isFirst);

          // Utiliser pushNamedAndRemoveUntil avec MaterialPageRoute
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        } catch (e) {
          if (!mounted) return;

          // Fermer l'indicateur de chargement en cas d'erreur
          Navigator.of(context, rootNavigator: true).pop();

          // Afficher un message d'erreur
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la déconnexion: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur inattendue: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(
          160.0,
        ), // Hauteur totale augmentée à 160px
        child: Container(
          margin: const EdgeInsets.only(top: 1), // Marge en haut augmentée
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(80), // Coins encore plus arrondis
              bottomRight: Radius.circular(80), // Coins encore plus arrondis
            ),
            color: Colors.amber,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            automaticallyImplyLeading: false, // Supprime la flèche de retour
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 120, // Hauteur de la barre d'outils augmentée
            titleSpacing: 0, // Réinitialisation de l'espacement du titre
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Carte unique contenant le profil et les options
                  Padding(
                    padding: const EdgeInsets.symmetric(),
                    child: Card(
                      color: Colors.white,
                      elevation: 2,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Column(
                        children: [
                          // Section Profil
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                // Avatar
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      _getInitials(
                                        _userData?['nom'],
                                        _userData?['prenom'],
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Nom complet
                                Text(
                                  '${_userData?['prenom'] ?? ''} ${_userData?['nom'] ?? ''}'
                                      .trim(),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    letterSpacing: 0.5,
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                // Section d'information
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Email
                                      _buildInfoRow(
                                        Icons.email_outlined,
                                        'Email',
                                        _userData?['email'] ?? 'Non défini',
                                      ),
                                      const SizedBox(height: 12),
                                      // Téléphone
                                      _buildInfoRow(
                                        Icons.phone_android_outlined,
                                        'Téléphone',
                                        _userData?['telephone']?.toString() ??
                                            'Non défini',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Statut
                                const Text(
                                  'Je suis sur Betro',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Séparateur
                          const Divider(
                            height: 1,
                            thickness: 1,
                            indent: 24,
                            endIndent: 24,
                          ),

                          // Liste des options
                          // Modifier mon profil
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.amber,
                              ),
                            ),
                            title: const Text('Modifier mon profil'),
                            subtitle: const Text(
                              'Modifier mes informations personnelles',
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const EditProfilePage(),
                                ),
                              ).then((_) {
                                // Rafraîchir les données si nécessaire
                                _loadUserData();
                              });
                            },
                          ),

                          // Contacter le service client
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.phone,
                                color: Colors.green,
                              ),
                            ),
                            title: const Text('Contacter le service client'),
                            subtitle: const Text('Appuyez pour appeler'),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              _showContactDialog(context);
                            },
                          ),
                          const Divider(height: 1, indent: 20, endIndent: 20),

                          // Déconnexion
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.logout,
                                color: Colors.red,
                              ),
                            ),
                            title: const Text(
                              'Déconnexion',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onTap: _logout,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
