import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/time_reservation_card.dart';
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

  void _incrementTime(TimeIncrement increment, subs) {
    try {
      if (widget.player.subscriptionId != null) {
        sub = subs.firstWhere(
        (s) => s.subscriptionId == widget.player.subscriptionId,
        orElse: () => throw Exception('Subscription not found'),
      );
      }
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
          if (sub != null && sub!.remainingMinutes < timeReservedMinutes + 60) {
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
          if (sub != null && sub!.remainingMinutes < timeReservedMinutes + 30) {
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
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionsAsync = ref.watch(subscriptionsProvider);
    return subscriptionsAsync.when(
        loading: () =>
            MyDialog(child: Center(child: CircularProgressIndicator())),
        error: (error, stackTrace) => MyDialog(
              child: MyCard(
                child: Text(
                  'Error loading subscriptions: $error',
                  style: AppTextStyles.subtitleTextStyle.copyWith(
                    color: Colors.red,
                  ),
                ),
              ),
            ),
        data: (subs) {
          return MyDialog(
            width: MediaQuery.of(context).size.width * 0.3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TimeReservationCard(
                  title: 'Extend Time For ${widget.player.name}',
                  time: Duration(minutes: timeReservedMinutes),
                  isOpenTime: isOpenTime,
                  oneHourOnPressed: () {
                    setState(() {
                      _incrementTime(TimeIncrement.hour, subs);
                    });
                  },
                  halfHourOnPressed: () {
                    setState(() {
                      _incrementTime(TimeIncrement.halfHour, subs);
                    });
                  },
                  resetOnPressed: () {
                    setState(() {
                      timeReservedMinutes = 0;
                      isOpenTime = false;
                    });
                  },
                  isOpenTimeOnChanged: (value) {
                    setState(() {
                      isOpenTime = value ?? false;
                      if (isOpenTime) {
                        timeReservedMinutes = 0;
                      }
                    });
                  },
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
        });
  }
}
