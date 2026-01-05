import 'package:betro/services/api_service.dart';

// Mock ApiService
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
