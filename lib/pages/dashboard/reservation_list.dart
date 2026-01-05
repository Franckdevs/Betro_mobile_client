import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/reservation_model.dart';
import 'ticket_page.dart';

class ReservationList extends StatelessWidget {
  final List<Reservation> reservations;
  final bool isLoading;
  final String errorMessage;

  const ReservationList({
    super.key,
    required this.reservations,
    required this.isLoading,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow),
          strokeWidth: 3,
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Text(errorMessage, style: const TextStyle(color: Colors.red)),
      );
    }

    if (reservations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Text(
            'Aucune réservation trouvée',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reservations.length,
      itemBuilder: (context, index) {
        final reservation = reservations[index];
        return _buildReservationCard(context, reservation);
      },
    );
  }

  Widget _buildReservationCard(BuildContext context, Reservation reservation) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final numberFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'FCFA',
      decimalDigits: 0,
    );

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TicketPage(reservation: reservation.toJson()),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.directions_bus,
                    size: 20,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${reservation.marqueBus} (${reservation.immatriculationBus})',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: reservation.status == '1'
                          ? Colors.green.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      reservation.status == '1'
                          ? 'Scanné'
                          : 'En attente du scan',
                      style: TextStyle(
                        color: reservation.status == '1'
                            ? Colors.green
                            : Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 20,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${reservation.villeDepart} → ${reservation.villeArrivee}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.confirmation_number,
                    size: 20,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Place: ${reservation.numeroPlace}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        '${reservation.nombreTotalPlaces} sièges au total',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    numberFormat.format(reservation.prix),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Réservé le ${dateFormat.format(reservation.dateCreation)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
