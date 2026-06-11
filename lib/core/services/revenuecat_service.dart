import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RevenueCatService {
  static const _entitlement = 'gowai_pro_access';

  // ─────────────────────────────────────
  // Initialize
  // ─────────────────────────────────────
  Future<void> initialize() async {
    // ✅ Separate keys for Android and iOS
    final String apiKey;
    if (Platform.isAndroid) {
      apiKey = dotenv.env['REVENUECAT_ANDROID_KEY']!;
    } else {
      apiKey = dotenv.env['REVENUECAT_IOS_KEY']!;
    }

    // ✅ Only show debug logs in debug mode
    if (kDebugMode) {
      await Purchases.setLogLevel(LogLevel.debug);
    } else {
      await Purchases.setLogLevel(LogLevel.error);
    }

    final config = PurchasesConfiguration(apiKey);
    await Purchases.configure(config);
  }

  Future<void> logIn() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId != null) {
        await Purchases.logIn(userId);
        debugPrint('RevenueCat logged in: $userId');
      }
    } catch (e) {
      debugPrint('RevenueCat logIn error: $e');
    }
  }

  Future<void> logOut() async {
    try {
      await Purchases.logOut();
      debugPrint('RevenueCat logged out');
    } catch (e) {
      debugPrint('RevenueCat logOut error: $e');
    }
  }

  Future<bool> isPro() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(_entitlement);
    } catch (e) {
      debugPrint('RevenueCat isPro error: $e');
      return false;
    }
  }

  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('RevenueCat getOfferings error: $e');
      return null;
    }
  }

  Future<bool> purchase(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      final isPro = result.entitlements.active.containsKey(_entitlement);

      if (isPro) {
        await _updateSupabaseProStatus(true);
      }

      return isPro;
    } catch (e) {
      debugPrint('RevenueCat purchase error: $e');
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      final isPro = info.entitlements.active.containsKey(_entitlement);

      // ✅ Also update Supabase on restore
      if (isPro) {
        await _updateSupabaseProStatus(true);
      }

      return isPro;
    } catch (e) {
      debugPrint('RevenueCat restore error: $e');
      return false;
    }
  }

  Future<void> _updateSupabaseProStatus(bool isPro) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'is_pro': isPro}).eq('id', userId);

        debugPrint('Supabase is_pro updated: $isPro');
      }
    } catch (e) {
      debugPrint('Supabase update error: $e');
    }
  }

  Future<void> debugOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      debugPrint('Current offering: ${offerings.current?.identifier}');
      debugPrint('All offerings: ${offerings.all.keys}');

      offerings.current?.availablePackages.forEach((p) {
        debugPrint('Package: ${p.identifier} — ${p.storeProduct.identifier}');
      });
    } catch (e) {
      debugPrint('Offerings error: $e');
    }
  }
}
