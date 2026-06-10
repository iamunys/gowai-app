import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart' hide Marker;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/api_endpoints.dart';
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
  List<LatLng> _routePoints = [];
  Set<Marker> _markers = {};
  bool _markersReady = false;
  bool _saving = false;
  bool _loadingRoute = true;
  late Trip _trip;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _loadRoute();
    _loadMarkers();
  }

  // ─── Route loading ──────────────────────────────────────────────────────────

  Future<void> _loadRoute() async {
    final coords = _trip.stops
        .where((s) => s.latLng != null)
        .map((s) => s.latLng!)
        .toList();
    if (coords.length >= 2) {
      try {
        final points = await _directionsService.getRoutePoints(coords);
        if (mounted) setState(() => _routePoints = points);
      } catch (_) {}
    }
    if (mounted) setState(() => _loadingRoute = false);
  }

  // ─── Fix 5: Custom numbered circular map markers ────────────────────────────

  Future<void> _loadMarkers() async {
    final markers = <Marker>{};
    for (int i = 0; i < _trip.stops.length; i++) {
      final stop = _trip.stops[i];
      if (stop.latLng == null) continue;
      final icon = await _createNumberedMarker(i + 1, stop.photoUrl);
      markers.add(
        Marker(
          markerId: MarkerId('stop_${stop.stopNumber}'),
          position: stop.latLng!,
          icon: icon,
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
  }

  /// Loads a network image and decodes it for drawing on a [Canvas].
  /// Returns null if the URL is missing or the fetch/decode fails.
  Future<ui.Image?> _loadNetworkImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      final codec = await ui.instantiateImageCodec(response.bodyBytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  /// Paints a square marker showing the stop's photo (or a placeholder)
  /// with a circular numbered badge overlapping its top-left corner, then
  /// converts it to a BitmapDescriptor for GoogleMap.
  Future<BitmapDescriptor> _createNumberedMarker(
      int number, String? photoUrl) async {
    const double canvasSize = 130;
    const double imgSize = 100;
    const double imgOffset = 20;
    const double badgeRadius = 18;
    const imageRect = Rect.fromLTWH(imgOffset, imgOffset, imgSize, imgSize);
    final rrect = RRect.fromRectAndRadius(imageRect, const Radius.circular(14));

    final photo = await _loadNetworkImage(photoUrl);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Background placeholder behind the square.
    canvas.drawRRect(rrect, Paint()..color = AppColors.primary.withAlpha(30));

    canvas.save();
    canvas.clipRRect(rrect);
    if (photo != null) {
      final srcWidth = photo.width.toDouble();
      final srcHeight = photo.height.toDouble();
      Rect srcRect;
      if (srcWidth / srcHeight > 1) {
        final cropWidth = srcHeight;
        srcRect = Rect.fromLTWH(
            (srcWidth - cropWidth) / 2, 0, cropWidth, srcHeight);
      } else {
        final cropHeight = srcWidth;
        srcRect = Rect.fromLTWH(
            0, (srcHeight - cropHeight) / 2, srcWidth, cropHeight);
      }
      canvas.drawImageRect(photo, srcRect, imageRect, Paint());
    } else {
      // Fallback: location pin icon centered in the square.
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(Icons.place.codePoint),
          style: TextStyle(
            fontSize: 44,
            fontFamily: Icons.place.fontFamily,
            package: Icons.place.fontPackage,
            color: AppColors.primary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(
        canvas,
        Offset(
          imgOffset + (imgSize - iconPainter.width) / 2,
          imgOffset + (imgSize - iconPainter.height) / 2,
        ),
      );
    }
    canvas.restore();

    // White border around the square.
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // Numbered badge overlapping the top-left corner.
    const badgeCenter = Offset(imgOffset, imgOffset);
    canvas.drawCircle(badgeCenter, badgeRadius, Paint()..color = AppColors.primary);
    canvas.drawCircle(
      badgeCenter,
      badgeRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(badgeCenter.dx - tp.width / 2, badgeCenter.dy - tp.height / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(canvasSize.toInt(), canvasSize.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  // ─── Fix 1: Share trip (reuses existing token) ──────────────────────────────

  Future<void> _shareTrip() async {
    final user = Supabase.instance.client.auth.currentUser;
    try {
      Trip tripToShare = _trip;

      // Save first if not yet saved
      if (_trip.id == null && user != null) {
        tripToShare = await _service.saveTrip(_trip, user.id);
        if (mounted) setState(() => _trip = tripToShare);
      }

      // Reuse the existing shareToken — don't generate a new one every call.
      final token = tripToShare.shareToken ?? const Uuid().v4();

      if (tripToShare.id != null) {
        // makePublic may return null if RLS hides the updated row; fall back
        // to a local copy so sharing still works.
        final updated = await _service.makePublic(tripToShare.id!, token);
        tripToShare =
            updated ?? tripToShare.copyWith(isPublic: true, shareToken: token);
        if (mounted) setState(() => _trip = tripToShare);
      }

      final url = '${ApiEndpoints.shareBaseUrl}/$token';
      final shareText =
          '🗺️ Check out my Gowai trip to ${_trip.destination}!\n\n'
          '📍 ${_trip.stops.length} amazing stops planned\n'
          '🕐 Full day itinerary with timings & tips\n\n'
          'View the full trip here:\n$url\n\n'
          'Plan your own trip with Gowai 👇\nhttps://gowai.app';

      await Share.share(
        shareText,
        subject: 'My Gowai Trip to ${_trip.destination}',
      );
    } catch (e) {
      if (mounted) ErrorSnackbar.show(context, ErrorHandler.getMessage(e));
    }
  }

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              Column(
                children: [
                  // ── Map section (45% of screen height) ──────────────────
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.38,
                    child: Stack(
                      children: [
                        if (_loadingRoute)
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Lottie.asset(
                                  'assets/lottie/loader.json',
                                  width: 150,
                                  height: 150,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Drawing your route...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6C63FF),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          MapView(
                            stops: _trip.stops,
                            routePoints: _routePoints,
                            selectedIndex: _selectedStop,
                            // Pass custom numbered markers once ready.
                            externalMarkers: _markersReady ? _markers : null,
                            onMapReady: (ctrl) {
                              if (!_mapCompleter.isCompleted) {
                                _mapCompleter.complete(ctrl);
                              }
                            },
                            onMarkerTap: _zoomToStop,
                          ),

                        // Back + Share overlay buttons
                        SafeArea(
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => context.pop(),
                                icon: const _OverlayIconButton(
                                  child: Icon(Icons.arrow_back,
                                      color: AppColors.textPrimary),
                                ),
                              ),
                              const Spacer(),
                              // if (!widget.readOnly)
                              //   IconButton(
                              //     onPressed: _shareTrip,
                              //     icon: const _OverlayIconButton(
                              //       child: Icon(Icons.share,
                              //           color: AppColors.primary),
                              //     ),
                              //   ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Trip header ─────────────────────────────────────────
                  Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
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
                                  color: AppColors.textPrimary,
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

                  // ── Fix 2: Open Route in Google Maps button ─────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: GestureDetector(
                      onTap: _openInGoogleMaps,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF6C63FF),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C63FF).withAlpha(30),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.map_outlined,
                                color: Color(0xFF6C63FF), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Open Route in Google Maps',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6C63FF),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_ios,
                                size: 14, color: Color(0xFF6C63FF)),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 300.ms),
                  ),

                  // ── Stops section ───────────────────────────────────────
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
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        // Fix 3: bottom padding so last card clears the
                        // save button and device nav bar.
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.only(
                              left: 20,
                              right: 20,
                              bottom: bottomPad,
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

                  // ── Save button ─────────────────────────────────────────
                  if (!widget.readOnly)
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad + 16),
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
                    ),
                ],
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
