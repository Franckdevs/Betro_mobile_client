import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AppShimmer extends StatelessWidget {
  final Widget child;
  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE0E0E0),
      highlightColor: const Color(0xFFF5F5F5),
      child: child,
    );
  }
}

// Bloc rectangle générique pour les skeletons
class SkBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkBox({super.key, this.width, this.height = 14, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// Skeleton d'une carte de réservation (home / reservation_list)
class SkeletonReservationCard extends StatelessWidget {
  const SkeletonReservationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const SkBox(width: 30, height: 30, radius: 8),
            const SizedBox(width: 8),
            const Expanded(child: SkBox(width: 140, height: 13)),
            const SizedBox(width: 8),
            const SkBox(width: 70, height: 22, radius: 20),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 12),
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              SkBox(width: 80, height: 11),
              SizedBox(height: 5),
              SkBox(width: 120, height: 13),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: const [
              SkBox(width: 60, height: 11),
              SizedBox(height: 5),
              SkBox(width: 90, height: 13),
            ]),
          ]),
          const SizedBox(height: 12),
          Row(children: const [
            SkBox(width: 100, height: 11),
            Spacer(),
            SkBox(width: 80, height: 11),
          ]),
        ]),
      ),
    );
  }
}

// Skeleton d'une carte compagnie (grille)
class SkeletonCompagnieTile extends StatelessWidget {
  const SkeletonCompagnieTile({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
          SkBox(width: 56, height: 56, radius: 14),
          SizedBox(height: 10),
          SkBox(height: 13, radius: 6),
          SizedBox(height: 6),
          SkBox(width: 60, height: 11, radius: 6),
        ]),
      ),
    );
  }
}

// Skeleton d'une gare (liste)
class SkeletonGareCard extends StatelessWidget {
  const SkeletonGareCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const SkBox(width: 44, height: 44, radius: 12),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            SkBox(width: 130, height: 14),
            SizedBox(height: 6),
            SkBox(width: 90, height: 11),
          ]),
          const Spacer(),
          const SkBox(width: 32, height: 32, radius: 8),
        ]),
      ),
    );
  }
}

// Skeleton d'un siège (grille)
class SkeletonSeat extends StatelessWidget {
  const SkeletonSeat({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

// Skeleton liste générique (n items)
class SkeletonList extends StatelessWidget {
  final int count;
  final Widget Function() itemBuilder;

  const SkeletonList({super.key, this.count = 6, required this.itemBuilder});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      itemBuilder: (_, __) => itemBuilder(),
    );
  }
}
