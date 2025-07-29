import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/debt_payment_dialog.dart';
import 'package:intl/intl.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/my_card.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/providers/debt_provider.dart';

class DebtsCard extends ConsumerStatefulWidget {
  const DebtsCard({super.key});

  @override
  ConsumerState<DebtsCard> createState() => _DebtsCardState();
}

class _DebtsCardState extends ConsumerState<DebtsCard> {
  final formatter = NumberFormat.decimalPattern();
  final dateFormatter = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    return MyCard(
      child: ref.watch(debtProvider).when(
            data: (debts) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon
                  Row(
                    children: [
                      Text(
                        "Debts",
                        style: AppTextStyles.sectionHeaderStyle,
                      ),
                      const Spacer(),
                      if (debts.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${debts.length}',
                            style: AppTextStyles.subtitleTextStyle.copyWith(
                              color: Colors.red.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Content
                  if (debts.isEmpty)
                    _buildEmptyState()
                  else
                    Expanded(
                      child: _buildDebtsList(debts, formatter, dateFormatter),
                    ),
                ],
              );
            },
            error: (error, stackTrace) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (consistent even in error state)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Outstanding Debts",
                      style: AppTextStyles.sectionHeaderStyle
                          .copyWith(color: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildErrorState(error),
              ],
            ),
            loading: () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (consistent even in loading state)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Outstanding Debts",
                      style: AppTextStyles.sectionHeaderStyle
                          .copyWith(color: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLoadingState(),
              ],
            ),
          ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No outstanding debts',
              style: AppTextStyles.subtitleTextStyle.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All payments are up to date',
              style: AppTextStyles.subtitleTextStyle.copyWith(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtsList(
      List debts, NumberFormat formatter, DateFormat dateFormatter) {
    return ListView.separated(
      itemCount: debts.length,
      separatorBuilder: (context, index) => Divider(
        color: Colors.grey.shade200,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final debt = debts[index];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              // Player name and debt info
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.playerName,
                      style: AppTextStyles.regularTextStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFormatter.format(debt.createdAt.toLocal()),
                      style: AppTextStyles.subtitleTextStyle.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Amount
              Text(
                '${formatter.format(debt.amount)} SYP',
                style: AppTextStyles.amountTextStyle.copyWith(
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),

              // Action button
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) => DebtPaymentDialog(debt));
                },
                icon: Icon(
                  Icons.payment,
                  color: Colors.red.shade600,
                  size: 20,
                ),
                tooltip: 'Make Payment',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withAlpha(20),
                  minimumSize: const Size(32, 32),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(dynamic error) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load debts',
              style: AppTextStyles.subtitleTextStyle.copyWith(
                color: Colors.red[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: AppTextStyles.subtitleTextStyle.copyWith(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading debts...',
              style: AppTextStyles.subtitleTextStyle.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
