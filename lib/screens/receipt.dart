import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/my_card.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/models/subscription.dart';
import 'package:gravity_desktop_app/providers/combined_providers.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:gravity_desktop_app/utils/constants.dart';
import 'package:gravity_desktop_app/utils/fee_calculator.dart';
import 'package:gravity_desktop_app/utils/provider_utils.dart';
import 'package:intl/intl.dart';

enum TipType { returnChange, takeAsTip }

enum DiscountType { none, input, gift }

class _ReceiptTotals {
  final int totalFinalFee;
  final int totalAmountPaid;
  final Map<int, int> combinedProductsBought;

  _ReceiptTotals({
    required this.totalFinalFee,
    required this.totalAmountPaid,
    required this.combinedProductsBought,
  });
}

class Receipt extends ConsumerStatefulWidget {
  final List<int> sessionIds;

  const Receipt(this.sessionIds, {super.key});

  @override
  ConsumerState<Receipt> createState() => _ReceiptState();
}

class _ReceiptState extends ConsumerState<Receipt> {
  // useful variables
  final formatter = NumberFormat.decimalPattern();
  late final String nowIso;

  // player! variables
  List<Player> players = [];
  late final List<Duration> timeSpentList;
  bool get isGroupCheckout => players.length > 1;

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

  _ReceiptTotals _calculateTotals(dynamic receiptData) {
    Map<int, int> combinedProductsBought = {};
    int totalFinalFee = 0;
    int totalAmountPaid = 0;

    // For single checkout, use existing logic
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
      // Group checkout: calculate combined totals
      for (int i = 0; i < players.length; i++) {
        final player = players[i];
        final timeSpent = timeSpentList[i];

        int playerFee;
        if (player.subscriptionId != null) {
          playerFee = calculateProductsFee(
              productsBought: player.productsBought,
              allProducts: receiptData.allProducts);
        } else {
          playerFee = calculateFinalFee(
              timeReserved: player.timeReserved,
              isOpenTime: player.isOpenTime,
              timeExtendedMinutes: player.timeExtended.inMinutes,
              timeSpent: timeSpent,
              prices: receiptData.prices,
              productsBought: player.productsBought,
              allProducts: receiptData.allProducts);
        }

        totalFinalFee += playerFee;
        totalAmountPaid += player.amountPaid;

        // Combine products
        player.productsBought.forEach((productId, quantity) {
          combinedProductsBought[productId] =
              (combinedProductsBought[productId] ?? 0) + quantity;
        });
      }
    }

