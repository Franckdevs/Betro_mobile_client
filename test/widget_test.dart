import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:betro/core/constant/colors.dart';
import 'package:betro/core/utils/error_helper.dart';
import 'package:betro/core/utils/parsing.dart';

void main() {
  group('AppColors', () {
    test('les deux boutons de contact partagent la même couleur', () {
      // Régression : le bouton téléphone utilisait Colors.green alors que le
      // bouton WhatsApp utilisait 0xFF25D366.
      expect(AppColors.whatsapp, AppColors.appel);
    });

    test('la couleur primaire du thème est celle de la marque', () {
      expect(AppTheme.light.colorScheme.primary, AppColors.primaire);
    });
  });

  group('ErrorHelper', () {
    test('masque les URLs et les tokens', () {
      final message = ErrorHelper.cleanErrorMessage(
        'Echec sur https://betro.tresormoney.ci/api/liste_reservation/'
        'aBcDeF0123456789XyZwToken',
      );
      expect(message.contains('betro.tresormoney.ci'), isFalse);
      expect(message.contains('aBcDeF0123456789XyZwToken'), isFalse);
      expect(message.contains('[URL]'), isTrue);
    });

    test('remplace les erreurs socket par un message lisible', () {
      final message = ErrorHelper.cleanErrorMessage(
        'SocketException: Failed host lookup',
      );
      expect(message, 'Erreur de connexion réseau');
    });

    test('classe correctement les types d\'erreur', () {
      expect(ErrorHelper.getErrorType('401 Unauthorized'), ErrorType.auth);
      expect(ErrorHelper.getErrorType('socket closed'), ErrorType.network);
      expect(ErrorHelper.getErrorType('erreur interne 500'), ErrorType.server);
    });
  });

  testWidgets('un Scaffold construit avec AppTheme se rend sans erreur', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Center(child: Text('BETRO'))),
      ),
    );

    expect(find.text('BETRO'), findsOneWidget);
  });

  group('Conversions numériques (asInt / asDouble)', () {
    test('accepte un montant renvoyé en chaîne par l\'API', () {
      // Valeur exacte du crash : NoSuchMethodError sur String.toInt()
      expect(asInt('15000.00'), 15000);
      expect(asDouble('15000.00'), 15000.0);
    });

    test('accepte les nombres natifs', () {
      expect(asInt(15000), 15000);
      expect(asInt(15000.9), 15000);
      expect(asDouble(15000), 15000.0);
    });

    test('retombe sur la valeur par défaut si non convertible', () {
      expect(asInt(null), 0);
      expect(asInt('abc'), 0);
      expect(asInt(null, 42), 42);
      expect(asDouble('', 1.5), 1.5);
    });
  });
}
