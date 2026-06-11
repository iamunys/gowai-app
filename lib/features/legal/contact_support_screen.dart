import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/app_card.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  String _appVersion = '—';
  int? _expandedIndex;

  static const _supportEmail = 'gowai.app@gmail.com';

  static const _faqs = [
    (
      '🗺️',
      'Trip not generating',
      'Check your internet connection and try again. If the issue persists after a restart, '
          'contact us at gowai.app@gmail.com with your device model and a description of the error.',
    ),
    (
      '💳',
      'Subscription / billing issue',
      'For billing issues, please email us at gowai.app@gmail.com with your registered '
          'email address and your Google Play or App Store order ID. '
          'We typically resolve billing queries within 1–2 business days.',
    ),
    (
      '🗑️',
      'Delete my account',
      'Go to Profile → Delete Account to permanently remove your account and all data. '
          'Alternatively, email us at gowai.app@gmail.com and we will delete your account '
          'within 48 hours.',
    ),
    (
      '🔄',
      'Restore my purchase',
      'Go to Profile → Subscription & Payments → tap the "Restore Purchase" button. '
          'Make sure you\'re signed in with the same account you used to purchase Pro.',
    ),
    (
      '🐛',
      'Report a bug',
      'Please email us at gowai.app@gmail.com with a screenshot, your device model, '
          'OS version, and a brief description of the issue. This helps us fix it faster!',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {}
  }

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {'subject': 'Gowai Support Request'},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open email app. Please email $_supportEmail directly.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ),
        );
      }
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
          title: const Text('Contact Support'),
          centerTitle: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.headset_mic_rounded,
                        color: AppColors.primary,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "We're here to help",
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Usually respond within 24 hours',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Section 1: Quick Help Topics ──────────────────────────────
              Text('Quick Help', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),

              AppCard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: _faqs.asMap().entries.map((entry) {
                      final i = entry.key;
                      final faq = entry.value;
                      final isExpanded = _expandedIndex == i;
                      final isLast = i == _faqs.length - 1;

                      return Column(
                        children: [
                          InkWell(
                            onTap: () => setState(
                                () => _expandedIndex = isExpanded ? null : i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Text(faq.$1,
                                      style: const TextStyle(fontSize: 20)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      faq.$2,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isExpanded)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(48, 0, 16, 14),
                              color: AppColors.primary.withAlpha(8),
                              child: Text(
                                faq.$3,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.65,
                                ),
                              ),
                            ),
                          if (!isLast)
                            Divider(
                              height: 1,
                              color: AppColors.textSecondary.withAlpha(25),
                              indent: 16,
                              endIndent: 16,
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Section 2: Contact Directly ───────────────────────────────
              Text('Contact Us Directly',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _launchEmail,
                  icon: const Icon(Icons.email_outlined, color: Colors.white),
                  label: Text(
                    'Email Support',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              const AppCard(
                padding: EdgeInsets.all(AppSpacing.lg),
                radius: AppRadius.md,
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.schedule_outlined,
                      label: 'Response time',
                      value: 'Within 24 hours',
                    ),
                    Divider(height: 20),
                    _InfoRow(
                      icon: Icons.work_outline_rounded,
                      label: 'Working hours',
                      value: 'Mon–Sat, 9AM–6PM IST',
                    ),
                    Divider(height: 20),
                    _InfoRow(
                      icon: Icons.alternate_email_rounded,
                      label: 'Email',
                      value: _supportEmail,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Section 3: App Info ────────────────────────────────────────
              Text('App Info', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),

              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                radius: AppRadius.md,
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.info_outline_rounded,
                      label: 'App Version',
                      value: _appVersion,
                    ),
                    const Divider(height: 20),
                    _InfoRow(
                      icon: Platform.isIOS
                          ? Icons.phone_iphone
                          : Icons.phone_android,
                      label: 'Platform',
                      value: Platform.isIOS ? 'iOS' : 'Android',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.ink,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
