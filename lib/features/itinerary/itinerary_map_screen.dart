import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/trip.dart';
import '../../core/models/trip_stop.dart';
import '../../core/services/directions_service.dart';
import 'widgets/map_view.dart';
import 'widgets/overlay_icon_button.dart';
import 'widgets/stop_card.dart';

/// Full-screen map view for a trip, opened on demand from the itinerary
/// screen. Kept on its own route so the GoogleMap platform view is only
/// mounted while the user has explicitly asked to see the map — it is no
/// longer mounted automatically alongside the itinerary list.
class ItineraryMapScreen extends StatefulWidget {
  final Trip trip;
  final int initialStopIndex;

  const ItineraryMapScreen({
    super.key,
    required this.trip,
    this.initialStopIndex = 0,
  });

  @override
  State<ItineraryMapScreen> createState() => _ItineraryMapScreenState();
}

class _ItineraryMapScreenState extends State<ItineraryMapScreen> {
  final _directionsService = DirectionsService();
  final _mapCompleter = Completer<GoogleMapController>();
  final _scrollCtrl = ScrollController();

  late int _selectedStop;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  bool _markersReady = false;
  bool _loadingRoute = true;

  static final Map<int, BitmapDescriptor> _markerIconCache = {};

  @override
  void initState() {
    super.initState();
    _selectedStop = widget.initialStopIndex;
    _loadRoute();
    _loadMarkers();
  }

  // ─── Route loading ──────────────────────────────────────────────────────

