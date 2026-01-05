import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final StorageService _storageService = StorageService();
  final ApiService _apiService = ApiService();

  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _showPasswordFields = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _storageService.getUserData();
      setState(() {
        _nomController.text = userData?['nom'] ?? '';
        _prenomController.text = userData?['prenom'] ?? '';
        _telephoneController.text = userData?['telephone'] ?? '';
        _emailController.text = userData?['email'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des données';
        _isLoading = false;
      });
    }
  }

  bool _validatePasswords() {
    // Si on modifie le mot de passe, on vérifie qu'il est valide
    if (_showPasswordFields && _newPasswordController.text.isNotEmpty) {
      if (_newPasswordController.text.length < 6) {
        setState(
          () => _errorMessage =
              'Le mot de passe doit contenir au moins 6 caractères',
        );
        return false;
      }
      if (_newPasswordController.text != _confirmPasswordController.text) {
        setState(
          () => _errorMessage = 'Les mots de passe ne correspondent pas',
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _updateProfile() async {
    // Valider uniquement les champs remplis
    if (_showPasswordFields && !_validatePasswords()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception('Non authentifié');

      final Map<String, dynamic> requestData = {'token': token};

      // Ajouter uniquement les champs remplis
      if (_nomController.text.trim().isNotEmpty) {
        requestData['nom'] = _nomController.text.trim();
      }
      if (_prenomController.text.trim().isNotEmpty) {
        requestData['prenom'] = _prenomController.text.trim();
      }
      if (_telephoneController.text.trim().isNotEmpty) {
        requestData['telephone'] = _telephoneController.text.trim();
      }
      if (_emailController.text.trim().isNotEmpty) {
        requestData['email'] = _emailController.text.trim();
      }

      // Ajouter le nouveau mot de passe si demandé et rempli
      if (_showPasswordFields && _newPasswordController.text.isNotEmpty) {
        requestData['password'] = _newPasswordController.text;
      }

      final response = await _apiService.post(
        'modifier_information_utilisateur',
        requestData,
      );

      if (response['success'] == true) {
        // Mettre à jour les données locales
        await _storageService.saveUserData({
          'nom': _nomController.text.trim(),
          'prenom': _prenomController.text.trim(),
          'telephone': _telephoneController.text.trim(),
          'email': _emailController.text.trim(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil mis à jour avec succès')),
          );
          // Réinitialiser les champs de mot de passe
          if (_showPasswordFields) {
            setState(() {
              _newPasswordController.clear();
              _confirmPasswordController.clear();
              _showPasswordFields = false;
            });
          }
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(response['message'] ?? 'Échec de la mise à jour');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: ${e.toString().replaceAll('Exception: ', '')}';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier mon profil'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
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
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nomController,
                      decoration: const InputDecoration(
                        labelText: 'Nom',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
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
                        prefixIcon: Icon(Icons.email_outlined),
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
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre numéro de téléphone';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Text(
                          'Modifier le mot de passe',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: _showPasswordFields,
                          onChanged: (value) {
                            setState(() {
                              _showPasswordFields = value;
                              if (!value) {
                                _newPasswordController.clear();
                                _confirmPasswordController.clear();
                              }
                            });
                          },
                          activeColor: Colors.amber,
                        ),
                      ],
                    ),
                    if (_showPasswordFields) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        decoration: InputDecoration(
                          labelText: 'Nouveau mot de passe',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureNewPassword = !_obscureNewPassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirmer le nouveau mot de passe',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                    if (_errorMessage != null) ...{
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    },
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.amber,
                                ),
                                strokeWidth: 3,
                              ),
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
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
