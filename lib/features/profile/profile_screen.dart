import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gowai/core/services/revenuecat_service.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/user_profile.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/error_handler.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/error_snackbar.dart';
import '../../shared/widgets/primary_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _rcService = RevenueCatService();

  final _service = SupabaseService();
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final p = await _service.getProfile(user.id);
      if (mounted) setState(() => _profile = p);
    } catch (e) {
      if (mounted) ErrorSnackbar.show(context, ErrorHandler.getMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await _service.signOut();
    await _rcService.logOut(); // ✅ add this line

    if (mounted) context.go('/login');
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
              AppStrings.profile,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 30),
            ),
            centerTitle: false,
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
                        'Loading your profile...',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.primary.withAlpha(30),
                        child: Text(
                          (_profile?.fullName?.isNotEmpty == true
                                  ? _profile!.fullName![0]
                                  : _profile?.email[0] ?? 'U')
                              .toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                          .animate()
                          .scale(duration: 400.ms, curve: Curves.elasticOut),
                      const SizedBox(height: 16),
                      Text(
                        _profile?.fullName ?? 'Traveler',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ).animate().fadeIn(delay: 100.ms),
                      Text(
                        _profile?.email ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ).animate().fadeIn(delay: 150.ms),
                      const SizedBox(height: 32),

                      // Usage card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.cardShadow,
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _profile?.isPro == true
                                          ? 'Pro Member 🌟'
                                          : 'Free Plan',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: _profile?.isPro == true
                                            ? AppColors.warning
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${_profile?.tripsUsedThisMonth ?? 0} / ${_profile?.isPro == true ? '∞' : '3'} ${AppStrings.tripsThisMonth}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_profile?.isPro != true)
                                  const Icon(Icons.lock_outline,
                                      color: AppColors.textSecondary),
                              ],
                            ),
                            if (_profile?.isPro != true) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 6,
                                      color: AppColors.primary.withAlpha(30),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor:
                                          ((_profile?.tripsUsedThisMonth ?? 0) /
                                                  3)
                                              .clamp(0.0, 1.0),
                                      child: Container(
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 16),

                      // Upgrade button
                      if (_profile?.isPro != true)
                        PrimaryButton(
                          label: '${AppStrings.upgradeToProLabel} ✨',
                          onPressed: () => context.push('/paywall'),
                        ).animate().fadeIn(delay: 300.ms),

                      const SizedBox(height: 32),

                      // Sign out
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: _signOut,
                          icon:
                              const Icon(Icons.logout, color: AppColors.error),
                          label: Text(
                            AppStrings.signOut,
                            style: GoogleFonts.poppins(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ).animate().fadeIn(delay: 400.ms),
                    ],
                  ),
                ),
          bottomNavigationBar: const AppBottomNav(currentIndex: 2),
        ),
      ),
    );
  }
}
