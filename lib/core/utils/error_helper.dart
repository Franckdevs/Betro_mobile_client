import 'package:flutter/material.dart';

class ErrorHelper {
  // Nettoie les messages d'erreur pour cacher les URLs et données sensibles
  static String cleanErrorMessage(String errorMessage) {
    // Remplacer les URLs par un message générique
    String cleaned = errorMessage.replaceAll(RegExp(r'https?://[^\s]+'), '[URL]');
    
    // Remplacer les tokens par un message générique
    cleaned = cleaned.replaceAll(RegExp(r'\b[a-zA-Z0-9]{20,}\b'), '[TOKEN]');
    
    // Remplacer les informations sensibles
    cleaned = cleaned.replaceAll(RegExp(r'ClientException with SocketException.*'), 'Erreur de connexion réseau');
    cleaned = cleaned.replaceAll(RegExp(r'Failed host lookup.*'), 'Serveur inaccessible');
    cleaned = cleaned.replaceAll(RegExp(r'No address associated with hostname.*'), 'Serveur inaccessible');
    cleaned = cleaned.replaceAll(RegExp(r'OS Error.*'), 'Erreur système');
    cleaned = cleaned.replaceAll(RegExp(r'SocketException.*'), 'Erreur de connexion réseau');
    
    return cleaned;
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
