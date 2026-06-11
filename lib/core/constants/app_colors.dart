import 'package:flutter/material.dart';

/// App-wide color palette, including the conversational Planner theme.
class AppColors {
  static const primary = Color(0xFF6C63FF);
  static const primaryDark = Color(0xFF4B44CC);
  static const primaryTrack = Color(0xFFE8E7FF);
  static const primarySurface = Color(0xFFF3F0FF);
  static const accent = Color(0xFF00C896);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1A1A2E);
  static const muted = Color(0xFF6B7280);
  static const placeholder = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const background = Color(0xFFF8F9FF);
  static const textSecondary = Color(0xFF6B7280);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const cardShadow = Color(0x1A6C63FF);

  static const primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Washed-out variant of [primaryGradient] for disabled primary buttons.
  static const disabledGradient = LinearGradient(
    colors: [Color(0xFFB0ADE0), Color(0xFF8E8BCC)],
  );
}
