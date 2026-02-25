import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService extends ChangeNotifier {
  bool _isConnected = true;
  ConnectivityResult _connectionType = ConnectivityResult.none;

  bool get isConnected => _isConnected;
  ConnectivityResult get connectionType => _connectionType;

  ConnectivityService() {
    _initializeConnectivity();
    Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _initializeConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      if (kDebugMode) {
        print('Error checking connectivity: $e');
      }
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // Check if any connection is available (not none)
    _isConnected = results.any((result) => result != ConnectivityResult.none);
    _connectionType = results.isNotEmpty
        ? results.first
        : ConnectivityResult.none;
    notifyListeners();
  }
}
