import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/my_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/models/product.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:gravity_desktop_app/providers/product_provider.dart';
import 'package:intl/intl.dart';

class ProductPurchaseDialog extends ConsumerStatefulWidget {
  final Player? player;

  const ProductPurchaseDialog({super.key, this.player});

  @override
  ConsumerState<ProductPurchaseDialog> createState() =>
      _ProductPurchaseDialogState();
}

class _ProductPurchaseDialogState extends ConsumerState<ProductPurchaseDialog> {
  // <productId, quantity>
  final Map<int, int> _cart = {};
  final formatter = NumberFormat.decimalPattern();

  bool _isAddingToDatabase = false;

  @override
  void initState() {
    // Initialize the cart with existing products if the player is provided
    if (widget.player != null) {
      final player = widget.player!;
      for (var entry in player.productsBought.entries) {
        _cart[entry.key] = entry.value;
      }
    }

    super.initState();
  }

  void _onQuantityChanged(Product product, int newQuantity) {
    // Ensure the new quantity is within valid bounds
    if (newQuantity < 0 || newQuantity > product.quantityAvailable) return;

    setState(() {
      if (newQuantity > 0) {
        _cart[product.id] = newQuantity;
      } else {
        // Remove from cart if quantity becomes zero
        _cart.remove(product.id);
      }
    });
  }

  int _calculateTotalPrice(List<Product> allProducts) {
    if (_cart.isEmpty) return 0;
    int total = 0;
    _cart.forEach((productId, quantity) {
      final product = allProducts.firstWhere((p) => p.id == productId);
      total += product.price * quantity;
    });
    return total;
  }

  Future<void> _onConfirmPurchase(List<Product> allProducts) async {
    if (_cart.isEmpty) return;

    // ------------------------- SEPARATE PURCHASE
    if (widget.player == null) {
      // Create the Map<Product, int> expected by the provider
      final Map<Product, int> cartForProvider = {
        for (var entry in _cart.entries)
          allProducts.firstWhere((p) => p.id == entry.key): entry.value
      };

      try {
        await ref
            .read(productsProvider.notifier)
            .recordSeparatePurchase(cart: cartForProvider);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                backgroundColor: Colors.red.shade700,
                content: Text('Error: ${e.toString()}')),
          );
        }
      }
    } else {
      // ------------------------- PLAYER PURCHASE
      final player = widget.player!;
      player.clearProducts();

      for (var entry in _cart.entries) {
        player.addProduct(entry.key, entry.value);

        setState(() {
          _isAddingToDatabase = true;
        });

        // update the database
        await ref.read(databaseProvider).updatePlayerProducts(player);

        setState(() {
          _isAddingToDatabase = false;
        });
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productsProvider);

    return MyDialog(
      width: 600,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              widget.player == null
                  ? 'Separate Purchase'
                  : 'Purchase for ${widget.player!.name}',
              style: AppTextStyles.sectionHeaderStyle),
          const SizedBox(height: 16),
          const Divider(),
          productsState.when(
            loading: () => const Center(
                heightFactor: 5, child: CircularProgressIndicator()),
            error: (err, stack) => Center(
                heightFactor: 5, child: Text('Error loading products: $err')),
            data: (products) {
              final availableProducts =
                  products.where((p) => p.quantityAvailable > 0).toList();
              final totalPrice = _calculateTotalPrice(products);

              return Column(
                children: [
                  _buildProductList(availableProducts),
                  const SizedBox(height: 24),
                  _buildPriceSummary(totalPrice),
                  const SizedBox(height: 32),
                  _buildActionButtons(products),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(List<Product> products) {
    return products.isEmpty
        ? Center(
            heightFactor: 3,
            child: Text(
              'No products available for purchase.',
              style: AppTextStyles.subtitleTextStyle,
            ),
          )
        : ListView.separated(
            shrinkWrap: true,
            itemCount: products.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = products[index];
              final quantityInCart = _cart[product.id] ?? 0;
              return _ProductListItem(
                product: product,
                quantity: quantityInCart,
                onQuantityChanged: (newQuantity) {
                  _onQuantityChanged(product, newQuantity);
                },
              );
            },
          );
  }

  Widget _buildPriceSummary(int totalPrice) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total Price',
              style: AppTextStyles.regularTextStyle
                  .copyWith(fontWeight: FontWeight.bold)),
          Text(
            '${formatter.format(totalPrice)} SYP',
            style: AppTextStyles.highlightedTextStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(List<Product> allProducts) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: AppButtonStyles.secondaryButton,
          child: Text('Cancel', style: AppTextStyles.secondaryButtonTextStyle),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _isAddingToDatabase
              ? null
              : _cart.isNotEmpty
                  ? () => _onConfirmPurchase(allProducts)
                  : null,
          style: AppButtonStyles.primaryButton,
          child: _isAddingToDatabase
              ? const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.0,
                )
              : Text('Confirm Purchase',
                  style: AppTextStyles.primaryButtonTextStyle),
        ),
      ],
    );
  }
}

/// A private widget to represent a single product row in the purchase dialog.
class _ProductListItem extends StatelessWidget {
  const _ProductListItem({
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
  });

  final Product product;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: AppTextStyles.regularTextStyle),
                const SizedBox(height: 4),
                Text(
                  '${formatter.format(product.price)} SYP  •  ${product.quantityAvailable} in stock',
                  style: AppTextStyles.subtitleTextStyle,
                ),
              ],
            ),
          ),
          _buildQuantitySelector(),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueGrey.shade200, width: 1.5),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed:
                quantity > 0 ? () => onQuantityChanged(quantity - 1) : null,
            style: AppButtonStyles.iconButtonCircle.copyWith(
              shape: const WidgetStatePropertyAll(RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(6),
                      bottomLeft: Radius.circular(6)))),
              side: WidgetStateProperty.all(BorderSide.none),
            ),
            splashRadius: 20,
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppTextStyles.amountTextStyle,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: quantity < product.quantityAvailable
                ? () => onQuantityChanged(quantity + 1)
                : null,
            style: AppButtonStyles.iconButtonCircle.copyWith(
              shape: const WidgetStatePropertyAll(RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                      topRight: Radius.circular(6),
                      bottomRight: Radius.circular(6)))),
              side: WidgetStateProperty.all(BorderSide.none),
            ),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
