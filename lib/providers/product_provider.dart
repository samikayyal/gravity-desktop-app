import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/models/product.dart';
import 'package:gravity_desktop_app/providers/database_provider.dart';

final productsProvider =
    StateNotifierProvider<ProductsNotifier, AsyncValue<List<Product>>>((ref) {
  final dbHelper = ref.watch(databaseProvider);
  return ProductsNotifier(dbHelper);
});

// The Notifier class that holds and manages the list of products.
class ProductsNotifier extends StateNotifier<AsyncValue<List<Product>>> {
  final DatabaseHelper _dbHelper;

  ProductsNotifier(this._dbHelper) : super(const AsyncValue.loading()) {
    _fetchProducts(); // Fetch initial data
  }

  // Fetch products from the database and update the state
  Future<void> _fetchProducts() async {
    state = const AsyncValue.loading();
    try {
      final products = await _dbHelper.getProducts();
      state = AsyncValue.data(products);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Refreshes the product list from the database.
  Future<void> refresh() async {
    await _fetchProducts();
  }

  /// Handles the logic for purchasing a product.
  Future<void> purchaseProduct({
    required Product product,
    required int quantity,
  }) async {
    if (quantity <= 0 || quantity > product.quantityAvailable) {
      // This is a safeguard; the UI should prevent this.
      throw Exception("Invalid quantity for purchase.");
    }
    await _dbHelper.recordSeparatePurchase(
      productId: product.id,
      quantity: quantity,
    );
    await refresh(); // Refresh the list to show updated quantities
  }

    /// Handles the logic for purchasing multiple products at once.
  Future<void> purchaseMultipleProducts({
    required Map<Product, int> cart,
  }) async {
    // Filter out any items with a quantity of 0 and convert the map
    // to the Map<productId, quantity> format expected by the database.
    final Map<int, int> purchases = {
      for (var entry in cart.entries)
        if (entry.value > 0) entry.key.id: entry.value
    };

    if (purchases.isEmpty) {
      return; // Nothing to purchase
    }

    await _dbHelper.recordMultipleSeparatePurchases(purchases: purchases);
    await refresh(); // Refresh the product list to show updated quantities
  }
}