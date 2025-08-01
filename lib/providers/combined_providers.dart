import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/models/product.dart';
import 'package:gravity_desktop_app/models/subscription.dart';
import 'package:gravity_desktop_app/providers/product_provider.dart';
import 'package:gravity_desktop_app/providers/subscriptions_provider.dart';
import 'package:gravity_desktop_app/providers/time_prices_provider.dart';

// Models
class PricesProductsSubs {
  final Map<TimeSlice, int> prices;
  final List<Product> allProducts;
  final List<Subscription> allSubs;

  PricesProductsSubs(
      {required this.prices, required this.allProducts, required this.allSubs});
}

// Combined Providers
final pricesProductsSubsProvider = Provider<AsyncValue<PricesProductsSubs>>((ref) {
  final pricesAsync = ref.watch(pricesProvider);
  final productsAsync = ref.watch(productsProvider);
  final subsAsync = ref.watch(subscriptionsProvider);

  // If either provider is in an error state, the whole thing is an error
  if (pricesAsync.hasError) {
    return AsyncError(pricesAsync.error!, pricesAsync.stackTrace!);
  }
  if (productsAsync.hasError) {
    return AsyncError(productsAsync.error!, productsAsync.stackTrace!);
  }

  if (subsAsync.hasError) {
    return AsyncError(subsAsync.error!, subsAsync.stackTrace!);
  }

  // If either provider is loading, the whole thing is loading
  if (pricesAsync.isLoading || productsAsync.isLoading || subsAsync.isLoading) {
    return const AsyncLoading();
  }

  // If we get here, both have data. We can safely access it.
  return AsyncData(
    PricesProductsSubs(
      prices: pricesAsync.value!,
      allProducts: productsAsync.value!,
      allSubs: subsAsync.value!,
    ),
  );
});

// Debt combiner
