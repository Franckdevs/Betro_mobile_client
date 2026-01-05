import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _storageService = StorageService();
  final _apiService = ApiService();

  // Contrôleurs pour les champs du formulaire
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showPasswordFields = false;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _storageService.getUserData();
      if (userData != null) {
        setState(() {
          _nomController.text = userData['nom'] ?? '';
          _prenomController.text = userData['prenom'] ?? '';
          _emailController.text = userData['email'] ?? '';
          _telephoneController.text = userData['telephone'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des données';
        _isLoading = false;
      });
    }
  }

  // Valide que les mots de passe correspondent si le champ de confirmation est rempli
  bool _validatePasswords() {
    if (_newPasswordController.text.isNotEmpty ||
        _confirmPasswordController.text.isNotEmpty) {
      if (_currentPasswordController.text.isEmpty) {
        setState(
          () => _errorMessage = 'Veuillez entrer votre mot de passe actuel',
        );
        return false;
      }
      if (_newPasswordController.text.isEmpty) {
        setState(
          () => _errorMessage = 'Veuillez entrer un nouveau mot de passe',
        );
        return false;
      }
      if (_newPasswordController.text != _confirmPasswordController.text) {
        setState(
          () =>
              _errorMessage = 'Les nouveaux mots de passe ne correspondent pas',
        );
        return false;
      }
      if (_newPasswordController.text.length < 6) {
        setState(
          () => _errorMessage =
              'Le mot de passe doit contenir au moins 6 caractères',
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate() || !_validatePasswords()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Non authentifié');
      }

      final response = await _apiService.updateProfile(
        token: token,
        nom: _nomController.text,
        prenom: _prenomController.text,
        email: _emailController.text,
        telephone: _telephoneController.text,
        password: _currentPasswordController.text.isNotEmpty
            ? _currentPasswordController.text
            : null,
        newPassword: _newPasswordController.text.isNotEmpty
            ? _newPasswordController.text
            : null,
      );

      if (response['success'] == true) {
        // Mettre à jour les données locales
        await _storageService.saveUserData({
          'nom': _nomController.text,
          'prenom': _prenomController.text,
          'email': _emailController.text,
          'telephone': _telephoneController.text,
        });

        if (mounted) {
          await Fluttertoast.showToast(
            msg: 'Profil mis à jour avec succès',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green[700],
            textColor: Colors.white,
            fontSize: 16.0,
            timeInSecForIosWeb: 2,
          );
          if (mounted) {
            Navigator.of(context).pop(true);
          }
          Navigator.of(context).pop(true); // Retour à la page précédente
        }
      } else {
        throw Exception(response['message'] ?? 'Échec de la mise à jour');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // Ferme le toast si la page est fermée
  @override
  void dispose() {
    Fluttertoast.cancel();
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le profil'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow),
                strokeWidth: 3,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    TextFormField(
                      controller: _nomController,
                      decoration: const InputDecoration(
                        labelText: 'Nom',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre nom';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _prenomController,
                      decoration: const InputDecoration(
                        labelText: 'Prénom',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre prénom';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre email';
                        }
                        if (!value.contains('@')) {
                          return 'Veuillez entrer un email valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _telephoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre numéro de téléphone';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Bouton pour afficher/masquer les champs de mot de passe
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showPasswordFields = !_showPasswordFields;
                        });
                      },
                      icon: Icon(
                        _showPasswordFields
                            ? Icons.arrow_drop_up
                            : Icons.arrow_drop_down,
                      ),
                      label: Text(
                        _showPasswordFields
                            ? 'Masquer la modification du mot de passe'
                            : 'Modifier le mot de passe',
                      ),
                    ),

                    // Champs de mot de passe conditionnels
                    if (_showPasswordFields) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _currentPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Mot de passe actuel',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (value) {
                          if (_newPasswordController.text.isNotEmpty &&
                              (value == null || value.isEmpty)) {
                            return 'Veuillez entrer votre mot de passe actuel';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Nouveau mot de passe',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_reset),
                        ),
                        validator: (value) {
                          if (_currentPasswordController.text.isNotEmpty &&
                              (value == null || value.isEmpty)) {
                            return 'Veuillez entrer un nouveau mot de passe';
                          }
                          if (value != null &&
                              value.isNotEmpty &&
                              value.length < 6) {
                            return 'Le mot de passe doit contenir au moins 6 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirmer le nouveau mot de passe',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_reset),
                        ),
                        validator: (value) {
                          if (_newPasswordController.text.isNotEmpty &&
                              _newPasswordController.text != value) {
                            return 'Les mots de passe ne correspondent pas';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Bouton de sauvegarde
                    ElevatedButton(
                      onPressed: _isSaving ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.yellow,
                              ),
                              strokeWidth: 3,
                            )
                          : const Text(
                              'Enregistrer les modifications',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
