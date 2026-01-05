import 'package:flutter/material.dart';

class LicenseAgreementPage extends StatelessWidget {
  const LicenseAgreementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contrat de Licence Betro',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF757575),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF757575),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1. Licence d\'utilisation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Betro vous accorde une licence limitée, non exclusive et non transférable pour utiliser l\'application conformément aux présentes conditions.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              const Text(
                '2. Restrictions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Vous n\'êtes pas autorisé à :\n• Copier ou modifier l\'application\n• Utiliser l\'application à des fins commerciales sans autorisation\n• Tenter d\'extraire le code source de l\'application',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              const Text(
                '3. Propriété intellectuelle',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tous les droits de propriété intellectuelle relatifs à l\'application restent la propriété exclusive de Betro.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              const Text(
                '4. Résiliation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Cette licence est valable jusqu\'à sa résiliation. Vos droits cesseront automatiquement si vous ne respectez pas les termes de cette licence.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
