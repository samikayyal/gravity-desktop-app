// ignore: unused_import
import 'dart:developer';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/my_card.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/custom_widgets/revenue_card.dart';
import 'package:gravity_desktop_app/providers/stats_provider.dart';
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
                      flex: 2, child: MyCard(child: RevenueCard(widget.dates))),
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
                  Expanded(child: _buildBusiestHoursCard())
                ],
              ),
            )
          ],
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
}
