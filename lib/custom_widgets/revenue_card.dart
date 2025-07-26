import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:gravity_desktop_app/providers/stats_provider.dart';
import 'package:gravity_desktop_app/utils/constants.dart';
import 'package:intl/intl.dart';

class RevenueCard extends ConsumerStatefulWidget {
  final List<DateTime> dates;
  const RevenueCard(this.dates, {super.key});

  @override
  ConsumerState<RevenueCard> createState() => _RevenueCardState();
}

class _RevenueCardState extends ConsumerState<RevenueCard> {
  late int totalIncome;
  late int totalPlayersIncome;
  late int totalProductsIncome;
  late int totalTips;

  bool _isLoading = false;

  // Formatter for displaying currency values
  final formatter = NumberFormat.decimalPattern();

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
    });

    totalIncome = await ref.read(totalIncomeProvider(widget.dates).future);

    totalPlayersIncome =
        await ref.read(playersIncomeProvider(widget.dates).future);

    totalProductsIncome = await ref
        .read(productsIncomeProvider(ProductIncomeParams(widget.dates)).future);

    totalTips = await ref.read(tipsProvider(widget.dates).future);

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: mainBlue));
    }

    // watching currentPlayersProvider to ensure we have the latest player data
    // and to trigger a rebuild when the data changes
    return ref.watch(currentPlayersProvider).maybeWhen(
        data: (_) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Today\'s Stats',
                      style: AppTextStyles.sectionHeaderStyle,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    color: mainBlue,
                    tooltip: 'Refresh stats',
                    onPressed: _fetchStats,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Primary element - Total Income with Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 18.0, horizontal: 20.0),
                decoration: BoxDecoration(
                  color: mainBlue.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: mainBlue.withAlpha(50), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.monetization_on_outlined,
                            color: mainBlue, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Total Income',
                          style: AppTextStyles.subtitleTextStyle
                              .copyWith(color: mainBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${formatter.format(totalIncome)} SYP',
                      style: AppTextStyles.highlightedTextStyle.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Other stats in a grid
              Flexible(
                fit: FlexFit.loose,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      // Players Income
                      Expanded(
                        child: _buildStatCard(
                          'Players',
                          totalPlayersIncome,
                          Icons.person,
                          Colors.green.shade600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Products Income
                      Expanded(
                        child: _buildStatCard(
                          'Products',
                          totalProductsIncome,
                          Icons.shopping_cart,
                          Colors.orange.shade600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Tips
                      Expanded(
                        child: _buildStatCard(
                          'Tips',
                          totalTips,
                          Icons.monetization_on,
                          Colors.purple.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        orElse: () => Center(child: CircularProgressIndicator()));
  }

  Widget _buildStatCard(String title, int amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(50), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.subtitleTextStyle.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${formatter.format(amount)} SYP',
            style: AppTextStyles.amountTextStyle.copyWith(
              fontSize: 20,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
