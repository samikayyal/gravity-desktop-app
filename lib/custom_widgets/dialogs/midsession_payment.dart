import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/my_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_materialbanner.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text_field.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';

class MidsessionPaymentDialog extends ConsumerStatefulWidget {
  final Player player;
  const MidsessionPaymentDialog(this.player, {super.key});

  @override
  ConsumerState<MidsessionPaymentDialog> createState() =>
      _MidsessionPaymentDialogState();
}

class _MidsessionPaymentDialogState
    extends ConsumerState<MidsessionPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final amountPaidController = TextEditingController();
  bool _isLoading = false;

  late final Player playerSession;

  @override
  void initState() {
    _loadSession();
    super.initState();
  }

  Future<void> _loadSession() async {
    setState(() {
      _isLoading = true;
    });

    final player = await ref
        .read(currentPlayersProvider.notifier)
        .currentPlayerSession(widget.player.sessionID);

    setState(() {
      _isLoading = false;
      playerSession = player;
    });
  }

  Future<void> _handlePayment() async {
    if (!_formKey.currentState!.validate()) return;
    final int amount = int.parse(amountPaidController.text);

    try {
      await ref
          .read(currentPlayersProvider.notifier)
          .makePaymentMidSession(playerSession.sessionID, amount);
    } catch (e) {
      if (mounted) {
        MyMaterialBanner.showFloatingBanner(context,
            message: e.toString(), type: MessageType.error);
      }
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MyDialog(
          child: Center(
        child: CircularProgressIndicator(),
      ));
    }

    return MyDialog(
        child: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Make Payment for ${widget.player.name}",
            style: AppTextStyles.sectionHeaderStyle,
          ),
          const SizedBox(
            height: 16,
          ),
          MyTextField(
            controller: amountPaidController,
            labelText: "Amount Paid",
            hintText: "Enter amount",
            isNumberInputOnly: true,
            prefixText: 'SYP   ',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Enter valid amount";
              }
              final amount = int.tryParse(value);
              if (amount == null || amount < 0) {
                return "Enter valid amount";
              }
              return null;
            },
          ),
          const SizedBox(
            height: 16,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: AppButtonStyles.secondaryButton,
                  child: Text(
                    "Cancel",
                    style: AppTextStyles.secondaryButtonTextStyle,
                  )),
              const SizedBox(
                width: 8,
              ),
              ElevatedButton(
                  onPressed: () async => await _handlePayment(),
                  style: AppButtonStyles.primaryButton,
                  child: Text(
                    "Confirm",
                    style: AppTextStyles.primaryButtonTextStyle,
                  ))
            ],
          )
        ],
      ),
    ));
  }
}
