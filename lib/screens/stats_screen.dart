// ignore: unused_import
import 'dart:developer';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/my_card.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/custom_widgets/revenue_card.dart';
import 'package:gravity_desktop_app/providers/past_players_provider.dart';
import 'package:gravity_desktop_app/providers/stats_provider.dart';
import 'package:gravity_desktop_app/screens/player_details.dart';
import 'package:gravity_desktop_app/utils/constants.dart';
import 'package:gravity_desktop_app/utils/general.dart';
import 'package:intl/intl.dart';
import 'package:week_of_year/date_week_extensions.dart';

enum LineChartSelection { players, products, all }

class StatsScreen extends ConsumerStatefulWidget {
  final List<DateTime> dates;
  const StatsScreen(this.dates, {super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  final formatter = NumberFormat.decimalPattern();
  int _touchedPieChartIndex = -1;
  LineChartSelection _lineChartSelection = LineChartSelection.players;

  bool _checkIsRange() {
    final dates = widget.dates;
    if (dates.length <= 1) return false;

    for (int i = 0; i < dates.length - 1; i++) {
      if (dates[i].difference(dates[i + 1]).inDays.abs() > 1) {
        log("Difference between ${dates[i].toYYYYMMDD()} and ${dates[i + 1].toYYYYMMDD()} is more than 1 day");
        return false; // Found a gap larger than 1 day
      }
    }
    return true; // All dates are consecutive or the same
  }

  @override
  Widget build(BuildContext context) {
    // title setup
    String titleString = 'Statistics for ';
    if (_checkIsRange()) {
      titleString +=
          "${widget.dates.first.toYYYYMMDD()} ➜ ${widget.dates.last.toYYYYMMDD()}";
    } else {
      titleString += widget.dates.map((date) => date.toYYYYMMDD()).join(', ');
    }

    // build
    return Scaffold(
      appBar: MyAppBar(),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                  child: Text(
                titleString,
                style: AppTextStyles.pageTitleStyle,
              )),
              const SizedBox(height: 48),
              FractionallySizedBox(
                widthFactor: 0.56,
                child: Row(
                  spacing: 16,
                  children: [
                    Expanded(
                        flex: 2,
                        child: MyCard(child: RevenueCard(widget.dates))),
                    Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            _buildPeakCapacityCard(),
                            _buildSubscriptionRevenueCard(),
                          ],
                        ))
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FractionallySizedBox(
                widthFactor: 0.65,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildAgePieChartCard(),
                    ),
                    Expanded(
                      flex: 3,
                      child: _buildBusiestHoursCard(),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildDiscountsCard(),
                    )
                  ],
                ),
              ),
              FractionallySizedBox(
                widthFactor: 0.5,
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildTopPlayersCard(),
                    ),
                    Expanded(
                      flex: 1,
                      child: _buildProductSalesCard(),
                    )
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 70),
                child: _buildPlayerLineChart(),
              ),
              const SizedBox(
                height: 32,
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionRevenueCard() {
    final subRevenueAsync =
        ref.watch(subscriptionRevenueProvider(widget.dates));
    return subRevenueAsync.maybeWhen(
        orElse: () => MyCard(
                child: Center(
              child: CircularProgressIndicator(),
            )),
        data: (revenue) {
          return MyCard(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Subscriptions", style: AppTextStyles.sectionHeaderStyle),
              const SizedBox(
                height: 16,
              ),
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
                        Icon(Icons.person_4, color: mainBlue, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Subscription Income',
                          style: AppTextStyles.subtitleTextStyle
                              .copyWith(color: mainBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${formatter.format(revenue)} SYP',
                      style: AppTextStyles.highlightedTextStyle.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ));
        });
  }

  Widget _buildAgePieChartCard() {
    return ref.watch(ageGroupsProvider(widget.dates)).maybeWhen(
          orElse: () => MyCard(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
          data: (ageGroups) {
            return MyCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Age Groups Distribution",
                      style: AppTextStyles.sectionHeaderStyle),
                  const SizedBox(height: 16),
                  // Check if ageGroups is empty
                  if (ageGroups.isEmpty)
                    SizedBox(
                      height: 300,
                      width: 600,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.pie_chart_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No data available',
                              style: AppTextStyles.subtitleTextStyle.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 300,
                          width: 300,
                          child: PieChart(
                            PieChartData(
                                centerSpaceRadius: 0,
                                sectionsSpace: 0,
                                titleSunbeamLayout: true,
                                sections:
                                    ageGroups.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final ageGroupData = entry.value;
                                  // final ageGroup = ageGroupData.ageGroup;
                                  final percent = ageGroupData.count *
                                      100 /
                                      ageGroups.fold<int>(
                                          0, (sum, item) => sum + item.count);

                                  final isTouched =
                                      index == _touchedPieChartIndex;

                                  return PieChartSectionData(
                                    value: percent,
                                    title: "${percent.round()}%",
                                    radius: isTouched ? 150 : 130,
                                    titleStyle: AppTextStyles.subtitleTextStyle
                                        .copyWith(
                                      color: Colors.white,
                                    ),
                                    color: ageGroupData.color,
                                    titlePositionPercentageOffset: 0.8,
                                  );
                                }).toList(),
                                pieTouchData: PieTouchData(
                                    enabled: true,
                                    touchCallback: (touchEvent, touchResponse) {
                                      if (!touchEvent
                                              .isInterestedForInteractions ||
                                          touchResponse == null ||
                                          touchResponse.touchedSection ==
                                              null) {
                                        _touchedPieChartIndex = -1;
                                        return;
                                      }
                                      setState(() {
                                        _touchedPieChartIndex = touchResponse
                                            .touchedSection!
                                            .touchedSectionIndex;
                                      });
                                    })),
                          ),
                        ),
                        // Legend
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0; i < ageGroups.length; i++)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  i == _touchedPieChartIndex
                                      ? Container(
                                          color: ageGroups[i].color,
                                          child: const SizedBox(
                                            height: 22,
                                            width: 22,
                                          ),
                                        )
                                      : Container(
                                          color: ageGroups[i].color,
                                          child: const SizedBox(
                                            height: 15,
                                            width: 15,
                                          ),
                                        ),
                                  const SizedBox(
                                    width: 4,
                                  ),
                                  Text(
                                    ageGroups[i].ageGroup,
                                    style: i == _touchedPieChartIndex
                                        ? AppTextStyles.regularTextStyle
                                            .copyWith(
                                                fontWeight: FontWeight.bold)
                                        : AppTextStyles.regularTextStyle,
                                  )
                                ],
                              )
                          ],
                        )
                      ],
                    ),
                  ]
                ],
              ),
            );
          },
        );
  }

  Widget _buildBusiestHoursCard() {
    return ref.watch(busiestHoursProvider(widget.dates)).maybeWhen(
        data: (hoursData) {
          if (hoursData.isEmpty) {
            return MyCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Busiest Hours",
                    style: AppTextStyles.sectionHeaderStyle,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No data available',
                            style: AppTextStyles.subtitleTextStyle.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return MyCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Busiest Hours",
                  style: AppTextStyles.sectionHeaderStyle,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: hoursData.length,
                    itemBuilder: (context, index) {
                      final hourData = hoursData[index];
                      final isTopHour =
                          index < 3; // Highlight top 3 busiest hours

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isTopHour
                              ? mainBlue.withAlpha(15)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isTopHour
                                ? mainBlue.withAlpha(40)
                                : Colors.grey.withAlpha(40),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(5),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Rank indicator for top hours
                            if (isTopHour) ...[
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: mainBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: AppTextStyles.subtitleTextStyle
                                        .copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],

                            // Time with icon
                            Icon(
                              Icons.access_time,
                              size: 18,
                              color: isTopHour ? mainBlue : Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                hourData.hours,
                                style: AppTextStyles.regularTextStyle.copyWith(
                                  fontWeight: isTopHour
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isTopHour ? mainBlue : null,
                                ),
                              ),
                            ),

                            // Player count with background
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isTopHour
                                    ? mainBlue.withAlpha(25)
                                    : Colors.grey.withAlpha(25),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.people,
                                    size: 16,
                                    color:
                                        isTopHour ? mainBlue : Colors.grey[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${hourData.playerCount}",
                                    style:
                                        AppTextStyles.regularTextStyle.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isTopHour
                                          ? mainBlue
                                          : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
        orElse: () => MyCard(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ));
  }

  Widget _buildPeakCapacityCard() {
    return ref.watch(peakCapacityProvider(widget.dates)).maybeWhen(
          data: (peakCapacity) {
            return MyCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Peak Capacity",
                      style: AppTextStyles.sectionHeaderStyle),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 18.0, horizontal: 20.0),
                    decoration: BoxDecoration(
                      color: mainBlue.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: mainBlue.withAlpha(50), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '$peakCapacity players',
                        style: AppTextStyles.highlightedTextStyle.copyWith(
                            fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          orElse: () => MyCard(
            child: Center(child: CircularProgressIndicator()),
          ),
        );
  }

  Widget _buildDiscountsCard() {
    return ref.watch(discountDataProvider(widget.dates)).maybeWhen(
        data: (discountData) {
      return MyCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Discounts", style: AppTextStyles.sectionHeaderStyle),
            const SizedBox(height: 16),
            Column(
              children: [
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
                          Icon(Icons.discount, color: mainBlue, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Discount Amount',
                            style: AppTextStyles.subtitleTextStyle
                                .copyWith(color: mainBlue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${formatter.format(discountData.totalDiscountAmount)} SYP',
                        style: AppTextStyles.highlightedTextStyle.copyWith(
                            fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
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
                          Icon(Icons.numbers_outlined,
                              color: mainBlue, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Number of Discounts',
                            style: AppTextStyles.subtitleTextStyle
                                .copyWith(color: mainBlue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        formatter.format(discountData.totalNumberofDiscounts),
                        style: AppTextStyles.highlightedTextStyle.copyWith(
                            fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }, orElse: () {
      return MyCard(child: Center(child: CircularProgressIndicator()));
    });
  }

  Widget _buildTopPlayersCard() {
    return ref.watch(topPlayersProvider(widget.dates)).maybeWhen(
        data: (topPlayers) {
          if (topPlayers.isEmpty) {
            log("Top Players: $topPlayers");
            return MyCard(
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.person_off,
                      size: 24,
                      color: Colors.black.withAlpha(75),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      "No Players to Show.",
                      style: AppTextStyles.regularTextStyle
                          .copyWith(color: Colors.black.withAlpha(150)),
                    )
                  ],
                ),
              ),
            );
          }
          return MyCard(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Top 10 Players",
                style: AppTextStyles.sectionHeaderStyle,
              ),
              const SizedBox(
                height: 16,
              ),
              SizedBox(
                height: 350,
                width: double.infinity,
                child: ListView.separated(
                  itemCount: topPlayers.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final player = topPlayers[index];
                    final totalMinutes = player.timeSpent.inMinutes;
                    final hours = totalMinutes ~/ 60;
                    final minutes = totalMinutes % 60;

                    String timeDisplay;
                    if (hours > 0) {
                      timeDisplay = '${hours}h ${minutes}m';
                    } else {
                      timeDisplay = '${minutes}m';
                    }

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: mainBlue.withAlpha(10),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: mainBlue.withAlpha(30), width: 1),
                      ),
                      child: InkWell(
                        onTap: () async {
                          final playerForDetails = await ref
                              .read(pastPlayersProvider.notifier)
                              .getPlayerById(player.playerId);

                          if (context.mounted) {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) =>
                                    PlayerDetails(playerForDetails)));
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            // Rank circle
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: mainBlue,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style:
                                      AppTextStyles.subtitleTextStyle.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Player info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    player.name,
                                    style:
                                        AppTextStyles.regularTextStyle.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        timeDisplay,
                                        style: AppTextStyles.subtitleTextStyle
                                            .copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(
                                        Icons.event_repeat,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${player.sessionCount} session${player.sessionCount != 1 ? 's' : ''}',
                                        style: AppTextStyles.subtitleTextStyle
                                            .copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Arrow indicator
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: mainBlue.withAlpha(150),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            ],
          ));
        },
        orElse: () => MyCard(
                child: Center(
              child: CircularProgressIndicator(),
            )));
  }

  Widget _buildProductSalesCard() {
    return ref.watch(productSalesProvider(widget.dates)).maybeWhen(
        data: (productSales) {
          if (productSales.isEmpty) {
            return MyCard(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Product Sales",
                  style: AppTextStyles.sectionHeaderStyle,
                ),
                const SizedBox(
                  height: 16,
                ),
                SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.remove_shopping_cart,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No Products to show",
                          style: AppTextStyles.regularTextStyle
                              .copyWith(color: Colors.grey[600]),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ));
          }

          // Calculate total revenue for percentage display
          final totalRevenue = productSales.fold<int>(
              0, (sum, product) => sum + product.totalRevenue);

          return MyCard(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Product Sales",
                style: AppTextStyles.sectionHeaderStyle,
              ),
              const SizedBox(
                height: 16,
              ),
              // Products list
              SizedBox(
                height: 350,
                child: ListView.separated(
                  itemCount: productSales.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product = productSales[index];
                    final revenuePercentage = totalRevenue > 0
                        ? (product.totalRevenue / totalRevenue * 100)
                        : 0.0;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(5),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  product.name,
                                  style:
                                      AppTextStyles.regularTextStyle.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: mainBlue.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${revenuePercentage.toStringAsFixed(1)}%',
                                  style:
                                      AppTextStyles.subtitleTextStyle.copyWith(
                                    color: mainBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.inventory,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${product.quantitySold} sold',
                                    style: AppTextStyles.subtitleTextStyle
                                        .copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${formatter.format(product.totalRevenue)} SYP',
                                style: AppTextStyles.regularTextStyle.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: mainBlue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ));
        },
        orElse: () => MyCard(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ));
  }

  Widget _buildPlayerLineChart() {
    return ref.watch(lineChartDataProvider(widget.dates)).maybeWhen(
        data: (chartData) {
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
          double maxY = 0;
          for (var d in chartData) {
            if (d.playerCount > maxY) maxY = d.playerCount.toDouble();
            if (d.productSaleCount > maxY) maxY = d.productSaleCount.toDouble();
          }

          final LineChartBucketSize bucketSize;
          if (widget.dates.length < minDatesForDailyBuckets) {
            bucketSize = LineChartBucketSize.hourly;
          } else if (widget.dates.length < minDatesForWeeklyBuckets) {
            bucketSize = LineChartBucketSize.daily;
          } else if (widget.dates.length < minDatesForMonthlyBuckets) {
            bucketSize = LineChartBucketSize.weekly;
          } else {
            bucketSize = LineChartBucketSize.monthly;
          }

          return MyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Check-ins and Product Sales Over Time',
                      style: AppTextStyles.sectionHeaderStyle,
                    ),

                    // Legend
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_lineChartSelection ==
                                  LineChartSelection.players) {
                                _lineChartSelection = LineChartSelection.all;
                              } else {
                                _lineChartSelection =
                                    LineChartSelection.players;
                              }
                            });
                          },
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: [
                                    LineChartSelection.players,
                                    LineChartSelection.all
                                  ].contains(_lineChartSelection)
                                      ? playersLineChartColor
                                      : playersLineChartColor.withAlpha(100),
                                  shape: BoxShape.circle,
                                ),
                                width: [
                                  LineChartSelection.players,
                                  LineChartSelection.all
                                ].contains(_lineChartSelection)
                                    ? 20
                                    : 16,
                                height: [
                                  LineChartSelection.players,
                                  LineChartSelection.all
                                ].contains(_lineChartSelection)
                                    ? 20
                                    : 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Players',
                                style: [
                                  LineChartSelection.players,
                                  LineChartSelection.all
                                ].contains(_lineChartSelection)
                                    ? AppTextStyles.regularTextStyle
                                        .copyWith(fontWeight: FontWeight.bold)
                                    : AppTextStyles.regularTextStyle
                                        .copyWith(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_lineChartSelection ==
                                  LineChartSelection.products) {
                                _lineChartSelection = LineChartSelection.all;
                              } else {
                                _lineChartSelection =
                                    LineChartSelection.products;
                              }
                            });
                          },
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: [
                                    LineChartSelection.products,
                                    LineChartSelection.all
                                  ].contains(_lineChartSelection)
                                      ? productsLineChartColor
                                      : productsLineChartColor.withAlpha(100),
                                  shape: BoxShape.circle,
                                ),
                                width: [
                                  LineChartSelection.products,
                                  LineChartSelection.all
                                ].contains(_lineChartSelection)
                                    ? 20
                                    : 16,
                                height: [
                                  LineChartSelection.products,
                                  LineChartSelection.all
                                ].contains(_lineChartSelection)
                                    ? 20
                                    : 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Products',
                                style: [
                                  LineChartSelection.products,
                                  LineChartSelection.all
                                ].contains(_lineChartSelection)
                                    ? AppTextStyles.regularTextStyle
                                        .copyWith(fontWeight: FontWeight.bold)
                                    : AppTextStyles.regularTextStyle
                                        .copyWith(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                    height: 400,
                    child: LineChart(
                      LineChartData(
                        lineBarsData: [
                          if (_lineChartSelection ==
                                  LineChartSelection.players ||
                              _lineChartSelection == LineChartSelection.all)
                            // Players
                            LineChartBarData(
                                spots: [
                                  for (int i = 0; i < chartData.length; i++)
                                    FlSpot(i.toDouble(),
                                        chartData[i].playerCount.toDouble())
                                ],
                                isCurved: true,
                                curveSmoothness: 0.25,
                                dotData: FlDotData(show: false),
                                belowBarData: BarAreaData(show: false),
                                color: playersLineChartColor),
                          if (_lineChartSelection ==
                                  LineChartSelection.products ||
                              _lineChartSelection == LineChartSelection.all)
                            // Products
                            LineChartBarData(
                              spots: [
                                for (int i = 0; i < chartData.length; i++)
                                  FlSpot(i.toDouble(),
                                      chartData[i].productSaleCount.toDouble())
                              ],
                              isCurved: true,
                              curveSmoothness: 0.20,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(show: false),
                              color: productsLineChartColor,
                            ),
                        ],
                        minY: 0,
                        maxY: maxY,
                        titlesData: FlTitlesData(
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 100,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() < 0 ||
                                    value.toInt() >= chartData.length) {
                                  return Text('');
                                }
                                final time = chartData[value.toInt()].time;
                                final String formattedTime;
                                if (bucketSize == LineChartBucketSize.hourly) {
                                  formattedTime =
                                      DateFormat('hh:mm aa').format(time);
                                } else if (bucketSize ==
                                    LineChartBucketSize.daily) {
                                  formattedTime =
                                      DateFormat('MM/dd').format(time);
                                } else if (bucketSize ==
                                    LineChartBucketSize.weekly) {
                                  formattedTime =
                                      "${DateFormat('yyyy').format(time)}-${time.weekOfYear}";
                                } else {
                                  formattedTime =
                                      DateFormat('MMM/yyyy').format(time);
                                }

                                return Transform.translate(
                                  offset: const Offset(-10, 0),
                                  child: Column(
                                    children: [
                                      const SizedBox(
                                        height: 16,
                                      ),
                                      Transform.rotate(
                                        // rotate -45 degrees
                                        angle: -45 * 3.14 / 180,
                                        child: Text(formattedTime),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ))),
                      ),
                    )),
              ],
            ),
          );
        },
        orElse: () => MyCard(
                child: Center(
              child: CircularProgressIndicator(),
            )));
  }
}
