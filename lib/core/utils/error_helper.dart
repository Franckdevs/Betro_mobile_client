import 'package:flutter/material.dart';

class ErrorHelper {
  // Convertit n'importe quelle erreur technique (URL, exception système,
  // stacktrace...) en un message générique sûr à afficher à l'utilisateur.
  // Ne renvoie JAMAIS un fragment de l'erreur d'origine : soit elle est
  // reconnue comme un message métier propre (déjà rédigé côté app/serveur),
  // soit elle est remplacée intégralement par un message généré ici.
  static String cleanErrorMessage(String errorMessage) {
    final lower = errorMessage.toLowerCase();

    bool has(List<String> needles) => needles.any(lower.contains);

    if (has(['handshake', 'certificate', 'certificat', 'ssl', 'tls'])) {
      return 'Connexion sécurisée impossible pour le moment. Réessayez dans quelques instants.';
    }
    if (has(['timeoutexception', 'timed out', 'délai dépassé'])) {
      return 'Le serveur met trop de temps à répondre. Réessayez.';
    }
    if (has([
      'socketexception',
      'failed host lookup',
      'no address associated',
      'network is unreachable',
      'connection refused',
      'connection reset',
      'clientexception',
    ])) {
      return 'Impossible de se connecter au serveur. Vérifiez votre connexion internet.';
    }
    if (has(['formatexception', 'unexpected character', 'invalid json'])) {
      return 'Réponse du serveur invalide. Réessayez plus tard.';
    }
    if (has(['401', 'unauthorized', 'session expirée', 'non connecté'])) {
      return 'Votre session a expiré. Veuillez vous reconnecter.';
    }
    if (has(['404', 'not found', 'introuvable'])) {
      return "L'information demandée est introuvable.";
    }
    if (has(['500', 'internal server error'])) {
      return 'Le serveur rencontre un problème. Réessayez plus tard.';
    }

    // Toute trace d'URL, de nom de classe d'exception ou de stacktrace
    // signale un message technique non catégorisé ci-dessus : on ne le
    // laisse jamais remonter tel quel.
    final looksTechnical = errorMessage.contains(RegExp(r'https?://', caseSensitive: false)) ||
        errorMessage.contains(RegExp(r'\bException\b')) ||
        errorMessage.contains('#0') || // signature de stacktrace Dart
        errorMessage.contains(RegExp(r'\.(dart|cc):\d+'));

    if (looksTechnical) {
      return 'Une erreur est survenue. Veuillez réessayer.';
    }

    // Sinon, il s'agit déjà d'un message métier propre (ex. fourni par
    // l'API : "Code OTP invalide ou expiré.") : on le garde tel quel.
    return errorMessage.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }

  // Affiche un SnackBar avec un message d'erreur propre
  static void showErrorSnackBar(BuildContext context, String message) {
    String cleanMessage = cleanErrorMessage(message);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cleanMessage),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Affiche un SnackBar de succès
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Affiche un SnackBar d'information
  static void showInfoSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Vérifie si une erreur est une erreur d'authentification
  static bool isAuthError(String errorMessage) {
    final error = errorMessage.toLowerCase();
    return error.contains('401') || 
           error.contains('unauthorized') || 
           error.contains('expirée') ||
           error.contains('token') ||
           error.contains('session');
  }

  // Gère les erreurs réseau vs erreurs d'authentification
  static ErrorType getErrorType(String errorMessage) {
    final error = errorMessage.toLowerCase();
    
    if (isAuthError(error)) {
      return ErrorType.auth;
    } else if (error.contains('network') || 
               error.contains('connection') ||
               error.contains('host') ||
               error.contains('socket')) {
      return ErrorType.network;
    } else {
      return ErrorType.server;
    }
  }
}

enum ErrorType {
  auth,
  network,
  server,
}
