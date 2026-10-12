import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/location_sharing_service.dart';
import '../../core/widgets/shimmer_skeleton.dart';

class TrackLocationPage extends StatefulWidget {
  final String code;

  const TrackLocationPage({super.key, required this.code});

  @override
  State<TrackLocationPage> createState() => _TrackLocationPageState();
}

class _TrackLocationPageState extends State<TrackLocationPage> {
  GoogleMapController? _mapController;
  StreamSubscription<LocationData?>? _locationSub;

  LocationData? _sharerLocation;
  LatLng? _myPosition;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isNetworkError = false;
  String? _distanceText;
  bool _cameraFollowsSharer = true;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _startWatchingLocation();
    _startMyLocation();
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    _locationSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Timer? _errorTimer;

  void _startWatchingLocation() {
    // Si aucune donnée après 8s → code invalide ou pas de réseau
    _errorTimer = Timer(const Duration(seconds: 8), () async {
      if (!mounted || !_isLoading) return;
      final results = await Connectivity().checkConnectivity();
      final offline = results.every((r) => r == ConnectivityResult.none);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _isNetworkError = offline;
        });
      }
    });

    _locationSub = LocationSharingService.watchLocation(widget.code).listen(
      (data) {
        if (!mounted) return;
        if (data == null) {
          // Pas encore de ligne pour ce code — on attend le timer
          return;
        }
        _errorTimer?.cancel();
        final pos = LatLng(data.lat, data.lng);
        setState(() {
          _isLoading = false;
          _hasError = false;
          _sharerLocation = data;
          _markers.removeWhere((m) => m.markerId.value == 'sharer');
          _markers.add(Marker(
            markerId: const MarkerId('sharer'),
            position: pos,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
              title: 'Position partagée',
              snippet: data.active ? 'En direct' : 'Hors ligne',
            ),
          ));
          _updateDistanceAndPolyline();
        });

        if (_cameraFollowsSharer && _mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(pos));
        }
      },
      onError: (e) {
        if (!mounted) return;
        _errorTimer?.cancel();
        final isNetwork = e.toString().contains('SocketException') ||
            e.toString().contains('Failed host lookup') ||
            e.toString().contains('ClientException');
        setState(() {
          _isLoading = false;
          _hasError = true;
          _isNetworkError = isNetwork;
        });
      },
    );
  }

  Future<void> _startMyLocation() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((pos) {
      if (!mounted) return;
      final me = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _myPosition = me;
        _markers.removeWhere((m) => m.markerId.value == 'me');
        _markers.add(Marker(
          markerId: const MarkerId('me'),
          position: me,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Ma position'),
          zIndexInt: 2,
        ));
        _updateDistanceAndPolyline();
      });
    });
  }

  void _updateDistanceAndPolyline() {
    if (_myPosition == null || _sharerLocation == null) return;
    final sharerPos = LatLng(_sharerLocation!.lat, _sharerLocation!.lng);
    final distM = Geolocator.distanceBetween(
      _myPosition!.latitude, _myPosition!.longitude,
      sharerPos.latitude, sharerPos.longitude,
    );
    final distKm = distM / 1000;
    _distanceText = distKm >= 1
        ? '${distKm.toStringAsFixed(1)} km'
        : '${distM.round()} m';

    _polylines
      ..clear()
      ..add(Polyline(
        polylineId: const PolylineId('line'),
        points: [_myPosition!, sharerPos],
        color: const Color(0xFF1E88E5),
        width: 3,
        patterns: [PatternItem.dash(15), PatternItem.gap(8)],
      ));
  }

  void _fitBoth() {
    if (_mapController == null || _myPosition == null || _sharerLocation == null) return;
    final a = _myPosition!;
    final b = LatLng(_sharerLocation!.lat, _sharerLocation!.lng);
    final minLat = min(a.latitude, b.latitude);
    final maxLat = max(a.latitude, b.latitude);
    final minLng = min(a.longitude, b.longitude);
    final maxLng = max(a.longitude, b.longitude);
    final pad = max((maxLat - minLat) * 0.3, 0.01);
    final padLng = max((maxLng - minLng) * 0.3, 0.01);
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat - pad, minLng - padLng),
        northeast: LatLng(maxLat + pad, maxLng + padLng),
      ),
      60,
    ));
    setState(() => _cameraFollowsSharer = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        _buildHeader(),
        Expanded(child: _buildBody()),
      ]),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFC107),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.black87, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Suivi en direct',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                Text(
                  'Code : ${widget.code}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ]),
            ),
            if (_sharerLocation != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _sharerLocation!.active && _sharerLocation!.isRecent
                      ? Colors.green
                      : Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 6, height: 6,
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle))),
                  const SizedBox(width: 5),
                  Text(
                    _sharerLocation!.active && _sharerLocation!.isRecent
                        ? 'En direct'
                        : 'Hors ligne',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      // Skeleton de la carte en attendant la première position.
      return Stack(children: [
        Positioned.fill(
          child: AppShimmer(child: Container(color: Colors.white)),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Recherche de la position…',
                style: TextStyle(color: Colors.black54)),
          ),
        ),
      ]);
    }
    if (_hasError) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            _isNetworkError ? Icons.wifi_off_rounded : Icons.location_off_rounded,
            size: 56,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _isNetworkError
                ? 'Pas de connexion Internet.'
                : 'Code introuvable ou expiré.',
            style: const TextStyle(fontSize: 15, color: Colors.black54),
          ),
          if (_isNetworkError) ...[
            const SizedBox(height: 4),
            const Text(
              'Vérifiez votre Wi-Fi ou vos données mobiles.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black38),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _errorTimer?.cancel();
              _locationSub?.cancel();
              setState(() {
                _isLoading = true;
                _hasError = false;
                _isNetworkError = false;
              });
              _startWatchingLocation();
            },
            child: const Text('Réessayer'),
          ),
        ]),
      );
    }

    return GoogleMap(
      onMapCreated: (c) {
        _mapController = c;
        if (_sharerLocation != null) {
          c.animateCamera(CameraUpdate.newLatLngZoom(
            LatLng(_sharerLocation!.lat, _sharerLocation!.lng), 15));
        }
      },
      initialCameraPosition: CameraPosition(
        target: _sharerLocation != null
            ? LatLng(_sharerLocation!.lat, _sharerLocation!.lng)
            : const LatLng(0, 0),
        zoom: 15,
      ),
      markers: Set.from(_markers),
      polylines: Set.from(_polylines),
      myLocationEnabled: false,
      zoomControlsEnabled: false,
      onCameraMoveStarted: () => setState(() => _cameraFollowsSharer = false),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Distance banner
        if (_distanceText != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFFC107), Color(0xFFFF8F00)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              const Icon(Icons.social_distance_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Distance à vol d\'oiseau',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(_distanceText!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ]),
              ),
            ]),
          ),

        Row(children: [
          // Centrer sur le partageur
          Expanded(
            child: _bottomBtn(
              icon: Icons.person_pin_circle_rounded,
              label: 'Position partagée',
              color: const Color(0xFFFFC107),
              textColor: Colors.black87,
              onTap: () {
                if (_sharerLocation != null) {
                  setState(() => _cameraFollowsSharer = true);
                  _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
                    LatLng(_sharerLocation!.lat, _sharerLocation!.lng), 16));
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          // Voir les deux
          if (_myPosition != null) ...[
            _iconBtn(
              icon: Icons.fit_screen_rounded,
              active: false,
              onTap: _fitBoth,
            ),
            const SizedBox(width: 10),
          ],
          // Centrer sur moi
          Expanded(
            child: _bottomBtn(
              icon: Icons.my_location_rounded,
              label: 'Ma position',
              color: const Color(0xFF1E88E5),
              textColor: Colors.white,
              onTap: () {
                if (_myPosition != null) {
                  setState(() => _cameraFollowsSharer = false);
                  _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(_myPosition!, 16));
                }
              },
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _bottomBtn({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ]),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 58,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1E88E5) : Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Icon(icon,
            color: active ? Colors.white : Colors.grey[600], size: 22),
      ),
    );
  }
}
