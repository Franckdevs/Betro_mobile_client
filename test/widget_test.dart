import 'package:betro/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:betro/main.dart';
import '../lib/mocks/auth_mocks.dart'; // <- contient déjà MockAuthService

void main() {
  testWidgets('App loads WelcomePage when not logged in', (
    WidgetTester tester,
  ) async {
    // Build app with mock service
    // await tester.pumpWidget(PasserApp(
    //   isLoggedIn: false,
    //   // authService: MockApiService(), // <-- utilise le mock importé
    // ));

    // Vérifie que WelcomePage est affichée
    expect(find.text('BETRO'), findsOneWidget);
    expect(find.text('Réserver'), findsOneWidget);
  });
}

class MockApiService extends ApiService {
  @override
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data, {
    String? token,
  }) async {
    // ici tu peux simuler une réponse
    return {"status": true, "message": "Mock success"};
  }
}
