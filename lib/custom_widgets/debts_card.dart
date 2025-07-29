import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/providers/debt_provider.dart';

class DebtsCard extends ConsumerStatefulWidget {
  const DebtsCard({super.key});

  @override
  ConsumerState<DebtsCard> createState() => _DebtsCardState();
}

class _DebtsCardState extends ConsumerState<DebtsCard> {
  @override
  Widget build(BuildContext context) {
    return ref.watch(debtProvider).when(
        data: (debts) {
          if (debts.isEmpty) {
            return Center(
              child: Text(
                'No Debts',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return Column(
            children: [
              Text("Debts", style: AppTextStyles.sectionHeaderStyle),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: debts.length,
                  itemBuilder: (context, index) {
                    final debt = debts[index];
                    return ListTile(
                      title: Text(debt.playerName),
                      subtitle: Text('Amount: ${debt.amount}'),
                      trailing: Text('Created at: ${debt.createdAt.toLocal()}'),
                      leadingAndTrailingTextStyle:
                          AppTextStyles.regularTextStyle,
                      onTap: () {
                        // Handle tap to view or edit debt details
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
        error: (error, stackTrace) => Center(
              child: Text(
                'Error: $error',
                style: TextStyle(color: Colors.red),
              ),
            ),
        loading: () => Center(child: CircularProgressIndicator()));
  }
}
