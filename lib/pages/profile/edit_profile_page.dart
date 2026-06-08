import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import '../../core/widgets/shimmer_skeleton.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _storageService = StorageService();
  final _apiService = ApiService();

  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showPasswordFields = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  static const _amber = Color(0xFFFFC107);
  static const _darkBlue = Color(0xFF1A237E);

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

  bool _validatePasswords() {
    if (_newPasswordController.text.isNotEmpty ||
        _confirmPasswordController.text.isNotEmpty) {
      if (_currentPasswordController.text.isEmpty) {
        setState(() => _errorMessage = 'Veuillez entrer votre mot de passe actuel');
        return false;
      }
      if (_newPasswordController.text.isEmpty) {
        setState(() => _errorMessage = 'Veuillez entrer un nouveau mot de passe');
        return false;
      }
      if (_newPasswordController.text != _confirmPasswordController.text) {
        setState(() => _errorMessage = 'Les nouveaux mots de passe ne correspondent pas');
        return false;
      }
      if (_newPasswordController.text.length < 6) {
        setState(() => _errorMessage = 'Le mot de passe doit contenir au moins 6 caractères');
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
      final response = await _apiService.updateProfile(
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
        await _storageService.saveUserData({
          'nom': _nomController.text,
          'prenom': _prenomController.text,
          'email': _emailController.text,
          'telephone': _telephoneController.text,
        });

        if (mounted) {
          Fluttertoast.showToast(
            msg: 'Profil mis à jour avec succès',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green[700],
            textColor: Colors.white,
            fontSize: 16.0,
          );
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception(response['message'] ?? 'Échec de la mise à jour');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

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

  String get _initials {
    final nom = _nomController.text;
    final prenom = _prenomController.text;
    final n = nom.isNotEmpty ? nom[0].toUpperCase() : '';
    final p = prenom.isNotEmpty ? prenom[0].toUpperCase() : '';
    return '$n$p'.isEmpty ? '?' : '$n$p';
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
                  // ── Header ─────────────────────────────────────
                  _buildHeader(context),
                  // ── Body ───────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          if (_errorMessage != null) _buildErrorBanner(),
                          _buildSection(
                            icon: Icons.person_rounded,
                            title: 'Informations personnelles',
                            children: [
                              _buildField(
                                controller: _nomController,
                                label: 'Nom',
                                icon: Icons.badge_outlined,
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Champ requis'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              _buildField(
                                controller: _prenomController,
                                label: 'Prénom',
                                icon: Icons.person_outline,
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Champ requis'
                                    : null,
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
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Champ requis'
                                    : null,
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black87),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ── Header avec avatar ─────────────────────────────────────────────────────
  Widget _buildProfileSkeleton() {
    return AppShimmer(
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(children: [
            Center(child: Container(
              width: 90, height: 90,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            )),
            const SizedBox(height: 24),
            _skCard(rows: 3),
            const SizedBox(height: 16),
            _skCard(rows: 2),
            const SizedBox(height: 24),
            Container(height: 52, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14))),
          ]),
        ),
      ),
    );
  }

  Widget _skCard({int rows = 3}) {
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
            children: [
              // Back button row
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
                    'Mon profil',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Avatar
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _initials,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _amber,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: _darkBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, size: 14, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${_prenomController.text} ${_nomController.text}'.trim(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (_emailController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _emailController.text,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black87.withOpacity(0.6),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section card ───────────────────────────────────────────────────────────
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
      child: Padding(
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
                    letterSpacing: 0.3,
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
      ),
    );
  }

  // ── Champ texte stylisé ────────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14, color: Colors.grey),
        prefixIcon: Icon(icon, size: 20, color: _amber),
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

  // ── Section mot de passe ───────────────────────────────────────────────────
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
          // Toggle header
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _showPasswordFields = !_showPasswordFields),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _showPasswordFields
                          ? _darkBlue.withOpacity(0.1)
                          : _amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 18,
                      color: _showPasswordFields ? _darkBlue : _amber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Modifier le mot de passe',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showPasswordFields ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          // Fields
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
                          controller: _currentPasswordController,
                          label: 'Mot de passe actuel',
                          icon: Icons.lock_outline,
                          obscure: _obscureCurrent,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureCurrent
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: Colors.grey,
                            ),
                            onPressed: () =>
                                setState(() => _obscureCurrent = !_obscureCurrent),
                          ),
                          validator: (v) {
                            if (_newPasswordController.text.isNotEmpty &&
                                (v == null || v.isEmpty)) {
                              return 'Veuillez entrer votre mot de passe actuel';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _newPasswordController,
                          label: 'Nouveau mot de passe',
                          icon: Icons.lock_reset_rounded,
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
                            if (_currentPasswordController.text.isNotEmpty &&
                                (v == null || v.isEmpty)) {
                              return 'Veuillez entrer un nouveau mot de passe';
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
                            if (_newPasswordController.text.isNotEmpty &&
                                _newPasswordController.text != v) {
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

  // ── Bannière d'erreur ──────────────────────────────────────────────────────
  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
