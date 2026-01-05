import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'routes/app_routes.dart';
import 'pages/onboarding/welcome_page.dart';
import 'pages/dashboard/dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation des services
  final apiService = ApiService();
  final storageService = StorageService();
  final authService = AuthService(
    apiService: apiService,
    storageService: storageService,
  );

  // Vérifie si l’utilisateur est connecté
  final isLoggedIn = await authService.isLoggedIn();

  runApp(PasserApp(isLoggedIn: isLoggedIn, authService: authService));
}

class PasserApp extends StatelessWidget {
  final bool isLoggedIn;
  final AuthService authService;

  const PasserApp({
    super.key,
    required this.isLoggedIn,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Passer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Montserrat',
        scaffoldBackgroundColor: Colors.white,
      ),
      // Démarrage conditionnel
      home: isLoggedIn ? const Dashboard() : const Welcome(),
      routes: AppRoutes.routes,
    );
  }
}
