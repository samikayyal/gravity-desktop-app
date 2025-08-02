import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/my_card.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text_field.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/models/subscription.dart';
import 'package:gravity_desktop_app/providers/combined_providers.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:gravity_desktop_app/providers/debt_provider.dart';
import 'package:gravity_desktop_app/utils/constants.dart';
import 'package:gravity_desktop_app/utils/fee_calculator.dart';
import 'package:gravity_desktop_app/utils/provider_utils.dart';
import 'package:intl/intl.dart';

enum DiscountType { none, input, gift }

class ReceiptScreen extends ConsumerStatefulWidget {
  final List<int> sessionIds;
  const ReceiptScreen(this.sessionIds, {super.key});

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

enum TipType { returnChange, takeAsTip }

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  //helpers
  final formatter = NumberFormat.decimalPattern();
  late final String nowIso;

  // player variables
  List<Player> players = [];
  List<Duration> timeSpentList = [];
  int _debtAmount = 0;

  // controllers
  final _amountReceivedController = TextEditingController();
  final _discountController = TextEditingController();
  final _discountReasonController = TextEditingController();

  // state variables
  TipType? _tipType;
  DiscountType _discountType = DiscountType.none;
  _ReceiptTotals? _totals;
  int get discountAmount {
    if (_totals == null) return 0;

    if (_discountType == DiscountType.input) {
      return int.tryParse(_discountController.text) ?? 0;
    } else if (_discountType == DiscountType.gift) {
      return _totals!.totalFinalFee - _totals!.totalPrePaidAmount;
    } else {
      return 0;
    }
  }

  bool get isCheckoutEnabled {
    if (_totals == null) return false;

    // if amount received has no value
    if (int.tryParse(_amountReceivedController.text) == null) {
      return false;
    }
    final received = int.parse(_amountReceivedController.text);

    final totalReceived = received + _totals!.totalPrePaidAmount;
    final finalFee = _totals!.totalFinalFeeAfterDiscount;

    final bool isPaidExactly = _debtAmount == 0 && totalReceived == finalFee;
    final bool isOverpaidWithTipSelected =
        _debtAmount == 0 && totalReceived > finalFee && _tipType != null;
    final bool isResolvingDebt = _debtAmount > 0 && _tipType == null;

    return isPaidExactly || isOverpaidWithTipSelected || isResolvingDebt;
  }

  bool get isGroupCheckout => players.length > 1;

