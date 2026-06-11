import 'package:purchases_flutter/purchases_flutter.dart';
import '../constants/app_strings.dart';

/// Display prices for the Pro plans, sourced from the store via RevenueCat.
///
/// `StoreProduct.priceString` is what Google Play / the App Store will
/// actually charge, correctly localized. The hardcoded AppStrings values are
/// ONLY fallbacks for while offerings are loading or unreachable — App Store
/// review rejects screens whose displayed price disagrees with the purchase
/// sheet, so never prefer the fallbacks over live store data.
class PlanPricing {
  /// e.g. '₹99.00/month' (paywall plan card)
  final String monthlyLabel;

  /// e.g. '₹799.00/year' (paywall plan card)
  final String yearlyLabel;

  /// Bare price, e.g. '₹99.00' (subscription-info pricing card)
  final String monthlyPrice;

  /// Bare price, e.g. '₹799.00'
  final String yearlyPrice;

  /// 'Save NN%' computed from real prices; null when yearly isn't actually
  /// cheaper (so the badge disappears instead of lying).
  final String? savingsLabel;

  const PlanPricing._({
    required this.monthlyLabel,
    required this.yearlyLabel,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.savingsLabel,
  });

  factory PlanPricing.fromOfferings(Offerings? offerings) {
    final monthly = offerings?.current?.monthly?.storeProduct;
    final annual = offerings?.current?.annual?.storeProduct;

    String? savings;
    if (monthly != null && annual != null && monthly.price > 0) {
      final pct = ((1 - annual.price / (monthly.price * 12)) * 100).round();
      savings = pct > 0 ? 'Save $pct%' : null;
    } else {
      savings = AppStrings.savingsFallback;
    }

    return PlanPricing._(
      monthlyLabel: monthly != null
          ? '${monthly.priceString}/month'
          : AppStrings.monthlyPrice,
      yearlyLabel:
          annual != null ? '${annual.priceString}/year' : AppStrings.yearlyPrice,
      monthlyPrice: monthly?.priceString ?? AppStrings.monthlyPriceBare,
      yearlyPrice: annual?.priceString ?? AppStrings.yearlyPriceBare,
      savingsLabel: savings,
    );
  }
}
