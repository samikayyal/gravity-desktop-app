import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/models/product.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';

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

  /// Adds a new product to the database
  Future<void> addProduct({
    required String name,
    required int price,
    required int quantityAvailable,
  }) async {
    try {
      await _dbHelper.addProduct(
        name: name,
        price: price,
        quantityAvailable: quantityAvailable,
      );
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  /// Updates an existing product in the database
  Future<void> updateProduct({
    required int productId,
    String? name,
    int? price,
    int? quantityAvailable,
  }) async {
    try {
      await _dbHelper.updateProduct(
        productId: productId,
        name: name,
        price: price,
        quantityAvailable: quantityAvailable,
      );
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes a product from the database
  Future<void> deleteProduct(int productId) async {
    try {
      await _dbHelper.deleteProduct(productId);
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> recordSeparatePurchase(
      {required Map<Product, int> cart, required int discount}) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final db = await _dbHelper.database;

    cart.removeWhere((Product product, quantity) =>
        quantity <= 0 || product.effectiveStock < quantity);

    if (cart.isEmpty) {
      throw Exception('Cart is empty or all products have insufficient stock.');
    }

    await db.transaction((txn) async {
      int finalFee = 0;
      for (var entry in cart.entries) {
        // calc final fee
        final Product product = entry.key;
        final int quantity = entry.value;
        finalFee += product.price * quantity;

        // update the product quantity
        await txn.rawUpdate(
          '''
          UPDATE products
          SET quantity_available = quantity_available - ?
          WHERE product_id = ?
          ''',
          [quantity, product.id],
        );
      }
      final int amountPaid = finalFee - discount;

      // insert into sales
      final int saleId = await txn.insert('sales', {
        'session_id': null,
        'final_fee': finalFee,
        'amount_paid': amountPaid,
        'tips': 0,
        'discount': discount,
        'sale_time': nowIso,
        'last_modified': nowIso
      });

      // insert into sale_items
      for (var entry in cart.entries) {
        final Product product = entry.key;
        final int quantity = entry.value;

        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': product.id,
          'quantity': quantity,
          'price_per_item': product.price,
          'last_modified': nowIso,
        });
      }
    });
    await refresh();
  }
}
