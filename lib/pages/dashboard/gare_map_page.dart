import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../models/gare1_model.dart';

class GareMapPage extends StatefulWidget {
  final Gare? gare;
  final Gare? gareDepart;
  final Gare? gareArrive;
  final String title;

  const GareMapPage({
    Key? key,
    required this.gare,
    required this.title,
    this.gareDepart,
    this.gareArrive,
  }) : super(key: key);

  factory GareMapPage.itinerary({
    Key? key,
    required Gare gareDepart,
    required Gare gareArrive,
    required String title,
  }) {
    return GareMapPage(
      key: key,
      gare: null,
      gareDepart: gareDepart,
      gareArrive: gareArrive,
      title: title,
    );
  }

  @override
  State<GareMapPage> createState() => _GareMapPageState();
}

class _GareMapPageState extends State<GareMapPage>
    with SingleTickerProviderStateMixin {
  static const String _apiKey = 'AIzaSyB8AlNgBlhYxAfqoF5D9un8I8yRQJw1tnU';

  GoogleMapController? mapController;

  LatLng _gareLocation = const LatLng(0, 0);
  LatLng _gareDepartLocation = const LatLng(0, 0);
  LatLng _gareArriveLocation = const LatLng(0, 0);
  bool _isItineraryMode = false;

  Set<Polyline> _routePolylines = {};
  bool _isLoadingRoute = false;
  String? _routeError;
  String? _distance;
  String? _duration;

  // ── Suivi temps réel ─────────────────────────────────────────
  bool _isTracking = false;
  LatLng? _myPosition;
  String? _remainingDistance;
  StreamSubscription<Position>? _positionSub;
  Marker? _myMarker;
  LatLng? _lastRoutePosition;

  // ── Pré-itinéraire (rejoindre la gare de départ) ─────────────
  BitmapDescriptor? _personMarkerIcon;
  Set<Polyline> _preRoutePolylines = {};
  bool _isAtDeparture = true;
  bool _isLoadingPreRoute = false;
  static const double _atDepartureThresholdM = 300;

  late AnimationController _enterCtrl;
  late Animation<Offset> _slideHeader;
  late Animation<double> _fadeHeader;
  late Animation<double> _fadeBody;

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideHeader = Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _enterCtrl,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)));
    _fadeHeader = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _enterCtrl, curve: const Interval(0.0, 0.55, curve: Curves.easeOut)));
    _fadeBody = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _enterCtrl, curve: const Interval(0.25, 1.0, curve: Curves.easeOut)));
    _enterCtrl.forward();
    _loadPersonMarker();

    if (widget.gare != null) {
      _gareLocation = LatLng(
        double.tryParse(widget.gare!.latitude) ?? 0.0,
        double.tryParse(widget.gare!.longitude) ?? 0.0,
      );
    } else if (widget.gareDepart != null && widget.gareArrive != null) {
      _gareDepartLocation = LatLng(
        double.tryParse(widget.gareDepart!.latitude) ?? 0.0,
        double.tryParse(widget.gareDepart!.longitude) ?? 0.0,
      );
      _gareArriveLocation = LatLng(
        double.tryParse(widget.gareArrive!.latitude) ?? 0.0,
        double.tryParse(widget.gareArrive!.longitude) ?? 0.0,
      );
      _isItineraryMode = true;
      _gareLocation = _gareDepartLocation;
    }
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _positionSub?.cancel();
    mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadPersonMarker() async {
    const double s = 80;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Shadow
    canvas.drawCircle(
      const Offset(s / 2, s / 2 + 3),
      s / 2 - 5,
      Paint()
        ..color = Colors.black.withOpacity(0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Blue circle background
    canvas.drawCircle(
        const Offset(s / 2, s / 2), s / 2 - 5, Paint()..color = const Color(0xFF1565C0));
    // White border
    canvas.drawCircle(
      const Offset(s / 2, s / 2),
      s / 2 - 5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    // Head
    canvas.drawCircle(const Offset(s / 2, s / 2 - 13), 11, Paint()..color = Colors.white);
    // Body (half-circle shape)
    final body = Path()
      ..moveTo(12, s - 8)
      ..quadraticBezierTo(12, s / 2 + 6, s / 2, s / 2 + 6)
      ..quadraticBezierTo(s - 12, s / 2 + 6, s - 12, s - 8);
    canvas.drawPath(body, Paint()..color = Colors.white);

    final picture = recorder.endRecording();
    final img = await picture.toImage(s.toInt(), s.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (mounted && bytes != null) {
      setState(() {
        _personMarkerIcon = BitmapDescriptor.bytes(bytes.buffer.asUint8List());
      });
    }
  }

  // ── Fetch route depuis position utilisateur vers gare ────────
  Future<void> _fetchRouteFromMe(LatLng origin) async {
    if (_isLoadingRoute) return;
    setState(() { _isLoadingRoute = true; _routeError = null; });

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${origin.latitude},${origin.longitude}'
      '&destination=${_gareLocation.latitude},${_gareLocation.longitude}'
      '&mode=driving&language=fr&alternatives=false&key=$_apiKey',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          final route = (data['routes'] as List)[0] as Map<String, dynamic>;
          final leg = ((route['legs'] as List)[0]) as Map<String, dynamic>;
          final distText = (leg['distance'] as Map)['text'] as String;
          final durText  = (leg['duration'] as Map)['text'] as String;
          final List<LatLng> allPoints = [];
          for (final step in leg['steps'] as List) {
            final encoded = ((step as Map)['polyline'] as Map)['points'] as String;
            allPoints.addAll(_decodePolyline(encoded));
          }
          setState(() {
            _distance = distText;
            _duration = durText;
            _remainingDistance = '$distText · $durText';
            _routePolylines = {
              Polyline(polylineId: const PolylineId('route_border'), points: allPoints,
                  color: const Color(0xFF0D47A1), width: 11,
                  startCap: Cap.roundCap, endCap: Cap.roundCap, jointType: JointType.round, zIndex: 1),
              Polyline(polylineId: const PolylineId('route_main'), points: allPoints,
                  color: const Color(0xFF2196F3), width: 7,
                  startCap: Cap.roundCap, endCap: Cap.roundCap, jointType: JointType.round, zIndex: 2),
              Polyline(polylineId: const PolylineId('route_shine'), points: allPoints,
                  color: Colors.white.withOpacity(0.35), width: 2,
                  startCap: Cap.roundCap, endCap: Cap.roundCap, jointType: JointType.round, zIndex: 3),
            };
          });
          // Fit bounds seulement au premier fetch
          if (_lastRoutePosition == null) {
            _fitBoundsForRoute(allPoints);
          }
        } else {
          setState(() => _routeError = 'Itinéraire indisponible');
        }
      }
    } on Exception catch (e) {
      debugPrint('_fetchRouteFromMe error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  // ── Route vers la gare de départ (pré-itinéraire) ────────────
  Future<void> _fetchRouteToDepart(LatLng me) async {
    if (_isLoadingPreRoute) return;
    setState(() => _isLoadingPreRoute = true);
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${me.latitude},${me.longitude}'
      '&destination=${_gareDepartLocation.latitude},${_gareDepartLocation.longitude}'
      '&mode=driving&language=fr&alternatives=false&key=$_apiKey',
    );
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          final leg = (((data['routes'] as List)[0] as Map)['legs'] as List)[0] as Map<String, dynamic>;
          final List<LatLng> pts = [];
          for (final step in leg['steps'] as List) {
            pts.addAll(_decodePolyline(((step as Map)['polyline'] as Map)['points'] as String));
          }
          if (mounted) {
            setState(() {
              _preRoutePolylines = {
                Polyline(
                    polylineId: const PolylineId('pre_border'), points: pts,
                    color: const Color(0xFFE65100), width: 11,
                    startCap: Cap.roundCap, endCap: Cap.roundCap, jointType: JointType.round, zIndex: 1),
                Polyline(
                    polylineId: const PolylineId('pre_main'), points: pts,
                    color: const Color(0xFFFF6D00), width: 7,
                    startCap: Cap.roundCap, endCap: Cap.roundCap, jointType: JointType.round, zIndex: 2),
              };
            });
          }
        }
      }
    } on Exception catch (e) {
      debugPrint('_fetchRouteToDepart error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPreRoute = false);
    }
  }

  // ── Suivi temps réel ─────────────────────────────────────────
  Future<void> _toggleTracking() async {
    if (_isTracking) {
      _positionSub?.cancel();
      setState(() {
        _isTracking = false;
        _myMarker = null;
        _remainingDistance = null;
        _lastRoutePosition = null;
        _preRoutePolylines = {};
        _isAtDeparture = true;
        if (!_isItineraryMode) _routePolylines = {};
      });
      return;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission de localisation refusée.')),
        );
      }
      return;
    }

    setState(() => _isTracking = true);

    const settings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        if (!mounted) return;
        final me = LatLng(pos.latitude, pos.longitude);
        final dest = _isItineraryMode ? _gareArriveLocation : _gareLocation;

        // Distance restante vers la destination finale (en ligne droite)
        final distM = Geolocator.distanceBetween(me.latitude, me.longitude, dest.latitude, dest.longitude);
        final distKm = distM / 1000;
        final distStr = distKm >= 1 ? '${distKm.toStringAsFixed(1)} km' : '${distM.round()} m';

        // Distance vers la gare de départ (mode itinéraire)
        final distToDepart = _isItineraryMode
            ? Geolocator.distanceBetween(me.latitude, me.longitude,
                _gareDepartLocation.latitude, _gareDepartLocation.longitude)
            : double.infinity;
        final nowAtDeparture = !_isItineraryMode || distToDepart <= _atDepartureThresholdM;
        final wasAtDeparture = _isAtDeparture;

        String? newRemainingDistance;
        if (_isItineraryMode) {
          if (nowAtDeparture) {
            newRemainingDistance = distStr;
          } else {
            final dtdKm = distToDepart / 1000;
            newRemainingDistance = dtdKm >= 1
                ? '${dtdKm.toStringAsFixed(1)} km de la gare de départ'
                : '${distToDepart.round()} m de la gare de départ';
          }
        }

        setState(() {
          _myPosition = me;
          _isAtDeparture = nowAtDeparture;
          if (_isItineraryMode) _remainingDistance = newRemainingDistance;
          _myMarker = Marker(
            markerId: const MarkerId('my_position'),
            position: me,
            infoWindow: const InfoWindow(title: 'Ma position'),
            icon: _personMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            zIndex: 10,
          );
        });

        // Centrer la caméra sur ma position
        mapController?.animateCamera(CameraUpdate.newLatLng(me));

        if (_isItineraryMode) {
          if (!nowAtDeparture) {
            // Pré-itinéraire : afficher la route pour rejoindre la gare de départ
            final needsFetch = _lastRoutePosition == null ||
                Geolocator.distanceBetween(_lastRoutePosition!.latitude, _lastRoutePosition!.longitude,
                    me.latitude, me.longitude) > 30;
            if (needsFetch) {
              _lastRoutePosition = me;
              _fetchRouteToDepart(me);
            }
          } else if (!wasAtDeparture && nowAtDeparture) {
            // Vient d'arriver à la gare de départ — effacer le pré-itinéraire
            setState(() => _preRoutePolylines = {});
            if (_routePolylines.isEmpty) _fetchRoute();
          }
        } else {
          // Mode gare seule : fetch/recalcul de la route vers la gare
          final needsFetch = _lastRoutePosition == null ||
              Geolocator.distanceBetween(
                _lastRoutePosition!.latitude, _lastRoutePosition!.longitude,
                me.latitude, me.longitude,
              ) > 20;
          if (needsFetch) {
            _lastRoutePosition = me;
            _fetchRouteFromMe(me);
          }
        }
      },
      onError: (e) {
        if (mounted) setState(() { _isTracking = false; _myMarker = null; });
      },
    );
  }

  void _centerOnMe() {
    if (_myPosition != null) {
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_myPosition!, 16),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_isItineraryMode) {
      _fitBoundsForItinerary();
      _fetchRoute();
    } else {
      mapController?.animateCamera(CameraUpdate.newLatLngZoom(_gareLocation, 15.0));
    }
  }

  void _fitBoundsForItinerary() {
    if (!_isItineraryMode || mapController == null) return;
    final minLat = min(_gareDepartLocation.latitude, _gareArriveLocation.latitude);
    final maxLat = max(_gareDepartLocation.latitude, _gareArriveLocation.latitude);
    final minLng = min(_gareDepartLocation.longitude, _gareArriveLocation.longitude);
    final maxLng = max(_gareDepartLocation.longitude, _gareArriveLocation.longitude);
    final latPad = max((maxLat - minLat) * 0.20, 0.015);
    final lngPad = max((maxLng - minLng) * 0.20, 0.015);
    mapController!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat - latPad, minLng - lngPad),
        northeast: LatLng(maxLat + latPad, maxLng + lngPad),
      ),
      60.0,
    ));
  }

  Future<void> _fetchRoute() async {
    if (!_isItineraryMode) return;
    setState(() { _isLoadingRoute = true; _routeError = null; });

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${_gareDepartLocation.latitude},${_gareDepartLocation.longitude}'
      '&destination=${_gareArriveLocation.latitude},${_gareArriveLocation.longitude}'
      '&mode=driving&language=fr&alternatives=false&key=$_apiKey',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          final route = (data['routes'] as List)[0] as Map<String, dynamic>;
          final leg = ((route['legs'] as List)[0]) as Map<String, dynamic>;
          setState(() {
            _distance = (leg['distance'] as Map)['text'] as String;
            _duration = (leg['duration'] as Map)['text'] as String;
          });
          final List<LatLng> allPoints = [];
          for (final step in leg['steps'] as List) {
            final encoded = ((step as Map)['polyline'] as Map)['points'] as String;
            allPoints.addAll(_decodePolyline(encoded));
          }
          setState(() {
            _routePolylines = {
              Polyline(polylineId: const PolylineId('route_border'), points: allPoints,
                  color: const Color(0xFF0D47A1), width: 11,
                  startCap: Cap.roundCap, endCap: Cap.roundCap, jointType: JointType.round, zIndex: 1),
              Polyline(polylineId: const PolylineId('route_main'), points: allPoints,
                  color: const Color(0xFF2196F3), width: 7,
                  startCap: Cap.roundCap, endCap: Cap.roundCap, jointType: JointType.round, zIndex: 2),
              Polyline(polylineId: const PolylineId('route_shine'), points: allPoints,
                  color: Colors.white.withOpacity(0.35), width: 2,
                  startCap: Cap.roundCap, endCap: Cap.roundCap, jointType: JointType.round, zIndex: 3),
            };
          });
          _fitBoundsForRoute(allPoints);
        } else {
          setState(() => _routeError = 'Itinéraire indisponible (${data['status']})');
          _fallbackLine();
        }
      } else {
        setState(() => _routeError = 'Erreur réseau (${response.statusCode})');
        _fallbackLine();
      }
    } on Exception catch (e) {
      debugPrint('_fetchRoute error: $e');
      setState(() => _routeError = 'Erreur de connexion');
      _fallbackLine();
    } finally {
      setState(() => _isLoadingRoute = false);
    }
  }

  void _fitBoundsForRoute(List<LatLng> points) {
    if (points.isEmpty || mapController == null) return;
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final latPad = max((maxLat - minLat) * 0.12, 0.01);
    final lngPad = max((maxLng - minLng) * 0.12, 0.01);
    mapController!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat - latPad, minLng - lngPad),
        northeast: LatLng(maxLat + latPad, maxLng + lngPad),
      ),
      50.0,
    ));
  }

  void _fallbackLine() {
    setState(() {
      _routePolylines = {
        Polyline(
          polylineId: const PolylineId('route_fallback'),
          points: [_gareDepartLocation, _gareArriveLocation],
          color: Colors.blueGrey,
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      };
    });
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0; final int len = encoded.length; int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do { b = encoded.codeUnitAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      shift = 0; result = 0;
      do { b = encoded.codeUnitAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  Future<void> _launchNavigation({required String app}) async {
    final destLat  = _isItineraryMode ? _gareArriveLocation.latitude  : _gareLocation.latitude;
    final destLng  = _isItineraryMode ? _gareArriveLocation.longitude : _gareLocation.longitude;
    final destName = Uri.encodeComponent(
        _isItineraryMode ? (widget.gareArrive?.nomGare ?? '') : (widget.gare?.nomGare ?? ''));
    Uri url;
    switch (app) {
      case 'google_app': url = Uri.parse('google.navigation:q=$destLat,$destLng&mode=d'); break;
      case 'google_ios': url = Uri.parse('comgooglemaps://?daddr=$destLat,$destLng&directionsmode=driving'); break;
      case 'apple':      url = Uri.parse('maps://?daddr=$destLat,$destLng&dirflg=d'); break;
      default: url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng'
        '&destination_place_id=$destName&travelmode=driving&dir_action=navigate');
    }
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (app != 'web') {
      await _launchNavigation(app: 'web');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir l\'application de navigation.')));
    }
  }

  Future<void> _showNavigationChoice() async {
    if (Platform.isIOS) {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
                const Text('Naviguer vers', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  _isItineraryMode ? (widget.gareArrive?.nomGare ?? '') : (widget.gare?.nomGare ?? ''),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]), textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _navChoiceTile(
                  iconWidget: const Icon(Icons.map_rounded, color: Color(0xFF4285F4), size: 30),
                  label: 'Google Maps', subtitle: 'Depuis ma position actuelle',
                  onTap: () { Navigator.pop(context); _launchNavigation(app: 'google_ios'); },
                ),
                const SizedBox(height: 10),
                _navChoiceTile(
                  iconWidget: const Icon(Icons.map_outlined, color: Color(0xFF34C759), size: 30),
                  label: 'Plans (Apple Maps)', subtitle: 'Depuis ma position actuelle',
                  onTap: () { Navigator.pop(context); _launchNavigation(app: 'apple'); },
                ),
              ]),
            ),
          ),
        ),
      );
    } else {
      await _launchNavigation(app: 'google_app');
    }
  }

  Widget _navChoiceTile({required Widget iconWidget, required String label,
      required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: Colors.grey[50],
            border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          iconWidget, const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.grey[400]),
        ]),
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        // ── Header jaune ──────────────────────────────────
        SlideTransition(
          position: _slideHeader,
          child: FadeTransition(
            opacity: _fadeHeader,
            child: Container(
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
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(widget.title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (_isItineraryMode)
                      GestureDetector(
                        onTap: _isLoadingRoute ? null : _fetchRoute,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            _isLoadingRoute
                                ? const SizedBox(width: 14, height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(Colors.black54)))
                                : const Icon(Icons.refresh_rounded, size: 14, color: Colors.black87),
                            const SizedBox(width: 5),
                            const Text('Recalculer',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                          ]),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        ),

        // ── Carte ─────────────────────────────────────────
        Expanded(
          child: FadeTransition(
            opacity: _fadeBody,
            child: _buildMapStack(),
          ),
        ),
      ]),

      // ── Boutons bas ───────────────────────────────────────
      bottomNavigationBar: FadeTransition(
        opacity: _fadeBody,
        child: _buildBottomButtons(),
      ),
    );
  }

  // ── Boutons bas améliorés ────────────────────────────────────
  Widget _buildBottomButtons() {
    return Container(
      padding: EdgeInsets.only(
          left: 16, right: 16, top: 14,
          bottom: MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: _isItineraryMode ? _itineraryButtons() : _singleGareButtons(),
    );
  }

  Widget _itineraryButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Barre d'info distance restante (suivi actif)
        if (_isTracking && _remainingDistance != null)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isAtDeparture
                    ? [const Color(0xFF1E88E5), const Color(0xFF0D47A1)]
                    : [const Color(0xFFFF6D00), const Color(0xFFE65100)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Icon(
                _isAtDeparture ? Icons.my_location_rounded : Icons.directions_walk_rounded,
                color: Colors.white, size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    _isAtDeparture ? 'Suivi en cours' : 'Rejoignez la gare de départ',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    _isAtDeparture
                        ? 'Distance restante : $_remainingDistance'
                        : _remainingDistance!,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ]),
              ),
              GestureDetector(
                onTap: _centerOnMe,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 16),
                ),
              ),
            ]),
          ),

        // 3 boutons
        Row(children: [
          // Bouton Départ
          Expanded(
            child: _mapButton(
              icon: Icons.departure_board_rounded,
              label: 'Départ',
              sublabel: widget.gareDepart?.nomGare ?? '',
              color: const Color(0xFFFFC107),
              textColor: Colors.black87,
              onTap: () => mapController?.animateCamera(
                CameraUpdate.newCameraPosition(CameraPosition(target: _gareDepartLocation, zoom: 16.0)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Bouton Suivi temps réel
          _trackButton(),
          const SizedBox(width: 10),
          // Bouton Naviguer
          Expanded(
            child: _mapButton(
              icon: Icons.navigation_rounded,
              label: 'Naviguer',
              sublabel: widget.gareArrive?.nomGare ?? '',
              color: const Color(0xFF1E88E5),
              textColor: Colors.white,
              onTap: _showNavigationChoice,
            ),
          ),
        ]),
      ],
    );
  }

  Widget _singleGareButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bannière de suivi en cours
        if (_isTracking && _remainingDistance != null)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              const Icon(Icons.my_location_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Navigation en cours', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(
                    _isLoadingRoute ? 'Calcul de l\'itinéraire…' : _remainingDistance!,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ]),
              ),
              GestureDetector(
                onTap: _centerOnMe,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 16),
                ),
              ),
            ]),
          ),

        Row(children: [
          // Bouton centrer sur la gare
          Expanded(
            child: _mapButton(
              icon: Icons.location_on_rounded,
              label: 'Voir la gare',
              sublabel: widget.gare?.nomGare ?? '',
              color: const Color(0xFFFFC107),
              textColor: Colors.black87,
              onTap: () => mapController?.animateCamera(
                CameraUpdate.newCameraPosition(CameraPosition(target: _gareLocation, zoom: 18.0)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _trackButton(),
          const SizedBox(width: 10),
          Expanded(
            child: _mapButton(
              icon: Icons.navigation_rounded,
              label: 'Naviguer',
              sublabel: 'Depuis ma position',
              color: const Color(0xFF1E88E5),
              textColor: Colors.white,
              onTap: _showNavigationChoice,
            ),
          ),
        ]),
      ],
    );
  }

  // Bouton carré de suivi
  Widget _trackButton() {
    return GestureDetector(
      onTap: _toggleTracking,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 56, height: 66,
        decoration: BoxDecoration(
          color: _isTracking ? const Color(0xFF43A047) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isTracking ? const Color(0xFF2E7D32) : Colors.grey[300]!,
            width: 1.5,
          ),
          boxShadow: _isTracking
              ? [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, spreadRadius: 1)]
              : [],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            _isTracking ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
            color: _isTracking ? Colors.white : Colors.grey[600],
            size: 22,
          ),
          const SizedBox(height: 4),
          Text(
            _isTracking ? 'Live' : 'Suivi',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _isTracking ? Colors.white : Colors.grey[600],
            ),
          ),
        ]),
      ),
    );
  }

  // Bouton générique
  Widget _mapButton({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(sublabel,
                  style: TextStyle(color: textColor.withOpacity(0.75), fontSize: 10),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Carte + stack ────────────────────────────────────────────
  Widget _buildMapStack() {
    try {
      final allMarkers = <Marker>{
        ..._isItineraryMode
            ? {
                Marker(
                  markerId: MarkerId('gare_depart_${widget.gareDepart!.id}'),
                  position: _gareDepartLocation,
                  infoWindow: InfoWindow(
                    title: '🟢 ${widget.gareDepart!.nomGare}',
                    snippet: widget.gareDepart!.ville?.nomVille ?? '',
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  zIndex: 5,
                ),
                Marker(
                  markerId: MarkerId('gare_arrive_${widget.gareArrive!.id}'),
                  position: _gareArriveLocation,
                  infoWindow: InfoWindow(
                    title: '🔴 ${widget.gareArrive!.nomGare}',
                    snippet: widget.gareArrive!.ville?.nomVille ?? '',
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  zIndex: 5,
                ),
              }
            : {
                Marker(
                  markerId: MarkerId('gare_${widget.gare!.id}'),
                  position: _gareLocation,
                  infoWindow: InfoWindow(
                    title: widget.gare!.nomGare,
                    snippet: widget.gare!.ville?.nomVille ?? '',
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
                ),
              },
        if (_myMarker != null) _myMarker!,
      };

      return Stack(children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(target: _gareLocation, zoom: 14.0),
          markers: allMarkers,
          polylines: {..._routePolylines, ..._preRoutePolylines},
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: true,
          trafficEnabled: true,
        ),

        // Loader
        if (_isLoadingRoute)
          Container(
            color: Colors.black.withOpacity(0.25),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20)],
                ),
                child: const Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFC107))),
                  SizedBox(height: 14),
                  Text('Calcul de l\'itinéraire…', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ]),
              ),
            ),
          ),

        // Bandeau info (mode itinéraire)
        if (_isItineraryMode)
          Positioned(top: 12, left: 12, right: 12, child: _buildInfoBanner()),

        // Erreur
        if (_routeError != null)
          Positioned(
            top: _isItineraryMode ? 116 : 12,
            left: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_routeError!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
              ]),
            ),
          ),

        // Zoom controls
        Positioned(
          right: 12, bottom: 16,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _smallFab(tag: 'zoom_in', icon: Icons.add,
                onPressed: () => mapController?.animateCamera(CameraUpdate.zoomIn())),
            const SizedBox(height: 8),
            _smallFab(tag: 'zoom_out', icon: Icons.remove,
                onPressed: () => mapController?.animateCamera(CameraUpdate.zoomOut())),
            if (_isItineraryMode) ...[
              const SizedBox(height: 8),
              _smallFab(tag: 'fit_bounds', icon: Icons.zoom_out_map_rounded,
                  onPressed: _fitBoundsForItinerary),
            ],
          ]),
        ),
      ]);
    } catch (e) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.map_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('Carte indisponible', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Vérifiez que Google Play Services est disponible',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
        ]),
      );
    }
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            _routeLabel(color: const Color(0xFF2E7D32), icon: Icons.circle, text: widget.gareDepart!.nomGare),
            const SizedBox(height: 5),
            _routeLabel(color: Colors.red, icon: Icons.location_on_rounded, text: widget.gareArrive!.nomGare),
          ])),
          if (_distance != null && _duration != null) ...[
            Container(width: 1, height: 40, color: Colors.grey[200], margin: const EdgeInsets.symmetric(horizontal: 14)),
            Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.straighten_rounded, color: Color(0xFF1E88E5), size: 16),
              const SizedBox(height: 2),
              Text(_distance!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(width: 14),
            Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.access_time_rounded, color: Color(0xFFF57C00), size: 16),
              const SizedBox(height: 2),
              Text(_duration!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
          ] else if (_isLoadingRoute)
            const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFC107))),
        ]),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
        ),

        Row(children: [
          _legendDot(color: const Color(0xFF2E7D32), label: widget.gareDepart!.ville?.nomVille ?? 'Départ'),
          const SizedBox(width: 4),
          Expanded(
            child: LayoutBuilder(builder: (_, c) {
              final count = (c.maxWidth / 8).floor();
              return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(count, (_) => Container(width: 4, height: 1.5, color: Colors.grey[300])));
            }),
          ),
          const SizedBox(width: 4),
          _legendDot(color: Colors.red, label: widget.gareArrive!.ville?.nomVille ?? 'Arrivée', alignRight: true),
        ]),
      ]),
    );
  }

  Widget _routeLabel({required Color color, required IconData icon, required String text}) {
    return Row(children: [
      Icon(icon, color: color, size: 11), const SizedBox(width: 6),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _legendDot({required Color color, required String label, bool alignRight = false}) {
    final dot = Icon(Icons.circle, color: color, size: 9);
    final txt = Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700]));
    return Row(mainAxisSize: MainAxisSize.min,
        children: alignRight ? [txt, const SizedBox(width: 5), dot] : [dot, const SizedBox(width: 5), txt]);
  }

  Widget _smallFab({required String tag, required IconData icon, required VoidCallback onPressed}) {
    return Material(
      color: Colors.white, borderRadius: BorderRadius.circular(12), elevation: 3,
      child: InkWell(onTap: onPressed, borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 38, height: 38, child: Icon(icon, size: 18, color: Colors.black87))),
    );
  }
}
