// ignore: unused_import
import 'dart:developer';

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
        child: FractionallySizedBox(
          widthFactor: 0.8,
          child: Column(
            children: [
              Center(
                  child: Text(
                titleString,
                style: AppTextStyles.pageTitleStyle,
              )),
              const SizedBox(height: 48),
              FractionallySizedBox(
                widthFactor: 0.7,
                child: Row(
                  spacing: 16,
                  children: [
                    Expanded(
                        flex: 2,
                        child: MyCard(child: RevenueCard(widget.dates))),
                    Expanded(flex: 1, child: _buildSubscriptionRevenueCard())
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
}
