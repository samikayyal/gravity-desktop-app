import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
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
          'Table Error: $error \n$stackTrace',
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
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(50),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Scrollbar(
            controller: _verticalController,
            thumbVisibility: true,
            thickness: 8,
            radius: const Radius.circular(4),
            child: SingleChildScrollView(
              controller: _verticalController,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Table(
                    border: TableBorder(
                      horizontalInside: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    columnWidths: {
                      0: const FlexColumnWidth(2.0), // Product name
                      1: const FlexColumnWidth(1.5), // Price
                      2: const FlexColumnWidth(1.5), // Quantity
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      // Header Row
                      TableRow(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5F5F5),
                        ),
                        children: [
                          _buildHeaderCell('Product Name'),
                          _buildHeaderCell('Price'),
                          _buildHeaderCell('Quantity'),
                        ],
                      ),
                      // Data Rows
                      ...products
                          .map((product) => _buildTableRow(context, product)),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method to build header cells
  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Text(
        text,
        style: AppTextStyles.sectionHeaderStyle.copyWith(fontSize: 18),
      ),
    );
  }

  // Helper method to build regular data cells
  Widget _buildDataCell(String text, {TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: style ?? AppTextStyles.regularTextStyle,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // Create a table row for each product
  TableRow _buildTableRow(BuildContext context, Product product) {
    final String productName = product.name;
    final String productPrice = formatter.format(product.price);
    final String quantityAvailable =
        formatter.format(product.quantityAvailable);

    final TextStyle cellStyle = AppTextStyles.tableCellStyle;
    final TextStyle amountStyle = AppTextStyles.amountTextStyle;

    return TableRow(
      children: [
        _buildDataCell(productName, style: cellStyle),
        _buildDataCell(productPrice, style: amountStyle),
        _buildDataCell(quantityAvailable, style: amountStyle),
      ],
    );
  }
}
