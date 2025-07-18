import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/my_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/my_card.dart';
import 'package:gravity_desktop_app/custom_widgets/my_materialbanner.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/models/subscription.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:gravity_desktop_app/providers/subscriptions_provider.dart';

enum TimeIncrement { hour, halfHour }

class ExtendTimeDialog extends ConsumerStatefulWidget {
  final Player player;

  const ExtendTimeDialog(this.player, {super.key});

  @override
  ConsumerState<ExtendTimeDialog> createState() => _ExtendTimeDialogState();
}

class _ExtendTimeDialogState extends ConsumerState<ExtendTimeDialog> {
  bool isOpenTime = false;
  int timeReservedMinutes = 0;

  Subscription? sub;

  void _incrementTime(TimeIncrement increment) {
    ref.watch(subscriptionsProvider).whenData((subs) {
      try {
        sub = subs.firstWhere(
          (s) => s.subscriptionId == widget.player.subscriptionId,
          orElse: () => throw Exception('Subscription not found'),
        );
      } catch (e) {
        if (e.toString().contains('Subscription not found')) {
          sub = null;
        } else {
          rethrow;
        }
      }

      setState(() {
        // 10 hours max
        if (!isOpenTime && timeReservedMinutes <= 60 * 9.5) {
          if (increment == TimeIncrement.hour) {
            // check subscription limits
            if (sub != null &&
                sub!.remainingMinutes < timeReservedMinutes + 60) {
              MyMaterialBanner.showBanner(
                context,
                message: 'Cannot extend time beyond subscription limits.',
                type: MessageType.error,
              );
              return;
            }

            // Increment time
            timeReservedMinutes += 60;
          } else if (increment == TimeIncrement.halfHour) {
            // check subscription limits
            if (sub != null &&
                sub!.remainingMinutes < timeReservedMinutes + 30) {
              MyMaterialBanner.showBanner(
                context,
                message: 'Cannot extend time beyond subscription limits.',
                type: MessageType.error,
              );
              return;
            }

            timeReservedMinutes += 30;
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    int hoursReserved = timeReservedMinutes ~/ 60;
    int minutesReserved = timeReservedMinutes % 60;
    return MyDialog(
      width: MediaQuery.of(context).size.width * 0.3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Extend Time For ${widget.player.name}',
                  style: AppTextStyles.sectionHeaderStyle
                      .copyWith(color: Colors.black),
                ),
                const SizedBox(height: 24),

                // Reserved Time Display
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100.withAlpha(156),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      isOpenTime
                          ? 'Open Time'
                          : '$hoursReserved Hours $minutesReserved Minutes',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Time Buttons
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    runAlignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        child: Text(
                          "+1 Hour",
                          style: AppTextStyles.primaryButtonTextStyle
                              .copyWith(fontSize: 18),
                        ),
                        onPressed: () {
                          setState(() {
                            _incrementTime(TimeIncrement.hour);
                          });
                        },
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        child: Text(
                          "+30 Minutes",
                          style: AppTextStyles.primaryButtonTextStyle
                              .copyWith(fontSize: 18),
                        ),
                        onPressed: () {
                          setState(() {
                            _incrementTime(TimeIncrement.halfHour);
                          });
                        },
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        child: Text(
                          "Reset",
                          style: AppTextStyles.primaryButtonTextStyle
                              .copyWith(fontSize: 18),
                        ),
                        onPressed: () {
                          setState(() {
                            timeReservedMinutes = 0;
                            isOpenTime = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Open Time Toggle
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scale: 1.4,
                          child: Checkbox(
                            value: isOpenTime,
                            onChanged: (value) {
                              setState(() {
                                isOpenTime = value ?? false;
                                if (isOpenTime) {
                                  hoursReserved = 0;
                                  minutesReserved = 0;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Open Time',
                          style: AppTextStyles.tableCellStyle,
                        ),
                      ],
                    ),
                  ),
                ),

                // Subscription warning section
                Consumer(
                  builder: (context, ref, child) {
                    final subscriptionsAsync = ref.watch(subscriptionsProvider);

                    return subscriptionsAsync.when(
                      data: (subscriptions) {
                        Subscription? sub;
                        try {
                          sub = subscriptions.firstWhere(
                            (s) => s.playerId == widget.player.playerID,
                          );
                        } catch (e) {
                          // No subscription found
                          return const SizedBox.shrink();
                        }

                        final totalRequestedMinutes =
                            hoursReserved * 60 + minutesReserved;
                        final showWarning =
                            (sub.remainingMinutes < totalRequestedMinutes &&
                                    !isOpenTime) ||
                                isOpenTime;

                        if (showWarning) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Text(
                              'Warning: This player has only ${sub.remainingMinutes ~/ 60} hours and ${sub.remainingMinutes % 60} minutes remaining in their subscription.',
                              style: AppTextStyles.subtitleTextStyle.copyWith(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (error, stack) => const SizedBox.shrink(),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Cancel',
                  style: AppTextStyles.primaryButtonTextStyle,
                ),
              ),
              ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(currentPlayersProvider.notifier)
                        .extendPlayerTime(widget.player,
                            timeToExtend:
                                Duration(minutes: timeReservedMinutes),
                            isOpenTime: isOpenTime);

                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  style: AppButtonStyles.primaryButton,
                  child: Text(
                    'Extend',
                    style: AppTextStyles.primaryButtonTextStyle,
                  )),
            ],
          )
        ],
      ),
    );
  }
}
