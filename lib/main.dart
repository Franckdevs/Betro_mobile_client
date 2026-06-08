import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/connectivity_service.dart';
import 'routes/app_routes.dart';
import 'pages/onboarding/welcome_page.dart';
import 'pages/dashboard/dashboard_page.dart';
import 'core/widgets/no_internet_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ignore silently network image 404 errors (e.g. default-user.png missing on server)
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exception is NetworkImageLoadException) return;
    FlutterError.presentError(details);
  };

  await Supabase.initialize(
    url: 'https://izaajiqogqhpdzzevmsx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml6YWFqaXFvZ3FocGR6emV2bXN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MDc2MjEsImV4cCI6MjA5MDE4MzYyMX0.Sty54yKvEGhb-sQN407WJex2Yc0QfLl5gmJilaexZf0',
  );

  // Bloquer la rotation — portrait uniquement
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize date formatting for French locale
  await initializeDateFormatting('fr');

  // Initialisation des services
  final apiService = ApiService();
  final storageService = StorageService();
  final authService = AuthService(
    apiService: apiService,
    storageService: storageService,
  );

  // Vérifie si l'utilisateur est connecté
  bool isLoggedIn = await authService.isLoggedIn();

  // Si connecté, vérifier immédiatement si le compte est bloqué
  if (isLoggedIn) {
    final token = await storageService.getToken();
    if (token != null) {
      final result = await apiService.verifierStatutCompte(token);
      if (result['est_bloque'] == true) {
        await storageService.clearAllUserData();
        isLoggedIn = false;
      }
    }
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ConnectivityService(),
      child: PasserApp(
        isLoggedIn: isLoggedIn,
        authService: authService,
        apiService: apiService,
        storageService: storageService,
      ),
    ),
  );
}

class PasserApp extends StatefulWidget {
  final bool isLoggedIn;
  final AuthService authService;
  final ApiService apiService;
  final StorageService storageService;

  const PasserApp({
    super.key,
    required this.isLoggedIn,
    required this.authService,
    required this.apiService,
    required this.storageService,
  });

  @override
  State<PasserApp> createState() => _PasserAppState();
}

class _PasserAppState extends State<PasserApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _dialogBlocageAffiche = false;
  late final _StatutCompteObserver _routeObserver;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _routeObserver = _StatutCompteObserver(_verifierStatutCompte);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Vérification aussi au retour au premier plan
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verifierStatutCompte();
    }
  }

  Future<void> _verifierStatutCompte() async {
    final token = await widget.storageService.getToken();
    if (token == null) return;

    final result = await widget.apiService.verifierStatutCompte(token);
    if (result['est_bloque'] == true && !_dialogBlocageAffiche) {
      await widget.storageService.clearAllUserData();
      _afficherDialogBlocage(result['message'] as String?);
    } else if (result['utilisateur'] != null) {
      // Synchroniser le token si le serveur en a émis un nouveau
      final serverToken = (result['utilisateur'] as Map<String, dynamic>?)?['token'] as String?;
      if (serverToken != null && serverToken != token) {
        await widget.storageService.saveToken(serverToken);
      }
    }
  }

  void _afficherDialogBlocage(String? message) {
    final ctx = _navigatorKey.currentContext;
    if (ctx == null) return;

    _dialogBlocageAffiche = true;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Compte bloque'),
        content: Text(
          message ?? 'Votre compte a ete bloque. Veuillez contacter l\'administration.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              _dialogBlocageAffiche = false;
              Navigator.of(ctx, rootNavigator: true).pop();
              _navigatorKey.currentState?.pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [_routeObserver],
      title: 'Passer',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('fr', 'FR'),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Montserrat',
        scaffoldBackgroundColor: Colors.white,
      ),
      home: widget.isLoggedIn ? const Dashboard() : const Welcome(),
      routes: AppRoutes.routes,
      builder: (context, child) {
        return Consumer<ConnectivityService>(
          builder: (context, connectivity, _) {
            return Stack(
              children: [
                child ?? const SizedBox.shrink(),
                if (!connectivity.isConnected)
                  const Positioned.fill(child: NoInternetOverlay()),
              ],
            );
          },
        );
      },
    );
  }
}

/// Observer qui appelle [onPageChange] à chaque navigation (push/pop/replace).
class _StatutCompteObserver extends NavigatorObserver {
  final VoidCallback onPageChange;

  _StatutCompteObserver(this.onPageChange);

  @override
  void didPush(Route route, Route? previousRoute) => onPageChange();

  @override
  void didPop(Route route, Route? previousRoute) => onPageChange();

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) => onPageChange();
}
