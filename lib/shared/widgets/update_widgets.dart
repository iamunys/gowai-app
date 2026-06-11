import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_versions.dart';
import '../../core/services/update_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// COMPONENT 1 — Minor Update Banner
// ══════════════════════════════════════════════════════════════════════════════

/// A non-blocking 52px banner that slides down from the top of the screen.
/// The user can dismiss it (hidden for 3 days) or tap "Update" to open the
/// appropriate store page.
class MinorUpdateBanner extends StatelessWidget {
  final String newVersion;

  /// Called when the user taps "✕". The parent should remove this widget from
  /// the tree; the 3-day suppression is recorded here before calling back.
  final VoidCallback onDismiss;

  const MinorUpdateBanner({
    super.key,
    required this.newVersion,
    required this.onDismiss,
  });

  Future<void> _openStore() async {
    final url =
        Platform.isIOS ? AppVersions.appStoreUrl : AppVersions.playStoreUrl;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _dismiss() async {
    await UpdateService.recordBannerDismiss();
    onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // ── Left: icon + label ─────────────────────────────────────────
          const Text('🆕', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Update available  v$newVersion',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ── Right: Update button + dismiss ─────────────────────────────
          GestureDetector(
            onTap: _openStore,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Update',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _dismiss,
            child: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
        ],
      ),
    )
        .animate()
        .slideY(begin: -1.0, end: 0.0, duration: 400.ms, curve: Curves.easeOut)
        .fadeIn(duration: 300.ms);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COMPONENT 2 — Major Update Dialog
// ══════════════════════════════════════════════════════════════════════════════

/// A full-screen blocking overlay shown for major version bumps.
/// There is intentionally NO dismiss / skip option — the app cannot be
/// used until the user updates.
class MajorUpdateDialog extends StatelessWidget {
  final String newVersion;

  const MajorUpdateDialog({super.key, required this.newVersion});

  static const _changelog = [
    '✨  Smarter AI trip generation',
    '✨  Faster map loading',
    '✨  New offline save feature',
    '✨  Bug fixes and improvements',
  ];

  Future<void> _openStore() async {
    final url =
        Platform.isIOS ? AppVersions.appStoreUrl : AppVersions.playStoreUrl;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Block the hardware back button — major update cannot be dismissed.
      canPop: false,
      child: Container(
        color: Colors.black.withAlpha(204), // 80% opacity
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Rocket animation ─────────────────────────────────────
                const Text(
                  '🚀',
                  style: TextStyle(fontSize: 72),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(
                      begin: -8,
                      end: 8,
                      duration: 800.ms,
                      curve: Curves.easeInOut,
                    ),

                const SizedBox(height: 24),

                // ── Title ────────────────────────────────────────────────
                Text(
                  'Gowai just got better!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),

                const SizedBox(height: 12),

                // ── Version badge ────────────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Version $newVersion is here',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── What's new ───────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "What's new",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._changelog.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            item,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.ink,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Update Now button ────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(80),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _openStore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        "Update Now — It's Free",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Redirect note ────────────────────────────────────────
                Text(
                  "You'll be redirected to the\n"
                  '${Platform.isIOS ? 'App Store' : 'Play Store'}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.placeholder,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.0, 1.0),
                duration: 400.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: 300.ms),
        ),
      ),
    );
  }
}
