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
