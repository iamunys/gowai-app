import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/plan_pricing.dart';
import '../../core/models/user_profile.dart';
import '../../core/services/revenuecat_service.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/error_snackbar.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _rcService = RevenueCatService();
  final _sbService = SupabaseService();

  bool _isPro = false;
  UserProfile? _profile;
  Offerings? _offerings;
  bool _loading = true;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final results = await Future.wait([
        _rcService.isPro(),
        if (userId != null)
          _sbService.getProfile(userId)
        else
          Future.value(null),
        // getOfferings catches internally and returns null on failure, so
        // it can't fail this Future.wait.
        _rcService.getOfferings(),
      ]);
      if (mounted) {
        setState(() {
          _isPro = results[0] as bool;
          _profile = results[1] as UserProfile?;
          _offerings = results[2] as Offerings?;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _restoring = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final success = await _rcService.restorePurchases();
      if (success && userId != null) {
        await _sbService.setProStatus(userId, true);
        await _loadData();
        if (mounted) {
          ErrorSnackbar.showSuccess(
              context, 'Purchase restored! Welcome to Pro 🎉');
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
      if (mounted) setState(() => _restoring = false);
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
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          // Style comes from AppBarTheme.titleTextStyle.
          title: const Text('Subscription & Payments'),
          centerTitle: false,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Section 1: Current Plan ────────────────────────────
                    const _SectionTitle('Current Plan'),
                    const SizedBox(height: 12),
                    _CurrentPlanCard(
                      isPro: _isPro,
                      tripsUsed: _profile?.tripsUsedThisMonth ?? 0,
                      onUpgrade: () => context.push('/paywall'),
                    ),

                    const SizedBox(height: 28),

                    // ── Section 2: Plan Comparison ─────────────────────────
                    const _SectionTitle('Plan Comparison'),
                    const SizedBox(height: 12),
                    const _ComparisonTable(),

                    const SizedBox(height: 28),

                    // ── Section 3: Pricing ─────────────────────────────────
                    const _SectionTitle('Pricing'),
                    const SizedBox(height: 12),
                    _PricingCard(pricing: PlanPricing.fromOfferings(_offerings)),

                    const SizedBox(height: 28),

                    // ── Section 4: Billing Info ────────────────────────────
                    const _SectionTitle('Billing Information'),
                    const SizedBox(height: 12),
                    _InfoCard(
                      items: [
                        'Payments are processed securely by ${Platform.isIOS ? 'Apple App Store' : 'Google Play Store'}.',
                        'Subscriptions automatically renew unless cancelled at least 24 hours before the renewal date.',
                        'Cancel anytime from your device\'s subscription settings — no cancellation fee.',
                        'No refunds are issued for partial subscription months.',
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Section 5: How to Cancel ───────────────────────────
                    const _SectionTitle('How to Cancel'),
                    const SizedBox(height: 12),
                    const _CancelInstructions(),

                    const SizedBox(height: 28),

                    // ── Section 6: Restore Purchase ────────────────────────
                    const _SectionTitle('Restore Purchase'),
                    const SizedBox(height: 12),
                    _RestoreCard(
                      isRestoring: _restoring,
                      onRestore: _restorePurchases,
                    ),

                    const SizedBox(height: 28),

                    // ── Section 7: Contact ─────────────────────────────────
                    const _SectionTitle('Billing Support'),
                    const SizedBox(height: 12),
                    const _InfoCard(
                      items: [
                        'For billing questions or disputes, email us at gowai.app@gmail.com with your registered email and order ID.',
                        'We aim to respond within 24 hours on working days.',
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─── Section title ─────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

// ─── Current plan card ──────────────────────────────────────────────────────

class _CurrentPlanCard extends StatelessWidget {
  final bool isPro;
  final int tripsUsed;
  final VoidCallback onUpgrade;

  const _CurrentPlanCard({
    required this.isPro,
    required this.tripsUsed,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      border: Border.all(
        color: isPro
            ? AppColors.warning.withAlpha(120)
            : AppColors.textSecondary.withAlpha(40),
        width: isPro ? 2 : 1,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPro
                            ? AppColors.warning.withAlpha(30)
                            : AppColors.textSecondary.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isPro ? '🌟 Pro Plan' : '⬜ Free Plan',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isPro
                              ? AppColors.warning
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isPro
                      ? 'Unlimited trips'
                      : '$tripsUsed / 3 trips used this month',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!isPro)
            ElevatedButton(
              onPressed: onUpgrade,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Upgrade',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          if (isPro)
            ElevatedButton(
              onPressed: () {
                // Platform subscription management
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Manage',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Comparison table ───────────────────────────────────────────────────────

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable();

  static const _rows = [
    ('Trips per month', '3', '∞'),
    ('AI itinerary', '✅', '✅'),
    ('Google Maps route', '✅', '✅'),
    ('Save trips', '✅', '✅'),
    ('Share trips', '✅', '✅'),
    ('Offline save', '❌', '✅'),
    ('PDF export', '❌', '✅'),
    ('Priority AI', '❌', '✅'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Feature',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink)),
                ),
                Expanded(
                  child: Center(
                    child: Text('Free',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('Pro',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),
                ),
              ],
            ),
          ),
          // Data rows
          ..._rows.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            final isLast = i == _rows.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                border: !isLast
                    ? Border(
                        bottom: BorderSide(
                            color: AppColors.textSecondary.withAlpha(20),
                            width: 1))
                    : null,
                borderRadius: isLast
                    ? const BorderRadius.vertical(bottom: Radius.circular(16))
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      row.$1,
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.ink),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(row.$2,
                          style: GoogleFonts.poppins(fontSize: 14)),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(row.$3,
                          style: GoogleFonts.poppins(fontSize: 14)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Pricing card ───────────────────────────────────────────────────────────

class _PricingCard extends StatelessWidget {
  /// Live store prices (with static fallbacks while offerings load).
  final PlanPricing pricing;

  const _PricingCard({required this.pricing});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: _PriceBox(
              label: 'Monthly',
              price: pricing.monthlyPrice,
              sub: 'per month',
              highlight: false,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PriceBox(
              label: 'Yearly',
              price: pricing.yearlyPrice,
              sub: 'per year',
              badge: pricing.savingsLabel,
              highlight: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceBox extends StatelessWidget {
  final String label;
  final String price;
  final String sub;
  final String? badge;
  final bool highlight;

  const _PriceBox({
    required this.label,
    required this.price,
    required this.sub,
    this.badge,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            highlight ? AppColors.primary.withAlpha(15) : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? AppColors.primary.withAlpha(80)
              : AppColors.textSecondary.withAlpha(40),
          width: highlight ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(badge!,
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          if (badge != null) const SizedBox(height: 8),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(price,
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: highlight ? AppColors.primary : AppColors.ink)),
          Text(sub,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ─── Info card (bulleted list) ─────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<String> items;
  const _InfoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(item,
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              height: 1.6)),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Cancel instructions ────────────────────────────────────────────────────

class _CancelInstructions extends StatelessWidget {
  const _CancelInstructions();

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isIOS) ...[
            const _CancelStep(icon: Icons.apple, platform: 'iOS'),
            const SizedBox(height: 8),
            Text(
              'Settings → Apple ID → Subscriptions → Gowai → Cancel Subscription',
              style: GoogleFonts.poppins(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.6),
            ),
          ] else ...[
            const _CancelStep(icon: Icons.shop, platform: 'Android'),
            const SizedBox(height: 8),
            Text(
              'Play Store → Profile icon → Payments & subscriptions → Subscriptions → Gowai → Cancel subscription',
              style: GoogleFonts.poppins(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.6),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cancel at least 24 hours before your renewal date to avoid being charged for the next period.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.ink, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelStep extends StatelessWidget {
  final IconData icon;
  final String platform;
  const _CancelStep({required this.icon, required this.platform});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          platform,
          style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
        ),
      ],
    );
  }
}

// ─── Restore card ───────────────────────────────────────────────────────────

class _RestoreCard extends StatelessWidget {
  final bool isRestoring;
  final VoidCallback onRestore;

  const _RestoreCard({required this.isRestoring, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Already purchased Pro on another device?',
            style: GoogleFonts.poppins(
                fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: isRestoring ? null : onRestore,
              icon: isRestoring
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restore, color: AppColors.primary),
              label: Text(
                isRestoring ? 'Restoring...' : 'Restore Purchase',
                style: GoogleFonts.poppins(
                    color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
