import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/models/trip_stop.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/error_handler.dart';
import '../../shared/widgets/error_snackbar.dart';
import '../../shared/widgets/loading_overlay.dart';
import 'widgets/stop_card.dart';
import 'widgets/stop_details_sheet.dart';

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
  bool _saving = false;
  late Trip _trip;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
  }

  // ─── Open full route in Google Maps app ─────────────────────────────────

  Future<void> _openInGoogleMaps() async {
    final validStops = _trip.stops.where((s) => s.latLng != null).toList();
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

  // ─── View on map (own route — see ItineraryMapScreen) ───────────────────

  void _viewOnMap({int initialStopIndex = 0}) {
    context.push(
      '/itinerary/map?stopIndex=$initialStopIndex',
      extra: _trip,
    );
  }

  // ─── Trip save ────────────────────────────────────────────────────────────

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

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    if (_trip.stops.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'Could not load itinerary.\nPlease try generating again.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back, color: AppColors.ink),
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
              Column(
                children: [
                  // ── Trip header ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
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

                  // ── View on map ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _viewOnMap(),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('View on Map'),
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms),

                  // ── Stops section ────────────────────────────────────
                  SizedBox(
                    height: 400,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(
                              left: 20,
                              right: 20,
                            ),
                            itemCount: _trip.stops.length,
                            itemBuilder: (_, i) => StopCard(
                              stop: _trip.stops[i],
                              isSelected: false,
                              // Tap a stop to view its full details.
                              onTap: () =>
                                  showStopDetailsSheet(context, _trip.stops[i]),
                              // Tap the map icon to open the map zoomed to it.
                              onMapTap: () => _viewOnMap(initialStopIndex: i),
                            ).animate().slideX(
                                begin: 0.2,
                                duration: 300.ms,
                                delay: Duration(milliseconds: i * 80)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Save button ──────────────────────────────────────
                  if (!widget.readOnly)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          20, 20, 20, bottomPad > 0 ? bottomPad : 16),
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
              if (_saving) const LoadingOverlay(message: 'Saving your trip...'),
            ],
          ),
        ),
      ),
    );
  }
}
