import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/models/product.dart';
import 'package:gravity_desktop_app/providers/product_provider.dart';
import 'package:intl/intl.dart';

// Enum to manage the state of the right-side detail panel
enum DetailPanelMode { idle, adding, editing }

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formatter = NumberFormat.decimalPattern();
  final _formKey = GlobalKey<FormState>();

  // State for the detail panel
  DetailPanelMode _panelMode = DetailPanelMode.idle;
  Product? _selectedProduct;

  // Form controllers
  final _addNameController = TextEditingController();
  final _addPriceController = TextEditingController();
  final _addQuantityController = TextEditingController();
  final _editPriceController = TextEditingController();
  final _addStockController = TextEditingController();
  int _resultingQuantity = 0;

  @override
  void dispose() {
    _addNameController.dispose();
    _addPriceController.dispose();
    _addQuantityController.dispose();
    _editPriceController.dispose();
    _addStockController.dispose();
    super.dispose();
  }

  /// Switches the right panel to the "Add New Product" form.
  void _switchToAddNew() {
    setState(() {
      _panelMode = DetailPanelMode.adding;
      _selectedProduct = null;
      _formKey.currentState?.reset();
      _addNameController.clear();
      _addPriceController.clear();
      _addQuantityController.clear();
    });
  }

  /// Switches the right panel to the "Edit Product" form for the given product.
  void _selectProduct(Product product) {
    setState(() {
      _panelMode = DetailPanelMode.editing;
      _selectedProduct = product;
      _formKey.currentState?.reset();

      // Pre-fill controllers for editing
      _editPriceController.text = product.price.toString();
      _addStockController.clear();
      _resultingQuantity = product.quantityAvailable;
    });
  }

  /// Resets the right panel to its initial idle state.
  void _resetPanel() {
    setState(() {
      _panelMode = DetailPanelMode.idle;
      _selectedProduct = null;
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: const MyAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMPROVEMENT: Using the new pageTitleStyle for a better header.
            Text('Manage Products', style: AppTextStyles.pageTitleStyle),
            const SizedBox(height: 24),
            Expanded(
              child: productsAsync.when(
                data: (products) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          flex: 2, child: _buildProductListPanel(products)),
                      const VerticalDivider(width: 48, thickness: 1),
                      Expanded(flex: 3, child: _buildDetailPanel()),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A helper to create consistent, styled input fields.
  InputDecoration _buildInputDecoration({
    required String label,
    IconData? icon,
    String? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTextStyles.subtitleTextStyle,
      hintStyle:
          AppTextStyles.subtitleTextStyle.copyWith(color: Colors.grey.shade400),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Color(0xFF3949AB), width: 1.5),
      ),
      filled: true,
      fillColor: Colors.blueGrey.shade50.withAlpha(128),
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade600) : null,
      suffixText: suffix,
    );
  }

  Widget _buildProductListPanel(List<Product> products) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_circle_outline, size: 20),
            label: Text('Add New Product',
                style: AppTextStyles.primaryButtonTextStyle),
            onPressed: _switchToAddNew,
            style: AppButtonStyles.primaryButton,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: products.isEmpty
              ? Center(
                  child: Text(
                  "No products found.\nClick 'Add New Product' to begin.",
                  textAlign: TextAlign.center,
                  // IMPROVEMENT: Using a consistent text style for placeholder text.
                  style: AppTextStyles.subtitleTextStyle,
                ))
              : ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final isSelected = _selectedProduct?.id == product.id;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      elevation: isSelected ? 3 : 1,
                      shadowColor: isSelected
                          ? Theme.of(context).primaryColor.withAlpha(128)
                          : null,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: isSelected
                              ? Color(0xFF3949AB)
                              : Colors.grey.shade300,
                          width: isSelected ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        title: Text(product.name,
                            style: AppTextStyles.regularTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 19,
                              color: isSelected ? Color(0xFF3949AB) : null,
                            )),
                        subtitle: Text(
                          'Price: ${_formatter.format(product.price)} SYP\nStock: ${product.quantityAvailable}',
                          style: AppTextStyles.subtitleTextStyle,
                        ),
                        isThreeLine: true,
                        selected: isSelected,
                        selectedTileColor: Colors.blueGrey.withAlpha(25),
                        onTap: () => _selectProduct(product),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDetailPanel() {
    // IMPROVEMENT: Using a styled card as the base for forms to create a
    // consistent, elevated container.
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: switch (_panelMode) {
              DetailPanelMode.idle => _buildIdlePanel(),
              DetailPanelMode.adding => _buildAddNewProductForm(),
              DetailPanelMode.editing => _buildEditProductForm(),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildIdlePanel() {
    return Center(
      key: const ValueKey('idle'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Select a product to edit or add a new one',
            style: AppTextStyles.subtitleTextStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAddNewProductForm() {
    return SingleChildScrollView(
      key: const ValueKey('add'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // IMPROVEMENT: Consistent header styling.
              Text('Add New Product',
                  style: AppTextStyles.sectionHeaderStyle.copyWith(
                    color: Colors.black87,
                    fontSize: 22,
                  )),
              // IMPROVEMENT: Using your custom styled icon button.
              IconButton(
                onPressed: _resetPanel,
                icon: const Icon(Icons.close),
                style: AppButtonStyles.iconButtonCircle,
                tooltip: "Cancel",
              ),
            ],
          ),
          const Divider(height: 32, thickness: 1),
          // IMPROVEMENT: Using the helper for consistent text fields.
          TextFormField(
            controller: _addNameController,
            style: AppTextStyles.regularTextStyle,
            decoration: _buildInputDecoration(
                label: 'Product Name', icon: Icons.shopping_bag_outlined),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _addPriceController,
            style: AppTextStyles.regularTextStyle,
            decoration: _buildInputDecoration(
                label: 'Price', icon: Icons.attach_money, suffix: 'SYP'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) => (v == null || v.isEmpty || int.tryParse(v)! <= 0)
                ? 'Valid price is required'
                : null,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _addQuantityController,
            style: AppTextStyles.regularTextStyle,
            decoration: _buildInputDecoration(
                label: 'Initial Stock Quantity',
                icon: Icons.production_quantity_limits),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) => (v == null || v.isEmpty || int.tryParse(v)! < 0)
                ? 'Valid quantity is required'
                : null,
          ),
          const SizedBox(height: 32),
          // IMPROVEMENT: Standard Save/Cancel action row.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: _resetPanel,
                style: AppButtonStyles.secondaryButton,
                child: Text('Cancel',
                    style: AppTextStyles.secondaryButtonTextStyle),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _handleAddProduct,
                icon: const Icon(Icons.save, size: 20),
                label: Text('Save Product',
                    style: AppTextStyles.primaryButtonTextStyle),
                style: AppButtonStyles.primaryButton,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditProductForm() {
    if (_selectedProduct == null) return _buildIdlePanel();

    return SingleChildScrollView(
      key: ValueKey(_selectedProduct!.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(_selectedProduct!.name,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.sectionHeaderStyle
                        .copyWith(color: Colors.black87, fontSize: 22)),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _resetPanel,
                style: AppButtonStyles.iconButtonCircle,
                tooltip: "Close",
              ),
            ],
          ),
          const Divider(height: 32, thickness: 1),
          Text("Price", style: AppTextStyles.sectionHeaderStyle),
          const SizedBox(height: 8),
          TextFormField(
            controller: _editPriceController,
            style: AppTextStyles.regularTextStyle,
            decoration: _buildInputDecoration(
                label: 'Product Price',
                icon: Icons.attach_money,
                suffix: 'SYP'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) => (v == null || v.isEmpty || int.tryParse(v)! <= 0)
                ? 'Valid price is required'
                : null,
          ),
          const SizedBox(height: 24),
          Text("Stock Management", style: AppTextStyles.sectionHeaderStyle),
          const SizedBox(height: 8),
          // IMPROVEMENT: Cleaner layout for stock info.
          _buildInfoRow("Current Stock:",
              _formatter.format(_selectedProduct!.quantityAvailable)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _addStockController,
                  style: AppTextStyles.regularTextStyle,
                  decoration: _buildInputDecoration(
                      label: 'Add to Stock', icon: Icons.add_box_outlined),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    final amountToAdd = int.tryParse(value) ?? 0;
                    if (_selectedProduct == null) return;
                    setState(() {
                      _resultingQuantity =
                          _selectedProduct!.quantityAvailable + amountToAdd;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                  child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: _buildInfoRow(
                    "Resulting Stock:", _formatter.format(_resultingQuantity)),
              )),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              ElevatedButton.icon(
                  onPressed: _handleDeleteProduct,
                  label: Text(
                    "Delete Product",
                    style: AppTextStyles.primaryButtonTextStyle.copyWith(
                      color: Colors.red.shade700,
                    ),
                  ),
                  icon:
                      Icon(Icons.delete, size: 20, color: Colors.red.shade700),
                  style: AppButtonStyles.dangerButton.copyWith(
                    backgroundColor: WidgetStateProperty.all<Color>(
                        Colors.red.shade700.withAlpha(15)),
                  )),
              const Spacer(),
              ElevatedButton(
                onPressed: _resetPanel,
                style: AppButtonStyles.secondaryButton,
                child: Text('Cancel',
                    style: AppTextStyles.secondaryButtonTextStyle),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _handleUpdateProduct,
                style: AppButtonStyles.primaryButton,
                icon: const Icon(Icons.save, size: 20),
                label: Text('Update Product',
                    style: AppTextStyles.primaryButtonTextStyle),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // A helper widget for displaying info rows consistently.
  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: AppTextStyles.subtitleTextStyle),
        const SizedBox(width: 8),
        Text(value, style: AppTextStyles.amountTextStyle),
      ],
    );
  }

  void _handleAddProduct() async {
    if (_formKey.currentState?.validate() ?? false) {
      final name = _addNameController.text;
      final price = int.parse(_addPriceController.text);
      final quantity = int.parse(_addQuantityController.text);

      await ref.read(productsProvider.notifier).addProduct(
            name: name,
            price: price,
            quantityAvailable: quantity,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: Colors.green.shade700,
              content: Text('Product "$name" added successfully!')),
        );
      }

      _switchToAddNew(); // Clear form for next entry
    }
  }

  void _handleUpdateProduct() async {
    if ((_formKey.currentState?.validate() ?? false) &&
        _selectedProduct != null) {
      final newPrice = int.tryParse(_editPriceController.text);
      final amountToAdd = int.tryParse(_addStockController.text) ?? 0;

      final originalProduct = _selectedProduct!;
      bool priceChanged = newPrice != originalProduct.price;
      bool stockChanged = amountToAdd > 0;

      if (!priceChanged && !stockChanged) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No changes were made.')),
        );
        return;
      }

      await ref.read(productsProvider.notifier).updateProduct(
            productId: originalProduct.id,
            price: newPrice,
            quantityAvailable: originalProduct.quantityAvailable + amountToAdd,
          );

      // UI will update automatically via ref.listen.
      // We just clear the "add stock" field and show feedback.
      _addStockController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: Colors.green.shade700,
              content: Text('"${originalProduct.name}" updated successfully!')),
        );
      }
    }
  }

  void _handleDeleteProduct() async {
    if (_selectedProduct == null) return;

    final product = _selectedProduct!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Product "${product.name}"?'),
        content: const Text(
            'This action cannot be undone. Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(productsProvider.notifier).deleteProduct(product.id);
      _resetPanel();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Product "${product.name}" deleted successfully!')),
        );
      }
    }
  }
}
