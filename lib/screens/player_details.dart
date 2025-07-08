import 'dart:developer';

import 'package:change_case/change_case.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/edit_profile_dialog.dart';
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page header with player name
              _buildPageHeader(),
              const SizedBox(height: 24),

              // Top row - Player details and quick stats
              Center(
                child: FractionallySizedBox(
                  widthFactor: 0.6,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 1,
                        child: _buildPlayerDetailsCard(),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: _buildQuickStatsCard(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bottom row - Subscription history and Past sessions
              Center(
                child: FractionallySizedBox(
                  widthFactor: 0.8,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: _buildPastSessionsCard(),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: _buildSubscriptionHistoryCard(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  MyCard _buildPlayerDetailsCard() {
    return ref.watch(playerPhonesProvider(widget.player.playerID)).when(
        data: (phoneNumbers) {
          return MyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3949AB).withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.person,
                        color: const Color(0xFF3949AB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Player Information",
                      style: AppTextStyles.sectionHeaderStyle.copyWith(
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Player details with modern styling
                _buildModernInfoItem(
                  icon: Icons.account_circle_outlined,
                  label: "Full Name",
                  value: widget.player.name,
                  valueStyle: AppTextStyles.highlightedTextStyle.copyWith(
                    fontSize: 22,
                  ),
                ),

                const SizedBox(height: 16),

                _buildModernInfoItem(
                  icon: Icons.cake_outlined,
                  label: "Age",
                  value: "${widget.player.age} years old",
                  valueStyle: AppTextStyles.regularTextStyle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 16),

                _buildModernInfoItem(
                  icon: Icons.phone_outlined,
                  label: "Phone Numbers",
                  value: phoneNumbers.isEmpty
                      ? "No phone numbers registered"
                      : phoneNumbers.join(" • "),
                  valueStyle: AppTextStyles.regularTextStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: phoneNumbers.isEmpty
                        ? Colors.grey[500]
                        : AppTextStyles.regularTextStyle.color,
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => MyCard(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: const Color(0xFF3949AB),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Loading player details...",
                      style: AppTextStyles.subtitleTextStyle,
                    ),
                  ],
                ),
              ),
            ),
        error: (error, stack) {
          log("Error fetching player details: $error");
          return MyCard(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red[600],
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Error loading player details",
                    style: AppTextStyles.subtitleTextStyle.copyWith(
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }

  Widget _buildModernInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required TextStyle valueStyle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF3949AB).withAlpha(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF3949AB).withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF3949AB),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.subtitleTextStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: valueStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3949AB).withAlpha(25),
            const Color(0xFF3949AB).withAlpha(5),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3949AB).withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF3949AB),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
              child: Text(
                widget.player.name.isNotEmpty
                    ? widget.player.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.player.name,
                  style: AppTextStyles.sectionHeaderStyle.copyWith(
                    fontSize: 28,
                    color: const Color(0xFF3949AB),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Player ID: ${widget.player.playerID}",
                  style: AppTextStyles.regularTextStyle.copyWith(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
              onPressed: () async {
                await showDialog(
                    context: context,
                    builder: (context) {
                      return EditProfileDialog(
                          playerId: widget.player.playerID);
                    });
              },
              icon: Icon(
                Icons.edit,
                size: 26,
                color: const Color(0xFF3949AB),
              ))
        ],
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    return MyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: const Color(0xFF3949AB),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "Quick Stats",
                style: AppTextStyles.sectionHeaderStyle,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total sessions stat
          ref.watch(pastSessionsProvider(widget.player.playerID)).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => const Text("Error loading stats"),
                data: (sessions) {
                  final totalSessions = sessions.length;
                  final totalTimeSpent = sessions.fold<int>(
                    0,
                    (sum, session) =>
                        sum +
                        session.checkOutTime
                            .difference(session.checkInTime)
                            .inMinutes,
                  );
                  final totalAmountPaid = sessions.fold<double>(
                    0.0,
                    (sum, session) => sum + session.amountPaid,
                  );

                  return Column(
                    children: [
                      _buildStatItem(
                        "Total Sessions",
                        totalSessions.toString(),
                        Icons.sports_esports,
                      ),
                      const SizedBox(height: 12),
                      _buildStatItem(
                        "Total Time Played",
                        "${(totalTimeSpent / 60).toStringAsFixed(1)} hours",
                        Icons.schedule,
                      ),
                      const SizedBox(height: 12),
                      _buildStatItem(
                        "Total Amount Paid",
                        NumberFormat.decimalPattern().format(totalAmountPaid),
                        Icons.monetization_on_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildStatItem(
                        "Average Session",
                        totalSessions > 0
                            ? "${(totalTimeSpent / totalSessions).toStringAsFixed(0)} minutes"
                            : "0 minutes",
                        Icons.access_time,
                      ),
                    ],
                  );
                },
              ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3949AB).withAlpha(5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF3949AB).withAlpha(25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF3949AB),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.regularTextStyle.copyWith(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: AppTextStyles.regularTextStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF3949AB),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  MyCard _buildSubscriptionHistoryCard() {
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final formatter = NumberFormat.decimalPattern();
    return MyCard(
      child: Column(
          spacing: 6,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.card_membership,
                  color: const Color(0xFF3949AB),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text("Subscription History",
                    style: AppTextStyles.sectionHeaderStyle),
              ],
            ),
            const SizedBox(height: 16),
            ref.watch(subInfoProvider(widget.player.playerID)).when(
                loading: () => Center(child: CircularProgressIndicator()),
                error: (error, stack) {
                  log("Error fetching subscription info: $error");
                  return Center(
                      child: Text("Error fetching subscription info",
                          style: AppTextStyles.regularTextStyle));
                },
                data: (subscriptions) {
                  if (subscriptions.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.card_membership_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No Subscriptions",
                              style: AppTextStyles.subtitleTextStyle.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "This player has never purchased a subscription",
                              style: AppTextStyles.subtitleTextStyle.copyWith(
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < subscriptions.length; i++) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF3949AB).withAlpha(50),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3949AB).withAlpha(20),
                                spreadRadius: 2,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with subscription number and status
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Subscription ${i + 1}",
                                        style:
                                            AppTextStyles.highlightedTextStyle,
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: subscriptions[i]
                                                  .status
                                                  .toLowerCase() ==
                                              'active'
                                          ? Colors.green.withAlpha(38)
                                          : subscriptions[i]
                                                      .status
                                                      .toLowerCase() ==
                                                  'expired'
                                              ? Colors.orange.withAlpha(38)
                                              : Colors.red.withAlpha(38),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: subscriptions[i]
                                                    .status
                                                    .toLowerCase() ==
                                                'active'
                                            ? Colors.green
                                            : subscriptions[i]
                                                        .status
                                                        .toLowerCase() ==
                                                    'expired'
                                                ? Colors.orange
                                                : Colors.red,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      subscriptions[i].status.toTitleCase(),
                                      style: AppTextStyles.subtitleTextStyle
                                          .copyWith(
                                        color: subscriptions[i]
                                                    .status
                                                    .toLowerCase() ==
                                                'active'
                                            ? Colors.green[700]
                                            : subscriptions[i]
                                                        .status
                                                        .toLowerCase() ==
                                                    'expired'
                                                ? Colors.orange[700]
                                                : Colors.red[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Subscription period
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3949AB).withAlpha(25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 16,
                                          color: const Color(0xFF3949AB),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Subscription Period",
                                          style: AppTextStyles.subtitleTextStyle
                                              .copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF3949AB),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Start Date",
                                              style: AppTextStyles
                                                  .subtitleTextStyle
                                                  .copyWith(
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              dateFormatter.format(
                                                  subscriptions[i].startDate),
                                              style: AppTextStyles
                                                  .regularTextStyle
                                                  .copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          width: 2,
                                          height: 30,
                                          color: const Color(0xFF3949AB)
                                              .withAlpha(75),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              "Expiry Date",
                                              style: AppTextStyles
                                                  .subtitleTextStyle
                                                  .copyWith(
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              dateFormatter.format(
                                                  subscriptions[i].expiryDate),
                                              style: AppTextStyles
                                                  .regularTextStyle
                                                  .copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Hours usage section
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withAlpha(13),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.withAlpha(51),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule,
                                          size: 16,
                                          color: Colors.blue[700],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Hours Usage",
                                          style: AppTextStyles.subtitleTextStyle
                                              .copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildStatCard(
                                            "Initial Hours",
                                            "${subscriptions[i].totalMinutes / 60}",
                                            Icons.hourglass_full,
                                            Colors.green,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildStatCard(
                                            "Used Hours",
                                            "${(subscriptions[i].totalMinutes - subscriptions[i].remainingMinutes) / 60}",
                                            Icons.hourglass_bottom,
                                            Colors.orange,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildStatCard(
                                            "Remaining",
                                            "${subscriptions[i].remainingMinutes / 60}",
                                            Icons.hourglass_top,
                                            Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Financial information
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green.withAlpha(13),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.withAlpha(51),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.monetization_on,
                                          size: 16,
                                          color: Colors.green[700],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Payment Information",
                                          style: AppTextStyles.subtitleTextStyle
                                              .copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Total Fee",
                                                style: AppTextStyles
                                                    .subtitleTextStyle
                                                    .copyWith(
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                formatter.format(
                                                    subscriptions[i].totalFee),
                                                style: AppTextStyles
                                                    .amountTextStyle
                                                    .copyWith(
                                                  color: Colors.green[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          width: 2,
                                          height: 30,
                                          color: Colors.green.withAlpha(76),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                "Amount Paid",
                                                style: AppTextStyles
                                                    .subtitleTextStyle
                                                    .copyWith(
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                formatter.format(
                                                    subscriptions[i]
                                                        .amountPaid),
                                                style: AppTextStyles
                                                    .amountTextStyle
                                                    .copyWith(
                                                  color: subscriptions[i]
                                                              .amountPaid >=
                                                          subscriptions[i]
                                                              .totalFee
                                                      ? Colors.green[700]
                                                      : Colors.red[700],
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (subscriptions[i].amountPaid <
                                        subscriptions[i].totalFee) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withAlpha(25),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          "Amount Left: ${formatter.format(subscriptions[i].totalFee - subscriptions[i].amountPaid)}",
                                          style: AppTextStyles.subtitleTextStyle
                                              .copyWith(
                                            color: Colors.red[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (i < subscriptions.length - 1)
                          const SizedBox(height: 16),
                      ]
                    ],
                  );
                }),
          ]),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withAlpha(75),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color.withAlpha(200),
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.amountTextStyle.copyWith(
              color: color.withAlpha(245),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.subtitleTextStyle.copyWith(
              fontSize: 14,
              color: color.withAlpha(180),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  MyCard _buildPastSessionsCard() {
    return MyCard(
      child: Column(
        spacing: 6,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                color: const Color(0xFF3949AB),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text("Past Sessions", style: AppTextStyles.sectionHeaderStyle),
            ],
          ),
          const SizedBox(height: 16),
          ref.watch(pastSessionsProvider(widget.player.playerID)).when(
                loading: () => Center(child: CircularProgressIndicator()),
                error: (error, stack) {
                  log("Error fetching past sessions: $error\n$stack");
                  return Center(child: Text("Error fetching past sessions"));
                },
                data: (List<Session> sessions) {
                  if (sessions.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.history_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "No Past Sessions",
                              style: AppTextStyles.regularTextStyle.copyWith(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "No past sessions found for this player",
                              style: AppTextStyles.regularTextStyle.copyWith(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < sessions.length; i++) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withAlpha(25),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Session ${sessions.length - i}  |  ${DateFormat('MMMM d, yyyy').format(sessions[i].checkInTime)}",
                                    style:
                                        AppTextStyles.regularTextStyle.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF3949AB),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          const Color(0xFF3949AB).withAlpha(25),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "${sessions[i].checkOutTime.difference(sessions[i].checkInTime).inMinutes} min",
                                      style: AppTextStyles.amountTextStyle
                                          .copyWith(
                                        color: const Color(0xFF3949AB),
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildSessionDetailRow(
                                          Icons.play_arrow,
                                          "Start",
                                          DateFormat('hh:mm a')
                                              .format(sessions[i].checkInTime),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildSessionDetailRow(
                                          Icons.stop,
                                          "End",
                                          DateFormat('hh:mm a')
                                              .format(sessions[i].checkOutTime),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildSessionDetailRow(
                                          Icons.monetization_on,
                                          "Fee",
                                          NumberFormat.decimalPattern()
                                              .format(sessions[i].finalFee),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildSessionDetailRow(
                                          Icons.payment,
                                          "Paid",
                                          NumberFormat.decimalPattern()
                                              .format(sessions[i].amountPaid),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (sessions[i].minutesUsed != null) ...[
                                const SizedBox(height: 8),
                                _buildSessionDetailRow(
                                  Icons.card_membership,
                                  "Subscription Hours Used",
                                  "${(sessions[i].minutesUsed! / 60).toStringAsFixed(1)} hours",
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (i < sessions.length - 1) const SizedBox(height: 12),
                      ]
                    ],
                  );
                },
              )
        ],
      ),
    );
  }

  Widget _buildSessionDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.regularTextStyle.copyWith(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: AppTextStyles.regularTextStyle.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
