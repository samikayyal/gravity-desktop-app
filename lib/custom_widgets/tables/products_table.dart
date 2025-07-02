import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/custom_widgets/tables/table.dart';
import 'package:gravity_desktop_app/models/product.dart';
import 'package:gravity_desktop_app/providers/product_provider.dart';
import 'package:intl/intl.dart';

class ProductsTable extends ConsumerStatefulWidget {
  const ProductsTable({super.key});

  @override
  ConsumerState<ProductsTable> createState() => _ProductsTableState();
}

class _ProductsTableState extends ConsumerState<ProductsTable> {
  final formatter = NumberFormat.decimalPattern();

  // Scrolling controller for vertical scrolling only
  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(
          'Table Error: $error',
          style: AppTextStyles.regularTextStyle.copyWith(color: Colors.red),
        ),
      ),
      data: (products) {
        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.remove_shopping_cart,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 24),
                Text(
                  'No Products',
                  style: AppTextStyles.regularTextStyle.copyWith(
                    color: Colors.grey,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Products you add will appear here',
                  style: AppTextStyles.regularTextStyle.copyWith(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        // Use a vertically scrollable table that fills the available space
        return TableContainer(
          verticalController: _verticalController,
          columnHeaders: [
            'Product Name',
            'Price',
            'Quantity',
          ],
          columnWidths: {
            0: const FlexColumnWidth(2.0), // Product name
            1: const FlexColumnWidth(1.5), // Price
            2: const FlexColumnWidth(1.5), // Quantity
          },
          rowData: [
            for (int i = 0; i < products.length; i++)
              _buildTableRow(context, products[i], i),
          ],
        );
      },
    );
  }

  // Create a table row for each product
  TableRow _buildTableRow(BuildContext context, Product product, int index) {
    final String productName = product.name;
    final String productPrice = formatter.format(product.price);
    final String quantityAvailable =
        formatter.format(product.quantityAvailable);

    final TextStyle cellStyle = AppTextStyles.tableCellStyle;
    final TextStyle amountStyle = AppTextStyles.amountTextStyle;

    return TableRow(
      decoration: BoxDecoration(
        color:
            index.isEven ? TableThemes.evenRowColor : TableThemes.oddRowColor,
      ),
      children: [
        buildDataCell(productName, style: cellStyle),
        buildDataCell(productPrice, style: amountStyle),
        buildDataCell(quantityAvailable, style: amountStyle),
      ],
    );
  }
}
