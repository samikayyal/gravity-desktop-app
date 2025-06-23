import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/providers/database_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final pricesAsync = ref.watch(pricesProvider);

    return pricesAsync.when(
      data: (prices) {
        String formattedTimeSpent =
            'Time Spent: ${timeSpent.inHours} Hours ${timeSpent.inMinutes.remainder(60)} minutes';

        String formattedCheckInTime =
            DateFormat('h:mm a').format(widget.player.checkInTime.toLocal());

        int finalFee = calculateFinalFee(timeSpent: timeSpent, prices: prices);
        int amountLeft = finalFee - widget.player.amountPaid;

        return AlertDialog(
          title: Text("Receipt for ${widget.player.name}"),
          content: SingleChildScrollView(
              child: ListBody(
            children: <Widget>[
              Text("Check-in Time: $formattedCheckInTime"),
              Text("Time Spent: $formattedTimeSpent"),
              const Divider(),
              Text("Final Fee: $finalFee SYP"),
              Text("Amount Paid: ${widget.player.amountPaid} SYP"),
              const Divider(),
              Text("Amount Left: $amountLeft SYP"),
              const SizedBox(height: 8.0),
              TextField(
                controller: _amountReceivedController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: "Amount Received",
                  hintText: "Enter amount received",
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    int amountReceived = int.tryParse(value) ?? 0;
                    _change = amountReceived - amountLeft;
                    _isCheckoutEnabled =
                        amountReceived >= amountLeft && _tipType != null;
                  });
                },
              ),
              if (_change > 0) Text("Change: $_change SYP"),
              if (_change == 0) Text("No Change"),
              if (_change < 0) Text("Still Owed: ${-_change} SYP"),
              const Divider(thickness: 2, color: Colors.grey),
              if (_change > 0)
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _tipType = TipType.takeAsTip;
                          _tip = _change;
                          _isCheckoutEnabled = true; // Enable checkout
                        });
                      },
                      style: _tipType == TipType.takeAsTip
                          ? AppButtonStyles.primaryButton
                          : AppButtonStyles.secondaryButton,
                      child: Text("Take change as tip"),
                    ),
                    ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _tipType = TipType.returnChange;
                            _tip = 0; // Reset tip when returning change
                            _isCheckoutEnabled = true; // Enable checkout
                          });
                        },
                        style: _tipType == TipType.returnChange
                            ? AppButtonStyles.primaryButton
                            : AppButtonStyles.secondaryButton,
                        child: Text("Return Change")),
                  ],
                ),
              const SizedBox(height: 8.0),
              if (_tipType == TipType.returnChange)
                Text("Action: Return $_change SYP as change"),
              if (_tipType == TipType.takeAsTip)
                Text("Action: Take $_change SYP as tip"),
            ],
          )),
          actions: [
            TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.of(context).pop()),
            ElevatedButton(
              onPressed: _isCheckoutEnabled
                  ? () {
                      ref.read(currentPlayersProvider.notifier).checkOutPlayer(
                          sessionID: widget.player.sessionID,
                          finalFee: finalFee,
                          amountPaid: int.parse(_amountReceivedController.text),
                          tips: _tip);
                      Navigator.of(context).pop();
                    }
                  : null,
              child: const Text("Confirm"),
            )
          ],
        );
      },
      loading: () => AlertDialog(
        title: const Text('Loading Prices'),
        content: const Center(child: CircularProgressIndicator()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
      error: (error, stackTrace) => AlertDialog(
        title: const Text('Error'),
        content: Text('Failed to load prices: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
