/// Conversions numériques tolérantes pour les données d'API.
///
/// Le backend renvoie les montants tantôt en nombre, tantôt en chaîne
/// (`"15000.00"`). Appeler `.toInt()` directement sur la valeur brute lève
/// alors un `NoSuchMethodError` à l'exécution : `String` n'a pas de `toInt`.
library;

/// Convertit [v] en `double`, quel que soit son type d'origine.
double asDouble(dynamic v, [double fallback = 0]) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? fallback;

/// Convertit [v] en `int`, en tronquant les décimales éventuelles.
int asInt(dynamic v, [int fallback = 0]) =>
    v is num ? v.toInt() : asDouble(v, fallback.toDouble()).toInt();

/// Convertit le champ `infractions` de l'API en texte affichable.
///
/// Accepte l'ancien format (texte) et le nouveau (liste d'objets
/// `{libelle, description, date}`, envoyée quand l'app passe l'en-tête
/// `X-Betro-Infractions: liste`). Renvoie `null` s'il n'y a aucune infraction.
String? infractionsEnTexte(dynamic raw) {
  if (raw == null) return null;
  if (raw is String) return raw.trim().isEmpty ? null : raw;
  final items = raw is List ? raw : (raw is Map ? [raw] : const []);
  final lignes = <String>[];
  for (final item in items) {
    if (item is Map) {
      final libelle = item['libelle']?.toString().trim() ?? '';
      if (libelle.isEmpty) continue;
      final date = _dateCourte(item['date']?.toString());
      final description = item['description']?.toString().trim() ?? '';
      lignes.add([
        date.isEmpty ? libelle : '$libelle ($date)',
        if (description.isNotEmpty) description,
      ].join(' — '));
    } else if (item != null && item.toString().trim().isNotEmpty) {
      lignes.add(item.toString().trim());
    }
  }
  return lignes.isEmpty ? null : lignes.join('\n');
}

String _dateCourte(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  if (d == null) return iso ?? '';
  String deux(int n) => n.toString().padLeft(2, '0');
  return '${deux(d.day)}/${deux(d.month)}/${d.year}';
}
