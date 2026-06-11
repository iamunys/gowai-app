import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../core/constants/app_colors.dart';

/// App-standard Lottie loading indicator with an optional message.
///
/// Replaces the Lottie.asset + LottieDelegates + Text block that was
/// copy-pasted across history, profile, shared-trip, the loading overlay
/// and the primary button. One place to swap the animation or styling.
class AppLoader extends StatelessWidget {
  final String? message;
  final double size;

  /// Fill color applied to the animation (defaults to the brand primary;
  /// use [AppColors.surface] on dark/colored backgrounds).
  final Color color;

  const AppLoader({
    super.key,
    this.message,
    this.size = 150,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final animation = Lottie.asset(
      'assets/lottie/loader.json',
      width: size,
      height: size,
      fit: BoxFit.contain,
      delegates: LottieDelegates(
        values: [
          ValueDelegate.color(const ['**', 'Fill 1', '**'], value: color),
        ],
      ),
    );

    if (message == null) return animation;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        animation,
        const SizedBox(height: 16),
        Text(
          message!,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
