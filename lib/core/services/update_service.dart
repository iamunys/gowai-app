import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';

// ─── Types ────────────────────────────────────────────────────────────────────

/// Describes whether a pending update is a major version bump or a minor one.
enum UpdateType {
  /// No update available (or could not be determined).
  none,

  /// Patch / minor update (second or third digit changed).
  /// Example: 1.2.3 → 1.2.4 or 1.3.0
  /// UX: non-blocking top banner that can be dismissed for 3 days.
  minor,

  /// Major update (first digit changed).
  /// Example: 1.x.x → 2.x.x
  /// UX: full-screen blocking dialog — app cannot be used without updating.
  major,
}

class UpdateResult {
  final UpdateType type;
  final String newVersion;

  const UpdateResult({required this.type, required this.newVersion});
}

// ─── Service ──────────────────────────────────────────────────────────────────

class UpdateService {
  static const _dismissKey = 'update_banner_dismissed_at';
  static const _dismissDays = 3;

  /// Queries the App Store / Play Store via [Upgrader] and returns an
  /// [UpdateResult] when an update is available, or `null` when the app is
  /// up-to-date or the check fails.
  static Future<UpdateResult?> checkForUpdate() async {
    try {
      final upgrader = Upgrader(debugLogging: kDebugMode);
      await upgrader.initialize();

      if (!upgrader.isUpdateAvailable()) return null;

      final storeVersion = upgrader.currentAppStoreVersion;
      if (storeVersion == null || storeVersion.trim().isEmpty) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final type = _classifyUpdate(
        current: currentVersion,
        latest: storeVersion,
      );

      if (type == UpdateType.none) return null;
      return UpdateResult(type: type, newVersion: storeVersion);
    } catch (e) {
      debugPrint('UpdateService.checkForUpdate error: $e');
      return null;
    }
  }

  /// Version comparison logic:
  ///   current 1.2.3 / latest 1.2.4 → MINOR  (patch bump)
  ///   current 1.2.3 / latest 1.3.0 → MINOR  (minor bump)
  ///   current 1.2.3 / latest 2.0.0 → MAJOR  (major bump)
  static UpdateType _classifyUpdate({
    required String current,
    required String latest,
  }) {
    final currentParts = current.split('.').map(int.tryParse).toList();
    final latestParts = latest.split('.').map(int.tryParse).toList();

    final currentMajor = currentParts.isNotEmpty ? currentParts[0] ?? 0 : 0;
    final latestMajor = latestParts.isNotEmpty ? latestParts[0] ?? 0 : 0;

    if (latestMajor > currentMajor) return UpdateType.major;

    // Any smaller-digit bump is minor
    for (var i = 0; i < latestParts.length && i < currentParts.length; i++) {
      final l = latestParts[i] ?? 0;
      final c = currentParts[i] ?? 0;
      if (l > c) return UpdateType.minor;
    }

    return UpdateType.none;
  }

  // ─── Minor banner dismiss helpers ──────────────────────────────────────────

  /// Returns `true` when the minor-update banner should be displayed.
  /// Returns `false` if the user dismissed it within the last [_dismissDays].
  static Future<bool> shouldShowMinorBanner() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMs = prefs.getInt(_dismissKey);
    if (savedMs == null) return true;
    final dismissedAt = DateTime.fromMillisecondsSinceEpoch(savedMs);
    return DateTime.now().difference(dismissedAt).inDays >= _dismissDays;
  }

  /// Persists the current timestamp so the banner is suppressed for
  /// [_dismissDays] days.
  static Future<void> recordBannerDismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dismissKey, DateTime.now().millisecondsSinceEpoch);
  }
}
