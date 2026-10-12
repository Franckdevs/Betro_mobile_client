import 'package:flutter/material.dart';

/// Palette de l'application.
///
/// Les couleurs étaient jusqu'ici écrites en dur dans les pages (263 littéraux
/// `Color(0xFF…)`), ce qui rendait impossible toute garantie de cohérence :
/// deux boutons voisins pouvaient avoir deux verts différents. Toute nouvelle
/// couleur doit être déclarée ici plutôt que dans un widget.
abstract final class AppColors {
  // ── Marque ────────────────────────────────────────────────────────────────
  /// Ambre BETRO — couleur d'accent principale (42 occurrences historiques).
  static const Color primaire = Color(0xFFFFC107);

  /// Bleu nuit utilisé pour le texte sur fond ambre et les en-têtes.
  static const Color secondaire = Color(0xFF1A237E);

  static const Color bleu = Color(0xFF1565C0);

  // ── Sémantique ────────────────────────────────────────────────────────────
  static const Color succes = Color(0xFF2E7D32);
  static const Color erreur = Color(0xFFD32F2F);
  static const Color avertissement = Color(0xFFFFA000);

  // ── Canaux de contact ─────────────────────────────────────────────────────
  /// Vert WhatsApp officiel.
  static const Color whatsapp = Color(0xFF25D366);

  /// Bouton d'appel — volontairement identique à [whatsapp] : les deux boutons
  /// de la feuille « Service Client » doivent avoir la même couleur.
  static const Color appel = whatsapp;

  // ── Neutres ───────────────────────────────────────────────────────────────
  static const Color fond = Colors.white;
  static const Color fondSecondaire = Color(0xFFF5F6FA);
  static const Color surface = Color(0xFFF5F5F5);
  static const Color bordure = Color(0xFFE0E0E0);
  static const Color texte = Color(0xFF212121);
  static const Color texteAttenue = Color(0xFF757575);
}

/// Thème dérivé de [AppColors].
///
/// Le thème déclarait `primarySwatch: Colors.blue` alors que l'interface est
/// ambre et verte — d'où les couleurs recopiées à la main dans chaque page.
abstract final class AppTheme {
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    fontFamily: 'Montserrat',
    scaffoldBackgroundColor: AppColors.fond,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaire,
      primary: AppColors.primaire,
      secondary: AppColors.secondaire,
      error: AppColors.erreur,
      surface: AppColors.fond,
    ),
  );
}
