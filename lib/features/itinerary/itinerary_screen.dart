import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/services/directions_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/error_handler.dart';
import '../../shared/widgets/error_snackbar.dart';
import '../../shared/widgets/loading_overlay.dart';
import 'widgets/map_view.dart';
import 'widgets/stop_card.dart';

/// TEMPORARY memory-bisect switch (2026-06-11) — DELETE AFTER DIAGNOSIS.
/// true = replace the GoogleMap with a plain box for one test run. If the
/// "Terminated due to memory issue" jetsam kill stops while this is on, the
/// leak is in the map/platform-view path (Flutter engine ↔ Xcode 26.2 SDK ↔
/// GoogleMaps pod), not in app code.
const bool kBisectDisableMap = true;

class ItineraryScreen extends StatefulWidget {
  final Trip trip;
  final bool readOnly;

  const ItineraryScreen({
    super.key,
    required this.trip,
    this.readOnly = false,
  });

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  final _service = SupabaseService();
  final _directionsService = DirectionsService();
  final _scrollCtrl = ScrollController();

  // Map camera controller — completed once GoogleMap fires onMapCreated.
  final _mapCompleter = Completer<GoogleMapController>();

  int _selectedStop = 0;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  bool _markersReady = false;
  bool _saving = false;
  bool _loadingRoute = true;
  // Fix 2: the GoogleMap platform view is created one frame after the first
  // paint so the initial layout (panel, list, app bar) shows up instantly
  // instead of waiting on native map/tile setup.
  bool _mapReady = false;
  late Trip _trip;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _loadRoute();
    _loadMarkers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _mapReady = true);
    });
  }

  // ─── Route loading ──────────────────────────────────────────────────────────

  Future<void> _loadRoute() async {
    final coords = _trip.stops
        .where((s) => s.latLng != null)
        .map((s) => s.latLng!)
        .toList();
    if (kDebugMode) {
      debugPrint('[Itinerary] ${_trip.stops.length} stops, '
          '${coords.length} with coordinates');
      for (final c in coords) {
        debugPrint('[Itinerary] stop @ lat=${c.latitude}, lng=${c.longitude}');
      }
    }
    if (coords.length >= 2) {
      try {
        final points = await _directionsService.getRoutePoints(coords);
        if (kDebugMode) {
          debugPrint('[Itinerary] route resolved: ${points.length} points'
              '${points.isNotEmpty ? ', first=${points.first}' : ''}');
        }
        // Fix 3: cap the polyline at ~100 points. Long driving routes can
        // return several hundred points from the Directions API; rendering
        // (and re-diffing) that many points on every map update is wasted
        // work since the visual difference beyond ~100 pts is negligible.
        final simplified = _simplifyRoute(points);
        if (mounted) {
          setState(() => _polylines = _buildPolylines(simplified));
        }
      } catch (e) {
        // Route is decorative — the map still works without it — but the
        // failure must not be invisible during development.
        if (kDebugMode) debugPrint('[Itinerary] route load failed: $e');
      }
    } else if (kDebugMode) {
      debugPrint('[Itinerary] skipping route: fewer than 2 stops have '
          'coordinates (Places enrichment may have failed)');
    }
    if (mounted) setState(() => _loadingRoute = false);
  }

  /// Down-samples [points] to at most [maxPoints], always keeping the first
  /// and last point so the route still spans the full trip.
  List<LatLng> _simplifyRoute(List<LatLng> points, {int maxPoints = 100}) {
    if (points.length <= maxPoints) return points;
    final step = (points.length / maxPoints).ceil();
    final simplified = <LatLng>[
      for (int i = 0; i < points.length; i += step) points[i],
    ];
    if (simplified.last != points.last) simplified.add(points.last);
    return simplified;
  }

  /// Built once when the route loads — passed down as a ready-made [Set] so
  /// MapView never has to recompute/recreate the polyline on every rebuild.
  Set<Polyline> _buildPolylines(List<LatLng> points) {
    if (points.isEmpty) return {};
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: isDark ? AppColors.surface : AppColors.primary,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(8)],
      ),
    };
  }

  // ─── Fix 1: lightweight numbered map markers ────────────────────────────────

  /// Numbered marker bitmaps depend only on the stop number, so they are
  /// cached for the whole app session — reopening any itinerary skips the
  /// canvas → PNG work entirely.
  static final Map<int, BitmapDescriptor> _markerIconCache = {};

  Future<BitmapDescriptor> _numberedMarkerIcon(int number) async {
    final cached = _markerIconCache[number];
    if (cached != null) return cached;
    final icon = await _createNumberedMarker(number);
    _markerIconCache[number] = icon;
    return icon;
  }

  void _loadMarkers() {
    // Fix 2/4: defer marker construction until after the first frame so the
    // N canvas->image conversions below don't compete with the initial
    // layout/paint, and don't run inside the same setState pass that shows
    // the map.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final stops = _trip.stops;
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
      }
    });
  }

  /// Draws a small filled circle with the stop number — pure [Canvas] ops,
  /// no network fetch and no image decoding. This replaces the previous
  /// marker that downloaded each stop's photo, decoded it, and composited
  /// it onto a 130x130 canvas — that was the main cause of the freeze on
  /// trips with several stops (N concurrent HTTP requests + image decodes
  /// + canvas->image conversions, all firing in initState).
  Future<BitmapDescriptor> _createNumberedMarker(int number) async {
    const double size = 84;
    const center = Offset(size / 2, size / 2);
    const radius = size / 2 - 4;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawCircle(center, radius, Paint()..color = AppColors.primary);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
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

  // NOTE: the in-app "share trip" button was removed with its _shareTrip
  // handler (recoverable from git history). The share backend — share
  // tokens, SupabaseService.makePublic and the /share/:token route — is
  // still fully functional for existing shared links.

  // ─── Fix 2: Open full route in Google Maps app ──────────────────────────────

  Future<void> _openInGoogleMaps() async {
    final validStops = _trip.stops.where((s) => s.latLng != null).toList();
    if (validStops.isEmpty) return;

    final origin = validStops.first.name;
    final destination = validStops.last.name;

    final waypointList = validStops.length > 2
        ? validStops
            .sublist(1, validStops.length - 1)
            .map((s) => s.name)
            .join('|')
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

  // ─── Fix 4: Zoom map camera to a specific stop ──────────────────────────────

  Future<void> _zoomToStop(int index) async {
    setState(() => _selectedStop = index);

    // Scroll the horizontal card list to bring this card into view.
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        index * 272.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }

    // Animate the map camera to the stop's position.
    final stop = _trip.stops[index];
    if (stop.latLng == null) return;
    final ctrl = await _mapCompleter.future;
    await ctrl.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: stop.latLng!, zoom: 16.0),
      ),
    );
  }

  // ─── Trip save ──────────────────────────────────────────────────────────────

  Future<void> _saveTrip() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await _service.saveTrip(_trip, user.id);
      setState(() => _trip = saved);
      if (mounted) ErrorSnackbar.showSuccess(context, AppStrings.tripSaved);
    } catch (e) {
      if (mounted) ErrorSnackbar.show(context, ErrorHandler.getMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final panelHeight = MediaQuery.of(context).size.height * 0.6;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          extendBody: true,
          extendBodyBehindAppBar: true,
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: const _OverlayIconButton(
                child: Icon(Icons.arrow_back, color: AppColors.ink),
              ),
            ),
            actions: [
              GestureDetector(
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
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(width: 12),
            ],
          ),
          body: Stack(
            children: [
              // ── Full-screen map ──────────────────────────────────────
              Positioned.fill(
                // Fix 2: the map mounts one frame after the first paint
                // (`!_mapReady` is true for exactly one frame) so the panel,
                // list and app bar appear instantly. Crucially it is NOT
                // gated on the route fetch anymore — the Directions HTTP
                // round-trip used to hide the whole map behind a loader;
                // now the polyline simply streams in when it resolves.
                child: (!_mapReady || kBisectDisableMap)
                    ? const ColoredBox(color: AppColors.background)
                    // Fix 4: RepaintBoundary isolates the GoogleMap's
                    // PlatformView layer from the rest of the Stack, so
                    // setState calls for unrelated state (e.g. _saving,
                    // _selectedStop) don't force the map to repaint.
                    : RepaintBoundary(
                        child: MapView(
                          stops: _trip.stops,
                          polylines: _polylines,
                          selectedIndex: _selectedStop,
                          // Pass lightweight numbered markers once ready.
                          externalMarkers: _markersReady ? _markers : null,
                          // Keep markers/controls clear of the floating panel.
                          padding: EdgeInsets.only(bottom: panelHeight),
                          onMapReady: (ctrl) {
                            if (!_mapCompleter.isCompleted) {
                              _mapCompleter.complete(ctrl);
                            }
                          },
                          onMarkerTap: _zoomToStop,
                        ),
                      ),
              ),

              // ── Route-loading pill (non-blocking) ────────────────────
              if (_loadingRoute)
                Positioned(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
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

              // ── Floating bottom panel ────────────────────────────────
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  height: panelHeight,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // ── Trip header ─────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _trip.destination,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  Text(
                                    '${_trip.stops.length} stops · ${_trip.vibe} · ${_trip.groupType}',
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.readOnly)
                              TextButton(
                                onPressed: () => context.go('/planner'),
                                child: Text(
                                  'Plan Your Own Trip',
                                  style: GoogleFonts.poppins(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // ── Stops section ────────────────────────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                              child: Text(
                                'Your Itinerary',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                controller: _scrollCtrl,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(
                                  left: 20,
                                  right: 20,
                                ),
                                itemCount: _trip.stops.length,
                                itemBuilder: (_, i) => StopCard(
                                  stop: _trip.stops[i],
                                  isSelected: i == _selectedStop,
                                  // Fix 4: tap → zoom map + scroll card list.
                                  onTap: () => _zoomToStop(i),
                                ).animate().slideX(
                                    begin: 0.2,
                                    duration: 300.ms,
                                    delay: Duration(milliseconds: i * 80)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Save button ──────────────────────────────────
                      if (!widget.readOnly)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              20, 8, 20, bottomPad > 0 ? bottomPad : 16),
                          child: ElevatedButton.icon(
                            onPressed: _trip.id != null ? null : _saveTrip,
                            icon: Icon(
                              _trip.id != null
                                  ? Icons.check_circle
                                  : Icons.bookmark_border,
                              color: Colors.white,
                            ),
                            label: Text(
                              _trip.id != null
                                  ? 'Trip Saved ✓'
                                  : AppStrings.saveTrip,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _trip.id != null
                                  ? AppColors.accent
                                  : AppColors.primary,
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        )
                      else
                        SizedBox(height: bottomPad > 0 ? bottomPad : 16),
                    ],
                  ),
                ),
              ),

              if (_saving) const LoadingOverlay(message: 'Saving your trip...'),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Small helper widget ────────────────────────────────────────────────────

class _OverlayIconButton extends StatelessWidget {
  final Widget child;
  const _OverlayIconButton({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 8),
        ],
      ),
      child: child,
    );
  }
}
