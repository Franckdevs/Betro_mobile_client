import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import '../../core/widgets/shimmer_skeleton.dart';

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
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isUploadingPhoto = false;
  String? _errorMessage;
  String? _photoUrl;
  File? _pickedImage;

  static const _amber = Color(0xFFFFC107);

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
        _photoUrl = userData?['photo_url'];
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des données';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_isUploadingPhoto) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choisir une photo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF8E1),
                child: Icon(Icons.photo_library_rounded, color: Color(0xFFFFC107)),
              ),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF8E1),
                child: Icon(Icons.camera_alt_rounded, color: Color(0xFFFFC107)),
              ),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    XFile? picked;
    try {
      final picker = ImagePicker();
      picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 800,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'ouvrir ${source == ImageSource.camera ? 'la caméra' : 'la galerie'}: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    if (picked == null) return; // Utilisateur a annulé
    if (!mounted) return;

    final imageFile = File(picked.path);

    setState(() {
      _pickedImage = imageFile;
      _isUploadingPhoto = true;
    });

    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception('Non authentifié');

      final result = await _apiService.modifierPhotoUtilisateur(
        token: token,
        imageFile: imageFile,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final newPhotoUrl = result['photo_url']?.toString() ??
            (result['utilisateur'] as Map<String, dynamic>?)?['photo_url']?.toString();

        final userData = await _storageService.getUserData() ?? {};
        userData['photo_url'] = newPhotoUrl;
        await _storageService.saveUserData(userData);

        if (mounted) {
          setState(() => _photoUrl = newPhotoUrl);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Text('Photo mise à jour avec succès'),
                ],
              ),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() => _pickedImage = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? 'Erreur lors de la mise à jour'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _pickedImage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  bool _validatePasswords() {
    if (_showPasswordFields && _newPasswordController.text.isNotEmpty) {
      if (_newPasswordController.text.length < 6) {
        setState(() => _errorMessage = 'Le mot de passe doit contenir au moins 6 caractères');
        return false;
      }
      if (_newPasswordController.text != _confirmPasswordController.text) {
        setState(() => _errorMessage = 'Les mots de passe ne correspondent pas');
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
      if (token == null) throw Exception('Non authentifié');

      final Map<String, dynamic> requestData = {'token': token};
      if (_nomController.text.trim().isNotEmpty) requestData['nom'] = _nomController.text.trim();
      if (_prenomController.text.trim().isNotEmpty) requestData['prenom'] = _prenomController.text.trim();
      if (_telephoneController.text.trim().isNotEmpty) requestData['telephone'] = _telephoneController.text.trim();
      if (_emailController.text.trim().isNotEmpty) requestData['email'] = _emailController.text.trim();
      if (_showPasswordFields && _newPasswordController.text.isNotEmpty) {
        requestData['password'] = _newPasswordController.text;
      }

      final response = await _apiService.post('modifier_information_utilisateur', requestData, token: token);

      if (response['success'] == true) {
        final userData = await _storageService.getUserData() ?? {};
        userData['nom'] = _nomController.text.trim();
        userData['prenom'] = _prenomController.text.trim();
        userData['telephone'] = _telephoneController.text.trim();
        userData['email'] = _emailController.text.trim();
        await _storageService.saveUserData(userData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Text('Profil mis à jour avec succès'),
                ],
              ),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(response['message'] ?? 'Échec de la mise à jour');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

  String get _initials {
    final n = _nomController.text.isNotEmpty ? _nomController.text[0].toUpperCase() : '';
    final p = _prenomController.text.isNotEmpty ? _prenomController.text[0].toUpperCase() : '';
    return '$p$n'.isEmpty ? '?' : '$p$n';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _isLoading
          ? _buildProfileSkeleton()
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                      child: Column(
                        children: [
                          if (_errorMessage != null) ...[
                            _buildErrorBanner(),
                            const SizedBox(height: 16),
                          ],
                          _buildSection(
                            icon: Icons.person_rounded,
                            title: 'Informations personnelles',
                            children: [
                              _buildField(
                                controller: _prenomController,
                                label: 'Prénom',
                                icon: Icons.person_outline,
                                validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
                              ),
                              const SizedBox(height: 14),
                              _buildField(
                                controller: _nomController,
                                label: 'Nom',
                                icon: Icons.badge_outlined,
                                validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildSection(
                            icon: Icons.contact_mail_rounded,
                            title: 'Coordonnées',
                            children: [
                              _buildField(
                                controller: _emailController,
                                label: 'Adresse email',
                                icon: Icons.email_outlined,
                                keyboard: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Champ requis';
                                  if (!v.contains('@')) return 'Email invalide';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildField(
                                controller: _telephoneController,
                                label: 'Téléphone',
                                icon: Icons.phone_outlined,
                                keyboard: TextInputType.phone,
                                maxLength: 10,
                                prefixWidget: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Text('🇨🇮', style: TextStyle(fontSize: 20)),
                                      SizedBox(width: 6),
                                      Text('+225',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildPasswordSection(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isLoading
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _updateProfile,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 22),
                  label: Text(
                    _isSaving ? 'Enregistrement…' : 'Enregistrer les modifications',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _amber,
                    foregroundColor: Colors.black87,
                    elevation: 4,
                    shadowColor: _amber.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildProfileSkeleton() {
    return AppShimmer(
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(children: [
            // Avatar
            Center(child: Container(
              width: 90, height: 90,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            )),
            const SizedBox(height: 24),
            // Section card 1
            _skProfileCard(rows: 3),
            const SizedBox(height: 16),
            _skProfileCard(rows: 2),
            const SizedBox(height: 16),
            _skProfileCard(rows: 1),
            const SizedBox(height: 24),
            Container(height: 52, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14))),
          ]),
        ),
      ),
    );
  }

  Widget _skProfileCard({int rows = 3}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        for (int i = 0; i < rows; i++) ...[
          Container(height: 52, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
          if (i < rows - 1) const SizedBox(height: 12),
        ],
      ]),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _amber,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.black87, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.08),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Modifier mon profil',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  // Avatar tappable
                  GestureDetector(
                    onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                    child: Stack(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _isUploadingPhoto
                                ? const Center(
                                    child: SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(_amber),
                                      ),
                                    ),
                                  )
                                : _pickedImage != null
                                    ? Image.file(_pickedImage!, fit: BoxFit.cover, width: 72, height: 72)
                                    : (_photoUrl != null && _photoUrl!.isNotEmpty && !_photoUrl!.contains('default-user'))
                                        ? Image.network(
                                            _photoUrl!,
                                            fit: BoxFit.cover,
                                            width: 72,
                                            height: 72,
                                            errorBuilder: (_, __, ___) => Center(
                                              child: Text(
                                                _initials,
                                                style: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: _amber,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              _initials,
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: _amber,
                                              ),
                                            ),
                                          ),
                          ),
                        ),
                        // Badge caméra
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_prenomController.text} ${_nomController.text}'.trim().isEmpty
                            ? 'Votre profil'
                            : '${_prenomController.text} ${_nomController.text}'.trim(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (_emailController.text.isNotEmpty)
                        Text(
                          _emailController.text,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black87.withOpacity(0.6),
                          ),
                        ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                        child: Text(
                          'Changer la photo',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black87.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Card section ──────────────────────────────────────────────────────────
  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: _amber),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ── Champ texte ───────────────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    Widget? prefixWidget,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      validator: validator,
      inputFormatters: maxLength != null
          ? [LengthLimitingTextInputFormatter(maxLength)]
          : null,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14, color: Colors.grey),
        prefixIcon: prefixWidget ?? Icon(icon, size: 20, color: _amber),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _amber, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.8),
        ),
      ),
    );
  }

  // ── Section mot de passe ──────────────────────────────────────────────────
  Widget _buildPasswordSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() {
              _showPasswordFields = !_showPasswordFields;
              if (!_showPasswordFields) {
                _newPasswordController.clear();
                _confirmPasswordController.clear();
              }
            }),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _showPasswordFields
                          ? Colors.orange.withOpacity(0.15)
                          : _amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 18,
                      color: _showPasswordFields ? Colors.orange : _amber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Modifier le mot de passe',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showPasswordFields ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child:
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showPasswordFields
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        const Divider(height: 1, color: Color(0xFFF0F0F0)),
                        const SizedBox(height: 16),
                        _buildField(
                          controller: _newPasswordController,
                          label: 'Nouveau mot de passe',
                          icon: Icons.lock_outline,
                          obscure: _obscureNew,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNew
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: Colors.grey,
                            ),
                            onPressed: () =>
                                setState(() => _obscureNew = !_obscureNew),
                          ),
                          validator: (v) {
                            if (_showPasswordFields && (v == null || v.isEmpty)) {
                              return 'Champ requis';
                            }
                            if (v != null && v.isNotEmpty && v.length < 6) {
                              return 'Minimum 6 caractères';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _confirmPasswordController,
                          label: 'Confirmer le mot de passe',
                          icon: Icons.lock_reset_rounded,
                          obscure: _obscureConfirm,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: Colors.grey,
                            ),
                            onPressed: () =>
                                setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          validator: (v) {
                            if (_showPasswordFields &&
                                _newPasswordController.text.isNotEmpty &&
                                v != _newPasswordController.text) {
                              return 'Les mots de passe ne correspondent pas';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── Bannière d'erreur ─────────────────────────────────────────────────────
  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: const Icon(Icons.close, color: Colors.red, size: 18),
          ),
        ],
      ),
    );
  }
}
