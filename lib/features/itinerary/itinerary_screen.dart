import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  int _selectedStop = 0;
  List<LatLng> _routePoints = [];
  bool _saving = false;
  bool _loadingRoute = true;
  late Trip _trip;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _loadRoute();
  }

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
      if (mounted) {
        ErrorSnackbar.showSuccess(context, AppStrings.tripSaved);
      }
    } catch (e) {
      if (mounted) {
        ErrorSnackbar.show(context, ErrorHandler.getMessage(e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareTrip() async {
    final user = Supabase.instance.client.auth.currentUser;
    try {
      Trip tripToShare = _trip;

      // Save first if not saved
      if (_trip.id == null && user != null) {
        tripToShare = await _service.saveTrip(_trip, user.id);
        setState(() => _trip = tripToShare);
      }

      final token = const Uuid().v4();
      if (tripToShare.id != null) {
        tripToShare = await _service.makePublic(tripToShare.id!, token);
        setState(() => _trip = tripToShare);
      }

      final url = '${ApiEndpoints.shareBaseUrl}/$token';
      await Share.share(
        'Check out my Gowai itinerary for ${_trip.destination}! 🗺️\n$url',
        subject: 'Gowai — ${_trip.destination} itinerary',
      );
    } catch (e) {
      if (mounted) {
        ErrorSnackbar.show(context, ErrorHandler.getMessage(e));
      }
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                // Map section
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.45,
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
                          onMarkerTap: (i) {
                            setState(() => _selectedStop = i);
                            _scrollCtrl.animateTo(
                              i * 272.0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          },
                        ),
                      SafeArea(
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.surface,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.cardShadow,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.arrow_back,
                                    color: AppColors.textPrimary),
                              ),
                            ),
                            const Spacer(),
                            if (!widget.readOnly)
                              IconButton(
                                onPressed: _shareTrip,
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: AppColors.surface,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.cardShadow,
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.share,
                                      color: AppColors.primary),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Trip header
                Container(
                  color: AppColors.surface,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _trip.destination,
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${_trip.stops.length} stops · ${_trip.vibe} · ${_trip.groupType}',
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

                // Stops horizontal list
                Expanded(
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
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _trip.stops.length,
                          itemBuilder: (_, i) => StopCard(
                            stop: _trip.stops[i],
                            isSelected: i == _selectedStop,
                            onTap: () => setState(() => _selectedStop = i),
                          ).animate().slideX(
                              begin: 0.2,
                              duration: 300.ms,
                              delay: Duration(milliseconds: i * 80)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Save button
                if (!widget.readOnly)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: ElevatedButton.icon(
                      onPressed: _trip.id != null ? null : _saveTrip,
                      icon: Icon(
                          _trip.id != null
                              ? Icons.check_circle
                              : Icons.bookmark_border,
                          color: Colors.white),
                      label: Text(
                        _trip.id != null ? 'Trip Saved ✓' : AppStrings.saveTrip,
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
