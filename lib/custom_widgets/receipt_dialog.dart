import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/providers/database_provider.dart';
import 'package:gravity_desktop_app/utils/fee_calculator.dart';
import 'package:intl/intl.dart';

class ReceiptDialog extends ConsumerWidget {
  final Player player;

  const ReceiptDialog({super.key, required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricesAsync = ref.watch(pricesProvider);
    return pricesAsync.when(
      data: (prices) {
        Duration timeSpent =
            DateTime.now().toUtc().difference(player.checkInTime);

        int finalFee = calculateFinalFee(
          timeSpent: timeSpent,
          prices: prices,
        );

        int amountDue = finalFee - player.amountPaid;
        String timeDetails =
            "Time Spent: ${timeSpent.inHours}h ${timeSpent.inMinutes % 60}m";
      },
      error: (error, stackTrace) => AlertDialog(
        title: const Text('Error'),
        content: Text('Failed to load prices: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
      loading: () => const AlertDialog(
        title: Text('Loading'),
        content: CircularProgressIndicator(),
      ),
    );
  }
}
