import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/plan_pricing.dart';
import '../../core/services/revenuecat_service.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/error_snackbar.dart';
import '../../shared/widgets/primary_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _rcService = RevenueCatService();
  final _sbService = SupabaseService();
  bool _loading = false;
  Offerings? _offerings;
  String _selectedPlan = 'monthly';

  static const _features = [
    (Icons.all_inclusive, AppStrings.unlimitedTrips),
    (Icons.download_outlined, AppStrings.offlineSave),
    (Icons.picture_as_pdf_outlined, AppStrings.pdfExport),
    (Icons.flash_on_outlined, AppStrings.priorityAI),
  ];

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      final o = await _rcService.getOfferings();
      if (mounted) setState(() => _offerings = o);
    } catch (_) {}
  }

  Future<void> _purchase() async {
    final current = _offerings?.current;
    final package =
        _selectedPlan == 'monthly' ? current?.monthly : current?.annual;

    // No package means offerings didn't load (network/store issue). Never
    // grant Pro from this path — an earlier demo fallback did exactly that,
    // handing out free subscriptions whenever RevenueCat was unreachable.
    if (package == null) {
      ErrorSnackbar.show(
        context,
        'Subscription plans are unavailable right now. '
        'Please check your connection and try again.',
      );
      _loadOfferings(); // refresh in the background for the next attempt
      return;
    }

    setState(() => _loading = true);
    try {
      final success = await _rcService.purchase(package);

      if (success) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await _sbService.setProStatus(user.id, true);
        }
        if (mounted) {
          ErrorSnackbar.showSuccess(context, 'Welcome to Gowai Pro! 🎉');
          context.pop();
        }
      }
      // success == false covers both user cancellation and store errors —
      // RevenueCatService.purchase returns a bare bool, so they can't be
      // told apart here. Stay silent rather than show "failed" to someone
      // who deliberately cancelled. (Distinguishing them needs a small
      // RevenueCatService change — flagged for the integrations module.)
    } catch (e) {
      if (mounted) {
        ErrorSnackbar.show(context, 'Purchase failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _loading = true);
    try {
      final success = await _rcService.restorePurchases();
      if (success) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await _sbService.setProStatus(user.id, true);
        }
        if (mounted) {
          ErrorSnackbar.showSuccess(context, 'Purchase restored!');
          context.pop();
        }
      } else {
        if (mounted) {
          ErrorSnackbar.show(context, 'No previous purchase found.');
        }
      }
    } catch (_) {
      if (mounted) {
        ErrorSnackbar.show(context, 'Restore failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
              centerTitle: false,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              ),
              title: Text(
                AppStrings.unlockPro,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 30),
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('🌟', style: TextStyle(fontSize: 64))
                      .animate()
                      .scale(duration: 500.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.unlockPro,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock unlimited AI trip planning',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 32),

                  // Features list
                  ..._features.asMap().entries.map((entry) {
                    final i = entry.key;
                    final feat = entry.value;
                    return _FeatureRow(icon: feat.$1, label: feat.$2)
                        .animate()
                        .slideX(
                            begin: -0.2,
                            delay: Duration(milliseconds: 200 + i * 80))
                        .fadeIn(delay: Duration(milliseconds: 200 + i * 80));
                  }),

                  const SizedBox(height: 32),

                  // Plan selector — prices come from the store via
                  // RevenueCat (PlanPricing falls back to the static
                  // AppStrings values only while offerings load).
                  Builder(builder: (context) {
                    final pricing = PlanPricing.fromOfferings(_offerings);
                    return Row(
                      children: [
                        Expanded(
                          child: _PlanCard(
                            title: 'Monthly',
                            price: pricing.monthlyLabel,
                            selected: _selectedPlan == 'monthly',
                            onTap: () =>
                                setState(() => _selectedPlan = 'monthly'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PlanCard(
                            title: 'Yearly',
                            price: pricing.yearlyLabel,
                            badge: pricing.savingsLabel,
                            selected: _selectedPlan == 'yearly',
                            onTap: () =>
                                setState(() => _selectedPlan = 'yearly'),
                          ),
                        ),
                      ],
                    );
                  }).animate().fadeIn(delay: 500.ms),

                  const SizedBox(height: 24),

                  PrimaryButton(
                    label: AppStrings.startFreeTrial,
                    isLoading: _loading,
                    onPressed: _purchase,
                  ).animate().fadeIn(delay: 600.ms),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: _loading ? null : _restore,
                    child: Text(
                      AppStrings.restorePurchase,
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ).animate().fadeIn(delay: 700.ms),
                ],
              ),
            ),
          ),
        ));
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withAlpha(15) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (badge != null) const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: selected ? AppColors.primary : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
