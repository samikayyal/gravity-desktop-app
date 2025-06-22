import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/providers/database_provider.dart';
import 'package:gravity_desktop_app/utils/fee_calculator.dart';

class ReceiptDialog extends ConsumerStatefulWidget {
  final Player player;
  const ReceiptDialog(this.player, {super.key});

  @override
  ConsumerState<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends ConsumerState<ReceiptDialog> {
  final TextEditingController _amountReceivedController =
      TextEditingController();
  final TextEditingController _tipController = TextEditingController();

  int _change = 0;
  bool _showTipField = false;
  bool _isCheckoutEnabled = false;

  @override
  void dispose() {
    _amountReceivedController.dispose();
    _tipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pricesAsync = ref.watch(pricesProvider);

    return pricesAsync.when(
      data: (prices) {
        Duration timeSpent =
            DateTime.now().toUtc().difference(widget.player.checkInTime);
        String formattedTimeSpent =
            'Time Spent: ${timeSpent.inHours} Hours ${timeSpent.inMinutes.remainder(60)} minutes';

        int finalFee = calculateFinalFee(timeSpent: timeSpent, prices: prices);
        int amountLeft = finalFee - widget.player.amountPaid;

        return AlertDialog(
          title: Text("Receipt for ${widget.player.name}"),
          content: SingleChildScrollView(
              child: ListBody(
            children: <Widget>[
              Text("Check-in Time: ${widget.player.checkInTime.toLocal()}"),
              Text(formattedTimeSpent),
              const Divider(),
              Text("Total Fee: $finalFee SYP"),
              Text("Amount Paid: ${widget.player.amountPaid} SYP"),
              const Divider(
                thickness: 2,
              ),
              Text("Amount Left: $amountLeft SYP"),

              const SizedBox(height: 20),
              // Amount to pay/receive
              TextFormField(
                controller: _amountReceivedController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: 'Amount Received',
                  hintText: 'Enter amount received in SYP',
                ),
                onChanged: (value) {
                  final int amountReceived = int.tryParse(value) ?? 0;
                  setState(() {
                    _change = amountReceived - amountLeft;
                    _isCheckoutEnabled = amountReceived >= amountLeft;
                  });
                },
              ),
              const SizedBox(height: 10),
              if (_change < 0) Text("Still owed: ${-_change} SYP"),
              if (_change >= 0) Text("Change: $_change SYP"),

              if (_change > 0 && !_showTipField)
                Row(
                  children: [
                    ElevatedButton(
                        child: Text("Take the change as tip"),
                        onPressed: () {
                          setState(() {
                            _tipController.text = _change.toString();
                          });
                        }),
                    OutlinedButton(
                      child: Text("Return Change"),
                      onPressed: () {
                        setState(() {
                          _showTipField = true;
                          _tipController.text = '0';
                        });
                      },
                    )
                  ],
                ),
              if (_showTipField || _change <= 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: TextFormField(
                    controller: _tipController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Tip Received',
                    ),
                  ),
                ),
            ],
          )),
          actions: [
            TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.of(context).pop()),
            ElevatedButton(
              onPressed: _isCheckoutEnabled
                  ? () {
                      // Handle confirmation logic
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