    return _ReceiptTotals(
      totalFinalFee: totalFinalFee,
      totalAmountPaid: totalAmountPaid,
      combinedProductsBought: combinedProductsBought,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ref.watch(pricesProductsSubsProvider).when(
          data: (receiptData) {
            final totals = _calculateTotals(receiptData);
            final int amountLeft =
                totals.totalFinalFee - totals.totalAmountPaid;

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
                                    _buildReceiptHeader(),
                                    const SizedBox(height: 16),
                                    _buildSessionDetails(receiptData, totals),
                                    const SizedBox(height: 16),
                                    if (totals
                                        .combinedProductsBought.isNotEmpty)
                                      _buildProductsCard(receiptData, totals),
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
                                  _buildPaymentOptions(totals, amountLeft),
                                  const SizedBox(height: 24),
                                  _buildActionButtons(
                                      receiptData, totals, amountLeft),
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

  Widget _buildReceiptHeader() {
    return Container(
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
          Text(
            "RECEIPT",
            style: GoogleFonts.notoSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: mainBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isGroupCheckout
                ? "Group Checkout (${players.length} players)"
                : players.first.name,
            style: GoogleFonts.notoSans(
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Date: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}",
            style: AppTextStyles.subtitleTextStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionDetails(dynamic receiptData, _ReceiptTotals totals) {
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
            _buildSinglePlayerSessionDetails(receiptData, totals)
          ]
          // Group checkout: show individual player details
          else ...[_buildGroupPlayerSessionDetails(receiptData)]
        ],
      ),
    );
  }

  Widget _buildSinglePlayerSessionDetails(
      dynamic receiptData, _ReceiptTotals totals) {
    final player = players.first;
    final timeSpent = timeSpentList.first;
    final String formattedTimeSpent =
        '${timeSpent.inHours}h ${timeSpent.inMinutes.remainder(60)}m';
    final String formattedCheckInTime =
        DateFormat('h:mm a').format(player.checkInTime.toLocal());

    return Column(children: [
      _buildInfoRow("Check-In Time", formattedCheckInTime),
      _buildInfoRow("Time Spent", formattedTimeSpent),
      if (totals.combinedProductsBought.isNotEmpty &&
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

  Widget _buildGroupPlayerSessionDetails(dynamic receiptData) {
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

  Widget _buildProductsCard(dynamic receiptData, _ReceiptTotals totals) {
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
            _buildSingleProductsList(receiptData, totals)
          ],
          const Divider(height: 1),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildGroupProductsList(dynamic receiptData) {
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
                    fontSize: 14,
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

  Widget _buildSingleProductsList(dynamic receiptData, _ReceiptTotals totals) {
    return Column(
      children: [
        // Single checkout: show combined products (original logic)
        ...totals.combinedProductsBought.entries.map((entry) {
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

  Widget _buildPaymentOptions(_ReceiptTotals totals, int amountLeft) {
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
          _buildDiscountOptions(amountLeft),
          const SizedBox(height: 24),
          _buildPaymentCollection(totals, amountLeft),
        ],
      ),
    );
  }

  Widget _buildDiscountOptions(int amountLeft) {
    return Container(
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
                  icon: const Icon(Icons.discount, size: 18),
                  label: const Text("Discount"),
                  onPressed: () {
                    setState(() {
                      if (_discountType == DiscountType.input) {
                        _discountType = DiscountType.none;
                        _discountAmount = 0;
                      } else {
                        _discountType = DiscountType.input;
                        _discountAmount = 0;
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
                  icon: const Icon(Icons.card_giftcard, size: 18),
                  label: const Text("Gift"),
                  onPressed: () {
                    setState(() {
                      if (_discountType == DiscountType.gift) {
                        _discountType = DiscountType.none;
                        _discountAmount = 0;
                      } else {
                        _discountType = DiscountType.gift;
                        _discountAmount = amountLeft;
                        _amountReceivedController.clear();
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
            _buildDiscountAmountField(),
          ],
          if (_discountType != DiscountType.none) ...[
            const SizedBox(height: 12),
            _buildDiscountReasonField(),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscountAmountField() {
    return TextFormField(
      controller: _discountController,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: "Discount Amount (SYP)",
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        prefixIcon: const Icon(Icons.money),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      onChanged: (value) {
        setState(() {
          _discountAmount = int.tryParse(value) ?? 0;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter an amount';
        }
        final amount = int.tryParse(value);
        if (amount == null) {
          return "Enter a valid amount";
        }
        return null;
      },
    );
  }

  Widget _buildDiscountReasonField() {
    return TextFormField(
      controller: _discountReasonController,
      decoration: InputDecoration(
        labelText: "Reason for Discount",
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        prefixIcon: const Icon(Icons.note),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildPaymentCollection(_ReceiptTotals totals, int amountLeft) {
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
          _buildPaymentSummary(totals, amountLeft),
          const SizedBox(height: 16),
          _buildAmountReceivedField(amountLeft),
          const SizedBox(height: 16),
          _buildChangeDisplay(),
          if (_change > 0) ...[
            const SizedBox(height: 16),
            _buildTipOptions(),
          ],
          if (_tipType != null && _change > 0) ...[
            const SizedBox(height: 16),
            _buildActionConfirmation(),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentSummary(_ReceiptTotals totals, int amountLeft) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildInfoRow(
              "Final Fee:", "${formatter.format(totals.totalFinalFee)} SYP",
              isHighlighted: true),
          if (_discountAmount > 0)
            _buildInfoRow(
                "Discount:", "-${formatter.format(_discountAmount)} SYP",
                textColor: Colors.red),
          _buildInfoRow("Amount Paid:",
              "${formatter.format(totals.totalAmountPaid)} SYP"),
          const Divider(height: 16),
          _buildInfoRow("Amount Due:",
              "${formatter.format(amountLeft - _discountAmount)} SYP",
              isHighlighted: true, textColor: Colors.deepPurple),
        ],
      ),
    );
  }

  Widget _buildAmountReceivedField(int amountLeft) {
    return TextField(
      controller: _amountReceivedController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: AppTextStyles.regularTextStyle,
      enabled: _discountType != DiscountType.gift,
      decoration: InputDecoration(
        labelText: "Amount Received (SYP)",
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.attach_money),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      onChanged: (value) {
        setState(() {
          int amountReceived = int.tryParse(value) ?? 0;
          _change = amountReceived - (amountLeft - _discountAmount);
          _isCheckoutEnabled =
              (amountReceived >= (amountLeft - _discountAmount) &&
                      (_change <= 0 || _tipType != null)) ||
                  _discountType == DiscountType.gift;
        });
      },
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
                    _tip = _change;
                    _isCheckoutEnabled = true;
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
                    _tip = 0;
                    _isCheckoutEnabled = true;
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

  Widget _buildActionConfirmation() {
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
                  ? "Return ${formatter.format(_change)} SYP as change"
                  : "Keep ${formatter.format(_change)} SYP as tip",
              style: GoogleFonts.notoSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      dynamic receiptData, _ReceiptTotals totals, int amountLeft) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.cancel_outlined),
            label: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
            style: AppButtonStyles.secondaryButton,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text("Complete Checkout"),
            onPressed: _isCheckoutEnabled
                ? () => _performCheckout(receiptData, totals)
                : null,
            style: _isCheckoutEnabled
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

  Future<void> _performCheckout(
      dynamic receiptData, _ReceiptTotals totals) async {
    int amountReceived = _discountType == DiscountType.gift
        ? 0
        : int.tryParse(_amountReceivedController.text) ?? 0;

    final int playersAmountPaid =
        players.fold(0, (sum, player) => sum + player.amountPaid);
    if (amountReceived + playersAmountPaid < totals.totalFinalFee) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Amount received must be at least ${formatter.format(totals.totalFinalFee)} SYP"),
        ),
      );
      return;
    }

    if (_tipType == TipType.returnChange) {
      amountReceived -= _change;
    }

    if (isGroupCheckout) {
      await _performGroupCheckout(receiptData, amountReceived);
    } else {
      await _performSingleCheckout(totals, amountReceived);
    }

    refreshAllProviders(ref);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _performGroupCheckout(
      dynamic receiptData, int amountReceived) async {
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
          ? playerFee + _tip - _discountAmount
          : playerFee;

      final int playerTip = i == players.length - 1 ? _tip : 0;
      final int playerDiscount = i == players.length - 1 ? _discountAmount : 0;

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
          );
    }
  }

  Future<void> _performSingleCheckout(
      _ReceiptTotals totals, int amountReceived) async {
    final player = players.first;
    await ref.read(currentPlayersProvider.notifier).checkOutPlayer(
          sessionID: player.sessionID,
          finalFee: totals.totalFinalFee,
          amountPaid: amountReceived + player.amountPaid,
          tips: _tip,
          discount: _discountAmount,
          discountReason: _discountReasonController.text.isNotEmpty
              ? _discountReasonController.text
              : null,
          checkoutTime: nowIso,
        );
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

  double _subRemainingTime(
      List<Subscription> subscriptions, Duration timeSpent) {
    final double hoursUsed = _subTimeUsed(timeSpent);
    final sub = subscriptions.firstWhere(
      (sub) => sub.subscriptionId == players.first.subscriptionId,
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
