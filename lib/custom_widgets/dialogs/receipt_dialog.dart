import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/my_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/models/product.dart';
import 'package:gravity_desktop_app/providers/database_provider.dart';
import 'package:gravity_desktop_app/providers/product_provider.dart';
import 'package:gravity_desktop_app/providers/time_prices_provider.dart';
import 'package:gravity_desktop_app/utils/fee_calculator.dart';
import 'package:intl/intl.dart';

enum TipType { returnChange, takeAsTip }

class ReceiptDialog extends ConsumerStatefulWidget {
  final Player player;
  const ReceiptDialog(this.player, {super.key});

  @override
  ConsumerState<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends ConsumerState<ReceiptDialog> {
  final formatter = NumberFormat.decimalPattern();
  late final Duration timeSpent;

  final TextEditingController _amountReceivedController =
      TextEditingController();

  int _change = 0;
  int _tip = 0;
  bool _isCheckoutEnabled = false;
  TipType? _tipType;

  List<Product> get products => ref.watch(productsProvider).valueOrNull ?? [];

  @override
  void initState() {
    timeSpent = DateTime.now().toUtc().difference(widget.player.checkInTime);
    super.initState();
  }

  @override
  void dispose() {
    _amountReceivedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pricesAsync = ref.watch(pricesProvider);

    return pricesAsync.when(
      data: (prices) {
        final String formattedTimeSpent =
            '${timeSpent.inHours}h ${timeSpent.inMinutes.remainder(60)}m';

        final String formattedCheckInTime =
            DateFormat('h:mm a').format(widget.player.checkInTime.toLocal());

        final int finalFee = calculateFinalFee(
            timeSpent: timeSpent,
            prices: prices,
            productsBought: widget.player.productsBought,
            allProducts: products);
        final int amountLeft = finalFee - widget.player.amountPaid;

        final Map<int, int> productsBought = widget.player.productsBought;

        return MyDialog(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Center(
                  child: Text(
                    "Receipt",
                    style: GoogleFonts.notoSans(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF3949AB),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    widget.player.name,
                    style: GoogleFonts.notoSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Check-in details section
                Text("Session Details",
                    style: AppTextStyles.sectionHeaderStyle),
                const SizedBox(height: 8),
                _buildInfoRow("Check-in Time:", formattedCheckInTime),
                _buildInfoRow("Time Spent:", formattedTimeSpent),
                if (widget.player.productsBought.isNotEmpty)
                  _buildInfoRow("Time Fee:",
                      "${formatter.format(calculateFinalFee(timeSpent: timeSpent, prices: prices))} SYP"),
                const SizedBox(height: 16),

                if (productsBought.isNotEmpty) ...[
                  Text("Products Bought",
                      style: AppTextStyles.sectionHeaderStyle),
                  const SizedBox(height: 8),
                  ...productsBought.entries.map((entry) {
                    // Find the product by ID
                    if (products.isEmpty) {
                      return const CircularProgressIndicator();
                    }
                    final product = products.firstWhere(
                      (p) => p.id == entry.key,
                    );
                    final productName = product.name;
                    final productPrice = product.price;
                    final quantity = entry.value;

                    return _buildInfoRow(
                      "$quantity * $productName:",
                      "${formatter.format(productPrice * quantity)} SYP",
                    );
                  }),
                  const SizedBox(height: 16),
                ],

                // Payment details section
                const Divider(height: 24, thickness: 1),
                Text("Payment Summary",
                    style: AppTextStyles.sectionHeaderStyle),
                const SizedBox(height: 12),
                _buildInfoRow("Final Fee:", "${formatter.format(finalFee)} SYP",
                    isHighlighted: true),
                _buildInfoRow("Amount Paid:",
                    "${formatter.format(widget.player.amountPaid)} SYP"),
                const Divider(height: 24, thickness: 1),
                _buildInfoRow(
                    "Amount Left:", "${formatter.format(amountLeft)} SYP",
                    isHighlighted: true),
                const SizedBox(height: 20),

                // Amount received input
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Amount Received",
                          style: AppTextStyles.sectionHeaderStyle),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amountReceivedController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          hintText: "Enter amount received",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            int amountReceived = int.tryParse(value) ?? 0;
                            _change = amountReceived - amountLeft;
                            _isCheckoutEnabled = (amountReceived > amountLeft &&
                                    _tipType != null) ||
                                amountReceived == amountLeft;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildChangeDisplay(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tip options section
                if (_change > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 24, thickness: 1),
                      Text("Change Options",
                          style: AppTextStyles.sectionHeaderStyle),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _tipType = TipType.takeAsTip;
                                  _tip = _change;
                                  _isCheckoutEnabled = true;
                                });
                              },
                              style: _tipType == TipType.takeAsTip
                                  ? AppButtonStyles.primaryButton
                                  : AppButtonStyles.secondaryButton,
                              child: Text("Take as Tip",
                                  style: AppTextStyles.primaryButtonTextStyle),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _tipType = TipType.returnChange;
                                  _tip = 0;
                                  _isCheckoutEnabled = true;
                                });
                              },
                              style: _tipType == TipType.returnChange
                                  ? AppButtonStyles.primaryButton
                                  : AppButtonStyles.secondaryButton,
                              child: Text("Return Change",
                                  style: AppTextStyles.primaryButtonTextStyle),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                // Action display
                if (_tipType != null)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    child: Text(
                      _tipType == TipType.returnChange
                          ? "Action: Return $_change SYP as change"
                          : "Action: Take $_change SYP as tip",
                      style: GoogleFonts.notoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF2E7D32),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Action buttons
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: AppButtonStyles.secondaryButton,
                      child: Text("Cancel",
                          style: AppTextStyles.primaryButtonTextStyle),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isCheckoutEnabled
                          ? () {
                              int amountReceived = int.tryParse(
                                      _amountReceivedController.text) ??
                                  0;

                              if (_tipType == TipType.returnChange) {
                                amountReceived -= _change;
                              }

                              ref
                                  .read(currentPlayersProvider.notifier)
                                  .checkOutPlayer(
                                      sessionID: widget.player.sessionID,
                                      finalFee: finalFee,
                                      amountPaid: amountReceived,
                                      tips: _tip);
                              Navigator.of(context).pop();
                            }
                          : null,
                      style: _isCheckoutEnabled
                          ? AppButtonStyles.primaryButton
                          : ButtonStyle(
                              backgroundColor:
                                  WidgetStateProperty.all(Colors.grey[300]),
                              foregroundColor:
                                  WidgetStateProperty.all(Colors.grey[600]),
                              padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(
                                    horizontal: 24.0, vertical: 16.0),
                              ),
                              shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                            ),
                      child: Text("Confirm",
                          style: AppTextStyles.primaryButtonTextStyle),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => MyDialog(
        width: null, // Let the dialog size itself
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Loading Prices',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            CircularProgressIndicator(),
            SizedBox(height: 8),
          ],
        ),
      ),
      error: (error, stackTrace) => MyDialog(
        width: null, // Let the dialog size itself
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Failed to load prices: $error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: AppButtonStyles.secondaryButton,
              child: Text('Close', style: AppTextStyles.primaryButtonTextStyle),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build info rows with a label and value
  Widget _buildInfoRow(String label, String value,
      {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.regularTextStyle),
          Text(
            value,
            style: isHighlighted
                ? AppTextStyles.highlightedTextStyle
                : AppTextStyles.amountTextStyle,
          ),
        ],
      ),
    );
  }

  // Helper method to build the change display
  Widget _buildChangeDisplay() {
    if (_change > 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F0F8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Change:", style: AppTextStyles.regularTextStyle),
            Text(
              "${formatter.format(_change)} SYP",
              style: AppTextStyles.highlightedTextStyle.copyWith(
                color: const Color(0xFF1976D2),
              ),
            ),
          ],
        ),
      );
    } else if (_change == 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F0E8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Change:", style: AppTextStyles.regularTextStyle),
            Text(
              "No Change",
              style: AppTextStyles.highlightedTextStyle.copyWith(
                color: const Color(0xFF388E3C),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Still Owed:", style: AppTextStyles.regularTextStyle),
            Text(
              "${-_change} SYP",
              style: AppTextStyles.highlightedTextStyle.copyWith(
                color: const Color(0xFFD32F2F),
              ),
            ),
          ],
        ),
      );
    }
  }
}
