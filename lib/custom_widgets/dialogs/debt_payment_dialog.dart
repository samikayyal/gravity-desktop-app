import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/my_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text_field.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/models/debt.dart';
import 'package:gravity_desktop_app/providers/debt_provider.dart';

class DebtPaymentDialog extends ConsumerStatefulWidget {
  final Debt debt;
  const DebtPaymentDialog(this.debt, {super.key});

  @override
  ConsumerState<DebtPaymentDialog> createState() => _DebtPaymentDialogState();
}

class _DebtPaymentDialogState extends ConsumerState<DebtPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _paymentController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final paymentAmount = int.parse(_paymentController.text);
      await ref
          .read(debtProvider.notifier)
          .payDebt(widget.debt.debtId, paymentAmount);

      if (mounted) {
        Navigator.of(context)
            .pop(true); // Return true to indicate successful payment
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Payment of $paymentAmount SYP processed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing payment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String? _validatePayment(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a payment amount';
    }

    final amount = int.tryParse(value);
    if (amount == null || amount <= 0) {
      return 'Please enter a valid amount greater than 0';
    }

    if (amount > widget.debt.amount) {
      return 'Payment cannot exceed debt amount (${widget.debt.amount} SYP)';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MyDialog(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header

            Text(
              'Process Debt Payment',
              style: AppTextStyles.sectionHeaderStyle,
            ),

            const SizedBox(height: 24),

            // Debt information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Player: ', style: AppTextStyles.regularTextStyle),
                      Text(
                        widget.debt.playerName,
                        style: AppTextStyles.regularTextStyle.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('Current Debt: ',
                          style: AppTextStyles.regularTextStyle),
                      Text(
                        '${widget.debt.amount} SYP',
                        style: AppTextStyles.regularTextStyle.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment amount input
            MyTextField(
              controller: _paymentController,
              labelText: 'Payment Amount',
              hintText: 'Enter amount to pay (max: ${widget.debt.amount} SYP)',
              isNumberInputOnly: true,
              validator: _validatePayment,
              prefixText: 'SYP   ',
              isDisabled: _isProcessing,
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed:
                      _isProcessing ? null : () => Navigator.of(context).pop(),
                  style: AppButtonStyles.secondaryButton,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: AppButtonStyles.primaryButton,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Process Payment'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
