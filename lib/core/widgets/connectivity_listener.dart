import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/connectivity_service.dart';
import '../../pages/utils/no_connection_page.dart';

class ConnectivityListener extends StatefulWidget {
  final Widget child;

  const ConnectivityListener({super.key, required this.child});

  @override
  State<ConnectivityListener> createState() => _ConnectivityListenerState();
}

class _ConnectivityListenerState extends State<ConnectivityListener> {
  final bool _showNoConnectionPage = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivityService, _) {
        return Stack(
          children: [
            widget.child,
            if (!connectivityService.isConnected && !_showNoConnectionPage)
              Positioned.fill(
                child: Container(
                  color: Colors.white,
                  child: const NoConnectionPage(),
                ),
              ),
          ],
        );
      },
    );
  }
}
