// ignore: unused_import
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/my_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text_field.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/models/product.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:gravity_desktop_app/providers/product_provider.dart';
import 'package:gravity_desktop_app/screens/receipt.dart';
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

  final _formKey = GlobalKey<FormState>();
  DiscountType _discountType = DiscountType.none;
  final _discountController = TextEditingController();

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
    if (newQuantity < 0 || newQuantity > product.effectiveStock) return;

    setState(() {
      if (newQuantity > 0) {
        _cart[product.id] = newQuantity;
      } else {
        // Remove from cart if quantity becomes zero
        _cart.remove(product.id);
      }
    });
  }

  int _calculateDiscount(List<Product> allProducts) {
    if (_discountType == DiscountType.input) {
      return int.tryParse(_discountController.text) ?? 0;
    } else if (_discountType == DiscountType.gift) {
      return _calculateTotalPrice(allProducts);
    }
    return 0;
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
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }
    // ------------------------- SEPARATE PURCHASE
    if (widget.player == null) {
      // Create the Map<Product, int> expected by the provider
      final Map<Product, int> cartForProvider = {
        for (var entry in _cart.entries)
          allProducts.firstWhere((p) => p.id == entry.key): entry.value
      };

      if (cartForProvider.isEmpty) return;

      try {
        await ref.read(productsProvider.notifier).recordSeparatePurchase(
            cart: cartForProvider, discount: _calculateDiscount(allProducts));
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
      setState(() {
        _isAddingToDatabase = true;
      });

      for (var entry in _cart.entries) {
        player.addProduct(entry.key, entry.value);
      }
      // update the database
      // TODO: Move this to a provider, either products or players
      await ref.read(databaseProvider).updatePlayerProducts(player);
      await ref.read(productsProvider.notifier).refresh();
      setState(() {
        _isAddingToDatabase = false;
      });
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
                  products.where((p) => p.effectiveStock > 0).toList();
              return Column(
                children: [
                  _buildProductList(availableProducts),
                  if (widget.player == null) ...[
                    const SizedBox(height: 12),
                    _buildDiscountButtons(),
                  ],
                  if (_discountType == DiscountType.input) ...[
                    const SizedBox(height: 12),
                    MyTextField(
                      controller: _discountController,
                      labelText: 'Discount Amount',
                      hintText: 'Enter discount amount',
                      isNumberInputOnly: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a discount amount';
                        }
                        final amount = int.tryParse(value);
                        if (amount == null ||
                            amount < 0 ||
                            amount > _calculateTotalPrice(products)) {
                          return 'Invalid discount amount';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {
                          // Trigger a rebuild to update the price summary
                        });
                      },
                    )
                  ],
                  const SizedBox(height: 12),
                  _buildPriceSummary(products),
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
              return ProductListItem(
                product: product,
                quantity: quantityInCart,
                onQuantityChanged: (newQuantity) {
                  _onQuantityChanged(product, newQuantity);
                },
              );
            },
          );
  }

  Widget _buildPriceSummary(List<Product> allProducts) {
    final totalPrice = _calculateTotalPrice(allProducts);
    final discount = _calculateDiscount(allProducts);
    final discountedPrice = totalPrice - discount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Price',
              style: AppTextStyles.sectionHeaderStyle
                  .copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
          if (_discountType == DiscountType.none)
            Text(
              '${formatter.format(totalPrice)} SYP',
              style: AppTextStyles.highlightedTextStyle,
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Total: ${formatter.format(totalPrice)} SYP',
                  style: AppTextStyles.regularTextStyle,
                ),
                const SizedBox(height: 4),
                Text(
                  'Discount: ${formatter.format(discount)} SYP',
                  style: AppTextStyles.regularTextStyle.copyWith(
                      color: Colors.red.shade700, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Final Price: ${formatter.format(discountedPrice)} SYP',
                  style:
                      AppTextStyles.highlightedTextStyle.copyWith(fontSize: 22),
                ),
              ],
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
              : () async => await _onConfirmPurchase(allProducts),
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

  Widget _buildDiscountButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
          onPressed: () {
            setState(() {
              if (_discountType == DiscountType.input) {
                _discountType = DiscountType.none;
              } else {
                _discountType = DiscountType.input;
              }
            });
          },
          style: _discountType == DiscountType.input
              ? AppButtonStyles.primaryButton
              : AppButtonStyles.secondaryButton,
          child: Text('Discount',
              style: _discountType == DiscountType.input
                  ? AppTextStyles.primaryButtonTextStyle
                  : AppTextStyles.secondaryButtonTextStyle),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () {
            setState(() {
              if (_discountType == DiscountType.gift) {
                _discountType = DiscountType.none;
              } else {
                _discountType = DiscountType.gift;
              }
            });
          },
          style: _discountType == DiscountType.gift
              ? AppButtonStyles.primaryButton
              : AppButtonStyles.secondaryButton,
          child: Text('Gift',
              style: _discountType == DiscountType.gift
                  ? AppTextStyles.primaryButtonTextStyle
                  : AppTextStyles.secondaryButtonTextStyle),
        ),
      ],
    );
  }
}

/// A private widget to represent a single product row in the purchase dialog.
class ProductListItem extends StatelessWidget {
  const ProductListItem({
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
    super.key,
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
                  '${formatter.format(product.price)} SYP  •  ${product.effectiveStock} in stock',
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
            onPressed: quantity < product.effectiveStock
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