  Future<void> _loadRoute() async {
    final coords = widget.trip.stops
        .where((s) => s.latLng != null)
        .map((s) => s.latLng!)
        .toList();
    if (coords.length >= 2) {
      try {
        final points = await _directionsService.getRoutePoints(coords);
        final simplified = _simplifyRoute(points);
        if (mounted) {
          setState(() => _polylines = _buildPolylines(simplified));
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[ItineraryMap] route load failed: $e');
      }
    }
    if (mounted) setState(() => _loadingRoute = false);
  }

  /// Down-samples [points] to at most [maxPoints], always keeping the first
  /// and last point so the route still spans the full trip. Lower than the
  /// original 100 — fewer polyline vertices noticeably reduces map redraw
  /// lag on longer routes.
  List<LatLng> _simplifyRoute(List<LatLng> points, {int maxPoints = 50}) {
    if (points.length <= maxPoints) return points;
    final step = (points.length / maxPoints).ceil();
    final simplified = <LatLng>[
      for (int i = 0; i < points.length; i += step) points[i],
    ];
    if (simplified.last != points.last) simplified.add(points.last);
    return simplified;
  }

  Set<Polyline> _buildPolylines(List<LatLng> points) {
    if (points.isEmpty) return {};
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: isDark ? AppColors.surface : AppColors.primary,
        width: 3,
        // Solid line: dash patterns make the SDK render many short
        // segments instead of one continuous line, which is noticeably
        // more expensive to redraw on camera moves.
      ),
    };
  }

  // ─── Numbered map markers ────────────────────────────────────────────────

  Future<BitmapDescriptor> _numberedMarkerIcon(int number) async {
    final cached = _markerIconCache[number];
    if (cached != null) return cached;
    final icon = await _createNumberedMarker(number);
    _markerIconCache[number] = icon;
    return icon;
  }

  void _loadMarkers() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final stops = widget.trip.stops;
      final icons = await Future.wait([
        for (int i = 0; i < stops.length; i++) _numberedMarkerIcon(i + 1),
      ]);
      final markers = <Marker>{};
      for (int i = 0; i < stops.length; i++) {
        final stop = stops[i];
        if (stop.latLng == null) continue;
        markers.add(
          Marker(
            markerId: MarkerId('stop_${stop.stopNumber}'),
            position: stop.latLng!,
            icon: icons[i],
            infoWindow: InfoWindow(
              title: stop.name,
              snippet: '${stop.time} · ${stop.durationMinutes}min',
            ),
            onTap: () => _zoomToStop(i),
          ),
        );
      }
      if (mounted) {
        setState(() {
          _markers = markers;
          _markersReady = true;
        });
        if (widget.initialStopIndex != 0) {
          _zoomToStop(widget.initialStopIndex);
        }
      }
    });
  }

  /// Draws a small filled circle with the stop number — pure [Canvas] ops.
  /// 48px (down from the original 84px): a smaller bitmap is cheaper for
  /// the map SDK to upload/composite per marker, and visually a numbered
  /// dot doesn't need to be much bigger than Google's default pin.
  Future<BitmapDescriptor> _createNumberedMarker(int number) async {
    const double size = 48;
    const center = Offset(size / 2, size / 2);
    const radius = size / 2 - 3;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawCircle(center, radius, Paint()..color = AppColors.primary);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  // ─── Camera + external navigation ───────────────────────────────────────

  Future<void> _zoomToStop(int index) async {
    setState(() => _selectedStop = index);

    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        index * 272.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }

    final stop = widget.trip.stops[index];
    if (stop.latLng == null) return;
    final ctrl = await _mapCompleter.future;
    if (!mounted) return;
    await ctrl.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: stop.latLng!, zoom: 16.0),
      ),
    );
  }

  Future<void> _openInGoogleMaps() async {
    final validStops =
        widget.trip.stops.where((s) => s.latLng != null).toList();
    if (validStops.isEmpty) return;

    // Prefer the place's formatted address: Maps shows it as a real label
    // instead of "Dropped pin", and since it's the address Places resolved
    // for this exact stop, it geocodes back to the same spot. Fall back to
    // coordinates, then the bare name. (place_id: prefixes are not honored
    // by this Maps URL flow — tested and confirmed to show "Cannot seem to
    // find that place".)
    String location(TripStop s) =>
        s.address ??
        (s.latLng != null
            ? '${s.latLng!.latitude},${s.latLng!.longitude}'
            : s.name);

    final origin = location(validStops.first);
    final destination = location(validStops.last);

    final waypointList = validStops.length > 2
        ? validStops.sublist(1, validStops.length - 1).map(location).join('|')
        : '';

    final buffer = StringBuffer('https://www.google.com/maps/dir/?api=1'
        '&origin=${Uri.encodeComponent(origin)}'
        '&destination=${Uri.encodeComponent(destination)}');
    if (waypointList.isNotEmpty) {
      buffer.write('&waypoints=${Uri.encodeComponent(waypointList)}');
    }
    buffer.write('&travelmode=driving');

    final uri = Uri.parse(buffer.toString());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Google Maps'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    const stripHeight = 190.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: MapView(
                  stops: widget.trip.stops,
                  polylines: _polylines,
                  selectedIndex: _selectedStop,
                  externalMarkers: _markersReady ? _markers : null,
                  padding: EdgeInsets.only(bottom: stripHeight + bottomPad),
                  onMapReady: (ctrl) {
                    if (!_mapCompleter.isCompleted) {
                      _mapCompleter.complete(ctrl);
                    }
                  },
                  onMarkerTap: _zoomToStop,
                ),
              ),
            ),

            // ── Back button ──────────────────────────────────────────
            Positioned(
              top: topPad + 8,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const OverlayIconButton(
                  child: Icon(Icons.arrow_back, color: AppColors.ink),
                ),
              ),
            ),

            // ── Open route button ────────────────────────────────────
            Positioned(
              top: topPad + 8,
              right: 16,
              child: GestureDetector(
                onTap: _openInGoogleMaps,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    boxShadow: [
                      BoxShadow(color: AppColors.cardShadow, blurRadius: 8),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.navigation_rounded,
                          color: AppColors.ink, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        "Open Route",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.ink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Route-loading pill ───────────────────────────────────
            if (_loadingRoute)
              Positioned(
                top: topPad + kToolbarHeight,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(color: AppColors.cardShadow, blurRadius: 8),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Drawing your route...',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.ink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 200.ms),
              ),

            // ── Bottom stop strip ────────────────────────────────────
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: stripHeight + bottomPad + 100,
                child: ListView.builder(
                  controller: _scrollCtrl,
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad + 12),
                  itemCount: widget.trip.stops.length,
                  itemBuilder: (_, i) => SizedBox(
                    height: stripHeight - 12,
                    child: StopCard(
                      stop: widget.trip.stops[i],
                      isSelected: i == _selectedStop,
                      onTap: () => _zoomToStop(i),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