  @override
  Widget build(BuildContext context) {
    if (players.length != widget.sessionIds.length) {
      return Scaffold(
        appBar: MyAppBar(),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return ref.watch(pricesProductsSubsProvider).maybeWhen(
        data: (receiptData) {
          _totals = _calculateTotals(receiptData);

          return Scaffold(
            appBar: MyAppBar(),
            body: Center(
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Row(
                  children: [
                    // LEFT SIDE
                    Expanded(
                      flex: 1,
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildReceiptHeader(),
                              _buildSessionDetails(receiptData),
                              const SizedBox(height: 16),
                              if (_totals!.combinedProductsBought.isNotEmpty)
                                _buildProductsCard(receiptData),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // RIGHT SIDE
                    Expanded(
                      flex: 1,
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildPaymentOptions(),
                              const SizedBox(height: 24),
                              _buildActionButtons(receiptData),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        orElse: () => Scaffold(
              appBar: MyAppBar(),
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ));
  }

  @override
  void initState() {
    nowIso = DateTime.now().toUtc().toIso8601String();
    _loadPlayers();
    super.initState();
  }

  Widget _buildActionButtons(PricesProductsSubs receiptData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.cancel_outlined),
            label:
                Text("Cancel", style: AppTextStyles.secondaryButtonTextStyle),
            onPressed: () => Navigator.of(context).pop(),
            style: AppButtonStyles.secondaryButton,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              "Complete Checkout",
              style: AppTextStyles.primaryButtonTextStyle,
            ),
            onPressed:
                isCheckoutEnabled ? () => _performCheckout(receiptData) : null,
            style: isCheckoutEnabled
                ? AppButtonStyles.primaryButton
                : ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(Colors.grey[300]),
                    foregroundColor: WidgetStateProperty.all(Colors.grey[600]),
                    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 16.0)),
                    shape: WidgetStateProperty.all(RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0))),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionConfirmation() {
    final int change = (int.tryParse(_amountReceivedController.text) ?? 0) -
        (_totals!.totalFinalFeeAfterDiscount - _totals!.totalPrePaidAmount);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Row(
        children: [
          Icon(
            _tipType == TipType.returnChange
                ? Icons.payments_outlined
                : Icons.savings,
            color: const Color(0xFF2E7D32),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _tipType == TipType.returnChange
                  ? "Return ${formatter.format(change)} SYP as change"
                  : "Keep ${formatter.format(change)} SYP as tip",
              style: AppTextStyles.regularTextStyle.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeDisplay() {
    final int change = (int.tryParse(_amountReceivedController.text) ?? 0) -
        (_totals!.totalFinalFeeAfterDiscount - _totals!.totalPrePaidAmount);
    if (change > 0) {
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
              "${formatter.format(change)} SYP",
              style: AppTextStyles.highlightedTextStyle.copyWith(
                color: const Color(0xFF1976D2),
              ),
            ),
          ],
        ),
      );
    } else if (change == 0) {
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
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_debtAmount > 0 ? "Player Debt:" : "Still Owed:",
                    style: AppTextStyles.regularTextStyle),
                Text(
                  "${formatter.format(-change)} SYP",
                  style: AppTextStyles.highlightedTextStyle.copyWith(
                    color: const Color(0xFFD32F2F),
                  ),
                ),
              ],
            ),
            if (_debtAmount == 0 && !isGroupCheckout) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("Confirm Debt"),
                          content: const Text(
                              "Are you sure you want to record this as a debt?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text("Confirm"),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirm == true) {
                      // "if (confirm)" doesnt work idk why
                      setState(() {
                        _debtAmount = -change;
                        _tipType = TipType.returnChange;
                      });
                    }
                  },
                  style: AppButtonStyles.dangerButton,
                  child: Text(
                    "Debt",
                    style: AppTextStyles.dangerButtonTextStyle,
                  ),
                ),
              )
            ]
          ],
        ),
      );
    }
  }

  Widget _buildDiscountOptions() {
    return _debtAmount > 0
        ? const SizedBox.shrink()
        : Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Apply Discount",
                    style: AppTextStyles.regularTextStyle
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(
                          Icons.discount,
                          size: 18,
                          color: _discountType == DiscountType.input
                              ? mainBlue
                              : Colors.grey,
                        ),
                        label: Text(
                          "Discount",
                          style: _discountType == DiscountType.input
                              ? AppTextStyles.primaryButtonTextStyle
                              : AppTextStyles.secondaryButtonTextStyle,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_discountType == DiscountType.input) {
                              _discountType = DiscountType.none;
                              _discountController.clear();
                            } else {
                              _discountType = DiscountType.input;
                            }
                          });
                        },
                        style: _discountType == DiscountType.input
                            ? AppButtonStyles.primaryButton
                            : AppButtonStyles.secondaryButton,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.card_giftcard,
                            size: 18,
                            color: _discountType == DiscountType.gift
                                ? mainBlue
                                : Colors.grey),
                        label: Text(
                          "Gift",
                          style: _discountType == DiscountType.gift
                              ? AppTextStyles.primaryButtonTextStyle
                              : AppTextStyles.secondaryButtonTextStyle,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_discountType == DiscountType.gift) {
                              _discountType = DiscountType.none;
                            } else {
                              _discountType = DiscountType.gift;
                              _amountReceivedController.text = '0';
                              _tipType = null;
                            }
                          });
                        },
                        style: _discountType == DiscountType.gift
                            ? AppButtonStyles.primaryButton
                            : AppButtonStyles.secondaryButton,
                      ),
                    ),
                  ],
                ),
                if (_discountType == DiscountType.input) ...[
                  const SizedBox(height: 16),
                  MyTextField(
                    controller: _discountController,
                    labelText: "Discount Amount (SYP)",
                    hintText: "Enter discount amount",
                    isNumberInputOnly: true,
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter a discount amount";
                      }
                      final int? amount = int.tryParse(value);

                      if (amount == null || amount <= 0) {
                        return "Please enter a valid discount amount";
                      }

                      if (amount > _totals!.totalFinalFee) {
                        return "Discount amount cannot exceed total fee";
                      }

                      return null;
                    },
                  ),
                ],
                if (_discountType != DiscountType.none) ...[
                  const SizedBox(height: 12),
                  MyTextField(
                    controller: _discountReasonController,
                    labelText: "Reason for Discount",
                    hintText: "Enter reason for discount",
                  )
                ],
              ],
            ),
          );
  }

  Widget _buildGroupPlayerSessionDetails(PricesProductsSubs receiptData) {
    return Column(
      children: [
        for (int i = 0; i < players.length; i++) ...[
          () {
            final player = players[i];
            final timeSpent = timeSpentList[i];
            final String formattedTimeSpent =
                '${timeSpent.inHours}h ${timeSpent.inMinutes.remainder(60)}m';
            final String formattedCheckInTime =
                DateFormat('h:mm a').format(player.checkInTime.toLocal());

            return Column(children: [
              // Player header
              if (i > 0) const Divider(height: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  player.name,
                  style: AppTextStyles.sectionHeaderStyle.copyWith(
                    color: Colors.blue.shade700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow("Amount Paid", formatter.format(player.amountPaid)),
              _buildInfoRow("Check-In Time", formattedCheckInTime),
              _buildInfoRow("Time Spent", formattedTimeSpent),

              // Individual player fee
              ...() {
                final playerFee = calculateFinalFee(
                    timeReserved: player.timeReserved,
                    isOpenTime: player.isOpenTime,
                    timeExtendedMinutes: player.timeExtended.inMinutes,
                    timeSpent: timeSpent,
                    prices: receiptData.prices,
                    productsBought: player.productsBought,
                    allProducts: receiptData.allProducts);
                final timeFee = calculateFinalFee(
                    timeReserved: player.timeReserved,
                    isOpenTime: player.isOpenTime,
                    timeExtendedMinutes: player.timeExtended.inMinutes,
                    timeSpent: timeSpent,
                    prices: receiptData.prices);
                return [
                  _buildInfoRow(
                      "Individual Total", "${formatter.format(playerFee)} SYP",
                      isHighlighted: true),
                  if (player.productsBought.isNotEmpty)
                    _buildInfoRow("Time Fee", formatter.format(timeFee))
                ];
              }()
            ]);
          }()
        ]
      ],
    );
  }

  Widget _buildGroupProductsList(PricesProductsSubs receiptData) {
    return Column(
      children: [
        // Group checkout: show products by player
        for (int i = 0; i < players.length; i++) ...[
          if (players[i].productsBought.isNotEmpty) ...[
            // Player header for products
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  players[i].name,
                  style: AppTextStyles.regularTextStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ),
            // Products for this player
            ...players[i].productsBought.entries.map((entry) {
              final product =
                  receiptData.allProducts.firstWhere((p) => p.id == entry.key);
              final productName = product.name;
              final productPrice = product.price;
              final quantity = entry.value;

              return Padding(
                padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                child: _buildInfoRow(
                  "$quantity × $productName",
                  "${formatter.format(productPrice * quantity)} SYP",
                ),
              );
            }),
          ]
        ]
      ],
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool isHighlighted = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.regularTextStyle),
          Text(
            value,
            style: isHighlighted
                ? AppTextStyles.highlightedTextStyle.copyWith(
                    color: textColor,
                  )
                : AppTextStyles.amountTextStyle.copyWith(
                    color: textColor,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCollection() {
    int amountLeft =
        _totals!.totalFinalFeeAfterDiscount - _totals!.totalPrePaidAmount;

    final int change =
        (int.tryParse(_amountReceivedController.text) ?? 0) - amountLeft;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined,
                  size: 20, color: Color(0xFF1976D2)),
              const SizedBox(width: 8),
              Text("Payment Collection",
                  style: AppTextStyles.regularTextStyle
                      .copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          _buildPaymentSummary(),
          const SizedBox(height: 16),
          MyTextField(
            controller: _amountReceivedController,
            labelText: "Amount Received",
            hintText: "Enter amount received",
            isNumberInputOnly: true,
            isDisabled: _debtAmount > 0 || _discountType == DiscountType.gift,
            onChanged: (value) => setState(() {}),
            suffixText: 'SYP  ',
          ),
          const SizedBox(height: 16),
          _buildChangeDisplay(),
          if (change > 0) ...[
            const SizedBox(height: 16),
            _buildTipOptions(),
          ],
          if (_tipType != null && change > 0) ...[
            const SizedBox(height: 16),
            _buildActionConfirmation(),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentOptions() {
    return MyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments, size: 20, color: Color(0xFF5E35B1)),
              const SizedBox(width: 8),
              Text("Payment Options", style: AppTextStyles.sectionHeaderStyle),
            ],
          ),
          const SizedBox(height: 16),
          _buildDiscountOptions(),
          const SizedBox(height: 24),
          _buildPaymentCollection(),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary() {
    int amountLeft =
        _totals!.totalFinalFeeAfterDiscount - _totals!.totalPrePaidAmount;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildInfoRow(
              "Final Fee:", "${formatter.format(_totals!.totalFinalFee)} SYP",
              isHighlighted: true),
          if (discountAmount > 0)
            _buildInfoRow(
                "Discount:", "-${formatter.format(discountAmount)} SYP",
                textColor: Colors.red),
          _buildInfoRow("Amount Paid:",
              "${formatter.format(_totals!.totalPrePaidAmount)} SYP"),
          const Divider(height: 16),
          _buildInfoRow("Amount Due:", "${formatter.format(amountLeft)} SYP",
              isHighlighted: true, textColor: Colors.deepPurple),
        ],
      ),
    );
  }

  Widget _buildProductsCard(PricesProductsSubs receiptData) {
    return MyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart,
                  size: 20, color: Color(0xFF1976D2)),
              const SizedBox(width: 8),
              Text("Products Purchased",
                  style: AppTextStyles.sectionHeaderStyle),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          // Display products differently for group vs single checkout
          if (isGroupCheckout) ...[
            _buildGroupProductsList(receiptData)
          ] else ...[
            _buildSingleProductsList(receiptData)
          ],
          const Divider(height: 1),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildReceiptHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: BoxDecoration(
        color: mainBlue.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mainBlue.withAlpha(50)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long,
            size: 36,
            color: mainBlue,
          ),
          const SizedBox(height: 8),
          Text("RECEIPT", style: AppTextStyles.sectionHeaderStyle),
          const SizedBox(height: 4),
          Text(
              isGroupCheckout
                  ? "Group Checkout (${players.length} players)"
                  : players.first.name,
              style: AppTextStyles.sectionHeaderStyle.copyWith(
                fontSize: 24,
                color: Colors.black,
              )),
          const SizedBox(height: 8),
          Text(
            "Date: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}",
            style: AppTextStyles.subtitleTextStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionDetails(PricesProductsSubs receiptData) {
    return MyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer, size: 20, color: mainBlue),
              const SizedBox(width: 8),
              Text(
                  isGroupCheckout ? "Group Session Details" : "Session Details",
                  style: AppTextStyles.sectionHeaderStyle),
            ],
          ),
          const SizedBox(height: 12),

          // Single player session details
          if (!isGroupCheckout) ...[
            _buildSinglePlayerSessionDetails(receiptData)
          ]
          // Group checkout: show individual player details
          else ...[_buildGroupPlayerSessionDetails(receiptData)]
        ],
      ),
    );
  }

  Widget _buildSinglePlayerSessionDetails(PricesProductsSubs receiptData) {
    final player = players.first;
    final timeSpent = timeSpentList.first;
    final String formattedTimeSpent =
        '${timeSpent.inHours}h ${timeSpent.inMinutes.remainder(60)}m';
    final String formattedCheckInTime =
        DateFormat('h:mm a').format(player.checkInTime.toLocal());

    return Column(children: [
      _buildInfoRow("Check-In Time", formattedCheckInTime),
      _buildInfoRow("Time Spent", formattedTimeSpent),
      // if he has products and not a subscriber
      if (_totals!.combinedProductsBought.isNotEmpty &&
          player.subscriptionId == null)
        () {
          final int playerFee = calculateFinalFee(
              timeReserved: player.timeReserved,
              isOpenTime: player.isOpenTime,
              timeExtendedMinutes: player.timeExtended.inMinutes,
              timeSpent: timeSpent,
              prices: receiptData.prices);
          return _buildInfoRow(
              "Time Fee", "${formatter.format(playerFee)} SYP");
        }(),

      if (player.subscriptionId != null) ...[
        const Divider(height: 24),
        Row(
          children: [
            const Icon(Icons.card_membership,
                size: 20, color: Color(0xFF43A047)),
            const SizedBox(width: 8),
            Text("Subscription Details",
                style: AppTextStyles.sectionHeaderStyle.copyWith(
                  color: const Color(0xFF43A047),
                )),
          ],
        ),
        const SizedBox(height: 12),
        _buildInfoRow("Time Used", "${_subTimeUsed(timeSpent)} Hours"),
        _buildInfoRow("Remaining Time",
            "${_subRemainingTime(receiptData.allSubs, timeSpent)} Hours"),
      ],
    ]);
  }

  Widget _buildSingleProductsList(PricesProductsSubs receiptData) {
    return Column(
      children: [
        // Single checkout: show combined products
        ..._totals!.combinedProductsBought.entries.map((entry) {
          // Find the product by ID
          final product =
              receiptData.allProducts.firstWhere((p) => p.id == entry.key);
          final productName = product.name;
          final productPrice = product.price;
          final quantity = entry.value;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: _buildInfoRow(
              "$quantity × $productName",
              "${formatter.format(productPrice * quantity)} SYP",
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTipOptions() {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.savings, size: 20, color: Color(0xFF388E3C)),
            const SizedBox(width: 8),
            Text("Change Options",
                style: AppTextStyles.regularTextStyle
                    .copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.savings_outlined, size: 18),
                label: const Text("Take as Tip"),
                onPressed: () {
                  setState(() {
                    _tipType = TipType.takeAsTip;
                  });
                },
                style: _tipType == TipType.takeAsTip
                    ? AppButtonStyles.primaryButton
                    : AppButtonStyles.secondaryButton,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text("Return Change"),
                onPressed: () {
                  setState(() {
                    _tipType = TipType.returnChange;
                  });
                },
                style: _tipType == TipType.returnChange
                    ? AppButtonStyles.primaryButton
                    : AppButtonStyles.secondaryButton,
              ),
            ),
          ],
        ),
      ],
    );
  }

  _ReceiptTotals _calculateTotals(PricesProductsSubs receiptData) {
    int totalFinalFee = 0;
    int totalAmountPaid = 0;
    Map<int, int> combinedProductsBought = {};

    // single checkout
    if (!isGroupCheckout) {
      final player = players.first;
      final timeSpent = timeSpentList.first;
      final Map<int, int> productsBought = player.productsBought;

      final int finalFee;
      if (player.subscriptionId != null) {
        finalFee = calculateProductsFee(
            productsBought: productsBought,
            allProducts: receiptData.allProducts);
      } else {
        finalFee = calculateFinalFee(
            timeReserved: player.timeReserved,
            isOpenTime: player.isOpenTime,
            timeExtendedMinutes: player.timeExtended.inMinutes,
            timeSpent: timeSpent,
            prices: receiptData.prices,
            productsBought: player.productsBought,
            allProducts: receiptData.allProducts);
      }
      totalFinalFee = finalFee;
      totalAmountPaid = player.amountPaid;
      combinedProductsBought = productsBought;
    } else {
      // Group checkout (no subs)
      for (int i = 0; i < players.length; i++) {
        final player = players[i];
        final timeSpent = timeSpentList[i];

        int playerFee;

        playerFee = calculateFinalFee(
            timeReserved: player.timeReserved,
            isOpenTime: player.isOpenTime,
            timeExtendedMinutes: player.timeExtended.inMinutes,
            timeSpent: timeSpent,
            prices: receiptData.prices,
            productsBought: player.productsBought,
            allProducts: receiptData.allProducts);

        totalFinalFee += playerFee;
        totalAmountPaid += player.amountPaid;

        // Combine products
        player.productsBought.forEach((productId, quantity) {
          combinedProductsBought[productId] =
              (combinedProductsBought[productId] ?? 0) + quantity;
        });
      }
    }

    final int totalFinalFeeAfterDiscount;
    if (_discountType == DiscountType.input) {
      totalFinalFeeAfterDiscount =
          totalFinalFee - (int.tryParse(_discountController.text) ?? 0);
    } else if (_discountType == DiscountType.gift) {
      totalFinalFeeAfterDiscount = 0 + totalAmountPaid;
    } else {
      // None
      totalFinalFeeAfterDiscount = totalFinalFee;
    }

    return _ReceiptTotals(
      totalFinalFee: totalFinalFee,
      totalFinalFeeAfterDiscount: totalFinalFeeAfterDiscount,
      totalPrePaidAmount: totalAmountPaid,
      combinedProductsBought: combinedProductsBought,
    );
  }

  Future<void> _loadPlayers() async {
    try {
      List<Player> loadedPlayers = [];
      List<Duration> timeSpentList = [];

      for (int sessionId in widget.sessionIds) {
        final playerData = await ref
            .read(currentPlayersProvider.notifier)
            .currentPlayerSession(sessionId);
        loadedPlayers.add(playerData);
        timeSpentList
            .add(DateTime.now().toUtc().difference(playerData.checkInTime));
      }

      log("Loaded ${loadedPlayers.length} players for checkout");
      setState(() {
        players = loadedPlayers;
        this.timeSpentList = timeSpentList;
      });
    } catch (e, st) {
      log('Error loading players!: $e\n$st');
    }
  }

  Future<void> _performCheckout(PricesProductsSubs receiptData) async {
    int amountReceived = _discountType == DiscountType.gift
        ? 0
        : int.tryParse(_amountReceivedController.text) ?? 0;

    final int playersAmountPaid =
        players.fold(0, (sum, player) => sum + player.amountPaid);
    if (amountReceived + playersAmountPaid <
            _totals!.totalFinalFeeAfterDiscount &&
        _debtAmount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Amount received must be at least ${formatter.format(_totals!.totalFinalFeeAfterDiscount)} SYP"),
        ),
      );
      return;
    }

    final int change = amountReceived -
        (_totals!.totalFinalFeeAfterDiscount - _totals!.totalPrePaidAmount);

    final int tip;
    if (_tipType == TipType.returnChange) {
      tip = 0;
      amountReceived -= change;
    } else {
      tip = change;
    }

    // add prepaid amount to amount received
    amountReceived += _totals!.totalPrePaidAmount;

    if (isGroupCheckout) {
      // Perform group checkout
      for (int i = 0; i < players.length; i++) {
        final player = players[i];
        final timeSpent = timeSpentList[i];

        final int playerFee = calculateFinalFee(
            timeReserved: player.timeReserved,
            isOpenTime: player.isOpenTime,
            timeExtendedMinutes: player.timeExtended.inMinutes,
            timeSpent: timeSpent,
            prices: receiptData.prices,
            productsBought: player.productsBought,
            allProducts: receiptData.allProducts);

        // last player gets the tip
        final int playerAmountReceived = i == players.length - 1
            ? playerFee + tip - discountAmount
            : playerFee;

        final int playerTip = i == players.length - 1 ? tip : 0;
        final int playerDiscount = i == players.length - 1 ? discountAmount : 0;

        await ref.read(currentPlayersProvider.notifier).checkOutPlayer(
            sessionID: player.sessionID,
            finalFee: playerFee,
            amountPaid: playerAmountReceived,
            tips: playerTip,
            discount: playerDiscount,
            discountReason: _discountReasonController.text.isNotEmpty
                ? _discountReasonController.text
                : null,
            checkoutTime: nowIso,
            debtAmount: 0);
      }
    } else {
      // perform single checkout
      final player = players.first;
      await ref.read(currentPlayersProvider.notifier).checkOutPlayer(
          sessionID: player.sessionID,
          finalFee: _totals!.totalFinalFee,
          amountPaid: amountReceived,
          tips: tip,
          discount: discountAmount,
          discountReason: _discountReasonController.text.isNotEmpty
              ? _discountReasonController.text
              : null,
          checkoutTime: nowIso,
          debtAmount: _debtAmount);
    }

    refreshAllProviders(ref);
    ref.read(debtProvider.notifier).refresh();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  double _subRemainingTime(
      List<Subscription> subscriptions, Duration timeSpent) {
    final double hoursUsed = _subTimeUsed(timeSpent);
    final sub = subscriptions.firstWhere(
      (sub) => sub.subscriptionId == players.first.subscriptionId,
      orElse: () => throw Exception('Subscription not found'),
    );
    return (sub.totalMinutes / 60) - hoursUsed;
  }

  double _subTimeUsed(Duration timeSpent) {
    final int halfHourBlocks = (timeSpent.inMinutes ~/ 30);
    final remainderMinutes = timeSpent.inMinutes % 30;

    int totalHalfHourBlocks = remainderMinutes > leewayMinutes
        ? halfHourBlocks + 1 // Over leeway, charge for next block
        : halfHourBlocks; // Within leeway, only charge for full blocks

    if (totalHalfHourBlocks == 0) {
      return 0.5; // At least charge for half an hour
    }

    return totalHalfHourBlocks * 0.5; // Convert to hours
  }
}

class _ReceiptTotals {
  final int totalFinalFee;
  final int totalPrePaidAmount;
  final int totalFinalFeeAfterDiscount;
  final Map<int, int> combinedProductsBought;

  _ReceiptTotals({
    required this.totalFinalFee,
    required this.totalPrePaidAmount,
    required this.totalFinalFeeAfterDiscount,
    required this.combinedProductsBought,
  });
}
