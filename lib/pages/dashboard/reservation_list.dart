import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/reservation_model.dart';
import '../../core/widgets/shimmer_skeleton.dart';
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
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (_, __) => const SkeletonReservationCard(),
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

        return _StaggerItem(

          index: index,

          child: _buildReservationCard(context, reservation),

        );

      },

    );

  }



  Widget _buildReservationCard(BuildContext context, Reservation reservation) {
    final isScanned = reservation.status == '1' ||
        reservation.status.toLowerCase().contains('scan') ||
        reservation.status.toLowerCase() == 'valide';

    final dateFormat = DateFormat("d MMM yyyy '·' HH:mm", 'fr');
    final priceFormat = NumberFormat('#,###', 'fr_FR');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => TicketPage(reservation: reservation.toJson())),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Ligne 1 : référence + badge statut
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.directions_bus_rounded,
                    color: Color(0xFFFFC107), size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reservation.numeroReservation ?? reservation.marqueBus,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isScanned
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: isScanned ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isScanned ? 'Scanné' : 'En attente',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isScanned ? Colors.green : Colors.orange,
                    ),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            // Ligne 2 : départ ── bus ── arrivée
            Row(children: [
              Container(
                  width: 8, height: 8,
                  decoration:
                      const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(reservation.villeDepart,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
              ),
              const Icon(Icons.directions_bus_outlined,
                  size: 18, color: Colors.black38),
              Expanded(
                child: Text(reservation.villeArrivee,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
              ),
              const SizedBox(width: 8),
              Container(
                  width: 8, height: 8,
                  decoration:
                      const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
            ]),
            // Infractions si présentes
            if ((reservation.chauffeurInfractions ?? '').isNotEmpty ||
                (reservation.busInfractions ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.warning_amber_rounded, size: 13, color: Colors.red),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    [
                      if ((reservation.chauffeurInfractions ?? '').isNotEmpty)
                        'Chauffeur: ${reservation.chauffeurInfractions}',
                      if ((reservation.busInfractions ?? '').isNotEmpty)
                        'Bus: ${reservation.busInfractions}',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 10),
            // Ligne 3 : date · place | prix
            Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 13, color: Colors.black45),
              const SizedBox(width: 4),
              Text(
                dateFormat.format(reservation.dateCreation.toLocal()),
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.airline_seat_recline_normal_rounded,
                  size: 13, color: Colors.black45),
              const SizedBox(width: 4),
              Text('Place ${reservation.numeroPlace}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
              const Spacer(),
              Text(
                '${priceFormat.format(reservation.prix.toInt())} FCFA',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ]),
          ]),
        ),
      ),
    );
  }


}

// ── Animation stagger par item ────────────────────────────────────────────────
class _StaggerItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggerItem({required this.index, required this.child});

  @override
  State<_StaggerItem> createState() => _StaggerItemState();
}

class _StaggerItemState extends State<_StaggerItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    final delay = 60 + widget.index.clamp(0, 10) * 60;
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
