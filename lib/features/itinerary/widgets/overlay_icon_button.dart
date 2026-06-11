import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Small circular surface used for icon buttons floating over a map or
/// image (back button, etc.).
class OverlayIconButton extends StatelessWidget {
  final Widget child;
  const OverlayIconButton({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 8),
        ],
      ),
      child: child,
    );
  }
}
