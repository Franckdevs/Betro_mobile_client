import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  final ApiService apiService;
  final StorageService storageService;

  AuthService({required this.apiService, required this.storageService});

  // Connexion avec email + mot de passe
  Future<bool> login(String email, String password) async {
    final response = await apiService.post('/login', {
      'email': email,
      'password': password,
    });

    if (response['status'] == true) {
      await storageService.saveToken(response['token']);
      return true;
    }
    return false;
  }

  // Envoi OTP
  Future<bool> sendOtp(String email) async {
    final response = await apiService.post('/send-otp', {'email': email});
    return response['status'] == true;
  }

  // Vérification OTP
  Future<bool> verifyOtp(String email, String otp) async {
    final response = await apiService.post('/verify-otp', {
      'email': email,
      'otp': otp,
    });

    if (response['status'] == true) {
      await storageService.saveToken(response['token']);
      return true;
    }
    return false;
  }

  // Déconnexion
  Future<void> logout() async {
    await storageService.clearToken();
  }

  // Vérifie si l'utilisateur est connecté
  Future<bool> isLoggedIn() async {
    final token = await storageService.getToken();
    return token != null;
  }
}
