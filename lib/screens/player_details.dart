import 'dart:developer';

import 'package:change_case/change_case.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
import 'package:gravity_desktop_app/custom_widgets/my_card.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/models/session.dart';
import 'package:gravity_desktop_app/providers/past_players_provider.dart';
import 'package:gravity_desktop_app/providers/subscriptions_provider.dart';
import 'package:intl/intl.dart';

class PlayerDetails extends ConsumerStatefulWidget {
  final Player player;

  const PlayerDetails(this.player, {super.key});

  @override
  ConsumerState<PlayerDetails> createState() => _PlayerDetailsState();
}

class _PlayerDetailsState extends ConsumerState<PlayerDetails> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: MyAppBar(),
        body: Wrap(children: [
          // ----------------- Player details card
          _buildPlayerDetailsCard(),

          // ----------------- Subscription history card
          _buildSubscriptionHistoryCard(),

          // ----------------- Past Sessions card
          _buildPastSessionsCard(),
        ]));
  }

  MyCard _buildPlayerDetailsCard() {
    setState(() {
      1 == 1;
    });
    return ref.watch(playerPhonesProvider(widget.player.playerID)).when(
        data: (phoneNumbers) {
          return MyCard(
            child: Column(
              spacing: 6,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Player Information",
                    style: AppTextStyles.sectionHeaderStyle),
                const SizedBox(height: 8),
                _buildInfoRow("Name", widget.player.name),
                _buildInfoRow("Age", "${widget.player.age}"),
                _buildInfoRow(
                    "Phone Numbers",
                    phoneNumbers.isEmpty
                        ? "No phone numbers"
                        : phoneNumbers.join(", ")),
              ],
            ),
          );
        },
        loading: () => MyCard(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        error: (error, stack) {
          log("Error fetching player details: $error");
          return MyCard(
              child: Center(child: Text("Error fetching player details")));
        });
  }

  MyCard _buildSubscriptionHistoryCard() {
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final formatter = NumberFormat.decimalPattern();
    return MyCard(
        child: Column(
            spacing: 6,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text("Subscription History", style: AppTextStyles.sectionHeaderStyle),
          const SizedBox(height: 8),
          ref.watch(subInfoProvider(widget.player.playerID)).when(
              loading: () => Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                log("Error fetching subscription info: $error");
                return Center(child: Text("Error fetching subscription info"));
              },
              data: (subscriptions) {
                if (subscriptions.isEmpty) {
                  return Center(child: Text("Player never subscribed"));
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < subscriptions.length; i++) ...[
                      Text(
                        "Subscription ${i + 1}",
                        style: AppTextStyles.sectionHeaderStyle
                            .copyWith(color: const Color(0xFF3949AB)),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow("Start Date",
                          dateFormatter.format(subscriptions[i].startDate)),
                      _buildInfoRow("Expiry Date",
                          dateFormatter.format(subscriptions[i].expiryDate)),
                      _buildInfoRow(
                          "Status", subscriptions[i].status.toTitleCase()),
                      _buildInfoRow("Initial Hours",
                          "${subscriptions[i].totalMinutes / 60}"),
                      _buildInfoRow("Used Hours",
                          "${(subscriptions[i].totalMinutes - subscriptions[i].remainingMinutes) / 60}"),
                      _buildInfoRow("Total Fee",
                          formatter.format(subscriptions[i].totalFee)),
                      _buildInfoRow("Amount Paid",
                          formatter.format(subscriptions[i].amountPaid)),
                      if (i < subscriptions.length - 1) ...[
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                      ]
                    ]
                  ],
                );
              }),
        ]));
  }

  MyCard _buildPastSessionsCard() {
    return MyCard(
      child: SingleChildScrollView(
        child: Column(
          spacing: 6,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Past Sessions", style: AppTextStyles.sectionHeaderStyle),
            const SizedBox(height: 8),
            ref.watch(pastSessionsProvider(widget.player.playerID)).when(
                  loading: () => Center(child: CircularProgressIndicator()),
                  error: (error, stack) {
                    log("Error fetching past sessions: $error\n$stack");
                    return Center(child: Text("Error fetching past sessions"));
                  },
                  data: (List<Session> sessions) {
                    if (sessions.isEmpty) {
                      return Center(child: Text("No past sessions found"));
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < sessions.length; i++) ...[
                          const Divider(),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                              "Start Time",
                              DateFormat('hh:mm a dd/MM/yyyy')
                                  .format(sessions[i].checkInTime)),
                          _buildInfoRow(
                              "End Time",
                              DateFormat('hh:mm a')
                                  .format(sessions[i].checkOutTime)),
                          _buildInfoRow("Time Spent",
                              "${sessions[i].checkOutTime.difference(sessions[i].checkInTime).inMinutes} minutes"),
                          _buildInfoRow(
                              "Final Fee",
                              NumberFormat.decimalPattern()
                                  .format(sessions[i].finalFee)),
                          _buildInfoRow(
                              "Amount Paid",
                              NumberFormat.decimalPattern()
                                  .format(sessions[i].amountPaid)),
                          if (sessions[i].minutesUsed != null)
                            _buildInfoRow(
                              "Subscription Hours Used",
                              (sessions[i].minutesUsed! / 60).toString(),
                            ),
                        ]
                      ],
                    );
                  },
                )
          ],
        ),
      ),
    );
  }

  Row _buildInfoRow(String label, String value) {
    return Row(
      // mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppTextStyles.regularTextStyle.copyWith(
                fontWeight: FontWeight.bold, color: const Color(0xFF3949AB))),
        Text(value, style: AppTextStyles.regularTextStyle),
      ],
    );
  }
}
