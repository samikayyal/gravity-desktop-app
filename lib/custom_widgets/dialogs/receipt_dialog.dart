import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/providers/database_provider.dart';
import 'package:gravity_desktop_app/utils/fee_calculator.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

enum TipType { returnChange, takeAsTip }

class ReceiptDialog extends ConsumerStatefulWidget {
  final Player player;
  const ReceiptDialog(this.player, {super.key});

  @override
  ConsumerState<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends ConsumerState<ReceiptDialog> {
  late final Duration timeSpent;

  final TextEditingController _amountReceivedController =
      TextEditingController();

  int _change = 0;
  int _tip = 0;
  bool _isCheckoutEnabled = false;
  TipType? _tipType;

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

  // Using shared text styles from my_text.dart

  @override
  Widget build(BuildContext context) {
    final pricesAsync = ref.watch(pricesProvider);

    return pricesAsync.when(
      data: (prices) {
        String formattedTimeSpent =
            '${timeSpent.inHours}h ${timeSpent.inMinutes.remainder(60)}m';

        String formattedCheckInTime =
            DateFormat('h:mm a').format(widget.player.checkInTime.toLocal());

        int finalFee = calculateFinalFee(timeSpent: timeSpent, prices: prices);
        int amountLeft = finalFee - widget.player.amountPaid;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24.0),
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
                const SizedBox(height: 16),

                // Payment details section
                const Divider(height: 24, thickness: 1),
                Text("Payment Summary",
                    style: AppTextStyles.sectionHeaderStyle),
                const SizedBox(height: 12),
                _buildInfoRow("Final Fee:", "$finalFee SYP",
                    isHighlighted: true),
                _buildInfoRow(
                    "Amount Paid:", "${widget.player.amountPaid} SYP"),
                const Divider(height: 24, thickness: 1),
                _buildInfoRow("Amount Left:", "$amountLeft SYP",
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
      loading: () => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
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
      ),
      error: (error, stackTrace) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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
                child: Text('Close',
                    style: AppTextStyles.primaryButtonTextStyle),
              ),
            ],
          ),
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
              "$_change SYP",
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
