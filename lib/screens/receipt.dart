import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_card.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/models/subscription.dart';
import 'package:gravity_desktop_app/providers/combined_providers.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:gravity_desktop_app/providers/product_provider.dart';
import 'package:gravity_desktop_app/utils/constants.dart';
import 'package:gravity_desktop_app/utils/fee_calculator.dart';
import 'package:intl/intl.dart';

enum TipType { returnChange, takeAsTip }

enum DiscountType { none, input, gift }

class Receipt extends ConsumerStatefulWidget {
  final int sessionId;
  const Receipt(this.sessionId, {super.key});

  @override
  ConsumerState<Receipt> createState() => _ReceiptState();
}

class _ReceiptState extends ConsumerState<Receipt> {
  // useful variables
  final formatter = NumberFormat.decimalPattern();
  late final String nowIso;

  // player! variables
  Player? player;
  late final Duration timeSpent;

  // receipt variables
  int _change = 0;
  int _tip = 0;
  bool _isCheckoutEnabled = false;

  TipType? _tipType;
  DiscountType _discountType = DiscountType.none;

  int _discountAmount = 0;

  // controllers
  final _amountReceivedController = TextEditingController();
  final _discountController = TextEditingController();
  final _discountReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPlayer();
    nowIso = DateTime.now().toUtc().toIso8601String();
  }

  Future<void> _loadPlayer() async {
    try {
      final playerData = await ref
          .read(currentPlayersProvider.notifier)
          .currentPlayerSession(widget.sessionId);
      log("${playerData.productsBought}");
      setState(() {
        player = playerData;
        timeSpent = DateTime.now().toUtc().difference(player!.checkInTime);
      });
    } catch (e, st) {
      log('Error loading player!: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (player == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ref.watch(pricesProductsSubsProvider).when(
          data: (receiptData) {
            final Map<int, int> productsBought = player!.productsBought;
            final String formattedTimeSpent =
                '${timeSpent.inHours}h ${timeSpent.inMinutes.remainder(60)}m';

            final String formattedCheckInTime =
                DateFormat('h:mm a').format(player!.checkInTime.toLocal());

            final int finalFee;
            if (player!.subscriptionId != null) {
              finalFee = calculateProductsFee(
                  productsBought: productsBought,
                  allProducts: receiptData.allProducts);
            } else {
              finalFee = calculateFinalFee(
                  timeSpent: timeSpent,
                  prices: receiptData.prices,
                  productsBought: player!.productsBought,
                  allProducts: receiptData.allProducts);
            }
            // amount paid be 0 if the player has a subscription
            final int amountLeft = finalFee - player!.amountPaid;

            return Scaffold(
                appBar: MyAppBar(),
                body: Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LEFT SIDE - Receipt Information
                          Expanded(
                            flex: 2,
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 16.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Header with customer name
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16.0),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3949AB)
                                            .withAlpha(25),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(0xFF3949AB)
                                                .withAlpha(50)),
                                      ),
                                      child: Column(
                                        children: [
                                          const Icon(
                                            Icons.receipt_long,
                                            size: 36,
                                            color: Color(0xFF3949AB),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "RECEIPT",
                                            style: GoogleFonts.notoSans(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF3949AB),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            player!.name,
                                            style: GoogleFonts.notoSans(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "Date: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}",
                                            style:
                                                AppTextStyles.subtitleTextStyle,
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    // Session details
                                    MyCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.timer,
                                                  size: 20,
                                                  color: Color(0xFF3949AB)),
                                              const SizedBox(width: 8),
                                              Text("Session Details",
                                                  style: AppTextStyles
                                                      .sectionHeaderStyle),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          _buildInfoRow("Check-In Time",
                                              formattedCheckInTime),
                                          _buildInfoRow(
                                              "Time Spent", formattedTimeSpent),
                                          if (productsBought.isNotEmpty &&
                                              player!.subscriptionId == null)
                                            _buildInfoRow("Time Fee",
                                                "${formatter.format(calculateFinalFee(timeSpent: timeSpent, prices: receiptData.prices))} SYP"),
                                          if (player!.subscriptionId !=
                                              null) ...[
                                            const Divider(height: 24),
                                            Row(
                                              children: [
                                                const Icon(
                                                    Icons.card_membership,
                                                    size: 20,
                                                    color: Color(0xFF43A047)),
                                                const SizedBox(width: 8),
                                                Text("Subscription Details",
                                                    style: AppTextStyles
                                                        .sectionHeaderStyle
                                                        .copyWith(
                                                      color: const Color(
                                                          0xFF43A047),
                                                    )),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            _buildInfoRow("Time Used",
                                                "${_subTimeUsed()} Hours"),
                                            _buildInfoRow("Remaining Time",
                                                "${_subRemainingTime(receiptData.allSubs)} Hours"),
                                          ],
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    // Products card (if exists)
                                    if (productsBought.isNotEmpty)
                                      MyCard(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.shopping_cart,
                                                    size: 20,
                                                    color: Color(0xFF1976D2)),
                                                const SizedBox(width: 8),
                                                Text("Products Purchased",
                                                    style: AppTextStyles
                                                        .sectionHeaderStyle),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            const Divider(height: 1),
                                            ...productsBought.entries
                                                .map((entry) {
                                              // Find the product by ID
                                              final product = receiptData
                                                  .allProducts
                                                  .firstWhere(
                                                (p) => p.id == entry.key,
                                              );
                                              final productName = product.name;
                                              final productPrice =
                                                  product.price;
                                              final quantity = entry.value;

                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8.0),
                                                child: _buildInfoRow(
                                                  "$quantity × $productName",
                                                  "${formatter.format(productPrice * quantity)} SYP",
                                                ),
                                              );
                                            }),
                                            const Divider(height: 1),
                                            const SizedBox(height: 8),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // RIGHT SIDE - Payment Processing
                          Expanded(
                            flex: 2,
                            child: SingleChildScrollView(
                                child: Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Payment options card
                                  MyCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.payments,
                                                size: 20,
                                                color: Color(0xFF5E35B1)),
                                            const SizedBox(width: 8),
                                            Text("Payment Options",
                                                style: AppTextStyles
                                                    .sectionHeaderStyle),
                                          ],
                                        ),
                                        const SizedBox(height: 16),

                                        // Discount options
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.grey.shade200),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text("Apply Discount",
                                                  style: AppTextStyles
                                                      .regularTextStyle
                                                      .copyWith(
                                                          fontWeight:
                                                              FontWeight.bold)),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      icon: const Icon(
                                                          Icons.discount,
                                                          size: 18),
                                                      label: const Text(
                                                          "Discount"),
                                                      onPressed: () {
                                                        setState(() {
                                                          if (_discountType ==
                                                              DiscountType
                                                                  .input) {
                                                            _discountType =
                                                                DiscountType
                                                                    .none;
                                                            _discountAmount = 0;
                                                          } else {
                                                            _discountType =
                                                                DiscountType
                                                                    .input;
                                                            _discountAmount = 0;
                                                          }
                                                        });
                                                      },
                                                      style: _discountType ==
                                                              DiscountType.input
                                                          ? AppButtonStyles
                                                              .primaryButton
                                                          : AppButtonStyles
                                                              .secondaryButton,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      icon: const Icon(
                                                          Icons.card_giftcard,
                                                          size: 18),
                                                      label: const Text("Gift"),
                                                      onPressed: () {
                                                        setState(() {
                                                          if (_discountType ==
                                                              DiscountType
                                                                  .gift) {
                                                            _discountType =
                                                                DiscountType
                                                                    .none;
                                                            _discountAmount = 0;
                                                          } else {
                                                            _discountType =
                                                                DiscountType
                                                                    .gift;
                                                            _discountAmount =
                                                                amountLeft;
                                                            _amountReceivedController
                                                                .clear();
                                                          }
                                                        });
                                                      },
                                                      style: _discountType ==
                                                              DiscountType.gift
                                                          ? AppButtonStyles
                                                              .primaryButton
                                                          : AppButtonStyles
                                                              .secondaryButton,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (_discountType ==
                                                  DiscountType.input) ...[
                                                const SizedBox(height: 16),
                                                TextFormField(
                                                  controller:
                                                      _discountController,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                  ],
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration: InputDecoration(
                                                    labelText:
                                                        "Discount Amount (SYP)",
                                                    filled: true,
                                                    fillColor: Colors.white,
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      borderSide:
                                                          BorderSide.none,
                                                    ),
                                                    prefixIcon:
                                                        const Icon(Icons.money),
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      horizontal: 16,
                                                      vertical: 16,
                                                    ),
                                                  ),
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _discountAmount =
                                                          int.tryParse(value) ??
                                                              0;
                                                    });
                                                  },
                                                  validator: (value) {
                                                    if (value == null ||
                                                        value.isEmpty) {
                                                      return 'Please enter an amount';
                                                    }
                                                    final amount =
                                                        int.tryParse(value);
                                                    if (amount == null) {
                                                      return "Enter a valid amount";
                                                    }
                                                    if (amount < 0 ||
                                                        amount > finalFee) {
                                                      return "Amount entered not valid";
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ],
                                              if (_discountType !=
                                                  DiscountType.none) ...[
                                                const SizedBox(height: 12),
                                                TextFormField(
                                                  controller:
                                                      _discountReasonController,
                                                  decoration: InputDecoration(
                                                    labelText:
                                                        "Reason for Discount",
                                                    filled: true,
                                                    fillColor: Colors.white,
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      borderSide:
                                                          BorderSide.none,
                                                    ),
                                                    prefixIcon:
                                                        const Icon(Icons.note),
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      horizontal: 16,
                                                      vertical: 16,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),

                                        const SizedBox(height: 24),

                                        // Amount received input
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF5F5F5),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: const Color(0xFFE0E0E0)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                      Icons.payments_outlined,
                                                      size: 20,
                                                      color: Color(0xFF1976D2)),
                                                  const SizedBox(width: 8),
                                                  Text("Payment Collection",
                                                      style: AppTextStyles
                                                          .regularTextStyle
                                                          .copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                ],
                                              ),
                                              const SizedBox(height: 16),

                                              // Summary of payment
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Column(
                                                  children: [
                                                    _buildInfoRow("Final Fee:",
                                                        "${formatter.format(finalFee)} SYP",
                                                        isHighlighted: true),
                                                    if (_discountAmount > 0)
                                                      _buildInfoRow("Discount:",
                                                          "-${formatter.format(_discountAmount)} SYP",
                                                          textColor:
                                                              Colors.red),
                                                    _buildInfoRow(
                                                        "Amount Paid:",
                                                        "${formatter.format(player!.amountPaid)} SYP"),
                                                    const Divider(height: 16),
                                                    _buildInfoRow("Amount Due:",
                                                        "${formatter.format(amountLeft - _discountAmount)} SYP",
                                                        isHighlighted: true,
                                                        textColor:
                                                            Colors.deepPurple),
                                                  ],
                                                ),
                                              ),

                                              const SizedBox(height: 16),

                                              TextField(
                                                controller:
                                                    _amountReceivedController,
                                                keyboardType:
                                                    TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                ],
                                                style: AppTextStyles
                                                    .regularTextStyle,
                                                enabled: _discountType !=
                                                    DiscountType.gift,
                                                decoration: InputDecoration(
                                                  labelText:
                                                      "Amount Received (SYP)",
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                  prefixIcon: const Icon(
                                                      Icons.attach_money),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    borderSide:
                                                        const BorderSide(
                                                            color: Color(
                                                                0xFFE0E0E0)),
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                    horizontal: 16,
                                                    vertical: 16,
                                                  ),
                                                ),
                                                onChanged: (value) {
                                                  setState(() {
                                                    int amountReceived =
                                                        int.tryParse(value) ??
                                                            0;
                                                    _change = amountReceived -
                                                        (amountLeft -
                                                            _discountAmount);
                                                    _isCheckoutEnabled =
                                                        (amountReceived >=
                                                                    (amountLeft -
                                                                        _discountAmount) &&
                                                                (_change <= 0 ||
                                                                    _tipType !=
                                                                        null)) ||
                                                            _discountType ==
                                                                DiscountType
                                                                    .gift;
                                                  });
                                                },
                                              ),

                                              const SizedBox(height: 16),
                                              _buildChangeDisplay(),

                                              // Tip options section
                                              if (_change > 0) ...[
                                                const SizedBox(height: 16),
                                                const Divider(),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.savings,
                                                        size: 20,
                                                        color:
                                                            Color(0xFF388E3C)),
                                                    const SizedBox(width: 8),
                                                    Text("Change Options",
                                                        style: AppTextStyles
                                                            .regularTextStyle
                                                            .copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceEvenly,
                                                  children: [
                                                    Expanded(
                                                      child:
                                                          ElevatedButton.icon(
                                                        icon: const Icon(
                                                            Icons
                                                                .savings_outlined,
                                                            size: 18),
                                                        label: const Text(
                                                            "Take as Tip"),
                                                        onPressed: () {
                                                          setState(() {
                                                            _tipType = TipType
                                                                .takeAsTip;
                                                            _tip = _change;
                                                            _isCheckoutEnabled =
                                                                true;
                                                          });
                                                        },
                                                        style: _tipType ==
                                                                TipType
                                                                    .takeAsTip
                                                            ? AppButtonStyles
                                                                .primaryButton
                                                            : AppButtonStyles
                                                                .secondaryButton,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child:
                                                          ElevatedButton.icon(
                                                        icon: const Icon(
                                                            Icons
                                                                .payments_outlined,
                                                            size: 18),
                                                        label: const Text(
                                                            "Return Change"),
                                                        onPressed: () {
                                                          setState(() {
                                                            _tipType = TipType
                                                                .returnChange;
                                                            _tip = 0;
                                                            _isCheckoutEnabled =
                                                                true;
                                                          });
                                                        },
                                                        style: _tipType ==
                                                                TipType
                                                                    .returnChange
                                                            ? AppButtonStyles
                                                                .primaryButton
                                                            : AppButtonStyles
                                                                .secondaryButton,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],

                                              // Action confirmation
                                              if (_tipType != null &&
                                                  _change > 0) ...[
                                                const SizedBox(height: 16),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFE8F5E9),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                        color: const Color(
                                                            0xFFA5D6A7)),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        _tipType ==
                                                                TipType
                                                                    .returnChange
                                                            ? Icons
                                                                .payments_outlined
                                                            : Icons.savings,
                                                        color: const Color(
                                                            0xFF2E7D32),
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          _tipType ==
                                                                  TipType
                                                                      .returnChange
                                                              ? "Return ${formatter.format(_change)} SYP as change"
                                                              : "Keep ${formatter.format(_change)} SYP as tip",
                                                          style: GoogleFonts
                                                              .notoSans(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: const Color(
                                                                0xFF2E7D32),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Action buttons with clearer layout
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon:
                                              const Icon(Icons.cancel_outlined),
                                          label: const Text("Cancel"),
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          style:
                                              AppButtonStyles.secondaryButton,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(
                                              Icons.check_circle_outline),
                                          label:
                                              const Text("Complete Checkout"),
                                          onPressed: _isCheckoutEnabled
                                              ? () async {
                                                  int amountReceived =
                                                      _discountType ==
                                                              DiscountType.gift
                                                          ? 0
                                                          : int.tryParse(
                                                                  _amountReceivedController
                                                                      .text) ??
                                                              0;

                                                  if (_tipType ==
                                                      TipType.returnChange) {
                                                    amountReceived -= _change;
                                                  }

                                                  await ref
                                                      .read(
                                                          currentPlayersProvider
                                                              .notifier)
                                                      .checkOutPlayer(
                                                        sessionID:
                                                            player!.sessionID,
                                                        finalFee: finalFee,
                                                        amountPaid:
                                                            amountReceived +
                                                                player!
                                                                    .amountPaid,
                                                        tips: _tip,
                                                        discount:
                                                            _discountAmount,
                                                        discountReason:
                                                            _discountReasonController
                                                                    .text
                                                                    .isNotEmpty
                                                                ? _discountReasonController
                                                                    .text
                                                                : null,
                                                        checkoutTime: nowIso,
                                                      );

                                                  await ref
                                                      .read(productsProvider
                                                          .notifier)
                                                      .refresh();

                                                  if (context.mounted) {
                                                    Navigator.of(context).pop();
                                                  }
                                                }
                                              : null,
                                          style: _isCheckoutEnabled
                                              ? AppButtonStyles.primaryButton
                                              : ButtonStyle(
                                                  backgroundColor:
                                                      WidgetStateProperty.all(
                                                          Colors.grey[300]),
                                                  foregroundColor:
                                                      WidgetStateProperty.all(
                                                          Colors.grey[600]),
                                                  padding:
                                                      WidgetStateProperty.all(
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 24.0,
                                                        vertical: 16.0),
                                                  ),
                                                  shape:
                                                      WidgetStateProperty.all(
                                                    RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            )),
                          ),
                        ],
                      ),
                    ),
                  ),
                ));
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            log('Error fetching receipt data: $error',
                error: error, stackTrace: stackTrace);
            return Center(child: Text('Error loading receipt data'));
          },
        );
  }

  double _subTimeUsed() {
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

  double _subRemainingTime(List<Subscription> subscriptions) {
    final double hoursUsed = _subTimeUsed();
    final sub = subscriptions.firstWhere(
      (sub) => sub.subscriptionId == player!.subscriptionId,
      orElse: () => throw Exception('Subscription not found'),
    );
    return (sub.totalMinutes / 60) - hoursUsed;
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
