import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../../../core/utils/error_helper.dart';

const Color _amber = Color(0xFFFFB300);

class PaiementWebViewPage extends StatefulWidget {
  final String urlPaiement;

  const PaiementWebViewPage({super.key, required this.urlPaiement});

  static Future<void> lancerUrl(String url) async {
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      throw 'Impossible d\'ouvrir l\'URL: $url';
    }
  }

  @override
  State<PaiementWebViewPage> createState() => _PaiementWebViewPageState();
}

class _PaiementWebViewPageState extends State<PaiementWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;
  bool _hasError = false;
  bool _hasConnection = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _checkConnectivity();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final connected = results.any((r) => r != ConnectivityResult.none);
      if (mounted) {
        setState(() => _hasConnection = connected);
        if (connected && _hasError) _reload();
      }
    });

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) async {
            await _handleUrl(url);
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
                _progress = 0;
              });
            }
          },
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress / 100);
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
              _isLoading = false;
              _progress = 1.0;
            });
            }
          },
          onWebResourceError: (error) {
            debugPrint('Erreur webview: ${error.description}');
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
          onNavigationRequest: (request) async {
            final url = request.url;
            if (url.startsWith('wave://')) {
              await _handleUrl(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.urlPaiement));
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _hasConnection = results.any((r) => r != ConnectivityResult.none));
    }
  }

  Future<void> _handleUrl(String url) async {
    if (url.startsWith('wave://')) {
      try {
        await PaiementWebViewPage.lancerUrl(url);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: ${ErrorHelper.cleanErrorMessage(e.toString())}'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _reload() {
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    _controller.loadRequest(Uri.parse(widget.urlPaiement));
  }

  @override
  void dispose() {
    _connectivitySub.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header amber
          Container(
            decoration: const BoxDecoration(
              color: _amber,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(0)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 8, 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.lock_outline,
                              color: Colors.black87,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Paiement sécurisé',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                'Connexion chiffrée SSL',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.home_outlined, color: Colors.black87, size: 24),
                      onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                        '/dashboard',
                        (route) => false,
                      ),
                      tooltip: 'Accueil',
                    ),
                    if (_hasConnection && !_hasError) ...[
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.black87, size: 22),
                        onPressed: _reload,
                        tooltip: 'Actualiser',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Barre de progression
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: (_isLoading && _hasConnection && !_hasError) ? 3 : 0,
            child: LinearProgressIndicator(
              value: _progress < 1.0 ? _progress : null,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(_amber),
              minHeight: 3,
            ),
          ),

          // Contenu
          Expanded(
            child: _hasConnection ? _buildWebContent() : _buildNoConnectionView(),
          ),
        ],
      ),
    );
  }

  Widget _buildWebContent() {
    if (_hasError) return _buildErrorView();

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          Container(
            color: Colors.white,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_amber),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Chargement du paiement...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNoConnectionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.orange[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded, size: 44, color: Colors.orange[400]),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pas de connexion internet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Une connexion internet est nécessaire pour accéder à la page de paiement.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _checkConnectivity,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text(
                  'Réessayer',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _amber,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Retour',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 44, color: Colors.red[400]),
            ),
            const SizedBox(height: 24),
            const Text(
              'Impossible de charger la page',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Une erreur est survenue lors du chargement de la page de paiement.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text(
                  'Réessayer',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _amber,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Retour',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
