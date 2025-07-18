import 'package:flutter/material.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/my_card.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';

class TimeReservationCard extends StatefulWidget {
  final String title;
  final Duration time;
  final bool isOpenTime;
  final VoidCallback oneHourOnPressed;
  final VoidCallback halfHourOnPressed;
  final VoidCallback resetOnPressed;
  final ValueChanged<bool?> isOpenTimeOnChanged;

  final bool warningCondition;
  final String? warningText;

  const TimeReservationCard(
      {super.key,
      required this.title,
      required this.time,
      required this.isOpenTime,
      required this.oneHourOnPressed,
      required this.halfHourOnPressed,
      required this.resetOnPressed,
      required this.isOpenTimeOnChanged,
      this.warningCondition = false,
      this.warningText});

  @override
  State<TimeReservationCard> createState() => _TimeReservationCardState();
}

class _TimeReservationCardState extends State<TimeReservationCard> {
  @override
  Widget build(BuildContext context) {
    int hoursReserved = widget.time.inHours;
    int minutesReserved = widget.time.inMinutes.remainder(60);
    return MyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style:
                AppTextStyles.sectionHeaderStyle.copyWith(color: Colors.black),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100.withAlpha(156),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                widget.isOpenTime
                    ? 'Open Time'
                    : '$hoursReserved Hours $minutesReserved Minutes',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runAlignment: WrapAlignment.center,
              alignment: WrapAlignment.center,
              runSpacing: 16,
              children: [
                ElevatedButton(
                  onPressed: widget.oneHourOnPressed,
                  style: AppButtonStyles.primaryButton,
                  child: Text('+1 Hour',
                      style: AppTextStyles.primaryButtonTextStyle),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: widget.halfHourOnPressed,
                  style: AppButtonStyles.primaryButton,
                  child: Text('+30 Minutes',
                      style: AppTextStyles.primaryButtonTextStyle),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: widget.resetOnPressed,
                  style: AppButtonStyles.secondaryButton,
                  child: Text(
                    'Reset',
                    style: AppTextStyles.secondaryButtonTextStyle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: widget.isOpenTime,
                  onChanged: (value) {
                    widget.isOpenTimeOnChanged(value);
                  },
                ),
                Text(
                  'Open Time',
                  style: AppTextStyles.regularTextStyle,
                ),
              ],
            ),
          ),
          if (widget.warningCondition)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                widget.warningText ?? '',
                style: AppTextStyles.subtitleTextStyle.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
