import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';

class PaiementWebViewPage extends StatefulWidget {
  final String urlPaiement;

  const PaiementWebViewPage({super.key, required this.urlPaiement});

  /// Lance une URL dans le navigateur par défaut
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
  // Liste des URLs chargées (utilisée pour le débogage)
  final List<String> _loadedUrls = [];

  // Fonction pour gérer le lancement des URLs Wave
  Future<void> _handleUrl(String url) async {
    if (url.startsWith('wave://')) {
      try {
        await PaiementWebViewPage.lancerUrl(url);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
      return;
    }
  }

  @override
  void initState() {
    super.initState();
    // Forcer l'orientation portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) async {
            await _handleUrl(url);
            setState(() {
              _isLoading = true;
              _progress = 0;
              // _loadedUrls.add(url);  // Désactivé pour masquer l'affichage des URLs
              debugPrint(
                'URL chargée: $url',
              ); // Toujours enregistré dans les logs
            });
          },
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _progress = 1.0;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Erreur de chargement: ${error.description}');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur de chargement: ${error.description}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          onNavigationRequest: (NavigationRequest request) async {
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

  void _navigateToHome() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: const Text(
          'Paiement sécurisé',
          style: TextStyle(color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              _controller.reload();
            },
            tooltip: 'Actualiser la page',
          ),
          IconButton(
            icon: const Icon(Icons.home, color: Colors.black),
            onPressed: _navigateToHome,
            tooltip: 'Retour à l\'accueil',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading || _progress < 1.0)
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.blue,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
