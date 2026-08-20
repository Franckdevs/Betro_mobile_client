import 'package:flutter/foundation.dart';

/// Journalisation de développement.
///
/// `print` et `debugPrint` restent actifs dans les builds de release et
/// écrivent dans logcat : tokens, réponses d'API et données personnelles y
/// étaient donc lisibles sur l'appareil de l'utilisateur. Ce helper est un
/// no-op hors du mode debug.
void logDebug(String message) {
  if (kDebugMode) debugPrint(message);
}
