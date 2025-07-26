import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/custom_widgets/revenue_card.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/my_card.dart';
import 'package:gravity_desktop_app/providers/stats_provider.dart';
import 'package:intl/intl.dart';

class StatsScreen2 extends ConsumerStatefulWidget {
  final List<DateTime> dates;
  const StatsScreen2(this.dates, {super.key});

  @override
  ConsumerState<StatsScreen2> createState() => _StatsScreen2State();
}

class _StatsScreen2State extends ConsumerState<StatsScreen2> {
  @override
  Widget build(BuildContext context) {
    final statsNotifier = ref.watch(statsProvider);

    return Scaffold(
      appBar: MyAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: Text(
                'Statistics',
                style: AppTextStyles.pageTitleStyle,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            // Revenue Cards Row
            Row(
              children: [
                Expanded(
                  child: MyCard(
                    child: RevenueCard(widget.dates),
                  ),
                ),
                Expanded(
                  child: MyCard(child: SizedBox.shrink()),
                ),
              ],
            ),

            // Subscription Stats and Age Distribution Row
            Row(
              children: [
                Expanded(
                  child: _buildSubscriptionStatsCard(statsNotifier),
                ),
                Expanded(
                  child: _buildAgeDistributionCard(statsNotifier),
                ),
              ],
            ),

            // Peak Capacity and Busiest Hours Row
            Row(
              children: [
                Expanded(
                  child: _buildPeakCapacityCard(statsNotifier),
                ),
                Expanded(
                  child: _buildBusiestHoursCard(statsNotifier),
                ),
              ],
            ),

            // Product Sales and Discounts Row
            Row(
              children: [
                Expanded(
                  child: _buildProductSalesCard(statsNotifier),
                ),
                Expanded(
                  child: _buildDiscountsCard(statsNotifier),
                ),
              ],
            ),

            // Most Frequent Players Card
            _buildMostFrequentPlayersCard(statsNotifier),

            // Check-in Chart Card
            _buildCheckInChartCard(statsNotifier),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionStatsCard(StatsNotifier statsNotifier) {
    return MyCard(
      child: FutureBuilder<Map<String, dynamic>>(
        future: statsNotifier.getSubscriptionStats(widget.dates),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = snapshot.data ?? {};
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subscription Stats',
                style: AppTextStyles.sectionHeaderStyle,
              ),
              const SizedBox(height: 16),
              _buildStatRow('Active', '${stats['activeCount'] ?? 0}'),
              _buildStatRow('Expired', '${stats['expiredCount'] ?? 0}'),
              _buildStatRow('New', '${stats['newSubscriptionsCount'] ?? 0}'),
              _buildStatRow('Avg Utilization',
                  '${(stats['averageUtilization'] ?? 0.0).toStringAsFixed(1)}%'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAgeDistributionCard(StatsNotifier statsNotifier) {
    return MyCard(
      child: FutureBuilder<Map<String, int>>(
        future: statsNotifier.getPlayerAgeDistribution(widget.dates),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final ageData = snapshot.data ?? {};
          if (ageData.isEmpty) {
            return Column(
              children: [
                Text('Player Age Distribution',
                    style: AppTextStyles.sectionHeaderStyle),
                const SizedBox(height: 16),
                const Text('No data available'),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Player Age Distribution',
                style: AppTextStyles.sectionHeaderStyle,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: _createPieChartSections(ageData),
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ..._buildPieChartLegend(ageData),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPeakCapacityCard(StatsNotifier statsNotifier) {
    return MyCard(
      child: FutureBuilder<int>(
        future: statsNotifier.getPeakCapacity(widget.dates),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final peakCapacity = snapshot.data ?? 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Peak Capacity',
                style: AppTextStyles.sectionHeaderStyle,
              ),
              const SizedBox(height: 16),
              Text(
                '$peakCapacity',
                style:
                    AppTextStyles.highlightedTextStyle.copyWith(fontSize: 32),
              ),
              const SizedBox(height: 8),
              Text(
                'Maximum concurrent players',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBusiestHoursCard(StatsNotifier statsNotifier) {
    return MyCard(
      child: FutureBuilder<Map<int, int>>(
        future: statsNotifier.getBusiestHours(widget.dates),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final hourlyData = snapshot.data ?? {};
          final sortedHours = hourlyData.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Busiest Hours',
                style: AppTextStyles.sectionHeaderStyle,
              ),
              const SizedBox(height: 16),
              if (sortedHours.isEmpty)
                const Text('No data available')
              else
                ...sortedHours.take(5).map((entry) => _buildStatRow(
                    '${entry.key}:00', '${entry.value} check-ins')),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductSalesCard(StatsNotifier statsNotifier) {
    return MyCard(
      child: FutureBuilder<Map<String, dynamic>>(
        future: statsNotifier.getProductSalesDetails(widget.dates),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final salesData = snapshot.data ?? {};
          final products =
              salesData['products'] as List<Map<String, dynamic>>? ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product Sales',
                style: AppTextStyles.sectionHeaderStyle,
              ),
              const SizedBox(height: 16),
              _buildStatRow('Total Revenue',
                  NumberFormat('#,###').format(salesData['totalRevenue'] ?? 0)),
              _buildStatRow(
                  'Total Quantity', '${salesData['totalQuantity'] ?? 0}'),
              const SizedBox(height: 12),
              if (products.isEmpty)
                const Text('No products sold')
              else
                ...products.take(3).map((product) => _buildStatRow(
                      product['name'] as String,
                      '${product['quantity']} sold - ${NumberFormat('#,###').format(product['revenue'])}',
                    )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDiscountsCard(StatsNotifier statsNotifier) {
    return MyCard(
      child: FutureBuilder<Map<String, dynamic>>(
        future: statsNotifier.getDiscountStats(widget.dates),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final discountData = snapshot.data ?? {};
          final reasons =
              discountData['discountReasons'] as List<Map<String, dynamic>>? ??
                  [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Discounts',
                style: AppTextStyles.sectionHeaderStyle,
              ),
              const SizedBox(height: 16),
              _buildStatRow(
                  'Total Discount',
                  NumberFormat('#,###')
                      .format(discountData['totalDiscount'] ?? 0)),
              _buildStatRow(
                  'Discount Count', '${discountData['discountCount'] ?? 0}'),
              const SizedBox(height: 12),
              if (reasons.isEmpty)
                const Text('No discounts given')
              else
                ...reasons.take(3).map((reason) => _buildStatRow(
                      reason['reason'] as String,
                      '${NumberFormat('#,###').format(reason['totalDiscount'])} (${reason['count']}x)',
                    )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMostFrequentPlayersCard(StatsNotifier statsNotifier) {
    return MyCard(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: statsNotifier.getMostFrequentPlayers(widget.dates),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final players = snapshot.data ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Most Frequent Players',
                style: AppTextStyles.sectionHeaderStyle,
              ),
              const SizedBox(height: 16),
              if (players.isEmpty)
                const Text('No data available')
              else
                ...players.map((player) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${player['name']} (${player['age']})',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(
                            '${player['visitCount']} visits',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCheckInChartCard(StatsNotifier statsNotifier) {
    return MyCard(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: statsNotifier.getPlayerCheckInChart(widget.dates),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final chartData = snapshot.data ?? [];
          if (chartData.isEmpty) {
            return Column(
              children: [
                Text('Check-ins Over Time',
                    style: AppTextStyles.sectionHeaderStyle),
                const SizedBox(height: 16),
                const Text('No data available'),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Check-ins Over Time',
                style: AppTextStyles.sectionHeaderStyle,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 &&
                                value.toInt() < chartData.length) {
                              final data = chartData[value.toInt()];
                              final time = data['time'] as DateTime;
                              return Text(
                                widget.dates.length <= 4
                                    ? DateFormat('HH:mm').format(time)
                                    : DateFormat('MM/dd').format(time),
                                style: const TextStyle(fontSize: 10),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text(value.toInt().toString());
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: chartData.asMap().entries.map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            (entry.value['checkInCount'] as int).toDouble(),
                          );
                        }).toList(),
                        isCurved: true,
                        color: Theme.of(context).primaryColor,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  List<PieChartSectionData> _createPieChartSections(Map<String, int> ageData) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    final total = ageData.values.fold(0, (sum, count) => sum + count);

    return ageData.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final ageGroup = entry.value.key;
      final count = entry.value.value;
      final percentage = (count / total * 100);

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: count.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  List<Widget> _buildPieChartLegend(Map<String, int> ageData) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    return ageData.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final ageGroup = entry.value.key;
      final count = entry.value.value;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text('$ageGroup: $count'),
          ],
        ),
      );
    }).toList();
  }
}
