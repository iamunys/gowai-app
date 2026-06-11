/// Spacing and radius tokens.
///
/// Use these instead of raw numbers in padding/margins/radii so the scale
/// stays consistent (4-pt grid). Existing code is migrated opportunistically
/// as files are touched — new code should always use the tokens.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class AppRadius {
  AppRadius._();

  /// Chips, small inputs.
  static const double sm = 8;

  /// Buttons inside sheets/dialogs.
  static const double md = 12;

  /// Standard buttons & text fields.
  static const double button = 14;

  /// Cards.
  static const double card = 16;

  /// Pills/badges.
  static const double pill = 20;

  /// Bottom sheets / floating panels.
  static const double sheet = 24;
}
