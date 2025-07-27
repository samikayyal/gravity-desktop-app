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

class StatsScreen extends ConsumerStatefulWidget {
  final List<DateTime> dates;
  const StatsScreen(this.dates, {super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  final formatter = NumberFormat.decimalPattern();
  int _touchedPieChartIndex = -1;

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
                    Expanded(flex: 1, child: _buildSubscriptionRevenueCard())
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FractionallySizedBox(
                widthFactor: 0.5,
                child: Row(
                  children: [
                    _buildAgePieChartCard(),
                    Expanded(
                      child: _buildBusiestHoursCard(),
                    )
                  ],
                ),
              ),
              FractionallySizedBox(
                widthFactor: 0.43,
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildPeakCapacityCard(),
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
                      child: _buildTopPlayersCard(),
                    ),
                  ],
                ),
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
          return MyCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Busiest Hours",
                  style: AppTextStyles.sectionHeaderStyle,
                ),
                const SizedBox(
                  height: 16,
                ),
                for (var hourData in hoursData)
                  Padding(
                      padding: EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            hourData.hours,
                            style: AppTextStyles.regularTextStyle,
                          ),
                          Text(
                            "${hourData.playerCount} players",
                            style: AppTextStyles.regularTextStyle
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ))
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
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
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
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  flex: 1,
                  child: Container(
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
                    Text("No Players to Show.")
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
}
