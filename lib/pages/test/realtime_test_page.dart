import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeTestPage extends StatefulWidget {
  const RealtimeTestPage({super.key});

  @override
  State<RealtimeTestPage> createState() => _RealtimeTestPageState();
}

class _RealtimeTestPageState extends State<RealtimeTestPage> {
  final _supabase = Supabase.instance.client;
  StreamSubscription? _subscription;
  List<Map<String, dynamic>> _data = [];
  String _status = 'Connexion en cours...';
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    setState(() {
      _status = 'Écoute Realtime sur live_locations...';
      _isConnected = false;
    });

    _subscription = _supabase
        .from('live_locations')
        .stream(primaryKey: ['id'])
        .listen(
          (data) {
            debugPrint('[Realtime] data reçue: $data');
            setState(() {
              _data = List<Map<String, dynamic>>.from(data);
              _isConnected = true;
              _status = 'Realtime OK — ${_data.length} ligne(s) reçue(s)';
            });
          },
          onError: (error) {
            debugPrint('[Realtime] erreur: $error');
            setState(() {
              _isConnected = false;
              _status = 'Erreur: $error';
            });
          },
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Supabase Realtime'),
        backgroundColor: _isConnected ? Colors.green : Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _subscription?.cancel();
              _startListening();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statut
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isConnected
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isConnected ? Colors.green : Colors.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isConnected
                        ? Icons.check_circle
                        : Icons.hourglass_empty,
                    color: _isConnected ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _status,
                      style: TextStyle(
                        color: _isConnected
                            ? Colors.green.shade800
                            : Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Table: live_locations',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),

            if (_data.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Aucune donnée.\nInsère une ligne dans live_locations\npour tester Realtime.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _data.length,
                  itemBuilder: (context, index) {
                    final row = _data[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: row.entries
                              .map(
                                (e) => Text(
                                  '${e.key}: ${e.value}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
