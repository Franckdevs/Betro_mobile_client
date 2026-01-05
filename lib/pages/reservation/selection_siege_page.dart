import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_service.dart';

class SelectionSiegePage extends StatefulWidget {
  final int busId;
  final int voyageId;
  final int nombrePlaces;

  const SelectionSiegePage({
    super.key,
    required this.busId,
    required this.voyageId,
    required this.nombrePlaces,
  });

  @override
  State<SelectionSiegePage> createState() => _SelectionSiegePageState();
}

class _SelectionSiegePageState extends State<SelectionSiegePage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _placesOccupees = [];
  List<dynamic> _placesDisponibles = [];
  int? _selectedSeat;
  String? _selectedSeatName;

  @override
  void initState() {
    super.initState();
    _loadBusSeats();
  }

  Future<void> _loadBusSeats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${_apiService.baseUrl}/bus_detail_place/${widget.busId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _placesOccupees = data['liste_place_deja_occupe'] ?? [];
            _placesDisponibles = data['data']?['places'] ?? [];
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  data['message'] ?? 'Erreur lors du chargement des places',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        throw Exception('Erreur lors du chargement des places');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur de connexion au serveur'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isSeatOccupied(int seatNumber) {
    return _placesOccupees.any((place) => place['numero_place'] == seatNumber);
  }

  void _selectSeat(int seatNumber, String seatName) {
    if (!_isSeatOccupied(seatNumber)) {
      setState(() {
        _selectedSeat = _selectedSeat == seatNumber ? null : seatNumber;
        _selectedSeatName = _selectedSeat == seatNumber ? null : seatName;
      });
    }
  }

  Widget _buildSeat(int seatNumber, String seatName) {
    final bool isOccupied = _isSeatOccupied(seatNumber);
    final bool isSelected = _selectedSeat == seatNumber;

    Color seatColor = Colors.green.shade200;
    if (isOccupied) {
      seatColor = Colors.grey.shade400;
    } else if (isSelected) {
      seatColor = Colors.amber;
    }

    return GestureDetector(
      onTap: () => _selectSeat(seatNumber, seatName),
      child: Container(
        width: 50,
        height: 50,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: seatColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              seatName,
              style: TextStyle(
                color: isOccupied ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isOccupied)
              const Icon(Icons.person, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildBusLayout() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow),
          strokeWidth: 3,
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Légende
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem(Colors.green.shade200, 'Disponible'),
                _buildLegendItem(Colors.amber, 'Sélectionné'),
                _buildLegendItem(Colors.grey.shade400, 'Occupé'),
              ],
            ),
          ),

          // Volant
          Container(
            width: 80,
            height: 80,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.blueGrey[100],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blueGrey[300]!),
            ),
            child: const Icon(
              Icons.directions_bus,
              size: 40,
              color: Colors.blueGrey,
            ),
          ),

          // Sièges
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: _placesDisponibles.length,
            itemBuilder: (context, index) {
              final place = _placesDisponibles[index];
              return _buildSeat(place['numero'] ?? 0, place['nom'] ?? '?');
            },
          ),

          // Bouton de confirmation
          if (_selectedSeat != null) ...[
            const SizedBox(height: 20),
            Text(
              'Siège sélectionné: $_selectedSeatName',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Naviguer vers la page de paiement ou de confirmation
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Siège $_selectedSeatName sélectionné'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Confirmer la réservation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade400),
          ),
        ),
        Text(text),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sélectionnez votre siège'),
        backgroundColor: Colors.amber[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildBusLayout(),
      ),
    );
  }
}
