import 'package:flutter_test/flutter_test.dart';
import 'package:betro/core/utils/parsing.dart';

void main() {
  test('ancien format texte conservé', () {
    expect(infractionsEnTexte('Excès de vitesse'), 'Excès de vitesse');
    expect(infractionsEnTexte(''), isNull);
    expect(infractionsEnTexte(null), isNull);
  });
  test('liste vide = aucune infraction', () {
    expect(infractionsEnTexte([]), isNull);
  });
  test('nouveau format liste', () {
    expect(
      infractionsEnTexte([
        {'libelle': 'Excès de vitesse', 'description': 'Axe Abidjan–Yamoussoukro', 'date': '2026-09-12'},
        {'libelle': 'Surcharge', 'description': null, 'date': '2026-08-01'},
      ]),
      'Excès de vitesse (12/09/2026) — Axe Abidjan–Yamoussoukro\nSurcharge (01/08/2026)',
    );
  });
}
