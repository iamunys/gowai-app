import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/user_profile.dart';
import '../../core/services/service_providers.dart';
import '../../core/utils/error_handler.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_loader.dart';
import '../../shared/widgets/error_snackbar.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/primary_button.dart';
import 'profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(supabaseServiceProvider).signOut();
    // RevenueCat logOut() is handled by the onAuthStateChange listener in main.dart
    if (context.mounted) context.go('/login');
  }

  Future<void> _showEditNameSheet(
      BuildContext context, WidgetRef ref, String initialName) async {
    // Controller is owned by _EditNameSheetState — no create/dispose here.
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditNameSheet(
        initialName: initialName,
        onSave: (name) async {
          Navigator.of(ctx).pop();
          await _saveName(context, ref, name);
        },
      ),
    );
  }

  Future<void> _saveName(
      BuildContext context, WidgetRef ref, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    try {
      await ref.read(profileProvider.notifier).updateName(trimmed);
      if (context.mounted) ErrorSnackbar.showSuccess(context, 'Name updated!');
    } catch (e) {
      if (context.mounted) {
        ErrorSnackbar.show(context, ErrorHandler.getMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

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
              style:
                  GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 30),
            ),
            centerTitle: false,
          ),
          body: profile.when(
            loading: () => const Center(
                child: AppLoader(message: 'Loading your profile...')),
            error: (error, _) => ErrorView(
              message: ErrorHandler.getMessage(error),
              onRetry: () => ref.invalidate(profileProvider),
            ),
            data: (p) => _ProfileBody(
              profile: p,
              onEditName: () =>
                  _showEditNameSheet(context, ref, p?.fullName ?? ''),
              onSignOut: () => _signOut(context, ref),
            ),
          ),
          bottomNavigationBar: const AppBottomNav(currentIndex: 2),
        ),
      ),
    );
  }
}

// ─── Profile body ───────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  final UserProfile? profile;
  final VoidCallback onEditName;
  final VoidCallback onSignOut;

  const _ProfileBody({
    required this.profile,
    required this.onEditName,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final isPro = profile?.isPro == true;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.primary.withAlpha(30),
            child: Text(
              (profile?.fullName?.isNotEmpty == true
                      ? profile!.fullName![0]
                      : profile?.email[0] ?? 'U')
                  .toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onEditName,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile?.fullName ?? 'Traveler',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms),
          Text(
            profile?.email ?? '',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 32),

          // Usage card
          AppCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPro ? 'Pro Member 🌟' : 'Free Plan',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: isPro ? AppColors.warning : AppColors.ink,
                          ),
                        ),
                        Text(
                          '${profile?.tripsUsedThisMonth ?? 0} / ${isPro ? '∞' : '3'} ${AppStrings.tripsThisMonth}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (!isPro)
                      const Icon(Icons.lock_outline,
                          color: AppColors.textSecondary),
                  ],
                ),
                if (!isPro) ...[
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
                              ((profile?.tripsUsedThisMonth ?? 0) / 3)
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
          if (!isPro)
            PrimaryButton(
              label: '${AppStrings.upgradeToProLabel} ✨',
              onPressed: () => context.push('/paywall'),
            ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 32),

          // ── Legal & Support ─────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Legal & Support',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _LegalTile(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () => context.push('/privacy-policy'),
                ),
                const _Divider(),
                _LegalTile(
                  icon: Icons.article_outlined,
                  label: 'Terms of Service',
                  onTap: () => context.push('/terms-of-service'),
                ),
                const _Divider(),
                _LegalTile(
                  icon: Icons.card_membership_outlined,
                  label: 'Subscription & Payments',
                  onTap: () => context.push('/subscription-info'),
                ),
                const _Divider(),
                _LegalTile(
                  icon: Icons.headset_mic_outlined,
                  label: 'Contact Support',
                  onTap: () => context.push('/contact-support'),
                ),
                const _Divider(),
                _LegalTile(
                  icon: Icons.delete_outline,
                  label: 'Delete Account',
                  labelColor: AppColors.error,
                  iconColor: AppColors.error,
                  onTap: () => context.push('/delete-account'),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 350.ms),

          const SizedBox(height: 32),

          // Sign out
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout, color: AppColors.error),
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
    );
  }
}

// ─── Edit name bottom sheet ────────────────────────────────────────────────

class _EditNameSheet extends StatefulWidget {
  final String initialName;
  final Future<void> Function(String name) onSave;

  const _EditNameSheet({required this.initialName, required this.onSave});

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  // Controller lives here — created in initState, disposed in dispose.
  // This ensures it outlives the close animation and is never used after disposal.
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await widget.onSave(name);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    // Padding widget handles keyboard insets OUTSIDE the Container so the
    // Column never exceeds available height → fixes the 99249px overflow.
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withAlpha(60),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Edit Name',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This is how you appear in Gowai.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Your full name',
                hintStyle: GoogleFonts.poppins(color: AppColors.textSecondary),
                prefixIcon:
                    const Icon(Icons.person_outline, color: AppColors.primary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: AppColors.textSecondary.withAlpha(40)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: AppColors.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                          color: AppColors.textSecondary.withAlpha(60)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        (_ctrl.text.trim().isEmpty || _saving) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withAlpha(80),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Save',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper widgets ────────────────────────────────────────────────────────

class _LegalTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;
  final Color? iconColor;

  const _LegalTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? AppColors.primary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? AppColors.ink,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: (labelColor ?? AppColors.textSecondary).withAlpha(150),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 50,
      endIndent: 16,
      color: AppColors.textSecondary.withAlpha(25),
    );
  }
}
