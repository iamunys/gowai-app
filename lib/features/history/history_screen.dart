import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/error_handler.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/error_snackbar.dart';
import 'widgets/trip_history_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _service = SupabaseService();
  List<Trip> _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final trips = await _service.getUserTrips(user.id);
      if (mounted) setState(() => _trips = trips);
    } catch (e) {
      if (mounted) ErrorSnackbar.show(context, ErrorHandler.getMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Fix 6: Show a confirmation bottom sheet before deleting.
  Future<void> _confirmDelete(Trip trip) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFEF4444),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Delete Trip?',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'Your trip to ${trip.destination} will be\npermanently deleted.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Yes, Delete',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(
                height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _deleteTrip(trip);
    }
  }

  Future<void> _deleteTrip(Trip trip) async {
    if (trip.id == null) return;
    try {
      await _service.deleteTrip(trip.id!);
      if (mounted) setState(() => _trips.removeWhere((t) => t.id == trip.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Trip deleted',
                    style: GoogleFonts.poppins(color: Colors.white)),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) ErrorSnackbar.show(context, ErrorHandler.getMessage(e));
    }
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
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: Text(
              AppStrings.myTrips,
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 30),
          ),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadTrips,
            ),
          ],
        ),
        body: _loading
            ? Center(
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
                      'Fetching your adventures...',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : _trips.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/images/camping.png',
                            width: 200, height: 200),
                        const SizedBox(height: 16),
                        Text(
                          AppStrings.noTripsYet,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () => context.go('/planner'),
                          child: Text(
                            'Plan your first trip →',
                            style: GoogleFonts.poppins(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadTrips,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _trips.length,
                      itemBuilder: (_, i) => TripHistoryCard(
                        trip: _trips[i],
                        onTap: () =>
                            context.push('/itinerary', extra: _trips[i]),
                        // Fix 6: show confirmation sheet before deleting.
                        onDelete: () => _confirmDelete(_trips[i]),
                      )
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: i * 60))
                          .scale(begin: const Offset(0.95, 0.95)),
                    ),
                  ),
        bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      ),
    ),
    );
  }
}
