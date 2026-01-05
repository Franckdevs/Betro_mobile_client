import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TicketPage extends StatelessWidget {
  final Map<String, dynamic> reservation;

  const TicketPage({Key? key, required this.reservation}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Afficher toutes les données de la réservation pour le débogage
    print('=== DONNÉES DE RÉSERVATION ===');
    reservation.forEach((key, value) {
      print('$key: $value');
    });
    print('=============================');
    final departureCity =
        reservation['arret']['tarification']['ville_depart']['nom_ville'] ?? '';
    final arrivalCity =
        reservation['arret']['tarification']['ville_arrivee']['nom_ville'] ??
        '';
    final busInfo = reservation['voyage']['bus']['nom_bus'] ?? '';
    final busNumber = reservation['voyage']['bus']['immatriculation_bus'] ?? '';
    final price = (reservation['arret']['montant'] ?? 0).toInt().toString();
    final date = _formatDate(reservation['voyage']['date_depart'] ?? '');
    final time = _formatTime(reservation['voyage']['heure_depart'] ?? '');
    final seatNumber = reservation['numero_place']?.toString() ?? '';
    final totalSeats =
        reservation['voyage']['bus']['places']?.length.toString() ?? '0';
    final ticketNumber = reservation['numero_reservation'] ?? 'N/A';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120.0),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.yellow,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            title: const Text(
              'Mon Billet',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.yellow,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.black87,
                size: 30,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Ticket Card
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 24.0,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header with yellow background
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: const BoxDecoration(
                      color: Colors.yellow,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        // Departure and Arrival
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: Text(
                                'Départ\n$departureCity',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward,
                              color: Colors.black54,
                              size: 28,
                            ),
                            Expanded(
                              child: Text(
                                'Arrivée\n$arrivalCity',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Passenger Name
                        // Row(
                        //   children: const [
                        //     Text(
                        //       'Nom Kone Innocent', // This should come from user data
                        //     ),
                        //   ],
                        // ),
                      ],
                    ),
                  ),

                  // Ticket Content
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bus Info
                        _buildInfoRow('Bus', '$busInfo $busNumber'),
                        const SizedBox(height: 18),

                        // Price
                        _buildInfoRow('Prix', '$price Fcfa'),
                        const SizedBox(height: 18),

                        // Date and Time
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: _buildInfoRow('Date', date)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildInfoRow('Heure', time)),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Seat Number
                        _buildInfoRow('Nbre de sièges', totalSeats),
                        const SizedBox(height: 18),

                        // Section "Attribuer à" (affichée uniquement si au moins un champ est renseigné)
                        if ((reservation['nom_complet'] != null &&
                                reservation['nom_complet']
                                    .toString()
                                    .isNotEmpty) ||
                            (reservation['telephone_proprietaire'] != null &&
                                reservation['telephone_proprietaire']
                                    .toString()
                                    .isNotEmpty))
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Attribuer à',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (reservation['nom_complet'] != null &&
                                  reservation['nom_complet']
                                      .toString()
                                      .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Text(
                                    reservation['nom_complet'],
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (reservation['telephone_proprietaire'] !=
                                      null &&
                                  reservation['telephone_proprietaire']
                                      .toString()
                                      .isNotEmpty)
                                Text(
                                  reservation['telephone_proprietaire'],
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              const SizedBox(height: 8),
                            ],
                          ),

                        // Dashed line with more space before QR code
                        Padding(
                          padding: const EdgeInsets.only(top: 28, bottom: 32),
                          child: CustomPaint(
                            painter: DashedLinePainter(),
                            size: const Size(double.infinity, 1),
                          ),
                        ),

                        // QR Code Section with more spacing
                        Padding(
                          padding: const EdgeInsets.only(bottom: 32.0),
                          child: Center(
                            child: Column(
                              children: [
                                QrImageView(
                                  data: reservation['numero_reservation'].toString(),
                                  version: QrVersions.auto,
                                  size: 140.0,
                                  backgroundColor: Colors.white,
                                ),
                                const SizedBox(height: 12),
                                const SizedBox(height: 8),

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (reservation['status'] == '1')
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: (reservation['status'] == '1')
                                          ? Colors.green
                                          : Colors.orange,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    (reservation['status'] == '1')
                                        ? 'Scanné par le contrôleur'
                                        : 'En attente de scan',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: (reservation['status'] == '1')
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),
                                const Text(
                                  'CODE QR',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  ticketNumber,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatTime(String timeString) {
    try {
      final timeParts = timeString.split(':');
      if (timeParts.length >= 2) {
        return '${timeParts[0]}:${timeParts[1]}';
      }
      return timeString;
    } catch (e) {
      return timeString;
    }
  }
}

class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
